---
name: claude-code
description: Use Claude Code CLI for coding (Claude Pro/Max subscription). Run shell commands via the `claude` binary for refactors, explanations, and code generation.
metadata: {"openclaw":{"requires":{"bins":["claude"]}}}
---

# Claude Code CLI

When the user asks for coding help (refactor, explain, generate, debug) and the `claude` binary is available, use it so the work runs against their **Claude Pro or Max subscription** (no API key).

## How to invoke

- **One-off query (then exit):**  
  `claude -p "USER REQUEST"`  
  Use this for a single question or task. Pass the user's request or a short, self-contained prompt.
- **Continue last conversation:**  
  `claude -c`  
  Use when the user wants to continue the previous Claude Code session.
- **Resume a session by name/ID:**  
  `claude -r "<session>" "follow-up request"`

## When to use

- User explicitly asks for "Claude" or "Claude Code" for coding.
- User wants coding help and you know `claude` is installed and authenticated; prefer using it for complex or multi-step coding so their subscription quota is used.

## When not to use

- If `claude` is not on PATH or not authenticated, use your normal tools (read, write, edit, exec with other commands) and your configured model instead.
- For very small edits (single line, obvious fix), your built-in edit/apply_patch may be enough.

## Notes

- Claude Code CLI uses the user's Anthropic account (Pro/Max). Auth is done once via `claude` interactively or via supported env/token if available.
- Output is streamed; capture stdout/stderr from the exec call and return relevant parts to the user.
