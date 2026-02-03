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

**Full guide (what we patch, how to merge without losing it):** [PATCHING-AND-UPSTREAM.md](PATCHING-AND-UPSTREAM.md).

Your fork (e.g. **CreamyG31337/openclaw** branch **deploy**) has the models dropdown and any other customizations. When upstream merges new changes, do this so you get fixes and new features and keep your dropdown.

### 1. Check if you’re behind

From **deploy** (this folder):

```powershell
.\check-upstream.ps1
```

That SSHs to the server, fetches `openclaw/openclaw` as `upstream`, and lists commits in `upstream/main` that are not in your current branch. If it says **"None. Your base is current"** you’re up to date; otherwise you’re behind and should merge (below).

(You can also run the same check locally: in **openclaw-src**, run `git fetch upstream` then `git log HEAD..upstream/main --oneline`.)

### 2. Merge upstream into your fork (openclaw-src)

On your machine, in **openclaw-src** (your fork clone):

```powershell
cd openclaw-src
git fetch upstream
git checkout deploy
git merge upstream/main
```

- **No conflicts:** You’re done with this step. Go to step 3.
- **Conflicts:** Git will list conflicted files (often `Dockerfile`, `docker-compose.yml`, or UI files like `ui/src/ui/app-render.helpers.ts`). Resolve them:
  - Keep your dropdown changes where they conflict (e.g. in `app-render.helpers.ts`, `controllers/models.ts`, `controllers/sessions.ts`).
  - Take upstream’s changes where you didn’t customize (e.g. new features in other files).
  - If upstream added a models dropdown or changed the same UI, merge both: keep your behavior and integrate any upstream improvements (e.g. types, styling).
  Then:
  ```powershell
  git add .
  git commit -m "Merge upstream/main; keep models dropdown"
  ```

### 3. Push your fork

```powershell
git push origin deploy
```

### 4. Redeploy so the server uses the updated fork

From **deploy** (this repo):

```powershell
cd deploy
.\deploy.ps1
```

That clones/pulls your fork (now with upstream merged), builds the image, and starts the gateway. If you use a registry and Watchtower: the push in step 3 doesn’t update the server by itself; you must run `.\deploy.ps1` once (build + push to registry) so the new image is available. After that, Watchtower can pull it, or you run `.\trigger-update.ps1` to pull and restart on the server.

**Summary:** `check-upstream.ps1` → merge `upstream/main` into **openclaw-src** `deploy` → resolve conflicts (keep dropdown) → push → `.\deploy.ps1`.
