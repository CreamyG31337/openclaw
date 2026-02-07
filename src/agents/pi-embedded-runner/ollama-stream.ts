import type { StreamFn } from "@mariozechner/pi-agent-core";
import type { Context } from "@mariozechner/pi-ai";
import { completeSimple, createAssistantMessageEventStream, streamSimple } from "@mariozechner/pi-ai";
import type { OpenClawConfig } from "../../config/config.js";
import { log } from "./logger.js";

function contextHasTools(context: Context): boolean {
  return Array.isArray(context.tools) && context.tools.length > 0;
}

export function shouldDisableStreamingForTools(params: {
  cfg: OpenClawConfig | undefined;
  provider: string;
}): boolean {
  const providerConfig = params.cfg?.models?.providers?.[params.provider];
  if (!providerConfig) {
    return params.provider === "ollama";
  }
  if (providerConfig.streamToolCalls === true) {
    return false;
  }
  if (providerConfig.streamToolCalls === false) {
    return true;
  }
  return params.provider === "ollama";
}

export function createOllamaAwareStreamFn(params: {
  cfg: OpenClawConfig | undefined;
  provider: string;
  baseStreamFn?: StreamFn;
}): StreamFn {
  const underlying = params.baseStreamFn ?? streamSimple;
  const disableStreamingForTools = shouldDisableStreamingForTools({
    cfg: params.cfg,
    provider: params.provider,
  });
  if (!disableStreamingForTools) {
    return underlying;
  }

  const wrappedStreamFn: StreamFn = (model, context, options) => {
    if (!contextHasTools(context)) {
      return underlying(model, context, options);
    }

    log.debug(
      `using completeSimple fallback for ${model.provider}/${model.id} because streamToolCalls is disabled`,
    );

    const stream = createAssistantMessageEventStream();
    void (async () => {
      try {
        const message = await completeSimple(model, context, options);
        if (message.stopReason === "error" || message.stopReason === "aborted") {
          stream.push({
            type: "error",
            reason: message.stopReason,
            error: message,
          });
        } else {
          stream.push({
            type: "done",
            reason: message.stopReason,
            message,
          });
        }
        stream.end(message);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        log.error(`completeSimple fallback failed for ${model.provider}/${model.id}: ${errorMessage}`);
        const errorAssistantMessage = {
          role: "assistant" as const,
          content: [],
          api: model.api,
          provider: model.provider,
          model: model.id,
          usage: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            totalTokens: 0,
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
          },
          stopReason: "error" as const,
          errorMessage,
          timestamp: Date.now(),
        };
        stream.push({
          type: "error",
          reason: "error",
          error: errorAssistantMessage,
        });
        stream.end(errorAssistantMessage);
      }
    })();
    return stream;
  };

  return wrappedStreamFn;
}

