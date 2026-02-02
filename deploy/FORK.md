# Deploy from your OpenClaw fork

We keep a clone of [openclaw/openclaw](https://github.com/openclaw/openclaw) in **openclaw-src/** with our patches applied (venv, ClawHub, git, cli-auth volumes, env vars). Push that to your fork and deploy from it so you get source control and no server-side patching.

## What’s in the fork (openclaw-src)

- **Dockerfile:** Python venv (httpx, rich) for searxng, ClawHub CLI, git.
- **docker-compose.yml:** cli-auth volume mounts (`.claude`, `.gemini`), optional `ANTHROPIC_API_KEY` / `GEMINI_API_KEY`.

The deploy repo’s `.gitignore` excludes `openclaw-src/` so the clone isn’t committed here.

## 1. Push openclaw-src to your fork

```powershell
cd openclaw-src
git remote add myfork https://github.com/YOUR_USER/openclaw.git
git checkout -b deploy
git add Dockerfile docker-compose.yml
git commit -m "Add venv, ClawHub, git, cli-auth volumes and env vars for deploy"
git push -u myfork deploy
```

Create the fork on GitHub first (Fork openclaw/openclaw → your account). Use your fork URL for `myfork`.

## 2. Deploy from your fork

On the server, deploy uses `OPENCLAW_REPO` and optionally `OPENCLAW_REPO_BRANCH`. Point them at your fork:

**Option A — One-time for a deploy**

```powershell
$env:OPENCLAW_REPO = "https://github.com/YOUR_USER/openclaw.git"
$env:OPENCLAW_REPO_BRANCH = "deploy"
.\deploy.ps1
```

**Option B — In deploy.ps1**

Set `OPENCLAW_REPO` and (optional) `OPENCLAW_REPO_BRANCH`; `deploy.ps1` passes them to `remote-setup.sh`, which clones that repo and branch. Example:

```powershell
$env:OPENCLAW_REPO = "https://github.com/YOUR_USER/openclaw.git"
$env:OPENCLAW_REPO_BRANCH = "deploy"
.\deploy.ps1
```

The server will clone your fork (and the `deploy` branch); the Dockerfile already has the venv/ClawHub/git block, so patching is skipped; build and run as usual.

## 3. Updating from upstream

```powershell
cd openclaw-src
git fetch origin
git merge origin/main
# Resolve conflicts in Dockerfile / docker-compose.yml if any
git push myfork deploy
```

Then redeploy so the server pulls the updated fork and rebuilds.
