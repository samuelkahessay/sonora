import Foundation

// MARK: - Protocols and Models

protocol LanguageQualityEvaluator {
    func evaluateQuality(_ response: TranscriptionResponse, text: String) -> QualityEvaluation
    func shouldTriggerFallback(_ evaluation: QualityEvaluation, threshold: Double) -> Bool
    func compareTwoResults(_ primary: QualityEvaluation, _ fallback: QualityEvaluation) -> ComparisonResult
}

struct QualityEvaluation {
    let overallScore: Double         // 0.0 to 1.0
    let language: String
    let isEnglish: Bool
    let confidence: Double           // same as overallScore for simplicity
    let source: QualitySource
    let factors: QualityFactors
}

struct QualityFactors {
    let serverConfidence: Double?
    let clientConfidence: Double?
    let textLength: Int
    let avgLogProb: Double?
    let wordDensity: Double          // words per minute estimate (0 if unknown)
}

enum QualitySource {
    case server(hasLogProb: Bool)
    case client
    case hybrid
}

enum ComparisonResult {
    case usePrimary(reason: String)
    case useFallback(reason: String, improvement: Double)
}

// MARK: - Implementation

final class DefaultLanguageQualityEvaluator: LanguageQualityEvaluator {
    private let clientLanguageService: ClientLanguageDetectionService

    init(clientLanguageService: ClientLanguageDetectionService = DefaultClientLanguageDetectionService()) {
        self.clientLanguageService = clientLanguageService
    }

    func evaluateQuality(_ response: TranscriptionResponse, text: String) -> QualityEvaluation {
        let clientDetection = clientLanguageService.detectLanguage(from: text)

        // Resolve language codes to ISO-639-1 where possible
        let serverLangISO = DefaultClientLanguageDetectionService.iso639_1(fromBCP47: response.detectedLanguage)
        let clientLang = clientDetection.language
        let finalLanguage = serverLangISO ?? clientLang

        // Start with best available confidence
        let serverConf = response.confidence
        let clientConf = clientDetection.confidence
        var baseScore: Double
        var source: QualitySource

        if let serverConf, serverConf > 0.3 {
            baseScore = serverConf
            source = .server(hasLogProb: response.avgLogProb != nil)
        } else {
            baseScore = clientConf
            source = .client
        }

        // If server and client disagree on language and both are confident enough, mark as hybrid and slightly penalize
        if let sLang = serverLangISO, !sLang.isEmpty, sLang != clientLang, (serverConf ?? 0) > 0.3, clientConf > 0.3 {
            source = .hybrid
            baseScore -= 0.05
        }

        // Apply quality adjustments
        baseScore = adjustForTextQuality(baseScore, text: text, clientResult: clientDetection)
        baseScore = adjustForLogProb(baseScore, logProb: response.avgLogProb)
        baseScore = clamp01(baseScore)

        // Compute word density (words per minute) when duration available
        let wpm: Double
        if let duration = response.duration, duration > 0 {
            wpm = Double(max(1, clientDetection.wordCount)) / duration * 60.0
        } else {
            wpm = 0.0
        }

        let eval = QualityEvaluation(
            overallScore: baseScore,
            language: finalLanguage,
            isEnglish: finalLanguage == "en",
            confidence: baseScore,
            source: source,
            factors: QualityFactors(
                serverConfidence: serverConf,
                clientConfidence: clientConf,
                textLength: text.count,
                avgLogProb: response.avgLogProb,
                wordDensity: wpm
            )
        )
        return eval
    }

    func shouldTriggerFallback(_ evaluation: QualityEvaluation, threshold: Double = 0.7) -> Bool {
        // 1. Overall quality below threshold
        if evaluation.overallScore < threshold { return true }

        // 2. High-confidence non-English detection (force-English fallback use case)
        if !evaluation.isEnglish && evaluation.confidence > 0.8 { return true }

        // 3. Mixed signals (server vs client) with low confidence
        if case .hybrid = evaluation.source, evaluation.confidence < 0.6 { return true }

        // 4. Abnormal speech rate heuristic when duration known
        if evaluation.factors.wordDensity > 0 {
            let wpm = evaluation.factors.wordDensity
            if wpm < 60 || wpm > 200 { // outside typical 100–160 WPM by a generous margin
                return evaluation.overallScore < max(0.8, threshold)
            }
        }

        return false
    }

    func compareTwoResults(_ primary: QualityEvaluation, _ fallback: QualityEvaluation) -> ComparisonResult {
        let diff = fallback.overallScore - primary.overallScore
        if diff > 0.02 {
            var reason = "Fallback has higher quality score (+\(String(format: "%.2f", diff)))."
            if primary.language != fallback.language {
                reason += " Language changed from \(primary.language) to \(fallback.language)."
            }
            return .useFallback(reason: reason, improvement: diff)
        }

        // Prefer English if scores are effectively tied and fallback is English
        if abs(diff) <= 0.02, fallback.isEnglish, !primary.isEnglish {
            return .useFallback(reason: "Scores tied; prefer English result.", improvement: max(0, diff))
        }

        return .usePrimary(reason: diff >= -0.02 ? "Primary score is higher or comparable." : "Primary score significantly higher.")
    }

    // MARK: - Private helpers

    private func adjustForTextQuality(_ base: Double, text: String, clientResult: LanguageDetectionResult) -> Double {
        var score = base
        let length = text.count
        if length > 50 { score += 0.1 }
        if length < 20 { score *= 0.7 }
        if clientResult.hasNonAsciiCharacters && clientResult.isEnglish {
            // Penalize improbable combination slightly
            score -= 0.03
        }
        return score
    }

    private func adjustForLogProb(_ base: Double, logProb: Double?) -> Double {
        guard let lp = logProb else { return base }
        // Map avgLogProb from [-2.0, 0.0] to [0, 1] and apply small boost
        let normalized = clamp01((lp + 2.0) / 2.0)
        return clamp01(base + 0.05 * normalized)
    }

    private func clamp01(_ x: Double) -> Double { max(0.0, min(1.0, x)) }
}

