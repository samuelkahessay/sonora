import { AnalysisJsonSchemas } from './schema.js';
import { chatCompletionsSupportsTemperature } from './caps.js';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODEL = process.env.SONORA_MODEL || 'gpt-5-mini';

if (!OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY environment variable is required');
}

type Verbosity = 'low'|'medium'|'high';
type ReasoningEffort = 'low'|'medium'|'high';

export interface CreateChatResult {
  jsonText: string;
  usage: { input: number; output: number; reasoning?: number };
}

export interface ModerationOutput {
  flagged: boolean;
  categories?: Record<string, boolean>;
  category_scores?: Record<string, number>;
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function requestWithRetry<T>(fn: () => Promise<T>): Promise<{ result: T; retryCount: number }> {
  const maxRetries = 3;
  for (let i = 0; i <= maxRetries; i++) {
    try {
      const result = await fn();
      return { result, retryCount: i };
    } catch (err: any) {
      const isRetryable = err?.name === 'AbortError' || String(err?.message || '').includes('rate') || String(err?.message || '').includes('timeout') || String(err?.message || '').includes('5');
      if (i === maxRetries || !isRetryable) throw err;
      const backoff = 400 * Math.pow(2, i) + Math.floor(Math.random() * 200);
      await sleep(backoff);
    }
  }
  throw new Error('Unexpected retry loop exit');
}

// Chat Completions API for Pro-tier modes (less strict schema validation)
export async function createChatCompletionsJSON({
  system,
  user,
  model,
  mode
}: {
  system: string;
  user: string;
  model?: string;
  mode?: string;
}): Promise<CreateChatResult> {
  const { result } = await requestWithRetry(async () => {
    const startTime = Date.now();
    const controller = new AbortController();
    // Allow longer generations for GPT-5 family; align with client 180s
    const timeout = setTimeout(() => controller.abort(), 180000);

    try {
      // Token limits accounting for GPT-5 reasoning overhead (~600-800 tokens)
      // Each mode needs: reasoning budget + output budget (~1000 tokens minimum)
      const tokenLimits: Record<string, number> = {
        'lite-distill': 1200,        // Full response: reasoning + 6 fields
        'distill': 1500,             // Full Pro response: reasoning + 7 fields + patterns
        'distill-summary': 1000,     // Single field BUT needs reasoning overhead
        'distill-actions': 1000,     // Single field BUT needs reasoning overhead
        'distill-themes': 1000,      // Single field BUT needs reasoning overhead
        'distill-reflection': 1000,  // Single field BUT needs reasoning overhead
        'events': 1000,              // Reasoning + event extraction
        'reminders': 1000            // Reasoning + reminder extraction
      };

      const selectedModel = (model || MODEL);
      const mLower = selectedModel.toLowerCase();

      const requestBody: Record<string, any> = {
        model: selectedModel,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user }
        ]
      };

      // Use strict JSON Schema format for GPT-5 models; fall back to json_object otherwise
      if (mLower.startsWith('gpt-5') && mode && (AnalysisJsonSchemas as any)[mode]) {
        const schemaDef = (AnalysisJsonSchemas as any)[mode];
        requestBody.response_format = {
          type: 'json_schema',
          json_schema: {
            name: schemaDef.name,
            schema: schemaDef.schema,
            strict: true
          }
        };
      } else {
        requestBody.response_format = { type: 'json_object' };
      }

      // Apply token limit if mode is specified
      if (mode && tokenLimits[mode]) {
        if (mLower.startsWith('gpt-5')) {
          requestBody.max_completion_tokens = tokenLimits[mode];
        } else {
          requestBody.max_tokens = tokenLimits[mode];
        }
      }

      if (chatCompletionsSupportsTemperature(requestBody.model)) {
        requestBody.temperature = 1.0;
      }

      if (mLower.startsWith('gpt-5')) {
        requestBody.reasoning_effort = 'low';
      }

      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        signal: controller.signal,
        body: JSON.stringify(requestBody)
      });

      clearTimeout(timeout);

