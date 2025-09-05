import Foundation
import Combine
import SwiftData

@MainActor
final class AnalysisRepositoryImpl: ObservableObject, AnalysisRepository {
    private var analysisCache: [String: Any] = [:]
    private var analysisHistory: [UUID: [(mode: AnalysisMode, timestamp: Date)]] = [:]
    private let logger: any LoggerProtocol
    private let modelContext: ModelContext

    init(context: ModelContext, logger: any LoggerProtocol = Logger.shared) {
        self.modelContext = context
        self.logger = logger
        logger.repository("AnalysisRepository initialized (SwiftData)", context: LogContext())
    }
    
    private func cacheKey(for memoId: UUID, mode: AnalysisMode) -> String {
        return "\(memoId.uuidString)_\(mode.rawValue)"
    }
    
    func saveAnalysisResult<T: Codable>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode) {
        let correlationId = UUID().uuidString
        let logCtx = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memoId.uuidString,
            "mode": mode.rawValue,
            "operation": "save"
        ])

        let saveTimer = PerformanceTimer(operation: "Analysis Save Operation", category: .repository)

        let key = cacheKey(for: memoId, mode: mode)
        logger.repository("Starting analysis save (SwiftData)", context: logCtx)

        do {
            let data = try JSONEncoder().encode(result)
            // Insert a new model instance (support history)
            let memoModel = try modelContext.fetch(FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == memoId })).first
            let model = AnalysisResultModel(
                id: UUID(),
                mode: mode.rawValue,
                summary: "",
                keywords: [],
                sentimentScore: nil,
                timestamp: Date(),
                payloadData: data,
                memo: memoModel
            )
            modelContext.insert(model)
            try modelContext.save()

            analysisCache[key] = result
            var history = analysisHistory[memoId] ?? []
            history.append((mode: mode, timestamp: model.timestamp))
            analysisHistory[memoId] = history

            _ = saveTimer.finish(additionalInfo: "Save completed successfully")
            logger.repository("Analysis saved successfully (SwiftData)", level: .info, context: logCtx)
        } catch {
            _ = saveTimer.finish(additionalInfo: "Save failed with error")
            logger.error("Failed to save analysis result (SwiftData)", category: .repository, context: logCtx, error: error)
        }
    }

    // MARK: - Private validation helpers
    private func validateEnvelopeJSON(data: Data, expectedMode: AnalysisMode) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        guard let modeStr = obj["mode"] as? String, modeStr == expectedMode.rawValue else { return false }
        guard let payload = obj["data"] as? [String: Any] else { return false }
        switch expectedMode {
        case .distill, .analysis:
            guard let summary = payload["summary"] as? String, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard let keyPoints = payload["key_points"] as? [Any] else { return false }
            // Ensure all key points are strings
            return keyPoints.allSatisfy { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        // Distill component modes (for parallel processing)
        case .distillSummary:
            guard let summary = payload["summary"] as? String, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            return true
        case .distillActions:
            guard let _ = payload["action_items"] as? [Any] else { return false }
            return true
        case .distillThemes:
            guard let _ = payload["key_themes"] as? [Any] else { return false }
            return true
        case .distillReflection:
            guard let _ = payload["reflection_questions"] as? [Any] else { return false }
            return true
        case .themes:
            guard let themes = payload["themes"] as? [Any], let sentiment = payload["sentiment"] as? String else { return false }
            guard ["positive","neutral","mixed","negative"].contains(sentiment.lowercased()) else { return false }
            // Basic per-item validation
            for item in themes {
                guard let t = item as? [String: Any], let name = t["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                guard let evidence = t["evidence"] as? [Any], evidence.allSatisfy({ ($0 as? String)?.isEmpty == false }) else { return false }
            }
            return true
        case .todos:
            guard let todos = payload["todos"] as? [Any] else { return false }
            for item in todos {
                guard let t = item as? [String: Any], let text = t["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                // due may be string or null — no strict check
            }
            return true
        case .events:
            // Basic structural check for events payload
            guard let events = payload["events"] as? [Any] else { return false }
            return !events.isEmpty
        case .reminders:
            guard let reminders = payload["reminders"] as? [Any] else { return false }
            return !reminders.isEmpty
        }
    }
    
    func getAnalysisResult<T: Codable>(for memoId: UUID, mode: AnalysisMode, responseType: T.Type) -> AnalyzeEnvelope<T>? {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memoId.uuidString,
            "mode": mode.rawValue,
            "operation": "get",
            "responseType": String(describing: T.self)
        ])
        
        let loadTimer = PerformanceTimer(operation: "Analysis Load Operation", category: .repository)
        
        let key = cacheKey(for: memoId, mode: mode)
        
        logger.repository("Starting analysis retrieval", context: context)
        
        // Check memory cache first
        if let cached = analysisCache[key] as? AnalyzeEnvelope<T> {
            _ = loadTimer.finish(additionalInfo: "Memory cache HIT")
            logger.repository("Analysis found in memory cache", 
                            level: .info,
                            context: LogContext(correlationId: correlationId, additionalInfo: [
                                "memoId": memoId.uuidString,
                                "mode": mode.rawValue,
                                "cacheType": "memory",
                                "latencyMs": cached.latency_ms
                            ]))
            return cached
        }
        
        logger.debug("Memory cache miss, checking SwiftData store", category: .repository, context: context)

        do {
            let descriptor = FetchDescriptor<AnalysisResultModel>(
                predicate: #Predicate { ($0.memo?.id == memoId) && ($0.mode == mode.rawValue) },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            if let model = try modelContext.fetch(descriptor).first, let data = model.payloadData {
                let result = try JSONDecoder().decode(AnalyzeEnvelope<T>.self, from: data)
                analysisCache[key] = result
                _ = loadTimer.finish(additionalInfo: "Store load successful, cached in memory")
                logger.repository("Analysis loaded from SwiftData and cached", level: .info, context: context)
                return result
            } else {
                _ = loadTimer.finish(additionalInfo: "No record found")
                logger.repository("No analysis record found in SwiftData", context: context)
                return nil
            }
        } catch {
            _ = loadTimer.finish(additionalInfo: "Store load failed - decode error")
            logger.error("Failed to load or decode analysis from SwiftData", category: .repository, context: context, error: error)
            return nil
        }
    }
    
    func hasAnalysisResult(for memoId: UUID, mode: AnalysisMode) -> Bool {
        let key = cacheKey(for: memoId, mode: mode)
        
        if analysisCache[key] != nil {
            return true
        }
        
        let descriptor = FetchDescriptor<AnalysisResultModel>(
            predicate: #Predicate { ($0.memo?.id == memoId) && ($0.mode == mode.rawValue) }
        )
        return ((try? modelContext.fetch(descriptor))?.isEmpty == false)
    }
    
    func deleteAnalysisResults(for memoId: UUID) {
        do {
            let descriptor = FetchDescriptor<AnalysisResultModel>(predicate: #Predicate { $0.memo?.id == memoId })
            let items = try modelContext.fetch(descriptor)
            for item in items { modelContext.delete(item) }
            try modelContext.save()
            analysisHistory.removeValue(forKey: memoId)
            print("🗑️ AnalysisRepository: Deleted all analysis results for memo \(memoId)")
        } catch {
            logger.error("Failed to delete all analysis results", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error)
        }
    }
    
    func deleteAnalysisResult(for memoId: UUID, mode: AnalysisMode) {
        let key = cacheKey(for: memoId, mode: mode)
        do {
            let descriptor = FetchDescriptor<AnalysisResultModel>(
                predicate: #Predicate { ($0.memo?.id == memoId) && ($0.mode == mode.rawValue) }
            )
            let items = try modelContext.fetch(descriptor)
            for item in items { modelContext.delete(item) }
            try modelContext.save()
            analysisCache.removeValue(forKey: key)
            if var history = analysisHistory[memoId] {
                history.removeAll { $0.mode == mode }
                analysisHistory[memoId] = history.isEmpty ? nil : history
            }
        } catch {
            logger.error("Failed to delete analysis result", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString, "mode": mode.rawValue]), error: error)
        }
    }
    
    func getAllAnalysisResults(for memoId: UUID) -> [AnalysisMode: Any] {
        var results: [AnalysisMode: Any] = [:]
        
        for mode in AnalysisMode.allCases {
            let key = cacheKey(for: memoId, mode: mode)
            if let cached = analysisCache[key] {
                results[mode] = cached
            } else {
                let descriptor = FetchDescriptor<AnalysisResultModel>(
                    predicate: #Predicate { ($0.memo?.id == memoId) && ($0.mode == mode.rawValue) }
                )
                if ((try? modelContext.fetch(descriptor))?.isEmpty == false) {
                    results[mode] = "Available in store"
                }
            }
        }
        
        return results
    }
    
    func clearCache() {
        analysisCache.removeAll()
        analysisHistory.removeAll()
        print("🧹 AnalysisRepository: Cleared analysis cache")
    }
    
    func getCacheSize() -> Int { analysisCache.count }
    
    func getAnalysisHistory(for memoId: UUID) -> [(mode: AnalysisMode, timestamp: Date)] {
        if let existing = analysisHistory[memoId] { return existing }
        // Derive from store
        if let items = try? modelContext.fetch(FetchDescriptor<AnalysisResultModel>(predicate: #Predicate { $0.memo?.id == memoId })) {
            return items.map { (mode: AnalysisMode(rawValue: $0.mode) ?? .analysis, timestamp: $0.timestamp) }
        }
        return []
    }
}
