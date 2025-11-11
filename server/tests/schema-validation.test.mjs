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