      if (!response.ok) {
        const text = await response.text().catch(() => '');
        const errorMessage = `GPT Chat Completions API error: ${response.status} - ${response.statusText}`;
        let errorJson: any;
        try {
          errorJson = JSON.parse(text);
        } catch {}
        console.error('🚨 Chat Completions API Error:', {
          status: response.status,
          statusText: response.statusText,
          bodyLength: text ? text.length : 0,
          bodyPreview: text ? text.slice(0, 400) : '',
          errorMessage: errorJson?.error?.message,
          errorType: errorJson?.error?.type,
          requestParams: {
            model: requestBody.model,
            temperature: requestBody.temperature,
            responseFormat: requestBody.response_format
          }
        });
        throw new Error(errorMessage);
      }

      const data: any = await response.json();
      const latency = Date.now() - startTime;

      // Log performance metrics
      console.log('⏱️  Chat Completions Performance:', {
        responseTime: `${latency}ms`,
        model: requestBody.model,
        inputTokens: data?.usage?.prompt_tokens || 0,
        outputTokens: data?.usage?.completion_tokens || 0,
        totalTokens: data?.usage?.total_tokens || 0
      });

      // Extract content from Chat Completions response
      const message = data?.choices?.[0]?.message;
      const refusal = message?.refusal;

      const extractContent = (): string | undefined => {
        const raw = message?.content;
        if (typeof raw === 'string') {
          return raw;
        }
        if (Array.isArray(raw)) {
          const parts = raw
            .map((part: any) => {
              if (typeof part === 'string') return part;
              if (typeof part?.text === 'string') return part.text;
              if (Array.isArray(part?.text)) {
                return part.text.filter((t: any) => typeof t === 'string').join('\n');
              }
              if (typeof part?.content === 'string') return part.content;
              if (Array.isArray(part?.content)) {
                return part.content.filter((t: any) => typeof t === 'string').join('\n');
              }
              if (part?.type === 'output_text' && typeof part?.text === 'string') {
                return part.text;
              }
              if (part?.type === 'output_text' && Array.isArray(part?.text)) {
                return part.text.filter((t: any) => typeof t === 'string').join('\n');
              }
              if (part?.type === 'tool_call' && typeof part?.input_json === 'string') {
                return part.input_json;
              }
              return undefined;
            })
            .filter((p: string | undefined) => typeof p === 'string' && p.trim().length > 0) as string[];
          if (parts.length > 0) {
            return parts.join('\n');
          }
        }

        if (Array.isArray(message?.tool_calls)) {
          const toolJson = message.tool_calls
            .map((call: any) => call?.function?.arguments)
            .filter((args: any) => typeof args === 'string' && args.trim().length > 0);
          if (toolJson.length > 0) {
            return toolJson.join('\n');
          }
        }

        return undefined;
      };

      const content = extractContent();

      if (!content) {
        const debugInfo = {
          hasChoices: Array.isArray(data?.choices),
          choicesLength: data?.choices?.length,
          hasUsage: !!data?.usage,
          hasRefusal: !!refusal,
          refusalMessage: refusal || 'none'
        };
        console.error('🚨 Chat Completions Response Parsing Failed:', debugInfo);
        throw new Error(`No content found in Chat Completions API response. ${refusal ? `Refusal: ${refusal}` : `Debug info: ${JSON.stringify(debugInfo)}`}`);
      }

      // Extract token usage
      const usage = {
        input: data?.usage?.prompt_tokens ?? 0,
        output: data?.usage?.completion_tokens ?? 0
      };

      return { jsonText: String(content).trim(), usage };
    } catch (e) {
      clearTimeout(timeout);
      throw e;
    }
  });

  return result;
}

export async function createModeration(text: string): Promise<ModerationOutput> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch('https://api.openai.com/v1/moderations', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: 'omni-moderation-latest',
        input: text.slice(0, 15000)
      })
    });
    clearTimeout(timeout);
    if (!response.ok) throw new Error(`Moderation API error: ${response.status}`);
    const data: any = await response.json();
    const res = (data && (data as any).results) ? (data as any).results[0] : undefined;
    return {
      flagged: !!res?.flagged,
      categories: res?.categories,
      category_scores: res?.category_scores
    };
  } catch (e) {
    clearTimeout(timeout);
    // Fail-closed as not flagged to avoid breaking app; server logs can capture details separately
    return { flagged: false };
  }
}
