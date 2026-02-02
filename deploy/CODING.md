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

### 3. ChatGPT / Codex

- **Codex CLI** (OpenAI): [developers.openai.com/codex/cli](https://developers.openai.com/codex/cli) — check whether it uses your Codex subscription or an API key.
- **Third-party ChatGPT CLIs** (e.g. `chatgpt-cli`, `chatGPT-shell-cli`) usually need an **API key**; Plus subscription alone often doesn’t expose one. If you have an OpenAI API key, you can add OpenAI as a provider in OpenClaw instead.

## Skills so the agent uses these CLIs

Skills teach OpenClaw **when** and **how** to use a tool. This repo includes two skills you can copy onto the server:

| Skill        | Binary   | Purpose                                      |
|-------------|----------|----------------------------------------------|
| `claude-code` | `claude` | Use Claude Code CLI for coding (Pro/Max).   |
| `gemini-cli`  | `gemini` | Use Gemini CLI for coding (Google account). |

**Install on the server (Docker):**

1. Copy the skill folder into the gateway’s config (e.g. from this repo’s `deploy/skills/`):
   ```bash
   # From your machine (PowerShell), copy skills to server
   scp -i C:\Utils\id_rsa -r deploy/skills/claude-code deploy/skills/gemini-cli lance@ts-ubuntu-server:~/.openclaw/skills/
   ```
2. Install the CLI **inside** the gateway container (so `exec` can run it):
   ```bash
   ssh -i C:\Utils\id_rsa lance@ts-ubuntu-server
   docker exec -it openclaw-gateway sh -c "npm i -g @anthropic-ai/claude-code || true"
   docker exec -it openclaw-gateway sh -c "npm i -g @google/gemini-cli || true"
   ```
3. **Log in** so the CLIs can use your account. See [Login / auth for Claude and Gemini](#login--auth-for-claude-and-gemini-in-the-gateway) below.
4. Restart the gateway or start a new session so it loads the new skills.

## Login / auth for Claude and Gemini in the gateway

The gateway runs in a **Docker container** with no browser. You have two ways to get the CLIs authenticated.

### Option A — Interactive login (once)

Use this if you want to use your **subscription** (Claude Pro/Max, Google account) with no API key.

1. SSH to the server and attach to the gateway container:
   ```bash
   ssh -i C:\Utils\id_rsa lance@ts-ubuntu-server
   docker exec -it openclaw-gateway sh
   ```
2. Inside the container, run the CLI:
   - **Claude:** run `claude`. It will print a URL or “Open this link…” — open that URL **on your phone or laptop**, sign in with your Anthropic account, then return to the terminal; the CLI should complete login.
   - **Gemini:** run `gemini`. It may print a URL or show “Login with Google” — open the URL on your phone/laptop, sign in, then the CLI in the container should finish. (If it only shows “Waiting for auth…” and times out, use Option B for Gemini.)
3. Exit the container (`exit`). The CLI stores credentials inside the container. They **persist until the container is recreated** (e.g. after a new image or `docker compose up -d --force-recreate`). If you want login to survive recreates, use Option B (API keys) or copy the CLI config dir from the container to a host path and mount it (CLI-specific).

### Option B — API keys / env (headless, survives restarts)

Use this when you can’t do interactive login or want the container to work after restarts without logging in again.

- **Gemini:** Get an API key from [Google AI Studio](https://aistudio.google.com/apikey). On the server, add to the OpenClaw `.env` (in the clone directory, e.g. `~/openclaw/.env`):
  ```bash
  GEMINI_API_KEY=your_key_here
  ```
  On the server, add `GEMINI_API_KEY=your_key_here` to the OpenClaw clone’s `.env`, and ensure the gateway gets it: either the clone’s `docker-compose.yml` already has `GEMINI_API_KEY: ${GEMINI_API_KEY:-}` under the gateway’s `environment`, or add it in a `docker-compose.override.yml` (e.g. under `openclaw-gateway` → `environment`). Then restart: `docker compose up -d openclaw-gateway`.

- **Claude:** For non-interactive use (`claude -p`), set an **Anthropic API key** (from [console.anthropic.com](https://console.anthropic.com)). On the server, add `ANTHROPIC_API_KEY=your_key_here` to the same `.env`, and ensure the gateway’s `environment` includes `ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}` (in the main compose or in an override). Restart the gateway.

Note: An **API key** is not the same as a Pro/Max **subscription** — API usage is billed separately. If you only have a subscription and no API key, use Option A for Claude.

### Summary

| CLI    | Option A (interactive) | Option B (headless)        |
|--------|-------------------------|-----------------------------|
| Claude | `docker exec -it … sh` → `claude` → open URL on phone/laptop | `ANTHROPIC_API_KEY` in `.env` (API key) |
| Gemini | `docker exec -it … sh` → `gemini` → open URL on phone/laptop | `GEMINI_API_KEY` in `.env` (Google AI Studio key) |

If the CLIs are installed on **another machine** (e.g. your laptop) where OpenClaw runs exec via a node/bridge, put the skills in that machine’s `~/.openclaw/skills` and ensure `claude` / `gemini` are on PATH there.

## Summary

- **Coding with OpenClaw today:** Use its built-in model + **exec**, **read**, **write**, **edit**, **apply_patch**. No extra CLIs required.
- **Use your subscriptions:** Install **Claude Code CLI** and/or **Gemini CLI** where exec runs; add the **claude-code** and **gemini-cli** skills from `deploy/skills/` so the agent knows to call them for coding tasks.
- **ChatGPT/Codex:** Prefer adding an OpenAI **API** provider in OpenClaw if you have an API key; otherwise check Codex CLI docs for subscription-based auth.
