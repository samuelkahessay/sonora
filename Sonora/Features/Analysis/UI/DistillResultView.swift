import SwiftUI

/// Comprehensive view for displaying Distill analysis results
/// Shows summary, action items, themes, and reflection questions in a mentor-like format
/// Supports progressive rendering of partial data as components complete
import UIKit

struct DistillResultView: View {
    let data: DistillData?
    let envelope: AnalyzeEnvelope<DistillData>?
    let memoId: UUID?
    // Pro gating (Action Items: detection visible to all; adds gated later)
    private var isPro: Bool { DIContainer.shared.storeKitService().isPro }
    @State private var showPaywall: Bool = false
    @SwiftUI.Environment(\.diContainer)
    var container: DIContainer

    // Initializer
    init(data: DistillData, envelope: AnalyzeEnvelope<DistillData>, memoId: UUID? = nil) {
        self.data = data
        self.envelope = envelope
        self.memoId = memoId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Section
            if let summary = effectiveSummary {
                DistillSummarySectionView(summary: summary)
            }

            // Patterns & Connections Section
            if let patterns = effectivePatterns, !patterns.isEmpty {
                PatternsSectionView(patterns: patterns)
            }

            // Action Items Section (host both tasks and detections)
            actionItemsHostSection

            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                ReflectionQuestionsSectionView(questions: reflectionQuestions)
            }

            // Pro-tier analysis sections
            if isPro {
                // Cognitive Clarity (CBT) Section
                if let cognitivePatterns = effectiveCognitivePatterns, !cognitivePatterns.isEmpty {
                    CognitiveClaritySectionView(patterns: cognitivePatterns)
                }

                // Philosophical Echoes Section
                if let philosophicalEchoes = effectivePhilosophicalEchoes, !philosophicalEchoes.isEmpty {
                    PhilosophicalEchoesSectionView(echoes: philosophicalEchoes)
                }

                // Values Recognition Section
                if let valuesInsights = effectiveValuesInsights {
                    ValuesInsightSectionView(insight: valuesInsights)
                }
            }

