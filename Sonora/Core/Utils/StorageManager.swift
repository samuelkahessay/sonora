import Foundation
import Network

/// Utilities for device storage and network awareness
enum StorageManager {
    // MARK: - Storage

    /// Returns available free bytes on the device volume used by the app
    static func availableFreeBytes() -> Int64? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        do {
            if let u = url {
                let values = try u.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let cap = values.volumeAvailableCapacityForImportantUsage { return cap }
            }
        } catch {}
        return nil
    }

    /// Formats bytes into human-readable string (e.g., 2.9 GB)
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Parses an approximate size string like "~2.9 GB" or "~488 MB" into bytes
    static func parseApproxSize(_ text: String) -> Int64? {
        let s = text.lowercased().replacingOccurrences(of: "~", with: "").replacingOccurrences(of: " ", with: "")
        let number = s.trimmingCharacters(in: CharacterSet.letters)
        let unit = s.trimmingCharacters(in: CharacterSet.decimalDigits.union(["."]))
        guard let value = Double(number) else { return nil }
        if unit.contains("gb") { return Int64(value * 1024 * 1024 * 1024) }
        if unit.contains("mb") { return Int64(value * 1024 * 1024) }
        return nil
    }

    // MARK: - Network

    @MainActor private static var monitor: NWPathMonitor = {
        let m = NWPathMonitor()
        m.start(queue: DispatchQueue(label: "StorageManager.Network"))
        return m
    }()

    /// Best-effort check if the current connection is Wi‑Fi
    @MainActor static func isOnWiFi() -> Bool {
        let path = monitor.currentPath
        if path.status != .satisfied { return false }
        return path.usesInterfaceType(.wifi)
    }
}
