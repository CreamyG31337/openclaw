# OpenClaw and coding (Claude, Gemini, ChatGPT, Codex)

OpenClaw can help with coding in two ways: **using its own model** (Z.AI, Ollama, or API providers you add), or **calling command-line tools** that use your **subscriptions** (Claude Code, Gemini CLI). Your ChatGPT/Codex and Google AI Pro subscriptions are account-based; the CLIs below use those accounts so you don’t need API keys.

## How OpenClaw helps with coding

- **Built-in tools:** The agent has **exec** (run shell commands), **read** / **write** / **edit** (files), and **apply_patch** (structured code patches). So you can ask it to “fix this function,” “add tests,” “refactor X,” and it will edit files and run commands.
- **Model:** It uses whatever model you configured (e.g. Z.AI, Ollama). For heavier coding you can add [OpenAI](https://docs.openclaw.ai/providers/openai), [Anthropic](https://docs.openclaw.ai/providers/anthropic), or [Google](https://docs.openclaw.ai/providers/models) **API** providers in `openclaw.json` if you have API keys.
- **Subscriptions vs API:** ChatGPT Plus, Claude Pro, Google AI Pro, Codex, etc. are usually **web/subscription** access. OpenClaw can’t call those directly unless you use **command-line** versions that log in with your account (see below).

## Command-line tools that use your subscriptions

These CLIs use your existing account (no API key). Install them **where OpenClaw runs exec** (e.g. gateway container, or your laptop if you use a local node).

### 1. Claude Code CLI (Claude Pro / Max subscription)

- **Uses:** Your Claude Pro or Max subscription.
- **Install:**  
  `npm install -g @anthropic-ai/claude-code`  
  or: `curl -fsSL https://claude.ai/install.sh | bash`
- **Auth:** Run `claude` once and sign in with your Anthropic account.
- **Use:** `claude -p "your prompt"` (one-off query), or `claude "prompt"` (REPL).  
  [Docs](https://docs.anthropic.com/en/docs/claude-code/cli-reference)

### 2. Gemini CLI (Google account / Google AI Pro)

- **Uses:** Your Google account (free tier or Google AI Pro).
- **Install:**  
  `npm install -g @google/gemini-cli`  
  or: `curl -fsSL https://dl.google.com/gemini/install.sh | bash`
- **Auth:** Run `gemini` and choose “Login with Google.”
- **Use:** `gemini "your prompt"` for coding, search, file ops.  
  [Docs](https://google-gemini.github.io/gemini-cli/)

### 3. OpenAI Codex CLI (ChatGPT / Codex subscription or API key)

- **Uses:** Your ChatGPT (Plus, Pro, Team, Edu, or Enterprise) account or an OpenAI API key.
- **Install:**  
  `npm install -g @openai/codex`
- **Auth:** Run `codex login --device-auth` in the container — open the URL on your phone/laptop, enter the code, sign in with **ChatGPT email and password** (no API key). Or use an API key: `echo "$OPENAI_API_KEY" | codex login --with-api-key`. Credentials are stored in `~/.codex/` (mounted as `cli-auth/codex` in the gateway).
- **Use:** `codex exec "your prompt"` (non-interactive one-off; alias `codex e`). For automation use `--full-auto` or `--dangerously-bypass-approvals-and-sandbox` in a container.  
  [Docs](https://developers.openai.com/codex/cli/reference), [Non-interactive](https://developers.openai.com/codex/noninteractive), [Auth](https://developers.openai.com/codex/auth).

**Third-party ChatGPT CLIs** (e.g. `chatgpt-cli`) usually need an API key. If you only use an OpenAI API key for models, you can add OpenAI as a provider in OpenClaw instead.

## Skills so the agent uses these CLIs

Skills teach OpenClaw **when** and **how** to use a tool. This repo includes two skills you can copy onto the server:

| Skill          | Binary   | Purpose                                        |
|----------------|----------|------------------------------------------------|
| `claude-code`  | `claude` | Use Claude Code CLI for coding (Pro/Max).     |
| `gemini-cli`   | `gemini` | Use Gemini CLI for coding (Google account).  |
| `openai-codex` | `codex`  | Use OpenAI Codex CLI for coding (ChatGPT/API).|

**Install on the server (Docker):**

1. Copy the skill folder into the gateway’s config (e.g. from this repo’s `deploy/skills/`):
   ```bash
   # From your machine (PowerShell), copy skills to server
   scp -i YOUR_KEY -r deploy/skills/claude-code deploy/skills/gemini-cli YOUR_USER@YOUR_SERVER:~/.openclaw/skills/
   ```
2. Install the CLI **inside** the gateway container (so `exec` can run it):
   ```bash
   ssh -i YOUR_KEY YOUR_USER@YOUR_SERVER
   docker exec -u root openclaw-gateway sh -c "npm i -g @anthropic-ai/claude-code || true"
   docker exec -u root openclaw-gateway sh -c "npm i -g @google/gemini-cli || true"
   docker exec -u root openclaw-gateway sh -c "npm i -g @openai/codex || true"
   ```
3. **Log in** so the CLIs can use your account. See [Login / auth for Claude, Gemini, and Codex](#login--auth-for-claude-gemini-and-codex-in-the-gateway) below.
4. Restart the gateway or start a new session so it loads the new skills.

## Login / auth for Claude, Gemini, and Codex in the gateway

The gateway runs in a **Docker container** with no browser. You have two ways to get the CLIs authenticated.

### Option A — Interactive login (once)

Use this if you want to use your **subscription** (Claude Pro/Max, Google account) with no API key.

1. SSH to the server and attach to the gateway container:
   ```bash
   ssh -i YOUR_KEY YOUR_USER@YOUR_SERVER
   docker exec -it openclaw-gateway sh
   ```
2. Inside the container, run the CLI:
   - **Claude:** run `claude`. It will print a URL or “Open this link…” — open that URL **on your phone or laptop**, sign in with your Anthropic account, then return to the terminal; the CLI should complete login.
   - **Gemini:** run `gemini`. It may print a URL or show "Login with Google" — open the URL on your phone/laptop, sign in, then the CLI in the container should finish. (If it only shows "Waiting for auth…" and times out, use Option B for Gemini.)
   - **Codex:** run `codex login --device-auth`. It will print a URL and a code — open the URL on your phone or laptop, enter the code, then sign in. No API key needed. Credentials are stored in `~/.codex/` (mounted from host `cli-auth/codex`). **If you see “Please contact your workspace admin to enable device code authentication”,** use [Codex when device code is disabled](#codex-when-device-code-is-disabled) below instead.
3. Exit the container (`exit`). The CLI stores credentials inside the container. They **persist until the container is recreated** (e.g. after a new image or `docker compose up -d --force-recreate`). If you want login to survive recreates, use Option B (API keys) or copy the CLI config dir from the container to a host path and mount it (CLI-specific).

### Option B — API keys / env (headless, survives restarts)

Use this when you can’t do interactive login or want the container to work after restarts without logging in again.

- **Gemini:** Get an API key from [Google AI Studio](https://aistudio.google.com/apikey). On the server, add to the OpenClaw `.env` (in the clone directory, e.g. `~/openclaw/.env`):
  ```bash
  GEMINI_API_KEY=your_key_here
  ```
  On the server, add `GEMINI_API_KEY=your_key_here` to the OpenClaw clone’s `.env`, and ensure the gateway gets it: either the clone’s `docker-compose.yml` already has `GEMINI_API_KEY: ${GEMINI_API_KEY:-}` under the gateway’s `environment`, or add it in a `docker-compose.override.yml` (e.g. under `openclaw-gateway` → `environment`). Then restart: `docker compose up -d openclaw-gateway`.

- **Claude:** For non-interactive use (`claude -p`), set an **Anthropic API key** (from [console.anthropic.com](https://console.anthropic.com)). On the server, add `ANTHROPIC_API_KEY=your_key_here` to the same `.env`, and ensure the gateway’s `environment` includes `ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}` (in the main compose or in an override). Restart the gateway.

- **Codex:** For non-interactive use (`codex exec`), set **OpenAI API key** (from [platform.openai.com](https://platform.openai.com/api-keys)). On the server, add `OPENAI_API_KEY=your_key_here` to the same `.env`; `remote-setup.sh` will add it to the gateway’s environment when set. Alternatively, run `echo "$OPENAI_API_KEY" | codex login --with-api-key` once inside the container so credentials are stored in the mounted `~/.codex/`.

Note: An **API key** is not the same as a **subscription** — API usage may be billed separately. If you only have a subscription and no API key, use Option A for Claude/Codex.

### Summary

| CLI    | Option A (interactive) | Option B (headless)        |
|--------|-------------------------|-----------------------------|
| Claude | `docker exec -it … sh` → `claude` → open URL on phone/laptop | `ANTHROPIC_API_KEY` in `.env` (API key) |
| Gemini | `docker exec -it … sh` → `gemini` → open URL on phone/laptop | `GEMINI_API_KEY` in `.env` (Google AI Studio key) |
| Codex  | `codex login --device-auth` in container, or [copy auth from PC](#codex-when-device-code-is-disabled) if device code is disabled | `OPENAI_API_KEY` in `.env` or `codex login --with-api-key` (optional) |

### Codex when device code is disabled

If you get **“Please contact your workspace admin to enable device code authentication”**, your ChatGPT workspace has device code login turned off. You can still use your subscription without an API key by logging in on a machine with a browser and copying the auth file to the server.

**Option 1 — Log in on your PC, then copy auth to the server (recommended):**

1. On your **Windows PC** (or any machine with a browser), install Codex and log in:
   ```powershell
   npm i -g @openai/codex
   codex login
   ```
   Complete the browser login. Codex stores credentials in `%USERPROFILE%\.codex\auth.json` (Windows) or `~/.codex/auth.json` (Mac/Linux).

2. From the **deploy** folder on your PC, run the copy script (it uploads your local auth to the server’s `~/.openclaw/cli-auth/codex/`, which is mounted as `~/.codex` in the gateway):
   ```powershell
   .\copy-codex-auth.ps1
   ```

3. Restart the gateway so it picks up the credentials:  
   `ssh ... "docker restart openclaw-gateway"`

**Option 2 — SSH port forward and log in inside the container:**

If you can forward ports from your PC to the server, you can use the normal browser flow from the container:

1. From your PC: `ssh -L 1455:localhost:1455 YOUR_USER@YOUR_SERVER`
2. In that SSH session: `docker exec -it openclaw-gateway sh`, then run `codex login`. Open the URL **on your PC**; the callback will reach the container via the tunnel.

**Option 3 — API key:** Use an OpenAI API key (see Option B above). Billing is separate from your ChatGPT subscription.

If the CLIs are installed on **another machine** (e.g. your laptop) where OpenClaw runs exec via a node/bridge, put the skills in that machine’s `~/.openclaw/skills` and ensure `claude` / `gemini` / `codex` are on PATH there.

## Summary

- **Coding with OpenClaw today:** Use its built-in model + **exec**, **read**, **write**, **edit**, **apply_patch**. No extra CLIs required.
- **Use your subscriptions:** Install **Claude Code CLI**, **Gemini CLI**, and/or **OpenAI Codex CLI** where exec runs; add the **claude-code**, **gemini-cli**, and **openai-codex** skills from `deploy/skills/` so the agent knows to call them for coding tasks.
- **Codex:** Use `@openai/codex` with ChatGPT OAuth or `OPENAI_API_KEY`; auth is persisted in `~/.codex/` (mounted as `cli-auth/codex` in the gateway).
