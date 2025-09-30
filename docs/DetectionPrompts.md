# Detection Prompt Guidelines

## Overview
Phase 1 focuses on clarifying instructions for differentiating calendar events from personal reminders. Prompts run in "events" and "reminders" modes share the same foundation: prioritize high precision, avoid duplicate detections, and return only valid JSON.

## Decision Tree
1. Does the phrase describe a concrete commitment tied to a specific time and often a counterpart (meeting, appointment, travel)?
   - **Yes** → treat as potential event; proceed to timing check.
   - **No** → evaluate as reminder candidate instead.
2. Does the language specify or strongly imply when it happens (absolute date, weekday + time, part of day, relative slot)?
   - **Yes** → keep the candidate. Normalize to ISO8601.
   - **No** → drop it; vague items without timing stay out of events.
3. For reminders, confirm the action is owned by the speaker and not a meeting request. Hypothetical or question-only language should be skipped.

## Field Mapping Cheatsheet
- `startDate` (events): use the most specific time available. If only a weekday is given, schedule 09:00 local; for parts of day assign 15:00 (afternoon) or 19:00 (evening). Leave `endDate` null unless duration is stated.
- `dueDate` (reminders): today → 17:00 local; tomorrow morning → 09:00; this weekend → Saturday 10:00; next week → Monday 09:00. Leave null when no clue is present.
- `participants`: list people, teams, or rooms explicitly mentioned. Do not invent names.
- `priority`: High when urgency words appear (`ASAP`, `today`, `urgent`), Low when optional or speculative, Medium otherwise.
- `sourceText`: exact quoted span that triggered the detection. Avoid paraphrasing.

## Confidence Rubric
Set the `confidence` field using the same scale for both events and reminders:
- **High (0.85–1.0)**: intent and timing are explicit.
- **Medium (0.60–0.84)**: one element is inferred but still likely.
- **Low (0.40–0.59)**: tentative or hedged language; skip if confidence would fall below 0.40.

## Examples
- “Meet with Alex next Tuesday at 2 pm to review drafts.” → Event, startDate `next Tuesday 14:00`, participants `Alex`, confidence 0.9.
- “Send updated deck to Alex by Friday EOD.” → Reminder, dueDate `Friday 17:00`, priority High, confidence 0.82.
- “We should probably plan something with marketing soon.” → Drop (no time, tentative).

## Logging Tag
Near-threshold candidates (within 0.10 of the computed minimum) are recorded in `Detection.NearMiss` structured logs along with transcript snippets to guide manual review.
