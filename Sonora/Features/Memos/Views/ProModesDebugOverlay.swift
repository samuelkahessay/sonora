import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

/// Debug overlay for diagnosing pro modes display issues in the MemoDetailView
/// Shows actual analysis data from the ViewModel for the current memo
struct ProModesDebugOverlay: View {
    @ObservedObject var viewModel: MemoDetailViewModel
    @SwiftUI.Environment(\.dismiss)
    private var dismiss

    @State private var subscriptionStatus: String = "Loading..."
    @State private var latestTransaction: String = "Checking..."

    var body: some View {
        NavigationView {
            List {
                // Subscription Status
                Section("Subscription Status") {
                    DebugRow(label: "isPro (StoreKit)", value: viewModel.storeKitService.isPro ? "✅ YES" : "❌ NO", status: viewModel.storeKitService.isPro ? .good : .bad)
                    DebugRow(label: "isProUser (ViewModel)", value: viewModel.isProUser ? "✅ YES" : "❌ NO", status: viewModel.isProUser ? .good : .bad)
                    DebugRow(label: "Latest Transaction", value: latestTransaction)

                    Button("Refresh Subscription") {
                        Task { await refreshSubscription() }
                    }
                }

                // Analysis State
                Section("Analysis State") {
                    DebugRow(label: "Selected Mode", value: viewModel.selectedAnalysisMode?.displayName ?? "None")
                    DebugRow(label: "Is Analyzing", value: viewModel.isAnalyzing ? "Yes" : "No")
                    DebugRow(label: "Cache Status", value: viewModel.analysisCacheStatus ?? "N/A")
                    DebugRow(label: "Performance", value: viewModel.analysisPerformanceInfo ?? "N/A")
                }

                // Analysis Payload (What came from API)
                Section("Analysis Payload (From API)") {
                    if let payload = viewModel.analysisPayload {
                        switch payload {
                        case .distill(let data, let envelope):
                            DebugRow(label: "Type", value: "Distill (Full)", status: .good)
                            DebugRow(label: "Model", value: envelope.model)
                            DebugRow(label: "Latency", value: "\(envelope.latency_ms)ms")
                            DebugRow(label: "Summary", value: data.summary.isEmpty ? "❌ Empty" : "✅ \(data.summary.count) chars")
                            DebugRow(label: "Reflection Questions", value: "\(data.reflection_questions.count) questions")

                            Divider()
                            Text("Pro Modes Data:")
                                .font(.headline)
                                .padding(.top, 4)

                            if let cognitive = data.cognitivePatterns {
                                DebugRow(label: "  Cognitive Patterns", value: "✅ \(cognitive.count) patterns", status: .good)
                            } else {
                                DebugRow(label: "  Cognitive Patterns", value: "❌ nil", status: .bad)
                            }

                            if let philosophical = data.philosophicalEchoes {
                                DebugRow(label: "  Philosophical Echoes", value: "✅ \(philosophical.count) echoes", status: .good)
                            } else {
                                DebugRow(label: "  Philosophical Echoes", value: "❌ nil", status: .bad)
                            }

                            if let values = data.valuesInsights {
                                DebugRow(label: "  Values Insights", value: "✅ \(values.coreValues.count) values", status: .good)
                            } else {
                                DebugRow(label: "  Values Insights", value: "❌ nil", status: .bad)
                            }

                        case .liteDistill(let data, let envelope):
                            DebugRow(label: "Type", value: "Lite Distill (Free Tier)", status: .bad)
                            DebugRow(label: "Model", value: envelope.model)
                            DebugRow(label: "Latency", value: "\(envelope.latency_ms)ms")
                            DebugRow(label: "Summary", value: data.summary.isEmpty ? "❌ Empty" : "✅ \(data.summary.count) chars")
                            Text("⚠️ Lite Distill never includes pro modes")
                                .font(.caption)
                                .foregroundColor(.orange)

                        case .events, .reminders:
                            DebugRow(label: "Type", value: "Events/Reminders only")
                        }
                    } else {
                        Text("No analysis payload yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                // UI Display Logic
                Section("UI Display Logic") {
                    let viewIsPro = viewModel.storeKitService.isPro
                    let hasData = viewModel.analysisPayload != nil

                    DebugRow(label: "isPro (in DistillResultView)", value: viewIsPro ? "✅ YES" : "❌ NO", status: viewIsPro ? .good : .bad)
                    DebugRow(label: "Has Analysis Data", value: hasData ? "Yes" : "No", status: hasData ? .good : .warning)

                    if let payload = viewModel.analysisPayload {
                        switch payload {
                        case .distill(let data, _):
                            let hasCognitive = data.cognitivePatterns != nil && !data.cognitivePatterns!.isEmpty
                            let hasPhilosophical = data.philosophicalEchoes != nil && !data.philosophicalEchoes!.isEmpty
                            let hasValues = data.valuesInsights != nil

                            Divider()
                            Text("Sections Should Display:")
                                .font(.headline)
                                .padding(.top, 4)

                            DebugRow(
                                label: "  Cognitive Clarity",
                                value: (viewIsPro && hasCognitive) ? "✅ YES" : "❌ NO",
                                status: (viewIsPro && hasCognitive) ? .good : .bad
                            )
                            DebugRow(
                                label: "  Philosophical Echoes",
                                value: (viewIsPro && hasPhilosophical) ? "✅ YES" : "❌ NO",
                                status: (viewIsPro && hasPhilosophical) ? .good : .bad
                            )
                            DebugRow(
                                label: "  Values Recognition",
                                value: (viewIsPro && hasValues) ? "✅ YES" : "❌ NO",
                                status: (viewIsPro && hasValues) ? .good : .bad
                            )
                        default:
                            Text("Not a Distill analysis")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }

                // Routing Decision Log
                Section("Last Routing Decision") {
                    Text("Check console logs for:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("📝 MemoDetailViewModel: Distill routing")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Pro Modes Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refreshSubscription()
            }
        }
    }

    private func refreshSubscription() async {
        await viewModel.storeKitService.refreshEntitlements(force: true)

        #if canImport(StoreKit)
        let productIds = ["sonora.pro.monthly", "sonora.pro.annual"]
        for id in productIds {
            if let result = await Transaction.latest(for: id) {
                switch result {
                case .verified(let transaction):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    latestTransaction = "\(id)\nPurchased: \(formatter.string(from: transaction.purchaseDate))\nRevoked: \(transaction.revocationDate != nil ? "YES" : "NO")"
                    return
                case .unverified:
                    latestTransaction = "\(id) - unverified"
                    return
                }
            }
        }
        #endif

        latestTransaction = "No transactions found"
    }
}

// MARK: - Supporting Views

struct DebugRow: View {
    enum Status {
        case good, warning, bad, neutral

        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .bad: return .red
            case .neutral: return .secondary
            }
        }
    }

    let label: String
    let value: String
    var status: Status = .neutral

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(status.color)
                .fontWeight(status != .neutral ? .medium : .regular)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
}
