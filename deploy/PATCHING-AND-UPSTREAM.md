# Patching and upstream — one guide

**Goal:** Know what we changed, where it lives, and how to pull upstream changes without losing our work. Some manual conflict resolution is expected.

---

## 1. What we have (two places)

| Place | What it is | Upstream? |
|-------|------------|------------|
| **openclaw/openclaw** (GitHub) | The app: gateway, Control UI (`ui/`), CLI, Dockerfile, etc. | Yes — **this is upstream**. It changes often. |
| **Our fork** (e.g. CreamyG31337/openclaw, branch `deploy`) | Same app **plus our patches** (see below). We deploy from here. | No — we maintain it. |
| **This repo** (openclaw with `deploy/` folder) | Our deploy tooling only: scripts, compose, docs. No app source. | No — it’s ours. Not a fork of the app. |

So: **upstream** = openclaw/openclaw (the app). **Our app** = the fork. **Our tooling** = this repo’s `deploy/` folder.

---

## 2. Our patches (what we maintain that isn’t in upstream)

These are the changes we care about when upstream updates.

### 2a. Patches in the **app** (live in the fork, branch `deploy`)

- **Models dropdown** — Control UI: model selector in the chat header.
  - Files: `ui/src/ui/app-render.helpers.ts`, `ui/src/ui/controllers/models.ts`, `ui/src/ui/controllers/sessions.ts`, `ui/src/ui/app-chat.ts`, `ui/src/ui/app-gateway.ts`, `ui/src/ui/app-view-state.ts`, `ui/src/ui/app.ts`, `ui/src/ui/types.ts`, `ui/src/styles/chat/layout.css`, `ui/src/ui/views/chat.test.ts`.
- **Dockerfile / docker-compose** (if we added venv, ClawHub, cli-auth volumes, etc. in the fork) — same repo, same branch.

All of the above live in **openclaw-src** locally (your clone of the fork) and in **your fork on GitHub**. They are **not** in the `deploy/` folder.

### 2b. Tooling in **deploy/** (this repo)

- **Scripts:** `sync-ollama-models.py`, `run-sync-ollama.ps1`, `remote-setup.sh`, `deploy.ps1`, etc.
- **Config:** `deploy/.env` (OPENCLAW_REPO, OPENCLAW_REPO_BRANCH, server, keys).
- **Docs:** this file, HOW-DEPLOY-WORKS.md, FORK.md, etc.

This is our deploy and server-admin stuff. It is **not** “patched from upstream” — we own it. Upstream doesn’t have a `deploy/` repo; we do.

---

## 3. Updating from upstream without losing our changes

We only “merge upstream” into **the app** (the fork). Deploy tooling doesn’t get merged from upstream; it’s separate.

**Workflow (do this when you want upstream fixes/features and want to keep our patches):**

1. **Check if you’re behind**
   - From `deploy/`: run `.\check-upstream.ps1` (uses server’s clone), or  
   - Locally in openclaw-src: `git fetch upstream` then `git log HEAD..upstream/main --oneline`.  
   - If there are commits listed, you’re behind; continue. If “None. Your base is current”, you’re done.

2. **Merge upstream into our app branch (openclaw-src)**
   ```powershell
   cd openclaw-src
   git fetch upstream
   git checkout deploy
   git merge upstream/main
   ```
   - **No conflicts:** Go to step 3.
   - **Conflicts:** Git will list files. Resolve by hand:
     - In **our patch files** (see 2a): keep our behavior; integrate any upstream changes you want (e.g. types, refactors). Our patch files: `ui/src/ui/app-render.helpers.ts`, `ui/src/ui/controllers/models.ts`, `ui/src/ui/controllers/sessions.ts`, and the other dropdown-related files listed in 2a. For Dockerfile/docker-compose, same idea: keep our additions, take upstream’s other changes.
     - In **files we didn’t change**: take upstream’s version (e.g. `git checkout --theirs path/to/file`), unless you have a reason to keep a local change.
     - Then: `git add .` and `git commit -m "Merge upstream/main; keep our patches"`.

3. **Push the fork**
   ```powershell
   git push origin deploy
   ```

4. **Redeploy** so the server uses the updated app:
   ```powershell
   cd deploy
   .\deploy.ps1
   ```
   (Or use your registry flow / trigger-update.ps1 if that’s how you roll.)

After this, the app (fork) has upstream’s latest plus our patches. Deploy tooling (this repo) is unchanged unless you edit it yourself.

---

## 4. Summary

- **Upstream** = openclaw/openclaw (the app). **Our app** = fork, branch `deploy`, with our patches (dropdown, etc.). **Our tooling** = this repo’s `deploy/` (scripts, docs); not part of the app.
- **Our patches** = app changes in the fork (see section 2a). Deploy folder = our scripts and config (see 2b).
- **To update from upstream:** merge `upstream/main` into the fork’s `deploy` branch in openclaw-src, resolve conflicts (keep our patches, take or merge upstream elsewhere), push, redeploy. Manual fixing is expected when the same files change upstream.

This file is the single place for “what we patch” and “how we pull upstream without losing our changes.” Point new docs or scripts here so we don’t go in circles.
