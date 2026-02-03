# Models dropdown on chat page — investigation

**Goal:** Add a model selector dropdown on the Control UI chat page so users can switch models without going into settings and typing the model name from memory (there is no slash-command picker; previously that was the only way).

---

**Where does the UI code live?**  
The dropdown (and all Control UI code) lives in the **full OpenClaw app repo** under **`ui/`** — **not** in this `deploy/` folder. This folder has **deploy scripts** (e.g. `sync-ollama-models.py`, `remote-setup.sh`, `deploy.ps1`), compose, and docs — but no **app source** (no `ui/`, no gateway `src/`). For a single list of what we patch and how we update from upstream, see [PATCHING-AND-UPSTREAM.md](PATCHING-AND-UPSTREAM.md). The app source (including `ui/`) is in:

- **Locally:** `openclaw-src/` (the full-app clone, gitignored here). Path: `openclaw-src/ui/`.
- **On the server:** whatever `OPENCLAW_REPO` clones (e.g. your fork) into `~/openclaw` — that clone has `ui/`.
- **On GitHub:** your fork (e.g. `CreamyG31337/openclaw`), branch `deploy`.

We implemented the dropdown in **openclaw-src** (under `ui/src/ui/`, etc.) and pushed that to the fork. The only things we added in **deploy/** were documentation and config (e.g. `OPENCLAW_REPO` in `.env` so the server builds from your fork). So: **code = full app repo (`ui/`). Deploy folder = scripts + docs only.**

---

## How we already patch the source

We **do** patch the OpenClaw source — but **on the server**, not in this repo:

1. **deploy.ps1** runs **remote-setup.sh** on the server via SSH.
2. **remote-setup.sh** **clones** your fork (e.g. `OPENCLAW_REPO` + `OPENCLAW_REPO_BRANCH`) into **`~/openclaw`** on the server. That clone is the **full OpenClaw app** (ui/, src/, Dockerfile, package.json, etc.).
3. **remote-setup.sh** then **patches files in that clone** before `docker build`:
   - **Dockerfile** — inserts Python venv, git, ClawHub (inline Python that edits the file before `USER node`).
4. **docker build** runs in that clone, so the image is built from the **patched** source.

So the “src” we patch is **the cloned repo on the server** (we only patch the Dockerfile today; the clone already contains **ui/** and the rest of the app). The same mechanism (edit or patch files in the clone after `git clone` and before `docker build`) could be used to patch the **Control UI** (ui/) to add a models dropdown.

## Where the UI code lives in that clone

- In the clone on the server: **`~/openclaw/ui/`** (Vite + Lit). **`ui/src/`** has `main.ts`, **`ui/`** (components), `styles/`. The image build runs `pnpm ui:build` and serves **`dist/control-ui`**.
- **This workspace** only has the `deploy/` folder (scripts, compose, docs). The app source (ui/, src/) is in your **fork** and in the **server’s clone** when we deploy.

## What exists today

- **Chat:** Control UI talks to the Gateway over WebSocket (`chat.send`, `chat.history`, `chat.abort`, `chat.inject`). Docs: [Control UI](https://docs.openclaw.ai/web/control-ui).
- **Model switching before the dropdown:** You had to go into settings and type the default model id from memory; there is no slash-command picker in chat. No dedicated model selector on the chat page in the default UI.
- **Gateway support:** The gateway already supports:
  - **`models.list`** — returns model snapshots (debug/status).
  - **`sessions.patch`** — can set per-session overrides, including **model** (so the session’s model can be changed via the protocol).
- **Config:** Available models come from `openclaw.json` → `agents.defaults.models` (e.g. `zai/glm-4.7`, `ollama/dolphin-mixtral:8x7b`). The gateway knows the list; the UI would need to get it (e.g. from config or a dedicated API).

## Can we add a dropdown?

**Yes.** You’d be coding in the **upstream OpenClaw UI**, not in this deploy repo.

1. **Get the UI source**  
   Clone openclaw (or your fork), use the branch you build from (e.g. `main` or `deploy`). The Control UI is under `ui/`.

2. **Find the chat view**  
   In `ui/src/ui/` (or equivalent), find the component that renders the chat thread and input (the “chat page”). That’s where you’d add the dropdown (e.g. in the header or above the input).

3. **Get the model list**  
   Either:
   - Call a gateway method that returns available models (e.g. from config or `models.list` / status), or  
   - Have the gateway expose something like `config.get` / agents defaults so the UI can read `agents.defaults.models` and optionally the primary model.  
   The exact RPC depends on what the gateway already exposes; the protocol supports session model override.

4. **Apply the selection**  
   When the user picks a model in the dropdown, call **`sessions.patch`** with the current session key and the new `model` (e.g. `ollama/dolphin-mixtral:8x7b`). That switches the session to that model; subsequent `chat.send` uses it.

5. **Build and deploy**  
   Run `pnpm ui:build`, then deploy so the Gateway serves the updated `dist/control-ui` (e.g. rebuild your Docker image and restart, or use your existing deploy pipeline).

## Two ways to add the dropdown

**Option A — Change in your fork (openclaw-src / deploy branch)**  
Edit the UI in a local clone of the full repo (or on GitHub), push to your fork’s deploy branch. The server already clones that branch and builds it; no change to remote-setup.sh. You maintain the UI change in the fork.

**Option B — Patch from this deploy repo (same as Dockerfile)**  
Add a **patch file** or small **script** under `deploy/` (e.g. `deploy/patches/models-dropdown.patch` or `deploy/patch-ui-models-dropdown.sh`) that modifies files under **`ui/`** in the server’s clone. In **remote-setup.sh**, after the Dockerfile patches and before `docker build`, run e.g.:

- `git apply deploy/patches/models-dropdown.patch`, or  
- a script that edits the Lit chat component to add a dropdown and wire it to `sessions.patch`.

Then every deploy would apply that patch to whatever branch the server cloned (upstream or your fork). You don’t need to keep the full openclaw app in this repo — only the patch. Downside: the patch may need updating when upstream changes the chat component.

## Summary

| Item | Location / approach |
|------|----------------------|
| Where we patch today | **Server clone** `~/openclaw` — Dockerfile only |
| UI code in that clone | **`ui/`** (Vite + Lit), e.g. `ui/src/ui/` for components |
| Chat view | Inside `ui/src/ui/` — find the chat page component |
| Model list | Gateway (config or `models.list` / status); UI calls WS to get it |
| Set model | **`sessions.patch`** with `model: "<provider>/<id>"` for current session |
| Add dropdown | **A:** Implement in fork and push. **B:** Add a patch in deploy/ and apply it in remote-setup.sh after clone, before build (same pattern as Dockerfile patches). |
