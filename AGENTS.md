# Workspace Instructions (OpenClaw deploy workspace)

This workspace has two parts:
- `deploy/` = deploy scripts + docs (source of truth for deployment steps).
- `openclaw-src/` = full OpenClaw repo clone where UI/gateway code changes live.

## .env usage (deploy/)
- `deploy/.env` drives all scripts.
- Key values:
  - `OPENCLAW_SERVER`, `OPENCLAW_DEPLOY_USER`, `OPENCLAW_KEY_PATH`
  - `OPENCLAW_REPO`, `OPENCLAW_REPO_BRANCH` (fork + branch to deploy)
  - optional provider keys (e.g. `ZAI_API_KEY`)

## Deploy workflow (UI/gateway changes)
1) Make code changes in `openclaw-src/`.
2) Commit + push to the fork branch in `deploy/.env`.
3) Run `deploy/deploy.ps1` (rebuilds image + restarts gateway).
4) If the deploy rotates the token, update the Control UI token.

## Models / dropdown
- The dropdown should only show models in `agents.defaults.models`.
- Refresh Ollama + Z.AI allowlist by running `deploy/run-sync-ollama.ps1`.
- If the UI behavior changes, you must redeploy to update the image.

## Guardrails
- Do not edit upstream guidance files in `openclaw-src/` unless asked.
- Avoid `package-lock.json` (this repo uses pnpm).
- Keep changes minimal and focused on the task.
