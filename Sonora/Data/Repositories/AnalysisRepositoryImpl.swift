import Foundation
import Combine

@MainActor
final class AnalysisRepositoryImpl: ObservableObject, AnalysisRepository {
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var analysisCache: [String: Any] = [:]
    private var analysisHistory: [UUID: [(mode: AnalysisMode, timestamp: Date)]] = [:]
    
    private func analysisURL(for memoId: UUID, mode: AnalysisMode) -> URL {
        let filename = "\(memoId.uuidString)_\(mode.rawValue)_analysis.json"
        return documentsPath.appendingPathComponent("analysis").appendingPathComponent(filename)
    }
    
    private func ensureAnalysisDirectory() {
        let analysisDir = documentsPath.appendingPathComponent("analysis")
        if !FileManager.default.fileExists(atPath: analysisDir.path) {
            try? FileManager.default.createDirectory(at: analysisDir, withIntermediateDirectories: true)
        }
    }
    
    private func cacheKey(for memoId: UUID, mode: AnalysisMode) -> String {
        return "\(memoId.uuidString)_\(mode.rawValue)"
    }
    
    func saveAnalysisResult<T: Codable>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode) {
        ensureAnalysisDirectory()
        
        let url = analysisURL(for: memoId, mode: mode)
        let key = cacheKey(for: memoId, mode: mode)
        
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: url)
            
            analysisCache[key] = result
            
            var history = analysisHistory[memoId] ?? []
            history.append((mode: mode, timestamp: Date()))
            analysisHistory[memoId] = history
            
            print("✅ AnalysisRepository: Saved \(mode.displayName) analysis for memo \(memoId)")
        } catch {
            print("❌ AnalysisRepository: Failed to save analysis: \(error)")
        }
    }
    
    func getAnalysisResult<T: Codable>(for memoId: UUID, mode: AnalysisMode, responseType: T.Type) -> AnalyzeEnvelope<T>? {
        let key = cacheKey(for: memoId, mode: mode)
        
        if let cached = analysisCache[key] as? AnalyzeEnvelope<T> {
            print("🎯 AnalysisRepository: Found cached \(mode.displayName) analysis for memo \(memoId)")
            return cached
        }
        
        let url = analysisURL(for: memoId, mode: mode)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(AnalyzeEnvelope<T>.self, from: data) else {
            print("🔍 AnalysisRepository: No saved \(mode.displayName) analysis found for memo \(memoId)")
            return nil
        }
        
        analysisCache[key] = result
        print("💾 AnalysisRepository: Loaded \(mode.displayName) analysis from disk for memo \(memoId)")
        return result
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