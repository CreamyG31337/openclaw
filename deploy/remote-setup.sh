#!/usr/bin/env bash
# OpenClaw Docker setup — run this on your Ubuntu server (with Docker)
set -eu

OPENCLAW_REPO="${OPENCLAW_REPO:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_REPO_BRANCH="${OPENCLAW_REPO_BRANCH:-}"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/openclaw}"
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"

echo "==> Checking Docker..."
if ! command -v docker &>/dev/null; then
  echo "Docker not found. Install with: curl -fsSL https://get.docker.com | sh"
  exit 1
fi
USE_DOCKER_RUN=0
if docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null && docker-compose version &>/dev/null; then
  COMPOSE_CMD="docker-compose"
else
  echo "Docker Compose not found (will use 'docker run' instead)."
  USE_DOCKER_RUN=1
fi
if [ "$USE_DOCKER_RUN" = 0 ]; then
  echo "==> Using: $COMPOSE_CMD"
fi

echo "==> Creating config dirs..."
mkdir -p "$OPENCLAW_CONFIG_DIR" "$OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_CONFIG_DIR/cli-auth/claude" "$OPENCLAW_CONFIG_DIR/cli-auth/gemini" "$OPENCLAW_CONFIG_DIR/cli-auth/codex"

echo "==> Cloning OpenClaw..."
if [[ -d "$OPENCLAW_DIR/.git" ]]; then
  (
    cd "$OPENCLAW_DIR"
    if [[ -n "$OPENCLAW_REPO" ]]; then
      git remote set-url origin "$OPENCLAW_REPO"
    fi
    git fetch --all
    if [[ -n "$OPENCLAW_REPO_BRANCH" ]]; then
      if ! git rev-parse --verify --quiet "origin/$OPENCLAW_REPO_BRANCH" >/dev/null; then
        echo "ERROR: Branch 'origin/$OPENCLAW_REPO_BRANCH' not found in $OPENCLAW_REPO"
        echo "Check OPENCLAW_REPO_BRANCH in deploy/.env and push that branch to origin."
        exit 1
      fi
      git reset --hard "origin/$OPENCLAW_REPO_BRANCH"
      git checkout -B "$OPENCLAW_REPO_BRANCH" "origin/$OPENCLAW_REPO_BRANCH"
    else
      git reset --hard
      git pull
    fi
  )
else
  if [[ -n "$OPENCLAW_REPO_BRANCH" ]]; then
    git clone -b "$OPENCLAW_REPO_BRANCH" "$OPENCLAW_REPO" "$OPENCLAW_DIR"
  else
    git clone "$OPENCLAW_REPO" "$OPENCLAW_DIR"
  fi
fi
cd "$OPENCLAW_DIR"

echo "==> Resolving gateway token..."
OPENCLAW_TOKEN_FILE="$OPENCLAW_CONFIG_DIR/gateway-token"
if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  echo "==> Using OPENCLAW_GATEWAY_TOKEN from environment"
elif [[ -f "$OPENCLAW_TOKEN_FILE" ]]; then
  OPENCLAW_GATEWAY_TOKEN="$(cat "$OPENCLAW_TOKEN_FILE")"
  echo "==> Reusing gateway token from $OPENCLAW_TOKEN_FILE"
elif [[ -f .env ]] && grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env 2>/dev/null; then
  OPENCLAW_GATEWAY_TOKEN="$(grep '^OPENCLAW_GATEWAY_TOKEN=' .env | cut -d= -f2-)"
  echo "==> Reusing existing gateway token from .env"
else
  if command -v openssl &>/dev/null; then
    OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
  else
    OPENCLAW_GATEWAY_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  fi
  echo "==> Generated new gateway token"
fi
printf '%s\n' "$OPENCLAW_GATEWAY_TOKEN" > "$OPENCLAW_TOKEN_FILE"
chmod 600 "$OPENCLAW_TOKEN_FILE" 2>/dev/null || true

echo "==> Writing .env..."
export OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR OPENCLAW_GATEWAY_PORT \
  OPENCLAW_BRIDGE_PORT OPENCLAW_GATEWAY_BIND OPENCLAW_GATEWAY_TOKEN
export OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-openclaw:local}"

cat > .env << ENV
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_GATEWAY_PORT=$OPENCLAW_GATEWAY_PORT
OPENCLAW_BRIDGE_PORT=$OPENCLAW_BRIDGE_PORT
OPENCLAW_GATEWAY_BIND=$OPENCLAW_GATEWAY_BIND
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN
OPENCLAW_IMAGE=$OPENCLAW_IMAGE
ENV

# Docker override: allow gateway to reach host (Ollama on host) + optional Z.AI env
echo "==> Adding Docker override (Ollama on host + optional Z.AI)..."
# So the container can reach host's Ollama at host.docker.internal:11434
if [[ -n "${ZAI_API_KEY:-}" ]]; then
  printf 'ZAI_API_KEY=%s\n' "$ZAI_API_KEY" >> .env
fi
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  printf 'OPENAI_API_KEY=%s\n' "$OPENAI_API_KEY" >> .env
fi
cat > docker-compose.override.yml << OVERRIDE
services:
  openclaw-gateway:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - \${OPENCLAW_CONFIG_DIR}/cli-auth/claude:/home/node/.claude
      - \${OPENCLAW_CONFIG_DIR}/cli-auth/gemini:/home/node/.gemini
      - \${OPENCLAW_CONFIG_DIR}/cli-auth/codex:/home/node/.codex