            // Copy results action (also triggers smart transcript expand via notification)
            copyAction
        }
        .textSelection(.enabled)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            Logger.shared.debug(
                "ActionItems.InitVM.TopAppear",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil",
                    "eventsForUI": eventsForUI.count,
                    "remindersForUI": remindersForUI.count,
                    "isDetectionPending": isDetectionPending
                ])
            )

            // Log Pro subscription status and section availability
            Logger.shared.info(
                "DistillResultView: Pro status check",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "isPro": isPro,
                    "hasCognitivePatterns": effectiveCognitivePatterns != nil,
                    "cognitivePatternCount": effectiveCognitivePatterns?.count ?? 0,
                    "hasPhilosophicalEchoes": effectivePhilosophicalEchoes != nil,
                    "philosophicalEchoesCount": effectivePhilosophicalEchoes?.count ?? 0,
                    "hasValuesInsights": effectiveValuesInsights != nil,
                    "proSectionsWillRender": isPro && (
                        (effectiveCognitivePatterns?.isEmpty == false) ||
                        (effectivePhilosophicalEchoes?.isEmpty == false) ||
                        (effectiveValuesInsights != nil)
                    )
                ])
            )

            if !isPro {
                Logger.shared.info(
                    "⚠️ Pro sections hidden: isPro=false",
                    category: .viewModel,
                    context: LogContext(additionalInfo: ["storeKitService": "check RevenueCat entitlements"])
                )
            } else if effectiveCognitivePatterns == nil && effectivePhilosophicalEchoes == nil && effectiveValuesInsights == nil {
                Logger.shared.warning(
                    "⚠️ Pro sections hidden: isPro=true but no Pro data available",
                    category: .viewModel,
                    context: LogContext(additionalInfo: ["reason": "Pro use case may not have executed"])
                )
            } else {
                Logger.shared.info(
                    "✅ Pro sections will render: isPro=true and Pro data available",
                    category: .viewModel,
                    context: LogContext()
                )
            }

            initializeViewModelIfNeeded()
        }
    }

    // MARK: - Computed Properties

    @ViewBuilder
    private var copyAction: some View {
        HStack {
            Spacer()
            Button(action: {
                let text = buildCopyText()
                UIPasteboard.general.string = text
                HapticManager.shared.playLightImpact()
                NotificationCenter.default.post(name: Notification.Name("AnalysisCopyTriggered"), object: nil)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Copy analysis results")
        }
    }

    private var effectiveSummary: String? {
        data?.summary
    }

    private var effectivePatterns: [DistillData.Pattern]? {
        data?.patterns
    }

    private var effectiveReflectionQuestions: [String]? {
        data?.reflection_questions
    }

    private var effectiveCognitivePatterns: [CognitivePattern]? {
        data?.cognitivePatterns
    }

    private var effectivePhilosophicalEchoes: [PhilosophicalEcho]? {
        data?.philosophicalEchoes
    }

    private var effectiveValuesInsights: ValuesInsight? {
        data?.valuesInsights
    }

    // Use domain-deduplicated results directly
    // Note: Repository fallback removed - async getAnalysisResult can't be called from computed property
    // TODO: Refactor to load repository data asynchronously in onAppear
    var eventsForUI: [EventsData.DetectedEvent] {
        if let ev = data?.events, !ev.isEmpty { return ev }
        return []
    }
    // Note: Repository fallback removed - async getAnalysisResult can't be called from computed property
    // TODO: Refactor to load repository data asynchronously in onAppear
    var remindersForUI: [RemindersData.DetectedReminder] {
        if let rem = data?.reminders, !rem.isEmpty { return rem }
        return []
    }

    // MARK: - Detections (Events + Reminders)
    @StateObject private var viewModelHolder = ViewModelHolder()

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        if let vm = viewModelHolder.vm {
            ActionItemsHostObservedSection(
                vm: vm,
                isPro: isPro,
                isDetectionPending: isDetectionPending
            )
            .onAppear {
                Logger.shared.info(
                    "ActionItems.HostAppeared",
                    category: .viewModel,
                    context: LogContext(additionalInfo: [
                        "memoId": memoId?.uuidString ?? "nil",
                        "eventsForUI": eventsForUI.count,
                        "remindersForUI": remindersForUI.count,
                        "isDetectionPending": isDetectionPending
                    ])
                )
            }
            .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
                vm.mergeIncoming(events: eventsForUI, reminders: remindersForUI)
            }
        } else {
            // Initialize lazily and render nothing until VM exists
            EmptyView()
                .onAppear {
                    Logger.shared.debug(
                        "ActionItems.InitVM.Request",
                        category: .viewModel,
                        context: LogContext(additionalInfo: [
                            "memoId": memoId?.uuidString ?? "nil",
                            "eventsForUI": eventsForUI.count,
                            "remindersForUI": remindersForUI.count,
                            "isDetectionPending": isDetectionPending
                        ])
                    )
                    initializeViewModelIfNeeded()
                }
        }
    }

    // MARK: - Reflection Questions Section

    // Reflection section extracted into component ReflectionQuestionsSectionView

    // MARK: - Detection helpers
    // Filtering and batch helpers consolidated in ActionItemDetectionState

    // MARK: - Async wrappers
    private func initializeViewModelIfNeeded() {
        if viewModelHolder.vm == nil {
            Logger.shared.debug(
                "ActionItems.InitVM.Build",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil",
                    "eventsForUI": eventsForUI.count,
                    "remindersForUI": remindersForUI.count,
                    "isDetectionPending": isDetectionPending
                ])
            )
            viewModelHolder.vm = ActionItemViewModel(
                memoId: memoId,
                initialEvents: eventsForUI,
                initialReminders: remindersForUI
            )
            Logger.shared.info(
                "ActionItems.InitVM.Built",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil"
                ])
            )
        }
    }

    // Removed local permission explainer; handled in ActionItemsHostSectionView

    // MARK: - Placeholder Views

    // Build a concatenated text representation for copying
    private func buildCopyText() -> String {
        var parts: [String] = []
        if let s = effectiveSummary, !s.isEmpty {
            parts.append("Summary:\n" + s)
        }
        // Patterns & Connections
        if let patterns = effectivePatterns, !patterns.isEmpty {
            var patternLines: [String] = ["Patterns & Connections:"]
            for (index, pattern) in patterns.enumerated() {
                patternLines.append("\(index + 1). \(pattern.theme)")
                patternLines.append("   \(pattern.description)")
                if let relatedMemos = pattern.relatedMemos, !relatedMemos.isEmpty {
                    patternLines.append("   Related memos:")
                    for memo in relatedMemos.prefix(3) {
                        let timeStr = memo.daysAgo.map { "(\($0) days ago)" } ?? ""
                        patternLines.append("   • \(memo.title) \(timeStr)")
                    }
                }
            }
            parts.append(patternLines.joined(separator: "\n"))
        }
        // Key Themes intentionally omitted from Distill (Themes is a separate mode)
        if let questions = effectiveReflectionQuestions, !questions.isEmpty {
            let list = questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            parts.append("Reflection Questions:\n" + list)
        }
        // Pro-tier analysis sections
        if isPro {
            // Cognitive Clarity
            if let cognitivePatterns = effectiveCognitivePatterns, !cognitivePatterns.isEmpty {
                var lines: [String] = ["Cognitive Clarity (CBT):"]
                for pattern in cognitivePatterns {
                    lines.append("• \(pattern.type.displayName): \(pattern.observation)")
                    if let reframe = pattern.reframe {
                        lines.append("  Reframe: \(reframe)")
                    }
                }
                parts.append(lines.joined(separator: "\n"))
            }
            // Philosophical Echoes
            if let echoes = effectivePhilosophicalEchoes, !echoes.isEmpty {
                var lines: [String] = ["Philosophical Echoes:"]
                for echo in echoes {
                    lines.append("• \(echo.tradition.displayName): \(echo.connection)")
                    if let quote = echo.quote {
                        lines.append("  \"\(quote)\"")
                        if let source = echo.source {
                            lines.append("  — \(source)")
                        }
                    }
                }
                parts.append(lines.joined(separator: "\n"))
            }
            // Values Recognition
            if let valuesInsights = effectiveValuesInsights {
                var lines: [String] = ["Values Recognition:"]
                lines.append("Core Values:")
                for value in valuesInsights.coreValues {
                    lines.append("• \(value.name) (\(value.confidenceCategory) confidence)")
                    lines.append("  \(value.evidence)")
                }
                if let tensions = valuesInsights.tensions, !tensions.isEmpty {
                    lines.append("Value Tensions:")
                    for tension in tensions {
                        lines.append("• \(tension.value1) ↔ \(tension.value2): \(tension.observation)")
                    }
                }
                parts.append(lines.joined(separator: "\n"))
            }
        }
        let events = eventsForUI
        let reminders = remindersForUI
        if !events.isEmpty || !reminders.isEmpty {
            var lines: [String] = []
            if !events.isEmpty {
                lines.append("Events:")
                lines.append(contentsOf: events.map(eventLine))
            }
            if !reminders.isEmpty {
                lines.append("Reminders:")
                lines.append(contentsOf: reminders.map(reminderLine))
            }
            parts.append(lines.joined(separator: "\n"))
        } else {
            // Append "none" message when no detections found
            parts.append("Events & Reminders:\nNo events or reminders detected")
        }
        return parts.joined(separator: "\n\n")
    }

    // Detection is never pending since we don't stream anymore
    private var isDetectionPending: Bool {
        return false
    }

}

