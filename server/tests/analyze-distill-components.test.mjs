import test from 'node:test';
import assert from 'node:assert/strict';

process.env.OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'test-key';
process.env.SONORA_MODEL = 'gpt-5-mini';
process.env.NODE_ENV = 'test';

const PERSONAL_INSIGHT_RESPONSE = {
  personalInsight: {
    type: 'emotionalTone',
    observation: 'You spoke with a softer tone when reflecting on your progress.',
    invitation: 'How might you celebrate that gentler approach this week?'
  }
};

const CLOSING_NOTE_RESPONSE = {
  closingNote: 'You showed steady patience with yourself—keep trusting that pace.'
};

const COMPLETION_FIXTURES = {
  distill_personal_insight_response: {
    body: PERSONAL_INSIGHT_RESPONSE,
    usage: { input: 42, output: 18 }
  },
  distill_closing_note_response: {
    body: CLOSING_NOTE_RESPONSE,
    usage: { input: 30, output: 12 }
  }
};

function buildResponse({ ok = true, status = 200, statusText = 'OK', jsonData }) {
  return {
    ok,
    status,
    statusText,
    headers: new Headers(),
    async json() { return jsonData; },
    async text() { return JSON.stringify(jsonData); }
  };
}

test('POST /analyze returns parsed payloads for personal insight and closing note modes', async (t) => {
  const originalFetch = globalThis.fetch;
  const completionsSchemas = [];

  globalThis.fetch = async (url, init) => {
    const target = typeof url === 'string' ? url : url.toString();
    if (target.startsWith('http://127.0.0.1')) {
      return originalFetch(url, init);
    }
    if (target.endsWith('/chat/completions')) {
      const body = JSON.parse(init?.body ?? '{}');
      const schemaName = body?.response_format?.json_schema?.name;
      completionsSchemas.push(schemaName);
      const fixture = COMPLETION_FIXTURES[schemaName];
      if (!fixture) {
        throw new Error(`No fixture for schema ${schemaName}`);
      }
      const { usage } = fixture;
      return buildResponse({
        jsonData: {
          choices: [
            {
              message: {
                content: JSON.stringify(fixture.body)
              }
            }
          ],
          usage: {
            prompt_tokens: usage.input,
            completion_tokens: usage.output,
            completion_tokens_details: { reasoning_tokens: 0 },
            total_tokens: usage.input + usage.output
          }
        }
      });
    }

    if (target.endsWith('/moderations')) {
      return buildResponse({ jsonData: { results: [{ flagged: false }] } });
    }

    throw new Error(`Unhandled fetch URL ${target}`);
  };

  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const { default: app } = await import('../dist/server.js');
  const server = app.listen(0);
  t.after(() => server.close());

  const port = server.address().port;
  const url = (path) => `http://127.0.0.1:${port}${path}`;

  const baseBody = {
    transcript: 'This is a sufficiently long transcript content for analysis.',
    historicalContext: []
  };

  const personalResponse = await fetch(url('/analyze'), {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-entitlement-pro': '1'
    },
    body: JSON.stringify({ ...baseBody, mode: 'distill-personalInsight' })
  });

  assert.equal(personalResponse.status, 200);
  const personalBody = await personalResponse.json();
  assert.equal(personalBody.mode, 'distill-personalInsight');
  assert.deepEqual(personalBody.data, PERSONAL_INSIGHT_RESPONSE);

  const closingResponse = await fetch(url('/analyze'), {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-entitlement-pro': '1'
    },
    body: JSON.stringify({ ...baseBody, mode: 'distill-closingNote' })
  });

  assert.equal(closingResponse.status, 200);
  const closingBody = await closingResponse.json();
  assert.equal(closingBody.mode, 'distill-closingNote');
  assert.deepEqual(closingBody.data, CLOSING_NOTE_RESPONSE);

  assert.deepEqual(completionsSchemas, [
    'distill_personal_insight_response',
    'distill_closing_note_response'
  ]);
});
