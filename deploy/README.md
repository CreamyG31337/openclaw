# OpenClaw Docker deploy

Deploys [OpenClaw](https://github.com/openclaw/openclaw) on your Ubuntu server using Docker.

**Coding (Claude, Gemini, ChatGPT):** See [CODING.md](CODING.md) for how OpenClaw helps with coding and how to use command-line tools (Claude Code CLI, Gemini CLI) with your subscriptions, plus skills in `deploy/skills/`.

**Registry + Watchtower (auto-update):** See [REGISTRY-AND-WATCHTOWER.md](REGISTRY-AND-WATCHTOWER.md) and run `.\deploy-with-registry.ps1` to build from your fork, push to ghcr.io, and let Watchtower update the gateway.

## Prerequisites

- **Server:** Your Ubuntu server reachable via SSH
- **Windows:** SSH key
- **Server:** Docker and Docker Compose installed ([install Docker](https://docs.docker.com/engine/install/ubuntu/))

**Sensitive config:** Copy `deploy/.env.example` to `deploy/.env` (`.env` is gitignored) and set at least `OPENCLAW_SERVER`, `OPENCLAW_DEPLOY_USER`, and `OPENCLAW_KEY_PATH`. The deploy scripts load `.env` automatically so you don’t leak hostnames or tokens in the repo.

## One-click sync + deploy (recommended)

If you want "update from upstream + push fork branch + deploy" in one step, use:

```bat
run-sync-and-deploy.cmd
```

This runs `sync-clean-upstream-and-deploy.ps1`, which:
1. Syncs `openclaw-clean` (or `OPENCLAW_LOCAL_REPO_DIR`) with upstream `origin/main`
2. Rebases your deploy branch (`OPENCLAW_REPO_BRANCH`) onto upstream
3. Pushes that branch to your fork (`OPENCLAW_REPO`)
4. Runs `deploy.ps1`

Required in `deploy/.env` for this flow:
- `OPENCLAW_REPO=https://github.com/<you>/openclaw.git`
- `OPENCLAW_REPO_BRANCH=deploy-clean` (or your branch name)

## Before you deploy (quick checks)

1. **SSH works** from your machine:
   ```powershell
   ssh -i YOUR_KEY_PATH YOUR_USER@YOUR_SERVER "echo OK"
   ```
   Set `$env:OPENCLAW_SERVER` and `$env:OPENCLAW_DEPLOY_USER` (and key path in the script if needed) so deploy uses your server and user.

2. **Docker on the server** — if not installed:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
   Then `docker compose version` should work.

3. **Ollama (optional)** — only if you want local models. Install and run with:
   ```bash
   OLLAMA_HOST=0.0.0.0 ollama serve
   ```
   You can deploy without Ollama; Z.AI will work on its own.

No other config is required. Set `ZAI_API_KEY` in `deploy/.env` if you want the Z.AI (GLM) model; the script generates the gateway token on the server.

## Deploy

From this folder (or from `openclaw` root):

```powershell
cd deploy
.\deploy.ps1
```

The script uses `$env:OPENCLAW_DEPLOY_USER` and `$env:OPENCLAW_SERVER` if set. To use a different user or server:

```powershell
$env:OPENCLAW_DEPLOY_USER = "ubuntu"
.\deploy.ps1
```

The script will:

1. SSH to your server with your key (from `deploy/.env`)
2. Clone the OpenClaw repo (or pull if already cloned)
3. Generate a gateway token and write `.env`
4. Build the Docker image (can take several minutes)
5. Start the gateway with `docker compose up -d`

**Save the token** printed at the end — you need it to connect from WebChat, CLI, or apps.

Token behavior:
- Deploy now keeps a stable token by default (stored server-side at `~/.openclaw/gateway-token`).
- If you set `OPENCLAW_GATEWAY_TOKEN` in `deploy/.env`, deploy will always enforce that exact token.
- `deploy.ps1` also prints the current token again at the end as a post-check.

### Z.AI (GLM) model

The deploy script is set up to use your **Z.AI API key** so the assistant uses the Z.AI (GLM) provider by default. The key is passed to the server and written into the gateway’s environment; if no `openclaw.json` exists yet, the default model is set to `zai/glm-4.7`. To use a different key or none, set before running:

```powershell
$env:ZAI_API_KEY = "your-key"   # or leave unset to skip Z.AI
.\deploy.ps1
```

Set `ZAI_API_KEY` in `deploy/.env` (or leave unset to skip Z.AI).

### Ollama (local on server)

If **Ollama** is running on the same server (e.g. `ollama serve` on port 11434), the deploy configures OpenClaw to use it:

- The gateway container gets **host access** via `host.docker.internal` so it can call `http://host.docker.internal:11434/v1` (Ollama’s OpenAI-compatible API).
- An **ollama** provider is added to `openclaw.json` with models: `llama3.2`, `llama3.1`, `mistral`, `codellama`. Use the **model dropdown** on the chat page (or change the default in settings) to switch.
- If no config exists yet and Z.AI is not set, the default model is **ollama/llama3.2**; otherwise the default stays **zai/glm-4.7** with Ollama available as an extra model.

**Adding new Ollama models (e.g. dolphin-mixtral):** OpenClaw only uses Ollama models that are listed in `openclaw.json`. If you pull a new model with `ollama pull dolphin-mixtral:8x7b` and switch to it in the UI but get no responses, the model is not registered. Either run the sync script on the server (so `openclaw.json` is updated from `ollama list`), or add the model manually. From your PC: `.\run-sync-ollama.ps1` (requires `deploy/.env`). On the server: `python3 ~/openclaw/deploy/sync-ollama-models.py` (uses `~/.openclaw/openclaw.json`). Then restart the gateway or switch model again. In the UI use **lowercase** `ollama/dolphin-mixtral:8x7b` (not `Ollama/...`).

Ensure Ollama is listening on `0.0.0.0:11434` (or that the Docker host gateway can reach it). On Linux, `OLLAMA_HOST=0.0.0.0 ollama serve` or set `OLLAMA_HOST` in your Ollama environment.

### Model dropdown: keep it to Ollama + Z.AI only

The Control UI model dropdown reads the **allowlist** from `openclaw.json` under:
`agents.defaults.models`. If it is empty, the UI will show every model in the catalog.

**Recommended workflow:**
1. Run `.\run-sync-ollama.ps1` from this repo after pulling new Ollama models.
   - It will keep existing non‑Ollama entries and add all installed `ollama/*` models.
   - It also adds all `zai/*` models so you can use any GLM model your key supports.
2. Restart the gateway after changes (the script already does this).

If the dropdown still shows everything, you are likely running an older image. Re-run
`.\deploy.ps1` so the gateway/UI updates land in the container image.

## After deploy

- **Onboarding (model, channels):** SSH in and run  
  `cd ~/openclaw && docker compose run --rm openclaw-cli onboard --no-install-daemon`
- **Logs:**  
  `ssh -i YOUR_KEY YOUR_USER@YOUR_SERVER "cd ~/openclaw && docker compose logs -f openclaw-gateway"`
- **Web UI:** From another machine, open `http://<server-ip>:18789` and use the token when prompted.

### Watchtower (auto-update)

If you already run **Watchtower** (or Portainer) on the server, it can pull a new image and restart the gateway — but only if the gateway runs from a **registry image** (not a local tag like `openclaw:local`).

**Searxng + auto-update:** Use **Option B** (your own registry, build + push). The deploy script patches the Dockerfile on the server (Python venv + ClawHub), builds the image, and pushes it to your registry. That image has searxng support, and Watchtower can update when you push a new build (re-run `.\deploy.ps1` or use CI).

**Option A — Public image (no login):** Use a community image; deploy pulls it and runs from it. Watchtower/Portainer can update when the publisher pushes.

```powershell
$env:OPENCLAW_USE_PUBLIC_IMAGE = "1"
.\deploy.ps1
```

That uses **`docker.io/heimdall777/openclaw:latest`** (community image built from [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw)). No username or password. The script skips the build, pulls the image, and runs the gateway from it.  
*Note:* That image does not include the Python venv or ClawHub patches from this repo; for those, build locally (don’t set `OPENCLAW_USE_PUBLIC_IMAGE`).

**Option B — Your own registry (build + push, searxng + Watchtower):** Set `OPENCLAW_REGISTRY_IMAGE` and credentials. The script clones the repo, patches the Dockerfile (venv + ClawHub), builds the image, pushes it to your registry, and runs the gateway from that image. The image includes searxng support. Watchtower can then auto-update when you push a new build: re-run `.\deploy.ps1` from this repo (or run your CI job that builds and pushes the same image tag).

```powershell
$env:OPENCLAW_REGISTRY_IMAGE   = "ghcr.io/YOUR_USER/openclaw:latest"
$env:OPENCLAW_REGISTRY_USER   = "your-username"
$env:OPENCLAW_REGISTRY_PASSWORD = "your-token-or-password"
.\deploy.ps1
```

### "Disconnected (1008): control ui requires HTTPS or localhost"

If you open the Control UI over **plain HTTP** from another machine (e.g. `http://<server-ip>:18789`), the browser runs in a **non-secure context** and OpenClaw blocks the WebSocket by default. The deploy config sets **`gateway.controlUi.allowInsecureAuth: true`** and **`gateway.controlUi.dangerouslyDisableDeviceAuth: true`** so token-only auth works over HTTP on a trusted LAN (no device identity required). **Recommended for production:** use HTTPS (e.g. Tailscale Serve below or a reverse proxy with TLS) and leave these false.

## Tailscale Serve (HTTPS, Tailnet-only)

Use **Tailscale Serve** so the Control UI is only reachable over your Tailnet, with HTTPS and no open ports.

### 1. Prerequisites on the server

- Tailscale installed and logged in: `tailscale status` should show the machine.
- OpenClaw gateway running (e.g. Docker on port **18789**).

### 2. Enable Serve (one-time)

**From Windows (recommended):** run the script (you’ll be prompted for your sudo password on the server):

```powershell
cd deploy
.\enable-tailscale-serve.ps1
```

**Or** SSH in and run:

```bash
# Proxy HTTPS to the Control UI on localhost (Tailscale handles TLS)
sudo tailscale serve https / http://127.0.0.1:18789
```

Tailscale will serve the UI at your machine’s **Tailscale name** (e.g. `https://your-machine`) or its MagicDNS name (e.g. `https://your-machine.your-tailnet.ts.net`).

### 3. Open the Control UI

From any device on your Tailnet (signed into Tailscale):

- Open: **`https://YOUR_TAILSCALE_NAME`** (or your MagicDNS URL).
- Use the **gateway token** when the UI asks for it.

Only Tailnet devices can reach this URL; the rest of the internet cannot.

### 4. Useful commands

| Command | Purpose |
|--------|--------|
| `sudo tailscale serve status` | Show current serve config. |
| `sudo tailscale serve reset` | Turn off serve and clear config. |
| `sudo tailscale serve https / http://127.0.0.1:18789` | (Re)enable HTTPS → Control UI. |

### 5. Persist across reboots

Tailscale Serve config is stored by Tailscale and **persists across reboots**. You only need to run the `tailscale serve` command once (or again if you run `tailscale serve reset`).

### 6. Security note

With Serve over HTTPS, you can remove the “allow insecure” options from `~/.openclaw/openclaw.json` if you want stricter auth (e.g. require device identity). Then the Control UI will only work over HTTPS (e.g. via Tailscale Serve).

## Agent can modify its own environment

By default the agent runs in a sandbox and `exec` may run on a separate host. To let the agent **modify its own environment** (e.g. edit `openclaw.json`, install skills, run commands inside the gateway container):

- Set **sandbox off** so exec runs in the gateway process/container.
- Set **exec host** to `gateway` so commands run there by default.

**From Windows (recommended):**

```powershell
cd deploy
.\enable-agent-env-modify.ps1
```

This copies `enable-agent-env-modify.py` to the server, runs it to update `~/.openclaw/openclaw.json` with `agents.defaults.sandbox.mode: off` and `tools.exec.host: gateway`, then restarts the gateway.

**Or** SSH in and run:

```bash
# On the server (e.g. after copying enable-agent-env-modify.py to your home)
python3 ~/enable-agent-env-modify.py
cd ~/openclaw && docker compose restart openclaw-gateway
```

**Security:** With sandbox off, the agent can change config and run arbitrary commands in the gateway environment. Only enable this on a trusted, single-tenant setup (e.g. your own server).

## Skills and ClawHub (more skills / skill store)

OpenClaw loads skills from **bundled** (ship with install), **managed** (`~/.openclaw/skills`), and **workspace** (`<workspace>/skills`). To use more skills or a "skill store," use config and **ClawHub**.

**Config (`~/.openclaw/openclaw.json` under `skills`):**
- **`skills.allowBundled`** — Optional *allowlist* for **bundled** skills only. To allow more bundled skills, **omit** this or set it to the list you want.
- **`skills.load.extraDirs`** — Extra directories to scan (e.g. `["/home/node/.openclaw/extra-skills"]`).
- **`skills.entries.<skillKey>`** — Per-skill: `enabled: true/false`, `env`, `apiKey`. Use to enable skills and pass API keys.

**ClawHub** ([clawhub.com](https://clawhub.com)) is the public skill registry. The deploy **installs the ClawHub CLI in the gateway image**, so you (or the agent via exec) can run it inside the container: `clawhub search "query"`, `clawhub install <slug>`. Install into the config dir so the gateway sees skills: `cd /home/node/.openclaw && clawhub install <slug>`. Restart the gateway or start a new session so the agent picks up new skills. Docs: [Skills](https://docs.openclaw.ai/tools/skills), [Skills config](https://docs.openclaw.ai/tools/skills-config), [ClawHub](https://docs.openclaw.ai/tools/clawhub).

## Python venv and ClawHub in the image

The deploy **patches the upstream Dockerfile** so the gateway image gets:

1. **Python venv** — Skills that use PEP 723 scripts (e.g. **searxng**) need `httpx` and `rich`:

- **`python3 -m venv --copies`** at `/opt/openclaw-venv` so the interpreter is a real binary (not a symlink) and finds its site-packages.
- **`PATH="/opt/openclaw-venv/bin:$PATH"`** so `python3` in the container uses that venv; no `PYTHONPATH` workaround needed.
2. **ClawHub CLI** — `npm i -g clawhub` so the container (and the agent via exec) can run `clawhub search` and `clawhub install`.

The patch is applied automatically when you run `.\deploy.ps1` (before `docker build`). Redeploys add ClawHub if the venv is already there but ClawHub is missing. No manual steps.

## Files

| File | Purpose |
|------|--------|
| `run-sync-and-deploy.cmd` | One-click launcher for upstream sync + push + deploy |
| `sync-clean-upstream-and-deploy.ps1` | Automates local `openclaw-clean` rebase/push workflow, then runs `deploy.ps1` |
| `deploy.ps1` | Runs from Windows: SSH + upload and run `remote-setup.sh` |
| `dockerfile-venv-snippet.txt` | Snippet inserted into Dockerfile by `remote-setup.sh` (Python venv + ClawHub CLI; logic is in the script) |
| `enable-agent-env-modify.ps1` | From Windows: upload and run `enable-agent-env-modify.py` on server, restart gateway |
| `enable-agent-env-modify.py` | Runs on server: sets sandbox=off, exec.host=gateway in `~/.openclaw/openclaw.json` |
| `enable-tailscale-serve.ps1` | Enables Tailscale Serve for the Control UI (HTTPS, Tailnet-only) |
| `remote-setup.sh` | Runs on server: clone, env, **patch Dockerfile (venv + ClawHub)**, build, `docker compose up` |
| `docker-compose.yml` | Reference only; real file is in the cloned repo on the server |
