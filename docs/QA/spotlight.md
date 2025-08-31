QA Checklist — Spotlight Indexing

Manual Tests
- Create a new memo; within 5–10s, search in iOS Spotlight for the memo title/keywords. Verify a result appears with correct title and description.
- Edit content by completing transcription; within 5–10s, search updates reflect transcript preview.
- Delete a memo; verify the Spotlight result disappears after a short delay.
- Tap a Spotlight result (cold start and warm start). The app should open MemoDetailView for that memo.
- Open deep link sonora://memo/<id> — app should open the memo detail.
- Toggle the indexing feature off (temporarily use AppConfiguration.shared.searchIndexingEnabled = false in a debug hook). Verify new saves/updates do not index; setting back to true and calling reindexAll() restores entries.

Reliability
- Works offline (Spotlight indexing does not require network; no crashes when unavailable).
- No crashes if CSSearchableIndex is not available; actions log warnings and continue.

Performance
- Bulk reindex (~1000 memos) completes successfully without UI hangs.
- Verify index calls are debounced (rapid edits do not queue redundant index operations).

