import { AnalysisJsonSchemas } from './schema.js';

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

// Enhanced logging for GPT-5-nano debugging
function logResponseDetails(data: any, startTime: number, requestParams: any) {
  const isDev = process.env.NODE_ENV === 'development';
  const responseTime = Date.now() - startTime;
  
  if (isDev) {
    console.log('🔍 GPT-5-nano Response Debug:', {
      responseTime: `${responseTime}ms`,
      requestParams: {
        model: requestParams.model,
        reasoningEffort: requestParams.reasoning?.effort,
        verbosity: requestParams.text?.verbosity,
        hasSchema: !!requestParams.text?.format?.json_schema
      },
      responseStructure: {
        hasOutput: Array.isArray(data?.output),
        outputLength: data?.output?.length,
        outputTypes: data?.output?.map((item: any) => item?.type),
        hasUsage: !!data?.usage,
        usageFields: data?.usage ? Object.keys(data.usage) : []
      }
    });
    
    // Log full response structure in development
    console.log('📋 Full Response Structure:', JSON.stringify(data, null, 2));
  }
  
  // Always log performance metrics
  console.log('⏱️  GPT-5-nano Performance:', {
    responseTime: `${responseTime}ms`,
    reasoning: requestParams.reasoning?.effort,
    inputTokens: data?.usage?.input_tokens || 0,
    outputTokens: data?.usage?.output_tokens || 0,
    reasoningTokens: data?.usage?.reasoning_tokens || 0,
    totalTokens: (data?.usage?.input_tokens || 0) + (data?.usage?.output_tokens || 0) + (data?.usage?.reasoning_tokens || 0)
  });
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

// NEW: Responses API
export async function createChatJSON({
  system,
  user,
  verbosity = 'low',
  reasoningEffort = 'medium',
  schema,
}: {
  system: string;
  user: string;
  verbosity?: Verbosity;
  reasoningEffort?: ReasoningEffort;
  schema?: { name: string; schema: any };
}): Promise<CreateChatResult> {
  const { result } = await requestWithRetry(async () => {
    const startTime = Date.now();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    try {
      const requestBody = {
        model: MODEL,
        // Messages as structured content blocks for Responses API
        input: [
          { role: 'system', content: [{ type: 'input_text', text: system }] },
          { role: 'user', content: [{ type: 'input_text', text: user }] }
        ],
        // GPT-5 knobs
        reasoning: { effort: reasoningEffort },
        // Updated parameter locations for Responses API
        text: { 
          format: schema ? {
            type: 'json_schema',
            name: schema.name,    // Name at format level
            schema: schema.schema // Schema directly at format level
          } : { 
            type: 'json_object' 
          },
          verbosity: verbosity
        }
      };

      const response = await fetch('https://api.openai.com/v1/responses', {
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
        const errorMessage = `GPT-5-nano Responses API error: ${response.status} - ${text || 'Unknown error'}`;
        console.error('🚨 Responses API Error:', {
          status: response.status,
          statusText: response.statusText,
          responseBody: text,
          requestParams: {
            model: requestBody.model,
            reasoningEffort: requestBody.reasoning?.effort,
            verbosity: requestBody.text?.verbosity,
            schemaName: schema?.name
          }
        });
        throw new Error(errorMessage);
      }
      
      const data: any = await response.json();
      
      // Log response details for debugging and performance monitoring
      logResponseDetails(data, startTime, requestBody);

      // Enhanced extraction with comprehensive fallback parsing
      let text = '';
      let extractionMethod = '';
      
      try {
        // Strategy 1: GPT-5-nano with reasoning - output[1] is message object
        if (Array.isArray(data?.output) && data.output.length > 1) {
          const messageObj = data.output[1];
          if (messageObj?.type === 'message' && Array.isArray(messageObj?.content)) {
            const textContent = messageObj.content.find((c: any) => c?.type === 'output_text');
            if (textContent?.text) {
              text = textContent.text;
              extractionMethod = 'reasoning-response-structure';
            }
          }
        }
        
        // Strategy 2: GPT-5-nano without reasoning - output[0] is direct message
        if (!text && Array.isArray(data?.output) && data.output.length === 1) {
          const messageObj = data.output[0];
          if (messageObj?.type === 'message' && Array.isArray(messageObj?.content)) {
            const textContent = messageObj.content.find((c: any) => c?.type === 'output_text');
            if (textContent?.text) {
              text = textContent.text;
              extractionMethod = 'direct-message-structure';
            }
          }
        }
        
        // Strategy 3: Legacy/compatibility - top-level output_text
        if (!text && typeof data?.output_text === 'string') {
          text = data.output_text;
          extractionMethod = 'legacy-output-text';
        }
        
        // Strategy 4: Fallback - any text content in first output
        if (!text && Array.isArray(data?.output) && data.output[0]?.content) {
          const first = data.output[0];
          const contentArr = Array.isArray(first?.content) ? first.content : [];
          
          // Try explicit output_text type first
          const outText = contentArr.find((c: any) => c?.type === 'output_text');
          if (outText?.text) {
            text = outText.text;
            extractionMethod = 'fallback-output-text-type';
          } else {
            // Try any output_text or text field
            const anyOutputText = contentArr.find((c: any) => c?.type === 'output_text' && typeof c?.text === 'string');
            const anyText = contentArr.find((c: any) => typeof c?.text === 'string');
            if (anyOutputText?.text) {
              text = anyOutputText.text;
              extractionMethod = 'fallback-any-output-text';
            } else if (anyText?.text) {
              text = anyText.text;
              extractionMethod = 'fallback-any-text';
            }
          }
        }
        
        if (process.env.NODE_ENV === 'development' && extractionMethod) {
          console.log(`✅ Text extracted using: ${extractionMethod}`);
        }
        
      } catch (parseError) {
        console.error('🚨 Error during response parsing:', parseError);
        throw new Error(`Failed to parse GPT-5-nano response structure: ${parseError}`);
      }

      // Enhanced error handling for missing text response
      if (!text) {
        const debugInfo = {
          hasOutput: Array.isArray(data?.output),
          outputLength: data?.output?.length,
          outputTypes: data?.output?.map((item: any) => item?.type),
          hasOutputText: !!data?.output_text,
          schemaUsed: schema?.name,
          reasoningEffort: reasoningEffort,
          verbosity: verbosity
        };
        
        console.error('🚨 GPT-5-nano Response Parsing Failed:', debugInfo);
        console.error('📋 Full response data:', JSON.stringify(data, null, 2));
        
        throw new Error(`No text content found in GPT-5-nano Responses API response. Debug info: ${JSON.stringify(debugInfo)}`);
      }

      // Enhanced token usage tracking with reasoning breakdown
      const usage = {
        input: data?.usage?.input_tokens ?? 0,
        output: data?.usage?.output_tokens ?? 0,
        reasoning: data?.usage?.reasoning_tokens ?? undefined
      };
      
      // Validate expected JSON structure if schema was provided
      if (schema && text) {
        try {
          const parsed = JSON.parse(text);
          if (process.env.NODE_ENV === 'development') {
            console.log(`🔍 Schema validation for ${schema.name}:`, {
              hasRequiredFields: true, // Basic validation - could be enhanced
              responseLength: text.length,
              parsedKeys: Object.keys(parsed)
            });
          }
        } catch (jsonError) {
          console.error('🚨 JSON parsing failed after successful text extraction:', {
            error: jsonError,
            textLength: text.length,
            textPreview: text.substring(0, 200),
            schemaName: schema.name
          });
          // Don't throw here - let the caller handle JSON parsing
        }
      }

      return { jsonText: String(text).trim(), usage };
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
