import Foundation
import os
import UIKit

@MainActor
final class PerformanceMetricsService: ObservableObject {
    static let shared = PerformanceMetricsService()

    private struct Config {
        static let dirName = "metrics"
        static let filePrefix = "metrics-"
        static let dateFormat = "yyyyMMdd-HHmmss"
        static let rotationEventCount = 500 // rotate file after N events
    }

    private var sessionId = UUID().uuidString
    private var appStartTime = Date()
    private var eventCount = 0
    private var currentFileURL: URL?
    private let encoder = JSONEncoder()

    private init() {
        encoder.outputFormatting = []
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? self?.flush()
            }
        }
    }

    func startSession() {
        sessionId = UUID().uuidString
        appStartTime = Date()
        eventCount = 0
        rotateFile()
        logEvent(name: "SessionStart", durationMs: nil, extras: ["sessionId": sessionId])
    }

    func mark() -> Date { Date() }

    func recordDuration(name: String, start: Date, extras: [String: String] = [:]) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        logEvent(name: name, durationMs: ms, extras: extras)
    }

    func recordStartupCompleted() {
        let ms = Int(Date().timeIntervalSince(appStartTime) * 1000)
        logEvent(name: "AppStartup", durationMs: ms)
    }

    private func rotateFile() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(Config.dirName, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let df = DateFormatter(); df.dateFormat = Config.dateFormat
        let file = dir.appendingPathComponent("\(Config.filePrefix)\(df.string(from: Date())).jsonl")
        currentFileURL = file
    }

    private func logEvent(name: String, durationMs: Int?, extras: [String: String] = [:]) {
        var event: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "session": sessionId,
            "name": name,
            "memoryMB": currentMemoryUsageMB()
        ]
        if let d = durationMs { event["durationMs"] = d }
        if !extras.isEmpty { event["extras"] = extras }
        appendJSONLine(event)
        eventCount += 1
        if eventCount % Config.rotationEventCount == 0 { rotateFile() }
    }

    private func appendJSONLine(_ dict: [String: Any]) {
        guard let url = currentFileURL else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.write(contentsOf: Data("\n".utf8))
                }
            } else {
                var out = data
                out.append(Data("\n".utf8))
                try out.write(to: url)
            }
        } catch {
            os_log("PerformanceMetricsService: Failed to write metrics: %{public}@", type: .error, String(describing: error))
        }
    }

    func flush() throws {
        // No-op since we append as we go, but kept for symmetry
    }

    private func currentMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
        }
    }
}

// no-op
