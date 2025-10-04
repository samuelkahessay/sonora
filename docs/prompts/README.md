# Prompts Documentation

This document consolidates two areas:
- Guided recording prompts (file‑backed catalog)
- Detection prompt guidelines (events vs reminders)

---

## Guided Prompts — File‑Backed Catalog

Edit `Sonora/Resources/prompts.ndjson` to add, update, or remove guided prompts. No code changes required.

- Format: NDJSON (JSON Lines). One prompt object per line.
- Comments: Lines starting with `#` or `//` are ignored. Blank lines ignored.
- Build: Just build/run; the app loads this file at launch. If the file is missing or empty, no prompts will be available — ensure the file is present and valid.

### Schema

Each line is a JSON object with fields:

- `id` (string, required): Stable identifier (used for favorites/usage)
- `text` (string, required): Prompt template. Tokens `[Name]`, `[DayPart]`, `[WeekPart]` are supported.
- `category` (string, optional): one of `growth|work|relationships|creative|goals|mindfulness`. Default: `goals`.
- `depth` (string, optional): `light|medium|deep`. Default: `light`.
- `dayParts` (array<string>, optional): `morning|afternoon|evening|night` (or `any`). Default: `any`.
- `weekParts` (array<string>, optional): `startOfWeek|midWeek|endOfWeek` (or `any`). Default: `any`.
- `weight` (int, optional): >=1. Higher weight slightly increases selection priority. Default: 1.

### Examples

```
{ "id":"work_delegate_or_drop", "text":"What can you delegate or drop to move faster?", "category":"work", "depth":"medium" }
{ "id":"growth_micro_win_today", "text":"What's one small win this [DayPart], [Name]?", "category":"growth", "depth":"light", "dayParts":["morning"], "weekParts":["startOfWeek"], "weight":2 }
// Relationships
{ "id":"relationships_check_in", "text":"Who could use a quick check-in from you today?", "category":"relationships", "depth":"light", "dayParts":["afternoon"] }
```

### Notes

- Localization: The `text` field is used as the display string. If later you add translations, the current localization provider returns the key when a translation is missing, so prompts render correctly during migrations.
- Safety: Invalid lines are skipped with a console warning. The loader logs how many prompts were loaded.
- Favorites/Usage: If you remove a prompt, any stored favorites/usage records for its `id` become inert and are ignored by selection logic.

---

## Detection Prompt Guidelines

### Overview
Phase 1 focuses on clarifying instructions for differentiating calendar events from personal reminders. Prompts run in "events" and "reminders" modes share the same foundation: prioritize high precision, avoid duplicate detections, and return only valid JSON.

### Decision Tree
1. Does the phrase describe a concrete commitment tied to a specific time and often a counterpart (meeting, appointment, travel)?
   - Yes → treat as potential event; proceed to timing check.
   - No → evaluate as reminder candidate instead.
2. Does the language specify or strongly imply when it happens (absolute date, weekday + time, part of day, relative slot)?
   - Yes → keep the candidate. Normalize to ISO8601.
   - No → drop it; vague items without timing stay out of events.
3. For reminders, confirm the action is owned by the speaker and not a meeting request. Hypothetical or question-only language should be skipped.

### Field Mapping Cheatsheet
- `startDate` (events): use the most specific time available. If only a weekday is given, schedule 09:00 local; for parts of day assign 15:00 (afternoon) or 19:00 (evening). Leave `endDate` null unless duration is stated.
- `dueDate` (reminders): today → 17:00 local; tomorrow morning → 09:00; this weekend → Saturday 10:00; next week → Monday 09:00. Leave null when no clue is present.
- `participants`: list people, teams, or rooms explicitly mentioned. Do not invent names.
- `priority`: High when urgency words appear (`ASAP`, `today`, `urgent`), Low when optional or speculative, Medium otherwise.
- `sourceText`: exact quoted span that triggered the detection. Avoid paraphrasing.

### Confidence Rubric
Set the `confidence` field using the same scale for both events and reminders:
- High (0.85–1.0): intent and timing are explicit.
- Medium (0.60–0.84): one element is inferred but still likely.
- Low (0.40–0.59): tentative or hedged language; skip if confidence would fall below 0.40.

### Examples
- “Meet with Alex next Tuesday at 2 pm to review drafts.” → Event, startDate `next Tuesday 14:00`, participants `Alex`, confidence 0.9.
- “Send updated deck to Alex by Friday EOD.” → Reminder, dueDate `Friday 17:00`, priority High, confidence 0.82.
- “We should probably plan something with marketing soon.” → Drop (no time, tentative).

### Logging Tag
Near-threshold candidates (within 0.10 of the computed minimum) are recorded in `Detection.NearMiss` structured logs along with transcript snippets to guide manual review.

