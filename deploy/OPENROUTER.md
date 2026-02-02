# OpenRouter with OpenClaw

**OpenRouter** is a single API that routes to many LLMs (OpenAI, Anthropic, Google, etc.) with one API key and one endpoint. OpenClaw has [built-in OpenRouter support](https://docs.openclaw.ai/providers/openrouter).

## Why use OpenRouter?

- **One key, many models** — Use Claude, GPT-4, Gemini, etc. via one OpenRouter API key instead of separate keys per provider.
- **Auto-routing** — Set model to `openrouter/auto` and OpenRouter picks a model for each request (e.g. by prompt complexity).
- **Unified API** — OpenAI-compatible `POST /api/v1/chat/completions`; you only change the `model` field (e.g. `anthropic/claude-3.5-sonnet`, `openai/gpt-4o`).
- **Pricing** — You pay OpenRouter; they handle provider billing. See [openrouter.ai](https://openrouter.ai) for pricing per model.

## Setup

### 1. Get an OpenRouter API key

1. Go to [openrouter.ai](https://openrouter.ai) and sign in.
2. Create an API key (e.g. Keys → Create key).
3. Copy the key (starts with `sk-or-...`).

### 2. Give the gateway the key

**Option A — Deploy / server `.env`**

- Add to your **deploy** `.env` (so the deploy script can pass it):
  ```env
  OPENROUTER_API_KEY=sk-or-your-key
  ```
- On the **server**, add the same to the OpenClaw clone’s `.env` (e.g. `~/openclaw/.env`):
  ```bash
  echo 'OPENROUTER_API_KEY=sk-or-your-key' >> ~/openclaw/.env
  ```
- Ensure the gateway gets it: either the main `docker-compose.yml` in the clone has `OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:-}` under the gateway’s `environment`, or add it in a `docker-compose.override.yml`. Then restart the gateway.

**Option B — Onboard via CLI**

- SSH to the server, then from the OpenClaw clone directory:
  ```bash
  docker compose run --rm openclaw-cli onboard --auth-choice apiKey --token-provider openrouter --token "sk-or-your-key"
  ```
  (Or set `OPENROUTER_API_KEY` in the environment and use `--token "$OPENROUTER_API_KEY"`.)

### 3. Set the default model (optional)

In `~/.openclaw/openclaw.json` (on the server, inside the gateway’s config mount), set the agent’s primary model to an OpenRouter model, for example:

- **Specific model:** `openrouter/anthropic/claude-sonnet-4` or `openrouter/openai/gpt-4o`
- **Auto-routing:** `openrouter/auto` (OpenRouter chooses a model per request)

Example snippet (merge into your existing config):

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/anthropic/claude-sonnet-4" },
      "models": {
        "openrouter/anthropic/claude-sonnet-4": { "alias": "Claude (OpenRouter)" },
        "openrouter/openai/gpt-4o": { "alias": "GPT-4o (OpenRouter)" },
        "openrouter/auto": { "alias": "OpenRouter Auto" }
      }
    }
  }
}
```

Model IDs follow OpenRouter’s format: `openrouter/<provider>/<model>`. Browse [openrouter.ai/models](https://openrouter.ai/models) for IDs.

### 4. Restart the gateway

```bash
docker restart openclaw-gateway
```

Or, if using compose: `cd ~/openclaw && docker compose up -d openclaw-gateway`.

## Summary

| Step | Action |
|------|--------|
| 1 | Get API key at [openrouter.ai](https://openrouter.ai) |
| 2 | Set `OPENROUTER_API_KEY` in server `~/openclaw/.env` and in gateway env (compose or override) |
| 3 | Set `agents.defaults.model.primary` in `openclaw.json` to e.g. `openrouter/anthropic/claude-sonnet-4` or `openrouter/auto` |
| 4 | Restart the gateway |

After that, the bot uses OpenRouter for the default model; you can switch models in chat (e.g. `/model`) if you added them to `agents.defaults.models`.
