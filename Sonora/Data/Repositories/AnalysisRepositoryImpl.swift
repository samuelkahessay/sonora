import Foundation
import Combine

@MainActor
final class AnalysisRepositoryImpl: ObservableObject, AnalysisRepository {
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var analysisCache: [String: Any] = [:]
    private var analysisHistory: [UUID: [(mode: AnalysisMode, timestamp: Date)]] = [:]
    private let logger: LoggerProtocol
    
    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
        logger.repository("AnalysisRepository initialized", 
                        context: LogContext(additionalInfo: ["documentsPath": documentsPath.path]))
    }
    
    private func analysisURL(for memoId: UUID, mode: AnalysisMode) -> URL {
        let filename = "\(memoId.uuidString)_\(mode.rawValue)_analysis.json"
        return documentsPath.appendingPathComponent("analysis").appendingPathComponent(filename)
    }
    
    private func ensureAnalysisDirectory() {
        let analysisDir = documentsPath.appendingPathComponent("analysis")
        let exists = FileManager.default.fileExists(atPath: analysisDir.path)
        
        if !exists {
            do {
                try FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true)
                logger.repository("Created analysis directory", 
                                context: LogContext(additionalInfo: ["path": analysisDir.path]))
            } catch {
                logger.error("Failed to create analysis directory", 
                           category: .repository, 
                           context: LogContext(additionalInfo: ["path": analysisDir.path]), 
                           error: error)
            }
        } else {
            logger.debug("Analysis directory already exists", category: .repository, 
                        context: LogContext(additionalInfo: ["path": analysisDir.path]))
        }
    }
    
    private func cacheKey(for memoId: UUID, mode: AnalysisMode) -> String {
        return "\(memoId.uuidString)_\(mode.rawValue)"
    }
    
    func saveAnalysisResult<T: Codable>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode) {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memoId.uuidString,
            "mode": mode.rawValue,
            "operation": "save"
        ])
        
        let saveTimer = PerformanceTimer(operation: "Analysis Save Operation", category: .repository)
        
        ensureAnalysisDirectory()
        
        let url = analysisURL(for: memoId, mode: mode)
        let key = cacheKey(for: memoId, mode: mode)
        
        logger.repository("Starting analysis save", context: context)
        
        do {
            let data = try JSONEncoder().encode(result)
            let dataSize = data.count
            
            try data.write(to: url)
            logger.repository("Analysis data written to disk", 
                            context: LogContext(correlationId: correlationId, additionalInfo: [
                                "filePath": url.path,
                                "fileSize": dataSize,
                                "mode": mode.rawValue
                            ]))
            
            analysisCache[key] = result
            logger.debug("Analysis cached in memory", category: .repository, context: context)
            
            var history = analysisHistory[memoId] ?? []
            history.append((mode: mode, timestamp: Date()))
            analysisHistory[memoId] = history
            
            saveTimer.finish(additionalInfo: "Save completed successfully")
            logger.repository("Analysis saved successfully", 
                            level: .info,
                            context: LogContext(correlationId: correlationId, additionalInfo: [
                                "memoId": memoId.uuidString,
                                "mode": mode.rawValue,
                                "cached": true,
                                "persisted": true,
                                "fileSize": dataSize
                            ]))
            
        } catch {
            saveTimer.finish(additionalInfo: "Save failed with error")
            logger.error("Failed to save analysis result", 
                       category: .repository, 
                       context: context, 
                       error: error)
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
            loadTimer.finish(additionalInfo: "Memory cache HIT")
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
        
        logger.debug("Memory cache miss, checking disk", category: .repository, context: context)
        
        // Check disk persistence
        let url = analysisURL(for: memoId, mode: mode)
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        
        guard fileExists else {
            loadTimer.finish(additionalInfo: "File does not exist")
            logger.repository("No analysis file found on disk", 
                            context: LogContext(correlationId: correlationId, additionalInfo: [
                                "filePath": url.path,
                                "mode": mode.rawValue
                            ]))
            return nil
        }
        
        logger.debug("Analysis file found, loading from disk", category: .repository, 
                    context: LogContext(correlationId: correlationId, additionalInfo: ["filePath": url.path]))
        
        do {
            let data = try Data(contentsOf: url)
            let result = try JSONDecoder().decode(AnalyzeEnvelope<T>.self, from: data)
            
            // Cache in memory for future access
            analysisCache[key] = result
            
            loadTimer.finish(additionalInfo: "Disk load successful, cached in memory")
            logger.repository("Analysis loaded from disk and cached in memory", 
                            level: .info,
                            context: LogContext(correlationId: correlationId, additionalInfo: [
                                "memoId": memoId.uuidString,
                                "mode": mode.rawValue,
                                "cacheType": "disk",
                                "fileSize": data.count,
                                "latencyMs": result.latency_ms,
                                "nowCachedInMemory": true
                            ]))
            return result
            
        } catch {
            loadTimer.finish(additionalInfo: "Disk load failed - decode error")
            logger.error("Failed to load or decode analysis from disk", 
                       category: .repository, 
                       context: LogContext(correlationId: correlationId, additionalInfo: [
                           "filePath": url.path,
                           "mode": mode.rawValue
                       ]), 
                       error: error)
            
            // Remove corrupted file
            try? FileManager.default.removeItem(at: url)
            logger.warning("Removed corrupted analysis file", category: .repository, 
                           context: LogContext(correlationId: correlationId, additionalInfo: ["filePath": url.path]), error: nil)
            
            return nil
        }
    }
    
    func hasAnalysisResult(for memoId: UUID, mode: AnalysisMode) -> Bool {
        let key = cacheKey(for: memoId, mode: mode)
        
        if analysisCache[key] != nil {
            return true
        }
        
        let url = analysisURL(for: memoId, mode: mode)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func deleteAnalysisResults(for memoId: UUID) {
        for mode in AnalysisMode.allCases {
            deleteAnalysisResult(for: memoId, mode: mode)
        }
        analysisHistory.removeValue(forKey: memoId)
        print("🗑️ AnalysisRepository: Deleted all analysis results for memo \(memoId)")
    }
    
    func deleteAnalysisResult(for memoId: UUID, mode: AnalysisMode) {
        let url = analysisURL(for: memoId, mode: mode)
        let key = cacheKey(for: memoId, mode: mode)
        
        try? FileManager.default.removeItem(at: url)
        analysisCache.removeValue(forKey: key)
        
        if var history = analysisHistory[memoId] {
            history.removeAll { $0.mode == mode }
            analysisHistory[memoId] = history.isEmpty ? nil : history
        }
    }
    
    func getAllAnalysisResults(for memoId: UUID) -> [AnalysisMode: Any] {
        var results: [AnalysisMode: Any] = [:]
        
        for mode in AnalysisMode.allCases {
            let key = cacheKey(for: memoId, mode: mode)
            if let cached = analysisCache[key] {
                results[mode] = cached
            } else {
                let url = analysisURL(for: memoId, mode: mode)
                if FileManager.default.fileExists(atPath: url.path) {
                    results[mode] = "Available on disk"
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
    
    func getCacheSize() -> Int {
        return analysisCache.count
    }
    
    func getAnalysisHistory(for memoId: UUID) -> [(mode: AnalysisMode, timestamp: Date)] {
        return analysisHistory[memoId] ?? []
    }
}