OVERRIDE
if [[ -n "${ZAI_API_KEY:-}" ]] || [[ -n "${OPENAI_API_KEY:-}" ]] || [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  cat >> docker-compose.override.yml << 'OVERRIDE'
    environment:
      - ZAI_API_KEY=${ZAI_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
  openclaw-cli:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - ZAI_API_KEY=${ZAI_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
OVERRIDE
else
  cat >> docker-compose.override.yml << 'OVERRIDE'
  openclaw-cli:
    extra_hosts:
      - "host.docker.internal:host-gateway"
OVERRIDE
fi

# Initial openclaw.json when none exists: Z.AI (if key set) + Ollama on host
if [[ ! -f "$OPENCLAW_CONFIG_DIR/openclaw.json" ]]; then
  mkdir -p "$OPENCLAW_CONFIG_DIR"
  PRIMARY="${ZAI_API_KEY:+zai/glm-4.7}"
  PRIMARY="${PRIMARY:-ollama/llama3.2}"
  cat > "$OPENCLAW_CONFIG_DIR/openclaw.json" << CONFIG
{
  "gateway": {
    "mode": "local",
    "controlUi": { "allowInsecureAuth": true, "dangerouslyDisableDeviceAuth": true },
    "auth": { "mode": "token", "token": "$OPENCLAW_GATEWAY_TOKEN" }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "$PRIMARY" },
      "models": {
        "zai/glm-4.7": { "alias": "Z.AI" },
        "ollama/llama3.2": { "alias": "Ollama" },
        "ollama/llama3.1": { "alias": "Llama 3.1" },
        "ollama/mistral": { "alias": "Mistral" },
        "ollama/codellama": { "alias": "CodeLlama" }
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "ollama": {
        "baseUrl": "http://host.docker.internal:11434/v1",
        "apiKey": "ollama",
        "models": [
          {
            "id": "llama3.2",
            "name": "Llama 3.2",
            "api": "openai-completions",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 4096
          },
          {
            "id": "llama3.1",
            "name": "Llama 3.1",
            "api": "openai-completions",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 4096
          },
          {
            "id": "mistral",
            "name": "Mistral",
            "api": "openai-completions",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 32000,
            "maxTokens": 4096
          },
          {
            "id": "codellama",
            "name": "CodeLlama",
            "api": "openai-completions",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 16384,
            "maxTokens": 4096
          }
        ]
      }
    }
  }
}
CONFIG
  echo "==> Created openclaw.json with default $PRIMARY and Ollama provider (host.docker.internal:11434)"
else
  # Ensure existing config has Control UI auth relaxed (token-only, no device identity)
  # and keep gateway auth token aligned with deploy token unless password mode is explicitly set.
  if [[ -f "$OPENCLAW_CONFIG_DIR/openclaw.json" ]]; then
    if python3 -c "
import json, os, sys
p = os.environ.get('OPENCLAW_CONFIG_DIR', os.path.expanduser('~/.openclaw')) + '/openclaw.json'
try:
    with open(p) as f: c = json.load(f)
    c.setdefault('gateway', {})
    c['gateway'].setdefault('controlUi', {})
    c['gateway']['controlUi']['allowInsecureAuth'] = True
    c['gateway']['controlUi']['dangerouslyDisableDeviceAuth'] = True
    auth = c['gateway'].setdefault('auth', {})
    mode = auth.get('mode')
    if mode is None or mode == 'token':
      auth['mode'] = 'token'
      auth['token'] = os.environ.get('OPENCLAW_GATEWAY_TOKEN', auth.get('token'))
    with open(p, 'w') as f: json.dump(c, f, indent=2)
except PermissionError:
    sys.exit(1)
"; then
      echo "==> Updated openclaw.json: Control UI auth settings and gateway token (when token mode)"
    else
      echo "==> WARNING: Could not update openclaw.json (permission denied). On the server run: sudo chown -R \$(whoami): $OPENCLAW_CONFIG_DIR"
    fi
  fi
fi

# Patch Dockerfile: add Python venv (--copies) so skills like searxng get httpx/rich without PYTHONPATH
if ! grep -q 'openclaw-venv' Dockerfile 2>/dev/null; then
  echo "==> Patching Dockerfile (Python venv for skills)..."
  VENV_SNIP=$(mktemp)
  cat << 'VENVSNIP' > "$VENV_SNIP"
# Python venv for skills (PEP 723 scripts: searxng etc.) — isolated so python3 finds httpx, rich
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && python3 -m venv --copies /opt/openclaw-venv \
    && /opt/openclaw-venv/bin/pip install --no-cache-dir httpx rich \
    && chown -R node:node /opt/openclaw-venv
ENV PATH="/opt/openclaw-venv/bin:${PATH}"
# ClawHub CLI so the container (and agent) can run clawhub search / install
RUN npm i -g clawhub
VENVSNIP
  python3 << PYEOF
p = "Dockerfile"
with open(p) as f:
    lines = f.readlines()
with open("$VENV_SNIP") as f:
    snip = f.read()
out = []
for line in lines:
    if line.strip() == "USER node":
        out.append(snip.rstrip() + "\n\n")
    out.append(line)
with open(p, "w") as f:
    f.writelines(out)
PYEOF
  rm -f "$VENV_SNIP"
else
  echo "==> Dockerfile already has Python venv patch, skipping"
fi

# If venv is present but git is not in the image, add git so the agent can clone/merge PRs
if grep -q 'openclaw-venv' Dockerfile 2>/dev/null && ! grep -q 'install.*git' Dockerfile 2>/dev/null; then
  echo "==> Adding git to Dockerfile..."
  python3 << 'PYEOF'
p = "Dockerfile"
with open(p) as f:
    lines = f.readlines()
out = []
for line in lines:
    if line.strip() == "USER node":
        out.append("RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git && apt-get clean && rm -rf /var/lib/apt/lists/*\n\n")
    out.append(line)
with open(p, "w") as f:
    f.writelines(out)
PYEOF
fi

# If venv is present but ClawHub is not, add ClawHub so redeploys get it without user action
if grep -q 'openclaw-venv' Dockerfile 2>/dev/null && ! grep -q 'clawhub' Dockerfile 2>/dev/null; then
  echo "==> Adding ClawHub to Dockerfile..."
  python3 << 'PYEOF'
p = "Dockerfile"
with open(p) as f:
    lines = f.readlines()
out = []
for line in lines:
    if line.strip() == "USER node":
        out.append("RUN npm i -g clawhub\n\n")
    out.append(line)
with open(p, "w") as f:
    f.writelines(out)
PYEOF
fi

# Write pull-and-restart.sh early (before long build) so it exists even if deploy times out
IMAGE_FOR_SCRIPT="${OPENCLAW_REGISTRY_IMAGE:-$OPENCLAW_IMAGE}"
echo "==> Writing pull-and-restart.sh (run on server for immediate image pull + restart)..."
if [ "$USE_DOCKER_RUN" = 1 ]; then
  cat > "$OPENCLAW_DIR/pull-and-restart.sh" << PULLRESTART
#!/usr/bin/env bash
set -eu
cd "$OPENCLAW_DIR"
[ -f .env ] && set -a && . ./.env && set +a
docker pull "\${OPENCLAW_IMAGE:?}"
docker rm -f openclaw-gateway 2>/dev/null || true
GATEWAY_ENV="-e HOME=/home/node -e TERM=xterm-256color -e OPENCLAW_GATEWAY_TOKEN=\$OPENCLAW_GATEWAY_TOKEN"
[ -n "\${ZAI_API_KEY:-}" ] && GATEWAY_ENV="\$GATEWAY_ENV -e ZAI_API_KEY=\$ZAI_API_KEY"
[ -n "\${OPENAI_API_KEY:-}" ] && GATEWAY_ENV="\$GATEWAY_ENV -e OPENAI_API_KEY=\$OPENAI_API_KEY"
[ -n "\${OPENROUTER_API_KEY:-}" ] && GATEWAY_ENV="\$GATEWAY_ENV -e OPENROUTER_API_KEY=\$OPENROUTER_API_KEY"
docker run -d --name openclaw-gateway --restart unless-stopped \\
  -v "$OPENCLAW_CONFIG_DIR:/home/node/.openclaw" \\
  -v "$OPENCLAW_WORKSPACE_DIR:/home/node/.openclaw/workspace" \\
  -v "$OPENCLAW_CONFIG_DIR/cli-auth/claude:/home/node/.claude" \\
  -v "$OPENCLAW_CONFIG_DIR/cli-auth/gemini:/home/node/.gemini" \\
  -v "$OPENCLAW_CONFIG_DIR/cli-auth/codex:/home/node/.codex" \\
  -p "\${OPENCLAW_GATEWAY_PORT:-18789}:18789" -p "\${OPENCLAW_BRIDGE_PORT:-18790}:18790" \\
  --add-host host.docker.internal:host-gateway \\
  \$GATEWAY_ENV \\
  "\$OPENCLAW_IMAGE" node dist/index.js gateway --bind "\${OPENCLAW_GATEWAY_BIND:-lan}" --port 18789
PULLRESTART
else
  cat > "$OPENCLAW_DIR/pull-and-restart.sh" << 'PULLRESTART'
#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
docker compose pull openclaw-gateway
docker compose up -d openclaw-gateway
PULLRESTART
fi
chmod +x "$OPENCLAW_DIR/pull-and-restart.sh"

# Use a registry image (pull only, no auth) so Watchtower can update; or build and optionally push
GATEWAY_IMAGE="$OPENCLAW_IMAGE"
if [ -n "${OPENCLAW_REGISTRY_IMAGE:-}" ] && [ -z "${OPENCLAW_REGISTRY_USER:-}" ]; then
  echo "==> Pulling image (no build): $OPENCLAW_REGISTRY_IMAGE"
  docker pull "$OPENCLAW_REGISTRY_IMAGE"
  GATEWAY_IMAGE="$OPENCLAW_REGISTRY_IMAGE"
else
  echo "==> Building Docker image (this may take several minutes)..."
  docker build -t "$OPENCLAW_IMAGE" -f Dockerfile .
  if [ -n "${OPENCLAW_REGISTRY_IMAGE:-}" ]; then
    echo "==> Pushing image to registry ($OPENCLAW_REGISTRY_IMAGE)..."
    docker tag "$OPENCLAW_IMAGE" "$OPENCLAW_REGISTRY_IMAGE"
    if [ -n "${OPENCLAW_REGISTRY_USER:-}" ] && [ -n "${OPENCLAW_REGISTRY_PASSWORD:-}" ]; then
      REGISTRY_HOST="${OPENCLAW_REGISTRY_IMAGE%%/*}"
      if [ "$REGISTRY_HOST" = "$OPENCLAW_REGISTRY_IMAGE" ]; then
        REGISTRY_HOST=""
      fi
      echo "${OPENCLAW_REGISTRY_PASSWORD}" | docker login -u "$OPENCLAW_REGISTRY_USER" --password-stdin ${REGISTRY_HOST:+$REGISTRY_HOST}
    fi
    docker push "$OPENCLAW_REGISTRY_IMAGE"
    GATEWAY_IMAGE="$OPENCLAW_REGISTRY_IMAGE"
  fi
fi

echo "==> Starting OpenClaw gateway..."
if [ "$USE_DOCKER_RUN" = 1 ]; then
  docker rm -f openclaw-gateway 2>/dev/null || true
  GATEWAY_ENV="-e HOME=/home/node -e TERM=xterm-256color -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN"
  [ -n "${ZAI_API_KEY:-}" ] && GATEWAY_ENV="$GATEWAY_ENV -e ZAI_API_KEY=$ZAI_API_KEY"
  [ -n "${OPENAI_API_KEY:-}" ] && GATEWAY_ENV="$GATEWAY_ENV -e OPENAI_API_KEY=$OPENAI_API_KEY"
  [ -n "${OPENROUTER_API_KEY:-}" ] && GATEWAY_ENV="$GATEWAY_ENV -e OPENROUTER_API_KEY=$OPENROUTER_API_KEY"
  docker run -d --name openclaw-gateway --restart unless-stopped \
    -v "$OPENCLAW_CONFIG_DIR:/home/node/.openclaw" \
    -v "$OPENCLAW_WORKSPACE_DIR:/home/node/.openclaw/workspace" \
    -v "$OPENCLAW_CONFIG_DIR/cli-auth/claude:/home/node/.claude" \
    -v "$OPENCLAW_CONFIG_DIR/cli-auth/gemini:/home/node/.gemini" \
    -v "$OPENCLAW_CONFIG_DIR/cli-auth/codex:/home/node/.codex" \
    -p "${OPENCLAW_GATEWAY_PORT}:18789" -p "${OPENCLAW_BRIDGE_PORT}:18790" \
    --add-host host.docker.internal:host-gateway \
    $GATEWAY_ENV \
    "$GATEWAY_IMAGE" node dist/index.js gateway --bind "$OPENCLAW_GATEWAY_BIND" --port 18789
else
  $COMPOSE_CMD up -d openclaw-gateway
fi

echo ""
echo "=============================================="
echo "OpenClaw gateway is running."
echo "=============================================="
echo "Config:    $OPENCLAW_CONFIG_DIR"
echo "Workspace: $OPENCLAW_WORKSPACE_DIR"
echo "Port:      $OPENCLAW_GATEWAY_PORT (gateway), $OPENCLAW_BRIDGE_PORT (bridge)"
echo "Token:     $OPENCLAW_GATEWAY_TOKEN"
echo ""
echo "Save the token above — you need it to connect (WebChat, CLI, apps)."
echo ""
echo "Next steps (optional):"
echo "  1. Run onboarding (model, channels):"
echo "     cd $OPENCLAW_DIR && docker compose run --rm openclaw-cli onboard --no-install-daemon"
echo "  2. View logs:"
echo "     docker compose -f $OPENCLAW_DIR/docker-compose.yml logs -f openclaw-gateway"
echo "  3. From another machine, open: http://<this-server-ip>:$OPENCLAW_GATEWAY_PORT"
echo ""
echo "  4. Control UI over Tailscale (open this URL so the UI gets the token automatically):"
echo "     https://YOUR_TAILSCALE_HOST/?token=$OPENCLAW_GATEWAY_TOKEN"
echo "     (Replace YOUR_TAILSCALE_HOST with your machine's Tailscale name or MagicDNS.)"
echo "  5. Immediate update (no Wait for Watchtower): run ./pull-and-restart.sh on the server, or from PC: .\\trigger-update.ps1"
echo "=============================================="
