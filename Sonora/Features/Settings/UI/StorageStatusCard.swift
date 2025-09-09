import SwiftUI

struct StorageStatusCard: View {
    @StateObject private var localManager = LocalModelDownloadManager.shared
    @State private var whisperInstalledIds: [String] = []
    @State private var whisperApproxBytes: Int64 = 0

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.purple)
                    Text("Storage Status")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                    Spacer()
                }

                let analysisBytes = localManager.getTotalDiskSpaceUsed()
                let total = whisperApproxBytes + Int64(analysisBytes)
                HStack {
                    Text("Models: \(StorageManager.formatBytes(total))")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textPrimary))
                    Spacer()
                    if let free = StorageManager.availableFreeBytes() {
                        Text("Available: \(StorageManager.formatBytes(free))")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }

                // Simple visual indicator
                ProgressView(value: usageFraction(total))
                    .tint(.semantic(.brandPrimary))
            }
        }
        .onAppear { refreshWhisperApprox() }
    }

    private func usageFraction(_ used: Int64) -> Double {
        guard let free = StorageManager.availableFreeBytes(), free > 0 else { return 0 }
        // Fraction relative to used + free on the primary volume (approximate)
        let total = Double(used + free)
        return min(1.0, max(0.0, Double(used) / max(total, 1)))
    }

    private func refreshWhisperApprox() {
        let provider = DIContainer.shared.whisperKitModelProvider()
        let ids = provider.installedModelIds()
        whisperInstalledIds = ids
        var sum: Int64 = 0
        for id in ids {
            if let info = WhisperModelInfo.model(withId: id), let bytes = StorageManager.parseApproxSize(info.size) { sum += bytes }
        }
        whisperApproxBytes = sum
    }
}