// Helper to own a @StateObject VM while allowing optional init in body
private final class ViewModelHolder: ObservableObject {
    @Published var vm: ActionItemViewModel?
}

private extension DistillResultView { }

// MARK: - Observed wrapper to react to VM changes
private struct ActionItemsHostObservedSection: View {
    @ObservedObject var vm: ActionItemViewModel
    let isPro: Bool
    let isDetectionPending: Bool

    var body: some View {
        ActionItemsHostSectionView(
            permissionService: vm.permissionService,
            visibleItems: vm.visibleItems,
            addedRecords: vm.addedRecords,
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: $vm.showBatchSheet,
            batchInclude: $vm.batchInclude,
            calendars: vm.availableCalendars,
            reminderLists: vm.availableReminderLists,
            defaultCalendar: vm.defaultCalendar,
            defaultReminderList: vm.defaultReminderList
        ) { event in
            switch event {
            case .item(let itemEvent):
                switch itemEvent {
                case .editToggle(let id):
                    vm.handleEditToggle(id)
                case .add(let item):
                    Task { @MainActor in await vm.handleAddSingle(item) }
                case .dismiss(let id):
                    vm.handleDismiss(id)
                }
            case .openBatch(let selected):
                Task { @MainActor in await vm.handleOpenBatch(selected: selected) }
            case .addSelected(let items, let calendar, let reminderList):
                Task { @MainActor in await vm.handleAddSelected(items, calendar: calendar, reminderList: reminderList) }
            case .dismissSheet:
                break
            }
        }
        // Conflict sheet when duplicates are found
        .sheet(isPresented: $vm.showConflictSheet) {
            EventConflictResolutionSheet(
                duplicates: vm.conflictDuplicates,
                onProceed: { Task { @MainActor in await vm.resolveConflictProceed() } },
                onSkip: { vm.resolveConflictSkip() }
            )
        }
    }
}
