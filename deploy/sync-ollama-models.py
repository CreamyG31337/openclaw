#!/usr/bin/env python3
"""Sync ollama list to OpenClaw openclaw.json ollama provider and agents.defaults.models.
Run on the server where Ollama and OpenClaw config live (e.g. OPENCLAW_CONFIG_DIR=~/.openclaw).

Only includes models that:
1. Report "tools" capability via /api/show
2. Are not in the blocklist (models that report tools but don't implement properly)
"""
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

CONFIG_DIR = os.environ.get("OPENCLAW_CONFIG_DIR") or os.path.expanduser("~/.openclaw")
CONFIG_PATH = os.path.join(CONFIG_DIR, "openclaw.json")
OLLAMA_API_URL = os.environ.get("OLLAMA_API_URL") or "http://127.0.0.1:11434"

# Models that report "tools" capability but don't properly implement tool_calls array.
# They return tool calls as JSON text in the content field instead.
BROKEN_TOOL_MODELS = {
    "mistral-small",
    "qwen2.5-coder",
}

# Get ollama list (run on host - ollama might be in docker or host)
def get_ollama_models():
    for cmd in [["ollama", "list"], ["docker", "exec", "ollama", "ollama", "list"]]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if r.returncode == 0 and r.stdout:
                lines = r.stdout.strip().split("\n")[1:]  # skip header
                return [line.split()[0] for line in lines if line.strip()]
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return []


def get_model_capabilities(model_id):
    """Query Ollama /api/show to get model capabilities."""
    try:
        req = urllib.request.Request(
            f"{OLLAMA_API_URL}/api/show",
            data=json.dumps({"model": model_id}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            return data.get("capabilities", [])
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError):
        return []


def is_model_broken(model_id):
    """Check if model is in the blocklist of broken tool implementations."""
    base_name = model_id.split(":")[0]
    return base_name in BROKEN_TOOL_MODELS


def filter_tool_capable_models(models):
    """Filter to only models that support tools and aren't broken."""
    filtered = []
    skipped_no_tools = []
    skipped_broken = []

    for mid in models:
        if is_model_broken(mid):
            skipped_broken.append(mid)
            continue

        caps = get_model_capabilities(mid)
        if "tools" not in caps:
            skipped_no_tools.append(mid)
            continue

        filtered.append(mid)

    if skipped_no_tools:
        print(f"Skipped (no tools capability): {', '.join(skipped_no_tools)}", file=sys.stderr)
    if skipped_broken:
        print(f"Skipped (broken tool implementation): {', '.join(skipped_broken)}", file=sys.stderr)

    return filtered

def display_name(model_id):
    """Human-readable name from id like llama3.2:3b -> Llama 3.2 3B"""
    name = model_id.replace(":", " ").replace("-", " ").title()
    return name

def run_json(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        if r.returncode != 0 or not r.stdout:
            return None
        return json.loads(r.stdout)
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return None

def get_zai_models():
    # Prefer host CLI if available; fallback to the gateway container CLI.
    data = run_json(["openclaw", "models", "list", "--all", "--provider", "zai", "--json"])
    if data is None:
        data = run_json(
            [
                "docker",
                "exec",
                "openclaw-gateway",
                "node",
                "dist/index.js",
                "models",
                "list",
                "--all",
                "--provider",
                "zai",
                "--json",
            ]
        )
    models = []
    for row in (data or {}).get("models", []):
        key = str(row.get("key", "")).strip()
        name = str(row.get("name", "")).strip()
        if key.startswith("zai/"):
            models.append({"key": key, "name": name})
    return models

def main():
    with open(CONFIG_PATH) as f:
        config = json.load(f)

    all_models = get_ollama_models()
    if not all_models:
        print("No ollama models found (run ollama list)", file=sys.stderr)
        sys.exit(1)

    # Filter to only tool-capable, non-broken models
    print(f"Found {len(all_models)} Ollama models, checking tool capability...")
    models = filter_tool_capable_models(all_models)
    if not models:
        print("No tool-capable Ollama models found after filtering", file=sys.stderr)
        sys.exit(1)

    # Build provider model entries (OpenClaw ollama provider format)
    template = {
        "api": "openai-completions",
        "reasoning": False,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 128000,
        "maxTokens": 4096,
        # Ollama's OpenAI-compatible API behaves more like classic max_tokens and
        # does not support newer OpenAI fields (developer role, reasoning_effort).
        "compat": {
            "supportsStore": False,
            "supportsDeveloperRole": False,
            "supportsReasoningEffort": False,
            "maxTokensField": "max_tokens",
        },
    }
    reasoning_models = {"deepseek-r1", "phi4-reasoning", "reasoning"}
    provider_models = []
    for mid in models:
        entry = {
            "id": mid,
            "name": display_name(mid),
            **template,
        }
        if any(r in mid.lower() for r in reasoning_models):
            entry["reasoning"] = True
        provider_models.append(entry)

    # Update config
    config.setdefault("models", {}).setdefault("providers", {})
    config["models"]["providers"]["ollama"] = {
        "baseUrl": config["models"]["providers"].get("ollama", {}).get("baseUrl", "http://host.docker.internal:11434/v1"),
        "apiKey": "ollama",
        "models": provider_models,
    }

    config.setdefault("agents", {}).setdefault("defaults", {}).setdefault("models", {})
    # Keep existing non-ollama entries (e.g. zai/glm-4.7)
    agents_models = config["agents"]["defaults"]["models"]
    agents_models = {k: v for k, v in agents_models.items() if not k.startswith("ollama/")}
    for mid in models:
        agents_models[f"ollama/{mid}"] = {"alias": display_name(mid)}
    zai_models = get_zai_models()
    for entry in zai_models:
        key = entry["key"]
        alias = entry["name"] or key.split("/", 1)[-1]
        agents_models[key] = {"alias": alias}
    config["agents"]["defaults"]["models"] = agents_models

    with open(CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2)

    if zai_models:
        print("Synced", len(zai_models), "Z.AI models:", ", ".join([m["key"] for m in zai_models]))
    print("Synced", len(models), "Ollama models:", ", ".join(models))

if __name__ == "__main__":
    main()
