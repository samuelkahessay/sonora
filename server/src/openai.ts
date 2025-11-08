import { AnalysisJsonSchemas } from './schema.js';
import { chatCompletionsSupportsTemperature } from './caps.js';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODEL = process.env.SONORA_MODEL || 'gpt-5-nano';

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
  model
}: {
  system: string;
  user: string;
  model?: string;
}): Promise<CreateChatResult> {
  const { result } = await requestWithRetry(async () => {
    const startTime = Date.now();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);

    try {
      const requestBody: Record<string, any> = {
        model: model || MODEL,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user }
        ],
        response_format: { type: 'json_object' },
      };
      if (chatCompletionsSupportsTemperature(requestBody.model)) {
        requestBody.temperature = 1.0;
      };

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
        const isDev = process.env.NODE_ENV === 'development';
        const errorMessage = `GPT Chat Completions API error: ${response.status} - ${response.statusText}`;
        console.error('🚨 Chat Completions API Error:', {
          status: response.status,
          statusText: response.statusText,
          ...(isDev ? { responseBody: text } : { bodyLength: text ? text.length : 0 }),
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
      const content = data?.choices?.[0]?.message?.content;

      if (!content) {
        const debugInfo = {
          hasChoices: Array.isArray(data?.choices),
          choicesLength: data?.choices?.length,
          hasUsage: !!data?.usage
        };
        console.error('🚨 Chat Completions Response Parsing Failed:', debugInfo);
        throw new Error(`No content found in Chat Completions API response. Debug info: ${JSON.stringify(debugInfo)}`);
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
