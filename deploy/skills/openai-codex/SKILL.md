---
name: openai-codex
description: Use OpenAI Codex CLI for coding (ChatGPT / Codex subscription or API key). Run shell commands via the `codex` binary for refactors, explanations, and code generation.
metadata: {"openclaw":{"requires":{"bins":["codex"]}}}
---

# OpenAI Codex CLI

When the user asks for coding help (refactor, explain, generate, debug) and the `codex` binary is available, use it so the work runs against their **ChatGPT/Codex subscription** or **OpenAI API key**.

## How to invoke

- **Non-interactive one-off (recommended for agent):**  
  `codex exec --full-auto "USER REQUEST"`  
  or, in a hardened/container environment:  
  `codex exec --dangerously-bypass-approvals-and-sandbox "USER REQUEST"`  
  Use for a single task without prompts. Alias: `codex e`.
- **With workspace directory:**  
  `codex exec -C /path/to/project --full-auto "USER REQUEST"`
- **Resume last session:**  
  `codex exec resume --last "follow-up request"`

## When to use

- User explicitly asks for "Codex" or "OpenAI Codex" or "ChatGPT" for coding.
- User wants coding help and you know `codex` is installed and authenticated; prefer using it so their subscription or API quota is used.

## When not to use

- If `codex` is not on PATH or not authenticated, use your normal tools (read, write, edit, exec with other commands) and your configured model instead.
- For very small edits (single line, obvious fix), your built-in edit/apply_patch may be enough.

## Notes

- Codex CLI uses ChatGPT login (no API key): run `codex login --device-auth` in the container; open the URL, enter the code, sign in. If you see "contact your workspace admin to enable device code", log in on a PC with a browser (`codex login`), then run `copy-codex-auth.ps1` from the deploy folder to copy `~/.codex/auth.json` to the server. Alternatively use an API key: `OPENAI_API_KEY` or `codex login --with-api-key`.
- [Docs](https://developers.openai.com/codex/cli/reference), [Non-interactive](https://developers.openai.com/codex/noninteractive), [Auth](https://developers.openai.com/codex/auth).
