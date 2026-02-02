---
name: gemini-cli
description: Use Gemini CLI for coding (Google account / Google AI Pro). Run the `gemini` binary for code generation, explanations, search grounding, and file operations.
metadata: {"openclaw":{"requires":{"bins":["gemini"]}}}
---

# Gemini CLI

When the user asks for coding help (generate, explain, debug, search) and the `gemini` binary is available, use it so the work runs against their **Google account** (free tier or Google AI Pro; no API key).

## How to invoke

- **Single prompt:**  
  `gemini "USER REQUEST"`  
  Use for one-off questions, code generation, or explanations. Pass the user's request as the argument.
- **Interactive:**  
  `gemini`  
  Starts REPL; use only when the user explicitly wants a multi-turn session (or pipe input).

## When to use

- User explicitly asks for "Gemini" or "Google AI" for coding.
- User wants coding help and you know `gemini` is installed and authenticated; prefer using it for code gen, search-grounded answers, or file/codebase tasks so their Google quota is used.

## When not to use

- If `gemini` is not on PATH or not authenticated, use your normal tools (read, write, edit, exec) and your configured model instead.
- For small, local edits (single file, obvious change), your built-in edit/apply_patch may be enough.

## Notes

- Gemini CLI uses the user's Google account (login once via `gemini`). Free tier has rate limits; Google AI Pro has higher quotas.
- Output is streamed; capture stdout/stderr from the exec call and return relevant parts to the user.
