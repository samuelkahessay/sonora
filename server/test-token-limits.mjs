#!/usr/bin/env node

// Test different token limits to find the sweet spot
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

const schema = {
  type: 'json_schema',
  json_schema: {
    name: 'analysis',
    schema: {
      type: 'object',
      properties: {
        summary: { type: 'string' },
        todos: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              text: { type: 'string' }
            },
            required: ['text'],
            additionalProperties: false
          }
        }
      },
      required: ['summary', 'todos'],
      additionalProperties: false
    },
    strict: true
  }
};

async function testTokenLimit(limit) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-5-nano',
      messages: [
        {
          role: 'system',
          content: 'You extract key information from meeting notes.'
        },
        {
          role: 'user',
          content: 'Extract info from: "Meeting with Sarah about Q2 goals. Follow up by Friday."'
        }
      ],
      response_format: schema,
      max_completion_tokens: limit
    })
  });

  const data = await response.json();
  const message = data.choices?.[0]?.message;
  const usage = data.usage?.completion_tokens_details;

  console.log(`\nLimit: ${limit}`);
  console.log(`  Reasoning: ${usage?.reasoning_tokens || 0}`);
  console.log(`  Total used: ${data.usage?.completion_tokens || 0}`);
  console.log(`  Finish: ${data.choices?.[0]?.finish_reason}`);
  console.log(`  Has content: ${!!message?.content && message.content !== ''}`);
  if (message?.content && message.content !== '') {
    console.log(`  Content length: ${message.content.length} chars`);
    console.log(`  Content: ${message.content.substring(0, 100)}...`);
  }
}

// Test incrementally higher limits
(async () => {
  for (const limit of [200, 400, 600, 800, 1000, 1500]) {
    await testTokenLimit(limit);
  }
})();
