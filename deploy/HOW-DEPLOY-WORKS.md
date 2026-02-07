# How deploy works (this design)

One place that describes the flow so you don’t have to guess.

## Flow

1. **You run** (from this repo, `openclaw/deploy`):
   ```powershell
   .\deploy.ps1
   ```
   `deploy.ps1` loads `deploy/.env`, then **SSHs to your server** and runs **remote-setup.sh** there (the script is piped over SSH; env vars like `OPENCLAW_REPO`, `OPENCLAW_REPO_BRANCH` are passed in the same command).

2. **On the server, remote-setup.sh**:
   - **Clones** `OPENCLAW_REPO` into `~/openclaw` (or `OPENCLAW_DIR`). If `OPENCLAW_REPO_BRANCH` is set, it clones that branch (e.g. `deploy`). Default repo is `https://github.com/openclaw/openclaw.git`; no default branch (then it uses whatever `git pull` / clone gives).
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

## Deploy the models dropdown (exact steps)

Your dropdown lives in **openclaw-src** (the full OpenClaw app clone). Deploy uses whatever repo/branch you point it at. So:

### 1. Push openclaw-src to your fork

From your machine, with **openclaw-src** containing the dropdown changes:

```powershell
cd openclaw-src
git status   # confirm your dropdown files are committed
git remote -v   # if you don’t have your fork yet: git remote add origin https://github.com/CreamyG31337/openclaw.git
git push origin deploy
```

Use the branch name you actually use (e.g. `deploy` or `main`). If the branch doesn’t exist yet:

```powershell
git checkout -b deploy
git push -u origin deploy
```

### 2. Point deploy at your fork

In **deploy/.env** (or set env when you run the script), set:

```env
OPENCLAW_REPO=https://github.com/CreamyG31337/openclaw.git
OPENCLAW_REPO_BRANCH=deploy
```

(Use your real GitHub user and branch name.)  
Also have `OPENCLAW_SERVER`, `OPENCLAW_DEPLOY_USER`, `OPENCLAW_KEY_PATH` set (see `.env.example`).

### 3. Run deploy (build on server)

From the **openclaw** repo (the one that contains the **deploy** folder):

```powershell
cd deploy
.\deploy.ps1
```

Do **not** set `OPENCLAW_REGISTRY_IMAGE` without `OPENCLAW_REGISTRY_USER` if you want a build this time — that would be “pull only” and wouldn’t use your fork. So either:

- Leave `OPENCLAW_REGISTRY_IMAGE` unset → server builds from the clone and runs `openclaw:local`, or  
- Set both `OPENCLAW_REGISTRY_IMAGE` and `OPENCLAW_REGISTRY_USER` (and `OPENCLAW_REGISTRY_PASSWORD`) → server builds from the clone, pushes to the registry, then runs from that image.

### 4. Verify

Open the Control UI (e.g. `http://<server>:18789`), go to Chat. You should see the **session** dropdown and the **model** dropdown next to it.

---

## Optional: registry + Watchtower

If you use **REGISTRY-AND-WATCHTOWER.md**:

- **Build and push (this run):** set `OPENCLAW_REGISTRY_IMAGE`, `OPENCLAW_REGISTRY_USER`, `OPENCLAW_REGISTRY_PASSWORD` → deploy builds from your fork and pushes.
- **Pull only (later runs or Watchtower):** set `OPENCLAW_REGISTRY_IMAGE` and **do not** set `OPENCLAW_REGISTRY_USER` → no build, just `docker pull` and run. That only gets the dropdown after you’ve done at least one “build and push” with your fork.

The local UI build we did (`npm install` + `npm run build` in `openclaw-src/ui`) was only to confirm the code compiles. The image that deploy runs is built **on the server** from the cloned repo (your fork) inside Docker.

---

## When upstream (openclaw/openclaw) updates

Use the one-click wrapper:

```bat
run-sync-and-deploy.cmd
```

This runs `sync-clean-upstream-and-deploy.ps1` and handles:
1. fetch/rebase of local `openclaw-clean` against `origin/main`
2. branch push to your fork branch (`OPENCLAW_REPO_BRANCH`)
3. deployment to your server via `deploy.ps1`

### Required config in `deploy/.env`

```env
OPENCLAW_REPO=https://github.com/<you>/openclaw.git
OPENCLAW_REPO_BRANCH=deploy-clean
```

Optional overrides:
- `OPENCLAW_LOCAL_REPO_DIR` (default `..\openclaw-clean`)
- `OPENCLAW_FORK_REMOTE_NAME` (default `fork`)
- `OPENCLAW_UPSTREAM_REMOTE_NAME` (default `origin`)
- `OPENCLAW_UPSTREAM_BRANCH` (default `main`)

### Conflict handling

If upstream introduces conflicts, the script will stop at rebase. Resolve conflicts in `openclaw-clean`, then continue:

```powershell
cd openclaw-clean
git rebase --continue
```

Then re-run `run-sync-and-deploy.cmd`.

**Summary:** use `run-sync-and-deploy.cmd` for normal updates; only drop to manual git when a rebase conflict needs intervention.
