//
//  MemosView.swift
//  Sonora
//
//  Main memo list container view
//

import SwiftUI

struct MemosView: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createMemoListViewModel()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    let popToRoot: (() -> Void)?
    @Binding var navigationPath: NavigationPath
    @State private var showSettings: Bool = false
    
    init(popToRoot: (() -> Void)? = nil, navigationPath: Binding<NavigationPath>) {
        self.popToRoot = popToRoot
        self._navigationPath = navigationPath
    }

    // Debug toggles removed

    @State private var eventSubscriptionId: UUID? = nil
    
    // MARK: - Computed Properties
    
    // Cached grouping to avoid recomputation on each render
    @State private var cachedGroupedMemos: [MemoSection] = []

    /// Group memos by time periods for contextual headers (cached)
    private func computeGroupedMemos() -> [MemoSection] {
        let signState = Signpost.beginInterval("MemoListGrouping")
        let t0 = PerformanceMetricsService.shared.mark()
        defer {
            Signpost.endInterval("MemoListGrouping", signState)
            PerformanceMetricsService.shared.recordDuration(name: "MemoListGrouping", start: t0, extras: [
                "totalMemos": String(viewModel.memos.count)
            ])
        }

        let calendar = Calendar.current
        let now = Date()

        var sections: [TimePeriod: [Memo]] = [:]

        for memo in viewModel.memos {
            let endDate = memo.recordingEndDate
            let period: TimePeriod

            if calendar.isDateInToday(endDate) {
                let hour = calendar.component(.hour, from: endDate)
                switch hour {
                case 5..<12: period = .thisMorning
                case 12..<17: period = .thisAfternoon
                case 17..<22: period = .thisEvening
                default: period = .today
                }
            } else if calendar.isDateInYesterday(endDate) {
                period = .yesterday
            } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(endDate) == true {
                period = .thisWeek
            } else if calendar.dateInterval(of: .month, for: now)?.contains(endDate) == true {
                period = .thisMonth
            } else {
                period = .older
            }

            sections[period, default: []].append(memo)
        }

        let orderedPeriods: [TimePeriod] = [
            .today, .thisEvening, .thisAfternoon, .thisMorning,
            .yesterday, .thisWeek, .thisMonth, .older
        ]

        return orderedPeriods.compactMap { period in
            guard let memos = sections[period], !memos.isEmpty else { return nil }
            return MemoSection(
                period: period,
                memos: memos.sorted { $0.recordingEndDate > $1.recordingEndDate }
            )
        }
    }

    var body: some View {
        mainContent
        .navigationTitle("Memos")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Settings gear in the leading position
            ToolbarItem(placement: .navigationBarLeading) {
                if #available(iOS 26, *) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .accessibilityLabel("Settings")
                            .accessibilityHint("Open app settings")
                    }
                    .buttonStyle(.plain)
                    .tint(.semantic(.brandPrimary))
                } else {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .symbolRenderingMode(.monochrome)
                            .accessibilityLabel("Settings")
                            .accessibilityHint("Open app settings")
                    }
                    .tint(.semantic(.brandPrimary))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                    MemoListTopBarView(
                        isEmpty: viewModel.isEmpty,
                        isEditMode: viewModel.isEditMode,
                        onToggleEdit: { viewModel.toggleEditMode() }
                    )
            }
        }
        // Present Settings without affecting the memos navigation stack
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .errorAlert($viewModel.error) { viewModel.retryLastOperation() }
        .loadingState(isLoading: viewModel.isLoading, message: "Loading memos...")
        .onAppear {
            // Subscribe to deep link navigation events
            eventSubscriptionId = EventBus.shared.subscribe(to: AppEvent.self) { event in
                switch event {
                case .navigateOpenMemoByID(let id):
                    if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                        navigationPath.append(memo)
                    }
                default:
                    break
                }
            }
            cachedGroupedMemos = computeGroupedMemos()
            Signpost.event("MemoListVisible")
        }
        .onDisappear {
            if let id = eventSubscriptionId { EventBus.shared.unsubscribe(id) }
            eventSubscriptionId = nil
        }
        .onChange(of: viewModel.memos) { _, _ in cachedGroupedMemos = computeGroupedMemos() }
        .overlay(alignment: .bottom) {
            // Bottom delete bar (only visible when in edit mode with selections)
            if viewModel.isEditMode && viewModel.hasSelection {
                MemoBottomDeleteBar(selectedCount: viewModel.selectedCount) { viewModel.deleteSelectedMemos() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .selectionAnimation(value: viewModel.hasSelection)
            }
        }
        // Drag selection indicator removed (tap-only selection)
    }

    // MARK: - Composed Content
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isEmpty {
            MemoEmptyStateView()
        } else {
            memoListView
        }
    }

    @ViewBuilder
    private var memoListView: some View {
        ScrollViewReader { proxy in
            List {
                Section { EmptyView() } header: {
                    AlternativeSelectionControls(viewModel: viewModel)
                }
                // Group memos by time periods for contextual headers
                ForEach(cachedGroupedMemos, id: \.period.rawValue) { section in
                    Section {
                        ForEach(section.memos, id: \.id) { memo in
                            let separatorConfig = separatorConfiguration(for: memo, in: section.memos)
                            let rowContent = MemoRowView(memo: memo, viewModel: viewModel)
                                .dragSelectionAccessibility(
                                    memo: memo,
                                    viewModel: viewModel,
                                    isSelected: viewModel.isMemoSelected(memo)
                                )
                            
                            if viewModel.isEditMode {
                                rowContent
                                    .contentShape(Rectangle())
                                    .onTapGesture { viewModel.toggleMemoSelection(memo) }
                                    .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                                    .listRowBackground(
                                        SelectedRowBackground(
                                            selected: viewModel.isMemoSelected(memo),
                                            colorScheme: colorScheme
                                        )
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                                    }
                            } else {
                                rowContent
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        // Defensive: ensure we pass an up-to-date value
                                        let latest = DIContainer.shared.memoRepository().getMemo(by: memo.id) ?? memo
                                        navigationPath.append(latest)
                                    }
                                    .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                                    .listRowBackground(
                                        SelectedRowBackground(
                                            selected: false,
                                            colorScheme: colorScheme
                                        )
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                                    }
                            }
                        }
                        .onDelete { offsets in
                            HapticManager.shared.playDeletionFeedback()
                            // Convert section-relative offsets to global memo indices
                            let memosToDelete = offsets.map { section.memos[$0] }
                            for memo in memosToDelete {
                                if let globalIndex = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                                    viewModel.deleteMemo(at: globalIndex)
                                }
                            }
                        }
                    } header: {
                        ContextualSectionHeader(
                            period: section.period,
                            memoCount: section.memos.count
                        )
                    }
                }
            }
            .accessibilityLabel(MemoListConstants.AccessibilityLabels.mainList)
            .modifier(ConditionalListStyle())
            .scrollContentBackground(.hidden)
            // Always allow scrolling (drag selection removed)
            .background({
                if #available(iOS 26, *) {
                    Color.clear
                } else {
                    MemoListColors.containerBackground(for: colorScheme)
                }
            }())
            .coordinateSpace(name: "memoList")
            // No safeAreaInset at top to ensure large titles are eligible
            .conditionalRefreshable(!viewModel.isEditMode) {
                await MainActor.run { viewModel.refreshMemos() }
            }
            // Drag selection lane and auto-scroll removed (tap-only selection)
        }
    }

    /// Position-specific separator configuration for clean design within sections
    /// Handles edge cases: first memo (no separators), middle memos (top & bottom), last memo (top only)
    private func separatorConfiguration(for memo: Memo, in sectionMemos: [Memo]) -> (visibility: Visibility, edges: VerticalEdge.Set) {
        let count = sectionMemos.count
        guard count > 1 else { return (.hidden, []) }
        let isFirst = sectionMemos.first?.id == memo.id
        let isLast = sectionMemos.last?.id == memo.id
        if isFirst { return (.hidden, []) }
        if isLast { return (.visible, .top) }
        return (.visible, .all)
    }
}


