#!/usr/bin/env node

// Debug script to test GPT-5-nano response structure
import * as fs from 'fs';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('OPENAI_API_KEY environment variable required');
  process.exit(1);
}

async function testGPT5(testCase) {
  console.log(`\n${'='.repeat(80)}`);
  console.log(`TEST: ${testCase.name}`);
  console.log(`${'='.repeat(80)}\n`);

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(testCase.requestBody)
  });

  if (!response.ok) {
    const text = await response.text();
    console.error('❌ API Error:', {
      status: response.status,
      statusText: response.statusText,
      body: text
    });
    return null;
  }

  const data = await response.json();

  console.log('✅ Response received');
  console.log('\n📊 Usage:', data.usage);
  console.log('\n📝 Choices:', data.choices?.length || 0);

  if (data.choices?.[0]) {
    const choice = data.choices[0];
    const message = choice.message;

    console.log('\n🔍 Message structure:');
    console.log('  - role:', message.role);
    console.log('  - content type:', typeof message.content);
    console.log('  - content is Array:', Array.isArray(message.content));
    console.log('  - refusal:', message.refusal || 'none');

    console.log('\n📦 Full message.content:');
    console.log(JSON.stringify(message.content, null, 2));

    console.log('\n📦 Full message object:');
    console.log(JSON.stringify(message, null, 2));
  }

  // Save full response to file for inspection
  const filename = `/tmp/gpt5-debug-${testCase.name.replace(/\s+/g, '-')}.json`;
  fs.writeFileSync(filename, JSON.stringify(data, null, 2));
  console.log(`\n💾 Full response saved to: ${filename}`);

  return data;
}

// Test cases - incrementally more complex
const tests = [
  {
    name: '1-minimal-json-object',
    requestBody: {
      model: 'gpt-5-nano',
      messages: [
        { role: 'user', content: 'Return JSON with a greeting field containing "hello"' }
      ],
      response_format: { type: 'json_object' },
      max_completion_tokens: 50
    }
  },
  {
    name: '2-json-schema-simple',
    requestBody: {
      model: 'gpt-5-nano',
      messages: [
        { role: 'user', content: 'Return a greeting' }
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'greeting',
          schema: {
            type: 'object',
            properties: {
              message: { type: 'string' }
            },
            required: ['message'],
            additionalProperties: false
          },
          strict: true
        }
      },
      max_completion_tokens: 50
    }
  },
  {
    name: '3-json-schema-complex',
    requestBody: {
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
      response_format: {
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
      },
      max_completion_tokens: 200
    }
  }
];

// Run tests sequentially
(async () => {
  for (const test of tests) {
    await testGPT5(test);
    console.log('\n');
  }
})();
