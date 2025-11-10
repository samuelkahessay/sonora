#!/usr/bin/env node

// Test latency vs quality for different token limits
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

const testTranscripts = [
  "Today I had a meeting with Sarah about the Q2 goals. We discussed the project timeline and I need to follow up by Friday with the budget proposal.",
  "Spent the morning reviewing the codebase. Found several performance issues in the authentication module. Need to refactor the token handling and add better caching. Also want to write comprehensive tests.",
  "Had an interesting conversation with the client about their user feedback. They're concerned about the onboarding flow being too complex. Proposed simplifying it into 3 steps instead of 5. Need to create mockups by next Tuesday.",
];

async function testLatencyQuality(model, limit, transcript) {
  const startTime = Date.now();

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
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
      max_completion_tokens: limit
    })
  });

  const latency = Date.now() - startTime;
  const data = await response.json();
  const message = data.choices?.[0]?.message;
  const usage = data.usage;

  return {
    model,
    limit,
    latency,
    success: !!message?.content && message.content !== '',
    finishReason: data.choices?.[0]?.finish_reason,
    usage: {
      reasoning: usage?.completion_tokens_details?.reasoning_tokens || 0,
      output: (usage?.completion_tokens || 0) - (usage?.completion_tokens_details?.reasoning_tokens || 0),
      total: usage?.completion_tokens || 0
    },
    contentLength: message?.content?.length || 0,
    content: message?.content ? JSON.parse(message.content) : null
  };
}

// Test configurations
const configs = [
  // GPT-5 models with different limits
  { model: 'gpt-5-nano', limits: [800, 900, 1000, 1100, 1200] },
  { model: 'gpt-5-mini', limits: [800, 900, 1000, 1100, 1200] },
  // Baseline: GPT-4o-mini
  { model: 'gpt-4o-mini', limits: [450] }
];

console.log('Testing latency and quality across different models and token limits...\n');
console.log('Target: <5s latency, detailed output\n');
console.log('='.repeat(120));

(async () => {
  for (const config of configs) {
    console.log(`\n📊 Model: ${config.model}`);
    console.log('-'.repeat(120));

    for (const limit of config.limits) {
      // Test with middle transcript (good variety)
      const result = await testLatencyQuality(config.model, limit, testTranscripts[1]);

      const speedIcon = result.latency < 5000 ? '✅' : '⚠️ ';
      const qualityIcon = result.success ? '✅' : '❌';

      console.log(`${speedIcon} ${qualityIcon} Limit: ${limit.toString().padEnd(4)} | ` +
                  `Latency: ${(result.latency/1000).toFixed(2)}s | ` +
                  `Reasoning: ${result.usage.reasoning.toString().padEnd(4)} | ` +
                  `Output: ${result.usage.output.toString().padEnd(3)} | ` +
                  `Finish: ${result.finishReason.padEnd(6)} | ` +
                  `Chars: ${result.contentLength}`);

      // Show sample output for successful responses
      if (result.content && limit === 1000) {
        console.log(`   Sample output:`);
        console.log(`   - Summary: ${result.content.summary?.substring(0, 80)}...`);
        console.log(`   - Themes: ${result.content.keyThemes?.length || 0} items`);
        console.log(`   - Todos: ${result.content.simpleTodos?.length || 0} items`);
      }
    }
  }

  console.log('\n' + '='.repeat(120));
  console.log('\n💡 Recommendation: Choose the lowest token limit that:');
  console.log('   1. Has latency < 5s (✅)');
  console.log('   2. Successfully completes (finish_reason: stop)');
  console.log('   3. Produces detailed output (200+ chars)');
})();
