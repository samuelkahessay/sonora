import Foundation

struct BacktestCase: Sendable {
    let memoId: UUID
    let transcript: String
    let expectedEvents: Set<String> // titles
    let expectedReminders: Set<String> // titles
}

struct BacktestReport: Sendable {
    let total: Int
    let fpReduction: Double // percentage 0..100
    let recallDelta: Double // percentage points (adaptive - baseline)
    let baselineFP: Int
    let adaptiveFP: Int
    let baselineRecall: Double
    let adaptiveRecall: Double
}

struct BaselineThresholdPolicy: AdaptiveThresholdPolicy {
    let event: Float
    let reminder: Float
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) { (event, reminder) }
}

@MainActor
enum DetectionBacktester {
    static func run(
        container: DIContainer = .shared,
        cases: [BacktestCase],
        baselineEvent: Float = Float(UserDefaults.standard.object(forKey: "eventConfidenceThreshold") as? Double ?? 0.7),
        baselineReminder: Float = Float(UserDefaults.standard.object(forKey: "reminderConfidenceThreshold") as? Double ?? 0.7)
    ) async -> BacktestReport {
        let baseline = await evaluate(container: container, cases: cases, policy: BaselineThresholdPolicy(event: baselineEvent, reminder: baselineReminder))
        let adaptive = await evaluate(container: container, cases: cases, policy: DefaultAdaptiveThresholdPolicy())

        // FP reduction (baselineFP - adaptiveFP) / baselineFP
        let fpReduction = baseline.falsePositives == 0 ? 0.0 : (Double(baseline.falsePositives - adaptive.falsePositives) / Double(baseline.falsePositives)) * 100.0
        let recallDelta = (adaptive.recall - baseline.recall) * 100.0

        return BacktestReport(
            total: cases.count,
            fpReduction: fpReduction,
            recallDelta: recallDelta,
            baselineFP: baseline.falsePositives,
            adaptiveFP: adaptive.falsePositives,
            baselineRecall: baseline.recall * 100.0,
            adaptiveRecall: adaptive.recall * 100.0
        )
    }

    private struct Eval: Sendable { let falsePositives: Int; let recall: Double }

    private static func evaluate(
        container: DIContainer,
        cases: [BacktestCase],
        policy: any AdaptiveThresholdPolicy
    ) async -> Eval {
        var fp = 0
        var tp = 0
        var fn = 0

        for c in cases {
            let useCase = DetectEventsAndRemindersUseCase(
                analysisService: container.analysisService(),
                localAnalysisService: container.localAnalysisService(),
                analysisRepository: container.analysisRepository(),
                logger: container.logger(),
                eventBus: container.eventBus(),
                operationCoordinator: container.operationCoordinator(),
                useLocalAnalysis: true,
                thresholdPolicy: policy
            )
            do {
                let res = try await useCase.execute(transcript: c.transcript, memoId: c.memoId)
                let predictedEvents = Set((res.events?.events ?? []).map { $0.title.lowercased() })
                let predictedReminders = Set((res.reminders?.reminders ?? []).map { $0.title.lowercased() })
                let expectedEvents = c.expectedEvents.map { $0.lowercased() }
                let expectedReminders = c.expectedReminders.map { $0.lowercased() }

                // Events
                let tpE = predictedEvents.intersection(expectedEvents).count
                let fpE = max(0, predictedEvents.count - tpE)
                let fnE = max(0, expectedEvents.count - tpE)

                // Reminders
                let tpR = predictedReminders.intersection(expectedReminders).count
                let fpR = max(0, predictedReminders.count - tpR)
                let fnR = max(0, expectedReminders.count - tpR)

                tp += (tpE + tpR)
                fp += (fpE + fpR)
                fn += (fnE + fnR)
            } catch {
                // Treat as miss
                fn += (c.expectedEvents.count + c.expectedReminders.count)
            }
        }
        let recall = (tp + fn) == 0 ? 1.0 : Double(tp) / Double(tp + fn)
        return Eval(falsePositives: fp, recall: recall)
    }
}

