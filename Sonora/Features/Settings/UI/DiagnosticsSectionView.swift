import SwiftUI

/// Diagnostics panel for Phase 2 optimizations
/// Shows live metrics and provides quick actions for core managers
struct DiagnosticsSectionView: View {
    @State private var whisperMetrics: ModelPerformanceMetrics = .init()
    @State private var isModelWarmed: Bool = false
    @State private var currentModelId: String? = nil

    @State private var qualityMetrics: AudioQualityMetrics = .init()
    @State private var currentVoiceSettings: AudioRecordingSettings = AudioRecordingSettings(sampleRate: 22050, bitRate: 64000, quality: 0.7, channels: 1, format: .mpeg4AAC)
    @State private var currentProfileName: String = ""
    @State private var adaptiveEnabled: Bool = true

    @State private var memoryStats: MemoryMetrics = .init()
    @State private var isUnderPressure: Bool = false

    @State private var systemOpsText: String = ""
    @State private var eventBusStats: String = ""

    @State private var showWhisperDiagnostics = false

    private let di = DIContainer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            whisperKitCard
            audioQualityCard
            memoryCard
            operationsCard
            eventBusCard
        }
        .onAppear { refreshAll() }
        .sheet(isPresented: $showWhisperDiagnostics) { WhisperKitDiagnosticsView() }
    }

    // MARK: - Sections
    @ViewBuilder private var whisperKitCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "brain.head.profile").foregroundColor(.semantic(.brandPrimary))
                    Text("Local Engine (WhisperKit)").font(.headline)
                    Spacer()
                    Button("Open Diagnostics") { showWhisperDiagnostics = true }.buttonStyle(.bordered)
                }
                gridRow("Warmed", isModelWarmed ? "Yes" : "No")
                gridRow("Current Model", currentModelId ?? "—")
                gridRow("Warm Hit Rate", String(format: "%.0f%%", whisperMetrics.warmHitRate * 100))
                gridRow("Avg Prewarm", String(format: "%.2fs", whisperMetrics.averagePrewarmTime))
                gridRow("Avg Cold Load", String(format: "%.2fs", whisperMetrics.averageColdLoadTime))
                HStack(spacing: Spacing.sm) {
                    Button("Prewarm Now") { Task { @MainActor in try? await di.whisperKitModelManager().prewarmModel(); refreshWhisper() } }
                        .buttonStyle(.borderedProminent)
                    Button("Unload Model", role: .destructive) { di.whisperKitModelManager().unloadModel(); refreshWhisper() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder private var audioQualityCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "waveform").foregroundColor(.semantic(.brandPrimary))
                    Text("Audio Quality").font(.headline)
                }
                gridRow("Profile", currentProfileName)
                gridRow("Adaptive", adaptiveEnabled ? "On" : "Off")
                gridRow("Voice Sample Rate", String(format: "%.0f Hz", currentVoiceSettings.sampleRate))
                gridRow("Voice Bit Rate", "\(currentVoiceSettings.bitRate) bps")
                gridRow("Voice Quality", String(format: "%.2f", currentVoiceSettings.quality))
                gridRow("Adaptive Usage", String(format: "%.0f%%", qualityMetrics.adaptiveUsageRate * 100))
                gridRow("Optimizations", "Batt \(qualityMetrics.batteryOptimizations) • Therm \(qualityMetrics.thermalOptimizations) • Stor \(qualityMetrics.storageOptimizations) • Mem \(qualityMetrics.memoryOptimizations)")
                HStack(spacing: Spacing.sm) {
                    Button("Refresh Settings") { refreshAudio() }.buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder private var memoryCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "gauge.with.needle").foregroundColor(.semantic(.brandPrimary))
                    Text("System Resources").font(.headline)
                }
                gridRow("Under Pressure", isUnderPressure ? "Yes" : "No")
                gridRow("Memory", String(format: "%.0f MB", memoryStats.memoryUsageMB))
                gridRow("Storage", String(format: "%.1f GB free", memoryStats.availableStorageGB))
                gridRow("Battery", memoryStats.batteryLevel < 0 ? "Unknown" : String(format: "%.0f%%", memoryStats.batteryLevel * 100))
                gridRow("Thermal", thermalName(memoryStats.thermalState))
                gridRow("CPU", String(format: "%.0f%%", memoryStats.cpuUsage))
                HStack(spacing: Spacing.sm) {
                    Button("Force Check") { _ = di.memoryPressureDetector().forceMemoryPressureCheck(); refreshMemory() }.buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder private var operationsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "chart.bar").foregroundColor(.semantic(.brandPrimary))
                    Text("Operations").font(.headline)
                }
                Text(systemOpsText).font(.caption).foregroundColor(.semantic(.textSecondary))
                HStack(spacing: Spacing.sm) {
                    Button("Refresh") { refreshOperations() }.buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder private var eventBusCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(.semantic(.brandPrimary))
                    Text("Event Bus").font(.headline)
                }
                Text(eventBusStats).font(.caption).foregroundColor(.semantic(.textSecondary))
                Button("Refresh") { refreshEventBus() }.buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers
    @ViewBuilder private func gridRow(_ left: String, _ right: String) -> some View {
        HStack { Text(left).font(.caption).foregroundColor(.semantic(.textSecondary)); Spacer(); Text(right).font(.caption).foregroundColor(.semantic(.textPrimary)) }
    }

    private func thermalName(_ t: ProcessInfo.ThermalState) -> String {
        switch t { case .nominal: return "Nominal"; case .fair: return "Fair"; case .serious: return "Serious"; case .critical: return "Critical"; @unknown default: return "Unknown" }
    }

    private func refreshAll() {
        refreshWhisper(); refreshAudio(); refreshMemory(); refreshOperations(); refreshEventBus()
    }

    private func refreshWhisper() {
        let mgr = di.whisperKitModelManager()
        whisperMetrics = mgr.getModelPerformanceMetrics()
        isModelWarmed = mgr.isModelWarmed
        currentModelId = mgr.currentModelId
    }

    private func refreshAudio() {
        let qm = di.audioQualityManager()
        qualityMetrics = qm.getQualityMetrics()
        adaptiveEnabled = qm.isAdaptiveMode
        currentProfileName = qm.currentProfile.displayName
        currentVoiceSettings = qm.getOptimalSettings(for: .voice)
    }

    private func refreshMemory() {
        let det = di.memoryPressureDetector()
        isUnderPressure = det.isUnderMemoryPressure
        memoryStats = det.currentMemoryMetrics
    }

    private func refreshOperations() {
        Task { @MainActor in
            let metrics = await OperationCoordinator.shared.getSystemMetrics()
            systemOpsText = "Total: \(metrics.totalOperations) • Active: \(metrics.activeOperations) • Queued: \(metrics.queuedOperations) • Max: \(metrics.maxConcurrentOperations) • AvgDur: \(metrics.averageOperationDuration.map { String(format: "%.2fs", $0) } ?? "—")"
        }
    }

    private func refreshEventBus() {
        eventBusStats = DIContainer.shared.eventBus().subscriptionStats
    }
}

#Preview {
    DiagnosticsSectionView()
}

