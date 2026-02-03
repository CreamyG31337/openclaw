# Ollama Tool Calling Issues

## Problem Summary

Ollama models selected from the dropdown don't behave the same as GLM/Z.AI models when using tool calling. This document analyzes the technical differences and known limitations.

## Root Cause Analysis

### 1. API Type: Same Path, Different Behaviors

Both Ollama and GLM use `api: "openai-completions"` — the OpenAI-compatible endpoint path. However:

- **GLM (Z.AI)**: Battle-tested OpenAI-compatible API with full tool support
- **Ollama**: Self-hosted OpenAI-compatible layer with incomplete/inconsistent tool handling

See [models-config.providers.ts#L266](file:///c:/Users/cream/OneDrive/Documents/openclaw/openclaw-src/src/agents/models-config.providers.ts#L266) where providers are configured.

### 2. No Ollama-Specific Tool Sanitization

The `sanitizeToolsForGoogle()` function only runs for Google providers:

```typescript
// google.ts#L160-L161
if (params.provider !== "google-antigravity" && params.provider !== "google-gemini-cli") {
  return params.tools;  // Ollama tools pass through unsanitized
}
```

Ollama may reject certain JSON Schema keywords that OpenClaw doesn't filter, including:
- `anyOf` / `oneOf` (union types)
- `additionalProperties`
- Complex nested schemas

### 3. Known Ollama Tool Calling Limitations

Per [Ollama's OpenAI compatibility docs](https://docs.ollama.com/api/openai-compatibility) and GitHub issues:

| Issue | Description | Impact |
|-------|-------------|--------|
| **Streaming + Tools** | Tool calls don't stream progressively; two-chunk response format differs from OpenAI standard | Breaks streaming integrations |
| **No Follow-up Content** | When asked to use a tool AND explain, only tool calls are returned, no explanatory text | Missing natural responses |
| **JSON Schema Strictness** | Some models reject schemas with array types or complex structures | Tools may fail to invoke |
| **Model Variance** | Not all Ollama models support tool calling equally; depends on fine-tuning | Inconsistent behavior per model |

### 4. Model Discovery Doesn't Check Tool Support

Current discovery in `discoverOllamaModels()` does NOT verify tool capability:

```typescript
// models-config.providers.ts#L112-125
return data.models.map((model) => {
  const modelId = model.name;
  const isReasoning = modelId.toLowerCase().includes("r1") || ...;
  return {
    id: modelId,
    name: modelId,
    reasoning: isReasoning,
    input: ["text"],
    cost: OLLAMA_DEFAULT_COST,
    // NOTE: No tools capability check!
  };
});
```

The docs say discovery "keeps only models that report `tools` capability" but the actual code doesn't filter by capability.

## Comparison: Ollama vs GLM/Z.AI

| Aspect | GLM (Z.AI) | Ollama |
|--------|-----------|--------|
| API | OpenAI-compatible, cloud-hosted | OpenAI-compatible, local |
| Tool Schema | Full OpenAI spec | Subset, model-dependent |
| Streaming + Tools | Works | Broken (GitHub issue #12557) |
| Error Handling | Standard OpenAI errors | Inconsistent |
| Schema Sanitization | None needed | May need filtering |

## Potential Fixes

### Option A: Add Ollama-Specific Tool Sanitization

Extend `sanitizeToolsForGoogle()` pattern to handle Ollama:

```typescript
export function sanitizeToolsForOllama(params: { tools: AgentTool[]; provider: string }) {
  if (!params.provider.startsWith("ollama")) {
    return params.tools;
  }
  return params.tools.map((tool) => {
    // Strip unsupported schema keywords
    // Flatten anyOf/oneOf unions to enum
    // etc.
  });
}
```

### Option B: Disable Streaming for Ollama Tool Calls

Per the workaround in [Ollama issue #12557](https://github.com/ollama/ollama/issues/12557):

```typescript
if (provider === "ollama" && hasTools) {
  stream = false;  // Force non-streaming for tool calls
}
```

### Option C: Filter Ollama Models by Tool Capability

Update `discoverOllamaModels()` to query `/api/show` and filter by tool support:

```typescript
const showResponse = await fetch(`${OLLAMA_API_BASE_URL}/api/show`, {
  method: "POST",
  body: JSON.stringify({ model: model.name }),
});
const info = await showResponse.json();
if (!info.capabilities?.includes("tools")) {
  continue; // Skip non-tool-capable models
}
```

### Option D: Mark Ollama as Experimental in UI

Add UI indicator that Ollama models have limited tool support:

```
⚠️ Ollama models may have limited tool calling support
```

## Status

**FIXED:**
- ✅ Option C: Filter by actual tool capability - `discoverOllamaModels()` now queries `/api/show` and only includes models with `tools` capability
- ✅ Tool schema sanitization - Ollama now uses the same schema sanitization as Google (strips `anyOf`, `oneOf`, `additionalProperties`, etc.)
- ✅ Streaming + tools - Fixed upstream by Ollama (May 2025, PR #10415)
- ✅ Blocklist for broken models - Models that report `tools` capability but return tool calls as text instead of proper `tool_calls` array are filtered out

**BLOCKLISTED MODELS** (report tools but don't implement properly):
- `mistral-small` - Returns tool calls as JSON text in content field
- `qwen2.5-coder` - Returns tool calls as JSON text in content field

**WORKING MODELS** (verified):
- `llama3.1`, `llama3.2`, `qwen3`, `qwen3-coder`, `granite3.3`

**NOT NEEDED:**
- Option B (disable streaming) - Fixed upstream
- Option D (UI warning) - Models without tool support are now filtered out

## Testing Approach

1. **Capability filtering**: Verify only tool-capable models appear in dropdown
2. **Schema sanitization**: Check logs for "tool schema snapshot (sanitized)" entries
3. **End-to-end**: Select an Ollama model and trigger a tool call

## References

- [Ollama OpenAI Compatibility Docs](https://docs.ollama.com/api/openai-compatibility)
- [Ollama Issue #12557 - Tool Calling + Streaming](https://github.com/ollama/ollama/issues/12557)
- [Spring AI Issue #2047 - JSON Schema array type](https://github.com/spring-projects/spring-ai/issues/2047)
- [OpenClaw Ollama Docs](file:///c:/Users/cream/OneDrive/Documents/openclaw/openclaw-src/docs/providers/ollama.md)
