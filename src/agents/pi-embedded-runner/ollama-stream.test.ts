import type { StreamFn } from "@mariozechner/pi-agent-core";
import type { Context, Model } from "@mariozechner/pi-ai";
import { AssistantMessageEventStream, completeSimple } from "@mariozechner/pi-ai";
import { describe, expect, it, vi } from "vitest";
import { createOllamaAwareStreamFn, shouldDisableStreamingForTools } from "./ollama-stream.js";

vi.mock("@mariozechner/pi-ai", async () => {
  const actual = await vi.importActual<typeof import("@mariozechner/pi-ai")>("@mariozechner/pi-ai");
  return {
    ...actual,
    completeSimple: vi.fn(),
  };
});

describe("shouldDisableStreamingForTools", () => {
  it("defaults to disabling streaming for ollama provider", () => {
    expect(shouldDisableStreamingForTools({ cfg: undefined, provider: "ollama" })).toBe(true);
  });

  it("does not disable streaming for non-ollama providers by default", () => {
    expect(shouldDisableStreamingForTools({ cfg: undefined, provider: "openai" })).toBe(false);
  });

  it("respects explicit streamToolCalls overrides", () => {
    const cfgTrue = {
      models: {
        providers: {
          ollama: {
            baseUrl: "http://127.0.0.1:11434/v1",
            models: [],
            streamToolCalls: true,
          },
        },
      },
    } as const;
    const cfgFalse = {
      models: {
        providers: {
          ollama: {
            baseUrl: "http://127.0.0.1:11434/v1",
            models: [],
            streamToolCalls: false,
          },
        },
      },
    } as const;
    expect(shouldDisableStreamingForTools({ cfg: cfgTrue as any, provider: "ollama" })).toBe(false);
    expect(shouldDisableStreamingForTools({ cfg: cfgFalse as any, provider: "ollama" })).toBe(true);
  });
});

describe("createOllamaAwareStreamFn", () => {
  it("returns the original stream fn when streaming is not disabled", () => {
    const baseStreamFn: StreamFn = () => new AssistantMessageEventStream();
    const wrapped = createOllamaAwareStreamFn({
      cfg: undefined,
      provider: "openai",
      baseStreamFn,
    });
    expect(wrapped).toBe(baseStreamFn);
  });

  it("uses completeSimple fallback for ollama tool turns", async () => {
    vi.mocked(completeSimple).mockResolvedValue({
      role: "assistant",
      content: [{ type: "toolCall", id: "tc_1", name: "read", arguments: { path: "README.md" } }],
      api: "openai-completions",
      provider: "ollama",
      model: "qwen2.5:7b",
      usage: {
        input: 1,
        output: 1,
        cacheRead: 0,
        cacheWrite: 0,
        totalTokens: 2,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
      },
      stopReason: "toolUse",
      timestamp: Date.now(),
    });

    const baseStreamFn: StreamFn = vi.fn(() => new AssistantMessageEventStream());
    const wrapped = createOllamaAwareStreamFn({
      cfg: undefined,
      provider: "ollama",
      baseStreamFn,
    });
    const model = {
      api: "openai-completions",
      provider: "ollama",
      id: "qwen2.5:7b",
      baseUrl: "http://127.0.0.1:11434/v1",
      reasoning: false,
      name: "qwen2.5:7b",
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 8192,
      maxTokens: 2048,
    } as Model<"openai-completions">;
    const context: Context = {
      messages: [],
      tools: [{ name: "read", description: "Read file", parameters: { type: "object" } as any }],
    };

    const stream = wrapped(model, context, {});
    const message = await stream.result();

    expect(baseStreamFn).not.toHaveBeenCalled();
    expect(completeSimple).toHaveBeenCalledOnce();
    expect(message.stopReason).toBe("toolUse");
  });
});

