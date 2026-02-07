# How deploy works (this design)

One place that describes the flow so you don’t have to guess.

## Flow

1. **You run** (from this repo, `openclaw/deploy`):
   ```powershell
   .\deploy.ps1
   ```
   `deploy.ps1` loads `deploy/.env`, then **SSHs to your server** and runs **remote-setup.sh** there (the script is piped over SSH; env vars like `OPENCLAW_REPO`, `OPENCLAW_REPO_BRANCH` are passed in the same command).

2. **On the server, remote-setup.sh**:
   - **Clones** `OPENCLAW_REPO` into `~/openclaw` (or `OPENCLAW_DIR`). If `OPENCLAW_REPO_BRANCH` is set, it clones that branch (for example `hotfix/ollama-toolcall-stream-fallback`).
   - **Patches the Dockerfile** in that clone (adds Python venv, git, ClawHub before `USER node`). Only if not already patched.
   - **Build or pull:**
     - If `OPENCLAW_REGISTRY_IMAGE` is set and **`OPENCLAW_REGISTRY_USER` is not set**: **pull only** — `docker pull $OPENCLAW_REGISTRY_IMAGE`, no build. Run the gateway from that image (Watchtower path).
     - Else if `OPENCLAW_REGISTRY_IMAGE` is set **and** `OPENCLAW_REGISTRY_USER` (and password) are set: **build** in the clone (`docker build`), tag, login to registry, push, then run the gateway from the registry image.
     - Else: **build** in the clone (`docker build -t openclaw:local .`), run the gateway from `openclaw:local`.
   - **Starts the gateway** with `docker compose up -d openclaw-gateway` (or `docker run` if compose isn’t available).

3. **Dockerfile** (in the cloned repo):
   - Uses `node:22-bookworm`, runs `corepack enable` (so **pnpm** is available inside the image).
   - Copies `package.json`, `pnpm-lock.yaml`, `ui/package.json`, etc., runs `pnpm install --frozen-lockfile`, then `COPY . .`, then `pnpm build`, then **`pnpm ui:build`**.
   - So the **UI (and app) build runs inside Docker** on the server. The server host does **not** need Node or pnpm; only Docker and the cloned repo.

**Bottom line:** Whatever is in **`OPENCLAW_REPO`** at **`OPENCLAW_REPO_BRANCH`** is what gets cloned, patched (Dockerfile only), built into the image, and run. To get the models dropdown (or any UI change) into the running gateway, that change must be in that repo and branch, and you must trigger a deploy that **builds** (not pull-only).

---

## Deploy a hotfix branch (exact steps)

### 1. Create/push a hotfix branch from the local source repo

```powershell
cd ..\openclaw-upstream-fresh
git fetch origin
git checkout main
git reset --hard origin/main
git checkout -b hotfix/<name>
# edit + test
git push -u fork hotfix/<name>
```

### 2. Point deploy at your fork branch

```env
OPENCLAW_REPO=https://github.com/<you>/openclaw.git
OPENCLAW_REPO_BRANCH=hotfix/<name>
OPENCLAW_LOCAL_REPO_DIR=..\openclaw-upstream-fresh
```

### 3. Deploy

```powershell
cd deploy
.\deploy.ps1
```

Do **not** set `OPENCLAW_REGISTRY_IMAGE` without credentials if you want to build from your branch (that mode is pull-only).

---

## Optional: registry + Watchtower

If you use **REGISTRY-AND-WATCHTOWER.md**:

- **Build and push (this run):** set `OPENCLAW_REGISTRY_IMAGE`, `OPENCLAW_REGISTRY_USER`, `OPENCLAW_REGISTRY_PASSWORD` → deploy builds from your fork and pushes.
- **Pull only (later runs or Watchtower):** set `OPENCLAW_REGISTRY_IMAGE` and **do not** set `OPENCLAW_REGISTRY_USER` → no build, just `docker pull` and run. That only gets the dropdown after you’ve done at least one “build and push” with your fork.

Any local UI build you run is only a compile check. The image that deploy runs is built **on the server** from the cloned repo (your fork) inside Docker.

---

## When upstream (openclaw/openclaw) updates

Use the one-click wrapper:

```bat
run-sync-and-deploy.cmd
```

This runs `sync-clean-upstream-and-deploy.ps1` and handles:
1. fetch/rebase of local source repo (`OPENCLAW_LOCAL_REPO_DIR`) against `origin/main`
2. branch push to your fork branch (`OPENCLAW_REPO_BRANCH`)
3. deployment to your server via `deploy.ps1`

### Required config in `deploy/.env`

```env
OPENCLAW_REPO=https://github.com/<you>/openclaw.git
OPENCLAW_REPO_BRANCH=hotfix/<name>
```

Optional overrides:
- `OPENCLAW_LOCAL_REPO_DIR` (recommended `..\openclaw-upstream-fresh`)
- `OPENCLAW_FORK_REMOTE_NAME` (default `fork`)
- `OPENCLAW_UPSTREAM_REMOTE_NAME` (default `origin`)
- `OPENCLAW_UPSTREAM_BRANCH` (default `main`)

### Conflict handling

If upstream introduces conflicts, the script will stop at rebase. Resolve conflicts in your local source repo, then continue:

```powershell
cd ..\openclaw-upstream-fresh
git rebase --continue
```

Then re-run `run-sync-and-deploy.cmd`.

**Summary:** use `run-sync-and-deploy.cmd` for normal updates; only drop to manual git when a rebase conflict needs intervention.
