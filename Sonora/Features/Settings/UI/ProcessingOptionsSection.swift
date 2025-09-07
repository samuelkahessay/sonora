import SwiftUI

/// Consolidated processing control that maps to existing settings:
/// - Transcription service: UserDefaults.selectedTranscriptionService
/// - Local analysis toggle: AppConfiguration.shared.useLocalAnalysis
struct ProcessingOptionsSection: View {
    @StateObject private var appConfig = AppConfiguration.shared
    @State private var advancedExpanded = false

    enum ProcessingMode: String, CaseIterable {
        case cloud
        case device
        case hybrid // derived only (not selectable) when user customizes in Advanced
    }

    private var currentMode: ProcessingMode {
        let svc = UserDefaults.standard.selectedTranscriptionService
        let localAI = appConfig.useLocalAnalysis
        switch (svc, localAI) {
        case (.cloudAPI, false): return .cloud
        case (.localWhisperKit, true): return .device
        default: return .hybrid
        }
    }

    private func setMode(_ mode: ProcessingMode) {
        HapticManager.shared.playSelection()
        switch mode {
        case .cloud:
            UserDefaults.standard.selectedTranscriptionService = .cloudAPI
            appConfig.useLocalAnalysis = false
            AppConfiguration.shared.strictLocalWhisper = false
        case .device:
            UserDefaults.standard.selectedTranscriptionService = .localWhisperKit
            appConfig.useLocalAnalysis = true
            AppConfiguration.shared.strictLocalWhisper = true
        case .hybrid:
            // Not settable via picker; managed through advanced options
            break
        }
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header + segmented control
                HStack(spacing: Spacing.md) {
                    Label("Processing", systemImage: "brain")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { currentMode == .hybrid ? ProcessingMode.device : currentMode },
                        set: { setMode($0) }
                    )) {
                        Text("Cloud").tag(ProcessingMode.cloud)
                        Text("Device").tag(ProcessingMode.device)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                // Minimal disclosure with Learn more → full disclosure sheet
                AIDisclosureMinimal()

                // Trade-offs card
                ProcessingModeCard(mode: currentMode)

                // Advanced controls
                if advancedExpanded {
                    Divider().background(Color.semantic(.separator))

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Advanced Options")
                            .font(.subheadline)
                            .foregroundColor(.semantic(.textSecondary))

                        // Existing toggles surfaced explicitly for power users
                        Toggle("Use Local Transcription", isOn: Binding(
                            get: { UserDefaults.standard.selectedTranscriptionService == .localWhisperKit },
                            set: { isOn in
                                let target: TranscriptionServiceType = isOn ? .localWhisperKit : .cloudAPI
                                HapticManager.shared.playSelection()
                                UserDefaults.standard.selectedTranscriptionService = target
                                AppConfiguration.shared.strictLocalWhisper = (target == .localWhisperKit)
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))

                        Toggle("Use Local Analysis", isOn: $appConfig.useLocalAnalysis)
                            .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))

                        // Optional strict local switch — keep copy short for beta
                        Toggle("Prefer On‑Device Only", isOn: Binding(
                            get: { AppConfiguration.shared.strictLocalWhisper },
                            set: { AppConfiguration.shared.strictLocalWhisper = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(action: { withAnimation { advancedExpanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Text(advancedExpanded ? "Hide Advanced" : "Show Advanced")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(advancedExpanded ? 180 : 0))
                    }
                    .foregroundColor(.semantic(.textSecondary))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Trade-off visualization using existing semantic colors
struct ProcessingModeCard: View {
    let mode: ProcessingOptionsSection.ProcessingMode

    private func prosForMode(_ mode: ProcessingOptionsSection.ProcessingMode) -> [String] {
        switch mode {
        case .cloud: return ["Faster processing", "Higher accuracy", "Latest models"]
        case .device: return ["Complete privacy", "Works offline", "No data leaves device"]
        case .hybrid: return ["Balanced approach", "Fallback options"]
        }
    }
    private func consForMode(_ mode: ProcessingOptionsSection.ProcessingMode) -> [String] {
        switch mode {
        case .cloud: return ["Requires internet", "Data sent to servers"]
        case .device: return ["Slower processing", "Uses device storage"]
        case .hybrid: return ["More to configure"]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prosForMode(mode), id: \.self) { pro in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.semantic(.success))
                                .font(.caption)
                            Text(pro)
                                .font(.caption)
                                .foregroundColor(.semantic(.textPrimary))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(consForMode(mode), id: \.self) { con in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.semantic(.warning))
                                .font(.caption)
                            Text(con)
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                    }
                }
            }
            .padding(Spacing.sm)
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(8)
        }
    }
}

// Minimal disclosure that opens the existing full disclosure view in a sheet
struct AIDisclosureMinimal: View {
    @State private var showFullDisclosure = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundColor(.semantic(.textSecondary))
                .font(.caption)
            Text("AI features use machine learning")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            Spacer()
            Button("Learn more") { showFullDisclosure = true }
                .font(.caption)
                .foregroundColor(.semantic(.brandPrimary))
        }
        .padding(.horizontal, 2)
        .sheet(isPresented: $showFullDisclosure) {
            ScrollView { AIDisclosureSectionView().padding() }
                .presentationDetents([.medium, .large])
        }
    }
}

