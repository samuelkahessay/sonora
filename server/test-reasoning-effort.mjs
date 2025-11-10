#!/usr/bin/env node

// Test different reasoning_effort levels with GPT-5 models
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

const schema = {
  type: 'json_schema',
  json_schema: {
    name: 'lite_distill_response',
    schema: {
      type: 'object',
      properties: {
        summary: { type: 'string' },
        keyThemes: {
          type: 'array',
          items: { type: 'string' }
        },
        personalInsight: {
          type: 'object',
          properties: {
            type: { type: 'string' },
            observation: { type: 'string' },
            invitation: { type: 'string' }
          },
          required: ['type', 'observation', 'invitation'],
          additionalProperties: false
        },
        simpleTodos: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              text: { type: 'string' },
              priority: { type: 'string', enum: ['high', 'medium', 'low'] }
            },
            required: ['text', 'priority'],
            additionalProperties: false
          }
        },
        reflectionQuestion: { type: 'string' },
        closingNote: { type: 'string' }
      },
      required: ['summary', 'keyThemes', 'personalInsight', 'simpleTodos', 'reflectionQuestion', 'closingNote'],
      additionalProperties: false
    },
    strict: true
  }
};

const transcript = "Spent the morning reviewing the codebase. Found several performance issues in the authentication module. Need to refactor the token handling and add better caching. Also want to write comprehensive tests.";

async function testConfiguration(model, tokenLimit, reasoningEffort) {
  const startTime = Date.now();

  try {
    const requestBody = {
      model,
      messages: [
        {
          role: 'system',
          content: 'You help people reflect on their voice memos by identifying key themes, actionable tasks, and meaningful patterns. Provide concise, thoughtful analysis.'
        },
        {
          role: 'user',
          content: `Analyze this voice memo: "${transcript}"`
        }
      ],
      response_format: schema,
      max_completion_tokens: tokenLimit
    };

    // Add reasoning_effort for GPT-5 models
    if (reasoningEffort) {
      requestBody.reasoning_effort = reasoningEffort;
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    const latency = Date.now() - startTime;

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ API Error (${response.status}):`, errorText.substring(0, 200));
      return null;
    }

    const data = await response.json();
    const message = data.choices?.[0]?.message;
    const usage = data.usage;

    const reasoningTokens = usage?.completion_tokens_details?.reasoning_tokens || 0;
    const totalTokens = usage?.completion_tokens || 0;
    const outputTokens = totalTokens - reasoningTokens;

    return {
      model,
      tokenLimit,
      reasoningEffort: reasoningEffort || 'none',
      latency,
      success: !!message?.content && message.content !== '',
      finishReason: data.choices?.[0]?.finish_reason,
      usage: {
        reasoning: reasoningTokens,
        output: outputTokens,
        total: totalTokens
      },
      contentLength: message?.content?.length || 0,
      content: message?.content ? JSON.parse(message.content) : null
    };
  } catch (err) {
    console.error(`❌ Exception:`, err.message);
    return null;
  }
}

console.log('🧪 Testing reasoning_effort parameter with different token limits\n');
console.log('Transcript:', transcript);
console.log('\n' + '='.repeat(140));

(async () => {
  // Test matrix: model x token limit x reasoning effort
  const tests = [
    // GPT-5-nano: test reasoning efforts
    { model: 'gpt-5-nano', limit: 800, effort: 'low' },
    { model: 'gpt-5-nano', limit: 800, effort: 'medium' },
    { model: 'gpt-5-nano', limit: 800, effort: 'high' },
    { model: 'gpt-5-nano', limit: 1000, effort: 'low' },
    { model: 'gpt-5-nano', limit: 1000, effort: 'medium' },
    { model: 'gpt-5-nano', limit: 1000, effort: 'high' },
    { model: 'gpt-5-nano', limit: 1200, effort: 'low' },

    // GPT-5-mini: test reasoning efforts
    { model: 'gpt-5-mini', limit: 800, effort: 'low' },
    { model: 'gpt-5-mini', limit: 800, effort: 'medium' },
    { model: 'gpt-5-mini', limit: 1000, effort: 'low' },

    // Baseline: GPT-4o-mini (no reasoning_effort parameter)
    { model: 'gpt-4o-mini', limit: 450, effort: null }
  ];

  console.log('\n📊 Results:\n');
  console.log(`${'Model'.padEnd(15)} | ${'Limit'.padEnd(5)} | ${'Effort'.padEnd(8)} | ${'Latency'.padEnd(8)} | ${'Rsng'.padEnd(5)} | ${'Out'.padEnd(4)} | ${'Finish'.padEnd(6)} | ${'Chars'.padEnd(5)} | Status`);
  console.log('-'.repeat(140));

  for (const test of tests) {
    const result = await testConfiguration(test.model, test.limit, test.effort);

    if (!result) {
      console.log(`${test.model.padEnd(15)} | ${test.limit.toString().padEnd(5)} | ${(test.effort || '-').padEnd(8)} | FAILED`);
      continue;
    }

    const speedIcon = result.latency < 5000 ? '✅' : '⚠️ ';
    const qualityIcon = result.success ? '✅' : '❌';
    const finishIcon = result.finishReason === 'stop' ? '✅' : '⚠️ ';

    console.log(
      `${result.model.padEnd(15)} | ` +
      `${result.tokenLimit.toString().padEnd(5)} | ` +
      `${result.reasoningEffort.padEnd(8)} | ` +
      `${(result.latency / 1000).toFixed(2)}s`.padEnd(8) + ` | ` +
      `${result.usage.reasoning.toString().padEnd(5)} | ` +
      `${result.usage.output.toString().padEnd(4)} | ` +
      `${result.finishReason.padEnd(6)} | ` +
      `${result.contentLength.toString().padEnd(5)} | ` +
      `${speedIcon} ${qualityIcon} ${finishIcon}`
    );

    // Show sample for successful medium effort responses
    if (result.content && result.reasoningEffort === 'medium' && result.tokenLimit === 1000) {
      console.log(`  └─ Sample: "${result.content.summary?.substring(0, 70)}..."`);
      console.log(`  └─ Todos: ${result.content.simpleTodos?.map(t => t.text).join(', ')}`);
    }

    // Small delay to avoid rate limits
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log('\n' + '='.repeat(140));
  console.log('\n💡 Legend:');
  console.log('   ✅ = Meets criteria  |  ⚠️  = Warning  |  ❌ = Failed');
  console.log('   Latency: ✅ <5s  |  Quality: ✅ has content  |  Finish: ✅ stop (not length)');
  console.log('\n📈 Recommendation: Choose configuration with all ✅✅✅ and lowest latency');
})();
