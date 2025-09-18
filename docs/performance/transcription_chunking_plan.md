# Cloud Transcription Chunking – Performance Investigation Plan

## Goals
- Validate the current cloud transcription pipeline that performs chunked uploads for long recordings.
- Identify concrete measurements required to understand latency bottlenecks (chunk export, upload, backend processing, aggregation).
- Evaluate the feasibility and risk of processing multiple chunks in parallel before attempting an implementation.

---

## 1. Verify the Existing Pipeline
1. **Trace execution path**
   - Entry point: `StartTranscriptionUseCase.execute` (auto branch).
   - Chunk creation: `AudioChunkManager.createChunks` (sequential AVAsset export).
   - Cloud uploads: `transcribeChunksWithLanguage` → `TranscriptionService.transcribe` (currently sequential).
   - Aggregation: `TranscriptionAggregator.aggregate` + metadata reconciliation.
2. **Instrumentation checklist**
   - Add temporary signposts / `os_signpost` markers for:
     - VAD segmentation duration.
     - Chunk export time per segment and total time spent in `AudioChunkManager`.
     - Network round-trip per chunk (time from request start until response parsed).
     - Aggregation / moderation / metadata save durations.
   - Capture baseline metrics with a representative set of recordings (short, mid (~5 min), long (~30 min)).
3. **Data collection**
   - Record device type, iOS version, network type (Wifi vs LTE), chunk count, success/failure rate.
   - Store anonymised run summaries in a spreadsheet or lightweight JSON log for comparison.

---

## 2. Parallel Chunk Processing Feasibility

### Current Behaviour
- Chunks are processed sequentially to keep ordering deterministic and to avoid concurrent requests to the backend.
- Operation progress is updated after each chunk (`stageLabel`), guaranteeing monotonic `percentage` updates for the UI.

### Questions to Answer Before Changing
1. **Backend limits**
   - Confirm with API owners whether the cloud endpoint can handle N concurrent requests per memo without throttling or mixing segments between jobs.
   - Verify rate limiting policies and cost implications (parallelism may increase instantaneous load).
2. **Ordering requirements**
   - Aggregation currently relies on original start times to sort transcripts; ensure aggregator is order-independent.
   - Confirm metadata (e.g., detected language, confidence) can be merged when chunks complete out of order.
3. **Device resource impact**
   - Multiple concurrent uploads increase CPU, memory, and battery consumption. Profile using Instruments (Energy Log, Network) with 2×, 3× concurrency.
4. **Progress reporting**
   - Redesign progress measurement if chunks complete out of order. Proposal: track `completedCount/total` off-main-thread and map to percentage.

### Experiment Proposal
- Implement a prototype branch using `withTaskGroup` to submit chunks with a configurable concurrency limit (start with 2).
- Collect the same telemetry as in baseline runs.
- Compare total transcription time, average chunk latency, failure rate, and resource usage.
- If gains are marginal (<10%) or error rate rises, keep sequential approach.

### Potential Outcomes
- **Positive**: Backend tolerates parallelism, total wall-clock time drops materially → proceed with production hardening (retry strategy, adaptive concurrency based on device/network conditions).
- **Negative/Neutral**: No significant speedup or stability regressions → retain sequential model and focus on upstream optimisations (chunk sizing, VAD thresholds, caching).

---

## 3. Additional Optimization Ideas (Post-Verification)
- Tune chunk duration targets to balance parallelism overhead vs. request payload size.
- Cache or reuse language detection results to skip the second pass when confidence is already high.
- Batch upload to the API (if supported) to reduce per-request overhead instead of parallelising at the client.
- Investigate streaming APIs if the backend roadmap includes them (would remove chunk concatenation altogether).

---

## Deliverables
- Baseline telemetry report (spreadsheet or markdown summary).
- Prototype branch with optional parallel chunk execution behind a feature flag.
- Decision document summarising performance comparison and go / no-go for parallel uploads.