// MARK: - Swipe Action Components

// Apply plain list style on iOS 26; insetGrouped elsewhere
private struct ConditionalListStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.listStyle(.plain)
        } else {
            content.listStyle(MemoListConstants.listStyle)
        }
    }
}

/// **Swipe Actions Configuration**
extension MemosView {
    
    /// **Contextual Transcription Actions**
    /// Contextual actions based on memo transcription state (excluding delete)
    /// 
    /// **Design Philosophy:**
    /// - Progressive disclosure: Show relevant actions only
    /// - Visual hierarchy: Primary action (transcribe) vs secondary (delete)
    /// - Accessibility: Full VoiceOver support with descriptive labels
    @ViewBuilder
    private func contextualTranscriptionActions(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: Transcription Actions
    
    /// **Transcribe Button**
    /// Primary action for unprocessed memos
    @ViewBuilder
    private func transcribeButton(for memo: Memo) -> some View { EmptyView() }
    
    /// **Retry Transcription Button**
    /// Recovery action for failed transcriptions
    @ViewBuilder
    private func retryTranscriptionButton(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: Destructive Actions
    
    /// **Delete Button**
    /// Destructive action with appropriate styling and feedback
    @ViewBuilder
    private func deleteButton(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: - Bottom Delete Bar
    
    /// Bottom delete bar for bulk deletion
    @ViewBuilder
    private var bottomDeleteBar: some View { EmptyView() }
    
    // Drag selection helpers removed (tap-only selection)
}

// MARK: - Supporting Structures

/// Time period categorization for contextual memo grouping
enum TimePeriod: String, CaseIterable {
    case thisMorning = "this_morning"
    case thisAfternoon = "this_afternoon" 
    case thisEvening = "this_evening"
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case older = "older"
    
    /// Brand voice header text with contextual messaging
    var headerText: String {
        switch self {
        case .thisMorning:
            return "This morning's clarity"
        case .thisAfternoon:
            return "Afternoon reflections"
        case .thisEvening:
            return "Evening thoughts"
        case .today:
            return "Today's insights"
        case .yesterday:
            return "Yesterday's wisdom"
        case .thisWeek:
            return "This week's discoveries"
        case .thisMonth:
            return "Recent explorations"
        case .older:
            return "Earlier reflections"
        }
    }
}

/// Memo section with time period and associated memos
struct MemoSection {
    let period: TimePeriod
    let memos: [Memo]
}

/// Contextual section header with brand voice and New York serif typography
struct ContextualSectionHeader: View {
    let period: TimePeriod
    let memoCount: Int
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // Brand voice header with New York serif (resolved via design system)
            Text(period.headerText)
                .font(SonoraDesignSystem.Typography.navigationTitle)
                .foregroundColor(.semantic(.textPrimary))
            
            Spacer()
            
            // Subtle count indicator
            Text("\(memoCount)")
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(.semantic(.textSecondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(
                        colorScheme == .dark
                        ? Color.semantic(.fillSecondary)
                        : Color.whisperBlue.opacity(0.6)
                    )
                )
                .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] }
        }
        .padding(.horizontal, SonoraDesignSystem.Spacing.md)
        .padding(.vertical, SonoraDesignSystem.Spacing.sm)
        .textCase(nil) // Preserve custom capitalization
    }
}

#Preview { MemosView(popToRoot: nil, navigationPath: .constant(NavigationPath())) }
