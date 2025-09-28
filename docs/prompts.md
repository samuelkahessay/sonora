# Guided Prompts — File‑Backed Catalog

Edit `Sonora/Resources/prompts.ndjson` to add, update, or remove guided prompts. No code changes required.

- Format: NDJSON (JSON Lines). One prompt object per line.
- Comments: Lines starting with `#` or `//` are ignored. Blank lines ignored.
- Build: Just build/run; the app loads this file at launch. If the file is missing or empty, no prompts will be available — ensure the file is present and valid.

## Schema

Each line is a JSON object with fields:

- `id` (string, required): Stable identifier (used for favorites/usage)
- `text` (string, required): Prompt template. Tokens `[Name]`, `[DayPart]`, `[WeekPart]` are supported.
- `category` (string, optional): one of `growth|work|relationships|creative|goals|mindfulness`. Default: `goals`.
- `depth` (string, optional): `light|medium|deep`. Default: `light`.
- `dayParts` (array<string>, optional): `morning|afternoon|evening|night` (or `any`). Default: `any`.
- `weekParts` (array<string>, optional): `startOfWeek|midWeek|endOfWeek` (or `any`). Default: `any`.
- `weight` (int, optional): >=1. Higher weight slightly increases selection priority. Default: 1.

## Examples

```
{ "id":"work_delegate_or_drop", "text":"What can you delegate or drop to move faster?", "category":"work", "depth":"medium" }
{ "id":"growth_micro_win_today", "text":"What's one small win this [DayPart], [Name]?", "category":"growth", "depth":"light", "dayParts":["morning"], "weekParts":["startOfWeek"], "weight":2 }
// Relationships
{ "id":"relationships_check_in", "text":"Who could use a quick check-in from you today?", "category":"relationships", "depth":"light", "dayParts":["afternoon"] }
```

## Notes

- Localization: The `text` field is used as the display string. If later you add translations, the current localization provider returns the key when a translation is missing, so prompts render correctly during migrations.
- Safety: Invalid lines are skipped with a console warning. The loader logs how many prompts were loaded.
- Favorites/Usage: If you remove a prompt, any stored favorites/usage records for its `id` become inert and are ignored by selection logic.
