const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const MODEL = process.env.SONORA_MODEL || 'gpt-5-nano';

if (!OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY environment variable is required');
}

interface ChatResponse {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
  };
}

interface CreateChatResult {
  jsonText: string;
  usage: { input: number; output: number };
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function requestWithRetry<T>(fn: () => Promise<T>): Promise<{ result: T; retryCount: number }> {
  const maxRetries = 4;
  let retryCount = 0;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await fn();
      return { result, retryCount };
    } catch (error: any) {
      const isRetryable = error.status === 429 || (error.status >= 500 && error.status < 600);
      
      if (!isRetryable || attempt === maxRetries - 1) {
        throw { ...error, retryCount };
      }
      
      retryCount++;
      const baseDelay = 200;
      const maxDelay = 2000;
      const exponentialDelay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
      const jitter = Math.random() * 0.3 * exponentialDelay;
      
      await sleep(exponentialDelay + jitter);
    }
  }
  
  throw new Error('Unexpected retry loop exit');
}

export async function createChatJSON({ system, user }: { system: string; user: string }): Promise<CreateChatResult> {
  const { result, retryCount } = await requestWithRetry(async () => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    
    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: MODEL,
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user }
          ],
          temperature: 0.2,
          top_p: 0.9,
          response_format: { type: 'json_object' },
          seed: 7,
          max_tokens: 1000
        })
      });
      
      clearTimeout(timeout);
      
      if (!response.ok) {
        throw { status: response.status, message: `OpenAI API error: ${response.status}` };
      }
      
      const data = await response.json() as ChatResponse;
      return data;
    } catch (error) {
      clearTimeout(timeout);
      throw error;
    }
  });
  
  const content = result.choices[0]?.message?.content || '{}';
  const usage = {
    input: result.usage?.prompt_tokens || 0,
    output: result.usage?.completion_tokens || 0
  };
  
  return { jsonText: content, usage };
}
