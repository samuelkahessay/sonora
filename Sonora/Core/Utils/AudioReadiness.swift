import Foundation
import AVFoundation

enum AudioReadiness {
    /// Ensure an audio file is ready for reading by AVFoundation.
    /// Performs bounded backoff checks for existence, stable size, and openability.
    static func ensureReady(url: URL, maxWait: TimeInterval = 0.8) async -> Bool {
        let start = Date()
        var lastSize: UInt64 = 0
        var stableCount = 0
        var attempt = 0
        var delay: UInt64 = 50_000_000 // 50ms

        func fileSize(_ url: URL) -> UInt64 {
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        }

        while Date().timeIntervalSince(start) < maxWait {
            attempt += 1
            // Existence and non-zero size
            guard FileManager.default.fileExists(atPath: url.path) else {
                try? await Task.sleep(nanoseconds: delay)
                delay = min(delay + 50_000_000, 250_000_000) // cap at 250ms
                continue
            }
            let size = fileSize(url)
            if size > 0 {
                if size == lastSize {
                    stableCount += 1
                } else {
                    stableCount = 0
                }
                lastSize = size
                // Require two consecutive stable size checks
                if stableCount >= 1 {
                    // Try probing with AVAudioFile quickly
                    if (try? AVAudioFile(forReading: url)) != nil {
                        return true
                    }
                }
            }
            try? await Task.sleep(nanoseconds: delay)
            delay = min(delay + 50_000_000, 250_000_000)
        }
        return false
    }

    /// Try to open an AVAudioFile with small bounded retry/backoff loop.
    static func openIfReady(url: URL, maxWait: TimeInterval = 0.5) throws -> AVAudioFile {
        let start = Date()
        var delay: UInt64 = 50_000_000 // 50ms
        while Date().timeIntervalSince(start) < maxWait {
            if let f = try? AVAudioFile(forReading: url) { return f }
            awaitSleep(delay)
            delay = min(delay + 50_000_000, 200_000_000)
        }
        // Final attempt (throw if it fails)
        return try AVAudioFile(forReading: url)
    }

    private static func awaitSleep(_ ns: UInt64) {
        // Sleep on current thread if possible; use Task.sleep when available
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(Int(ns))) {
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + .nanoseconds(Int(ns) + 50_000_000))
    }
}
