import test from 'node:test';
import assert from 'node:assert/strict';
import { DistillJsonSchema, LiteDistillJsonSchema } from '../dist/schema.js';

/**
 * Ensures invitation is explicitly required and nullable so OpenAI's strict JSON schema validation passes.
 * @param {typeof DistillJsonSchema} schema
 * @param {string} label
 */
function assertInvitationRequirement(schema, label) {
  const personalInsight = schema.schema.properties.personalInsight;
  assert.ok(personalInsight, `${label}: personalInsight block must exist`);

  const invitation = personalInsight.properties?.invitation;
  assert.ok(invitation, `${label}: personalInsight.invitation schema missing`);

  const required = personalInsight.required ?? [];
  assert.ok(required.includes('invitation'), `${label}: invitation must be listed in required[]`);

  const invitationType = invitation.type;
  if (Array.isArray(invitationType)) {
    assert.ok(
      invitationType.includes('null'),
      `${label}: invitation must allow null in strict schema mode`
    );
  }
}

test('Distill schema requires invitation field', () => {
  assertInvitationRequirement(DistillJsonSchema, 'distill');
});

test('Lite Distill schema requires invitation field', () => {
  assertInvitationRequirement(LiteDistillJsonSchema, 'lite-distill');
});

function assertRelatedMemosRequirement(schema) {
  const patterns = schema.schema.properties.patterns;
  assert.ok(patterns, 'distill: patterns definition missing');
  const relatedMemos = patterns.items?.properties?.relatedMemos;
  assert.ok(relatedMemos, 'distill: relatedMemos block missing');
  const itemSchema = relatedMemos.items;
  assert.ok(itemSchema?.properties, 'distill: relatedMemos items missing properties');

  const required = itemSchema.required ?? [];
  const expected = ['memoId', 'title', 'daysAgo', 'snippet'];
  for (const key of expected) {
    assert.ok(required.includes(key), `distill: relatedMemos must require ${key}`);
  }

  const memoIdType = itemSchema.properties.memoId?.type;
  assert.deepEqual(
    memoIdType?.sort?.() ?? memoIdType,
    ['null', 'string'],
    'distill: relatedMemos.memoId must allow string|null'
  );
  const daysAgoType = itemSchema.properties.daysAgo?.type;
  assert.deepEqual(
    daysAgoType?.sort?.() ?? daysAgoType,
    ['null', 'number'],
    'distill: relatedMemos.daysAgo must allow number|null'
  );
  const snippetType = itemSchema.properties.snippet?.type;
  assert.deepEqual(
    snippetType?.sort?.() ?? snippetType,
    ['null', 'string'],
    'distill: relatedMemos.snippet must allow string|null'
  );
}

test('Distill schema relatedMemos fields are required/nullable', () => {
  assertRelatedMemosRequirement(DistillJsonSchema);
});
