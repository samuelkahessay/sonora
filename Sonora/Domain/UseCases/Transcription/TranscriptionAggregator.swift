import Foundation

struct AggregatedResult {
    let text: String
    let confidence: Double
    let processedChunks: Int
    let totalChunks: Int
    let failures: [ChunkFailure]
}

enum ChunkResult {
    case success(ChunkTranscriptionResult)
    case failure(ChunkFailure)
}

struct ChunkFailure {
    let segment: VoiceSegment
    let error: Error
    let retryable: Bool
}

struct TranscriptionAggregator {
    func aggregate(_ results: [ChunkTranscriptionResult]) -> AggregatedResult {
        let sorted = results.sorted { $0.segment.startTime < $1.segment.startTime }
        let nonEmpty = sorted.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let text = joinTexts(sorted)

        // Confidence: prefer average of provided confidences; else proportion of non-empty
        let providedConfs = nonEmpty.compactMap { $0.confidence }
        let baseConfidence: Double
        if !providedConfs.isEmpty {
            baseConfidence = providedConfs.reduce(0, +) / Double(providedConfs.count)
        } else {
            baseConfidence = Double(nonEmpty.count) / Double(max(1, results.count))
        }

        return AggregatedResult(
            text: text,
            confidence: min(1.0, max(0.0, baseConfidence)),
            processedChunks: nonEmpty.count,
            totalChunks: results.count,
            failures: []
        )
    }

    func handlePartialFailures(_ results: [ChunkResult]) -> AggregatedResult {
        var successes: [ChunkTranscriptionResult] = []
        var failures: [ChunkFailure] = []
        successes.reserveCapacity(results.count)

        for r in results {
            switch r {
            case .success(let s): successes.append(s)
            case .failure(let f): failures.append(f)
            }
        }

        let agg = aggregate(successes)
        let total = results.count
        let failRatio = total > 0 ? Double(failures.count) / Double(total) : 0.0

        // Adjust confidence downward by failure ratio
        let adjustedConfidence = max(0.0, agg.confidence * (1.0 - failRatio))

        return AggregatedResult(
            text: agg.text,
            confidence: adjustedConfidence,
            processedChunks: agg.processedChunks,
            totalChunks: total,
            failures: failures
        )
    }

    // MARK: - Private helpers

    private func joinTexts(_ results: [ChunkTranscriptionResult]) -> String {
        var out = ""
        var lastEnd: TimeInterval = 0
        for (idx, r) in results.enumerated() {
            let t = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }

            let gap = r.segment.startTime - lastEnd
            let needsPausePunctuation = gap >= 1.2 // seconds

            if !out.isEmpty {
                if needsPausePunctuation && !endsWithSentencePunctuation(out) {
                    out.append(". ")
                } else if !out.hasSuffix(" ") && !startsWithPunctuation(t) {
                    out.append(" ")
                }
            }

            out.append(t)
            lastEnd = r.segment.endTime

            // If overlap occurs, we still append normally; overlaps are small and handled by spacing
            if idx == 0 && !out.isEmpty {
                // Capitalize first letter
                out = capitalizeFirst(out)
            }
        }
        return out
    }

    private func endsWithSentencePunctuation(_ s: String) -> Bool {
        guard let c = s.trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return ".!?".contains(c)
    }

    private func startsWithPunctuation(_ s: String) -> Bool {
        guard let c = s.trimmingCharacters(in: .whitespacesAndNewlines).first else { return false }
        return ",;:.!?".contains(c)
    }

    private func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        let cap = String(first).uppercased()
        return cap + s.dropFirst()
    }
}
