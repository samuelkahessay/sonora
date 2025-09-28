// Moved to Features/Memos/UI
import SwiftUI
import AVFoundation
import UIKit

struct MemoDetailView: View {
    let memo: Memo
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createMemoDetailViewModel()
    @StateObject private var titleTracker = DIContainer.shared.titleGenerationTracker()
    @SwiftUI.Environment(\.dismiss) private var _dismiss_tmp
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    @FocusState private var isTitleEditingFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    
    enum AccessibleElement {
        case playButton
        case transcribeButton
        case transcriptionText
        case analysisResults
        case memoTitle
    }
    
    private var dynamicNavigationTitle: String {
        let title = viewModel.currentMemoTitle
        if scrollOffset < -100 {
            let truncated = String(title.prefix(20))
            return title.count > 20 ? "\(truncated)..." : truncated
        }
        return "Details"
    }

    var body: some View {
        ScrollView {
            // Track scroll offset for dynamic title
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ScrollViewOffsetPreferenceKey.self, value: proxy.frame(in: .named("memoScroll")).minY)
            }
            .frame(height: 0)
            VStack(alignment: .leading, spacing: 0) {
                languageBannerView
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                // Banners for events/reminders were removed; Action Items now handles review/adding.
                
                headerInfoView
                    .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                    audioControlsView

                    // Inline status/error banners (hide for no-speech)
                    if case .failed(let err) = viewModel.transcriptionState,
                       !err.lowercased().contains("no speech detected"),
                       err != TranscriptionError.noSpeechDetected.errorDescription,
                       !dismissTranscriptionErrorBanner {
                        NotificationBanner(
                            type: .warning,
                            message: err,
                            onPrimaryAction: viewModel.canRetryTranscription ? { viewModel.retryTranscription() } : nil,
                            onDismiss: { dismissTranscriptionErrorBanner = true }
                        )
                        .padding(.horizontal)
                    }

                    // Subtle hint when transcript doesn't exist yet
                    if viewModel.transcriptionState.isNotStarted {
                        Text("Record a memo to unlock AI insights")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .padding(.horizontal)
                    }

                    // Show Distill section only when a transcript is available
                    analysisSectionView

                    // Collapsed transcript below Distill
                    transcriptCollapsedView

                    // Delete memo action
                    deleteSectionView
                }
                .padding(.horizontal)
            }
        }
        .coordinateSpace(name: "memoScroll")
        // Add a small top inset so content doesn't touch nav bar hairline
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .navigationTitle(dynamicNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        HapticManager.shared.playSelection()
                        viewModel.showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Share memo")
                    .accessibilityHint("Share voice recording, transcription, or analysis")
                    
                    RenameButton()
                }
            }
        }
        .renameAction {
            viewModel.startRenaming()
        }
        .sheet(isPresented: $viewModel.showShareSheet, onDismiss: {
            viewModel.presentPendingShareIfReady()
        }) {
            ShareMemoSheet(memo: memo, viewModel: viewModel) {
                viewModel.showShareSheet = false
            }
        }
        // Legacy quick-add sheets removed; flows are integrated in Action Items UI.
        .onAppear {
            viewModel.configure(with: memo)
            viewModel.onViewAppear()
        }
        // Ensure configuration runs reliably on push and when reusing the view
        .task(id: memo.id) {
            viewModel.configure(with: memo)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AnalysisCopyTriggered"))) { _ in
            isTranscriptExpanded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.restoreAnalysisStateIfNeeded()
        }
        .onChange(of: viewModel.transcriptionState) { _, state in
            if case .failed(let err) = state {
                let lower = err.lowercased()
                if lower.contains("no speech detected") || err == TranscriptionError.noSpeechDetected.errorDescription {
                    // Ensure the transcription section is visible without expanding
                    isTranscriptExpanded = true
                }
            }
        }
        .onAppear {
            if case .failed(let err) = viewModel.transcriptionState {
                let lower = err.lowercased()
                if lower.contains("no speech detected") || err == TranscriptionError.noSpeechDetected.errorDescription {
                    isTranscriptExpanded = true
                }
            }
        }
        .initialFocus {
            focusedElement = .playButton
        }
        .onChange(of: viewModel.isTranscriptionCompleted) { _, completed in
            if completed {
                HapticManager.shared.playProcessingComplete()
                FocusManager.shared.announceAndFocus(
                    "Transcription completed successfully.",
                    delay: FocusManager.contentDelay
                ) {
                    focusedElement = .transcriptionText
                }
            }
        }
        .onChange(of: viewModel.analysisResult != nil) { _, hasResult in
            if hasResult {
                HapticManager.shared.playProcessingComplete()
                FocusManager.shared.announceAndFocus(
                    "AI analysis completed.",
                    delay: FocusManager.contentDelay
                ) {
                    focusedElement = .analysisResults
                }
            }
        }
        .onChange(of: viewModel.didDeleteMemo) { _, deleted in
            if deleted {
                _dismiss_tmp()
            }
        }
        .handleErrorFocus($viewModel.error)
        .onTapGesture {
            // Dismiss title editing when tapping outside
            if viewModel.isRenamingTitle {
                viewModel.cancelRenaming()
            }
        }
        .errorAlert($viewModel.error) {
            viewModel.retryLastOperation()
        }
        .loadingState(
            isLoading: viewModel.isLoading,
            message: "Loading...",
            error: $viewModel.error
        ) {
            viewModel.retryLastOperation()
        }
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { newValue in
            scrollOffset = newValue
        }
        .onKeyPress(.escape) {
            if viewModel.isRenamingTitle {
                viewModel.cancelRenaming()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Extracted Sections
    // Quick-add state removed (superseded by Action Items UI)
    
    // Collapsed transcript + banners state
    @State private var isTranscriptExpanded: Bool = false
    @State private var dismissTranscriptionErrorBanner: Bool = false
    // Scrubber state
    @State private var isScrubbing: Bool = false
    @State private var scrubValue: Double = 0
    // Delete confirmation
    @State private var showDeleteConfirm: Bool = false
    
    @ViewBuilder
    private var languageBannerView: some View {
        if viewModel.showNonEnglishBanner {
            NotificationBanner.languageDetection(
                message: viewModel.languageBannerMessage,
                onDismiss: viewModel.dismissLanguageBanner
            )
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.3), value: viewModel.showNonEnglishBanner)
        }
    }
    
    @ViewBuilder
    private var headerInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isRenamingTitle {
                // Edit mode: Text field with save/cancel buttons
                VStack(spacing: 12) {
                    TextField("Memo Title", text: $viewModel.editedTitle)
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTitleEditingFocused)
                        .onAppear {
                            // Auto-focus when entering edit mode
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTitleEditingFocused = true
                            }
                        }
                        .onSubmit {
                            viewModel.saveRename()
                        }
                        .accessibilityLabel("Memo title editor")
                        .accessibilityFocused($focusedElement, equals: .memoTitle)
                    
                    HStack {
                        Button("Cancel") {
                            viewModel.cancelRenaming()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Cancel title editing")
                        
                        Spacer()
                        
                        Button("Save") {
                            viewModel.saveRename()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Save new title")
                    }
                }
            } else {
                // Display mode: Title with double-tap to edit
                HStack(spacing: 8) {
                    Text(viewModel.currentMemoTitle)
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focusedElement, equals: .memoTitle)
                        .accessibilityLabel("Memo title: \(viewModel.currentMemoTitle)")
                        .accessibilityHint("Double tap to rename this memo")
                        .onTapGesture(count: 2) {
                            viewModel.startRenaming()
                        }

                    if isAutoTitling {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.secondary)
                            .accessibilityLabel("Naming your memo")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.semantic(.fillPrimary))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isRenamingTitle ? "Editing memo title" : "Memo: \(viewModel.currentMemoTitle), Duration: \(memo.durationString)")
    }
    
    @ViewBuilder
    private var audioControlsView: some View {
        VStack(spacing: 10) {
            let current = isScrubbing ? scrubValue : viewModel.currentTime
            let duration = max(viewModel.totalDuration, 0)
            let canSkipBack = current > 0.1
            let canSkipForward = (duration - current) > 0.1
            // Top row: time left, scrubber, time right
            HStack(spacing: 8) {
                Text(formatTime(isScrubbing ? scrubValue : viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .frame(width: 48, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubValue : viewModel.currentTime },
                        set: { scrubValue = $0 }
                    ),
                    in: 0...(max(viewModel.totalDuration, 0.001)),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing { viewModel.seek(to: scrubValue) }
                    }
                )
                .tint(.semantic(.brandPrimary))
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(Int((isScrubbing ? scrubValue : viewModel.currentTime) / max(viewModel.totalDuration, 1) * 100)) percent")
                Text(formatTime(viewModel.totalDuration))
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .frame(width: 48, alignment: .trailing)
            }

            // Bottom row: -15, play/pause, +15 centered
            HStack(spacing: 22) {
                Button(action: {
                    viewModel.skip(by: -15)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title3)
                        .foregroundColor(.semantic(.brandPrimary))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip back 15 seconds")
                .opacity(canSkipBack ? 1 : 0.4)

                Button(action: {
                    HapticManager.shared.playSelection()
                    viewModel.playMemo()
                }) {
                    Image(systemName: viewModel.playButtonIcon)
                        .font(.title2)
                        .foregroundColor(.semantic(.textOnColored))
                        .frame(width: 40, height: 40)
                        .background(Color.semantic(.brandPrimary))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isPlaying ? "Pause \(viewModel.currentMemoTitle)" : "Play \(viewModel.currentMemoTitle)")
                .accessibilityHint("Double tap to \(viewModel.isPlaying ? "pause" : "play") this memo")
                .accessibilityFocused($focusedElement, equals: .playButton)
                .accessibilityAddTraits(.startsMediaSession)

                Button(action: {
                    viewModel.skip(by: 15)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.title3)
                        .foregroundColor(.semantic(.brandPrimary))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip forward 15 seconds")
                .opacity(canSkipForward ? 1 : 0.4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(12)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
    
    @ViewBuilder
    private var transcriptionSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Transcription")
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.semibold)
                
                Spacer()
                if viewModel.transcriptionState.isFailed {
                    if case .failed(let err) = viewModel.transcriptionState,
                       err != TranscriptionError.noSpeechDetected.errorDescription {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.semantic(.warning))
                            .font(.body)
                            .accessibilityLabel("Transcription failed")
                    }
                } else if viewModel.transcriptionState.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.semantic(.success))
                        .font(.body)
                        .accessibilityLabel("Transcription completed")
                }
            }
            transcriptionStateView
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
        .shadow(color: Color.semantic(.separator).opacity(0.2), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var deleteSectionView: some View {
        Button(role: .destructive) {
            HapticManager.shared.playSelection()
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Memo")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.semantic(.error))
        .accessibilityLabel("Delete this memo")
        .confirmationDialog(
            "Delete this memo?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteCurrentMemo()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    @ViewBuilder
    private var transcriptCollapsedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isTranscriptExpanded) {
                // Body
                transcriptionStateView
                    .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Text("Transcription")
                        .font(.system(.headline, design: .serif))
                        .fontWeight(.semibold)
                    Spacer()
                    if viewModel.transcriptionState.isInProgress {
                        LoadingIndicator(size: .small)
                    } else if viewModel.transcriptionState.isFailed {
                        if case .failed(let err) = viewModel.transcriptionState,
                           err != TranscriptionError.noSpeechDetected.errorDescription {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.semantic(.warning))
                                .font(.body)
                        }
                    } else if viewModel.transcriptionState.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.semantic(.success))
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
        .shadow(color: Color.semantic(.separator).opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var transcriptionStateView: some View {
        switch viewModel.transcriptionState {
        case .notStarted:
            VStack(spacing: 12) {
                Text("This memo hasn't been transcribed yet.")
                    .foregroundColor(.secondary)
                Button("Start Transcription") {
                    HapticManager.shared.playSelection()
                    viewModel.startTranscription()
                }
                .accessibilityLabel("Start transcription")
                .accessibilityHint("Double tap to transcribe this memo using AI")
                .accessibilityFocused($focusedElement, equals: .transcribeButton)
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(8)
        case .inProgress:
            VStack(spacing: 16) {
                // Single unified progress display
                VStack(spacing: 8) {
                    if let pct = viewModel.transcriptionProgressPercent {
                        ProgressView(value: pct)
                            .tint(.semantic(.brandPrimary))
                            .background(.secondary.opacity(0.2))
                            .accessibilityValue("\(Int(pct * 100)) percent complete")
                    } else {
                        ProgressView()
                            .tint(.semantic(.brandPrimary))
                            .scaleEffect(1.0)
                            .accessibilityLabel("Transcription in progress")
                    }
                }
                Text(viewModel.transcriptionProgressStep ?? "Transcribing your audio...")
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Transcription in progress. \(viewModel.transcriptionProgressStep ?? "Transcribing your audio...")")
            .accessibilityAddTraits(.updatesFrequently)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.semantic(.brandPrimary).opacity(0.05))
            .cornerRadius(8)
        case .completed(let text):
            completedTranscriptionView(text: text)
        case .failed(let error):
            failedTranscriptionView(error: error)
        }
    }
    
    @ViewBuilder
    private func completedTranscriptionView(text: String) -> some View {
        if viewModel.transcriptionModerationFlagged {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.semantic(.textSecondary))
                Text("This AI-generated transcription may contain sensitive or harmful content.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            .padding(8)
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(8)
        }
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(formatTranscriptParagraphs(text).enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(8)
            .frame(minHeight: 120)
            .accessibilityLabel("Transcription text")
            .accessibilityValue(text)
            .accessibilityHint("Transcribed text formatted in paragraphs for better readability.")
            .accessibilityFocused($focusedElement, equals: .transcriptionText)
            HStack {
                AIDisclaimerView.transcription()
                if let badge = viewModel.transcriptionServiceBadge {
                    let icon = viewModel.transcriptionServiceIcon ?? "waveform"
                    Label(badge, systemImage: icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.semantic(.fillSecondary))
                    .foregroundColor(.semantic(.textSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel("Transcription source: \(badge)")
                }
                Spacer()
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    copyText(text)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Copy transcription")
                .accessibilityHint("Copies the transcription to the clipboard")
            }
        }
    }
    
    @ViewBuilder
    private func failedTranscriptionView(error: String) -> some View {
        VStack(spacing: 12) {
            if error == TranscriptionError.noSpeechDetected.errorDescription || error.lowercased().contains("no speech detected") {
                // Option A: Minimal inline message with neutral tone
                HStack(spacing: 12) {
                    Image(systemName: "mic.slash")
                        .font(.title3)
                        .foregroundColor(.semantic(.textSecondary))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sonora didn't quite catch that")
                            .font(.subheadline)
                            .foregroundColor(.semantic(.textPrimary))

                        Text("Try recording again with clearer speech")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.warning))
                    Text(getErrorTitle(for: error))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.warning))
                }
                Text(error)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
            }
            if viewModel.canRetryTranscription {
                Button("Try Again") {
                    HapticManager.shared.playSelection()
                    viewModel.retryTranscription()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Retry transcription")
                .accessibilityHint("Double tap to retry the failed transcription")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background((error == TranscriptionError.noSpeechDetected.errorDescription || error.lowercased().contains("no speech detected")) ? Color.clear : Color.semantic(.warning).opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var analysisSectionView: some View {
        if viewModel.isTranscriptionCompleted, let transcriptText = viewModel.transcriptionText {
            AnalysisSectionView(transcript: transcriptText, viewModel: viewModel)
                .accessibilityFocused($focusedElement, equals: .analysisResults)
        }
    }
    
    // MARK: - UI Helper Methods
    
    private func shareText(_ text: String) {
        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    private func copyText(_ text: String) {
        UIPasteboard.general.string = text
        
        // Provide accessibility announcement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: "Text copied to clipboard")
        }
    }
    
    // MARK: - Error Message Helpers
    
    private func getErrorTitle(for error: String) -> String {
        if error == TranscriptionError.noSpeechDetected.errorDescription {
            return "No Speech Detected"
        } else if error.contains("network") || error.contains("connection") {
            return "Connection Problem"
        } else if error.contains("timeout") {
            return "Request Timed Out"
        } else if error.contains("quota") || error.contains("limit") {
            return "Service Limit Reached"
        } else if error.contains("audio") || error.contains("format") {
            return "Audio Format Issue"
        } else {
            return "Transcription Failed"
        }
    }
    
    // MARK: - Transcript Formatting Helpers
    
    private func formatTranscriptParagraphs(_ text: String) -> [String] {
        // Split text into sentences and group them into paragraphs
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for sentence in sentences {
            currentParagraph.append(sentence)
            
            // Create a new paragraph every 3-4 sentences for better readability
            if currentParagraph.count >= 3 {
                let paragraph = currentParagraph.joined(separator: ". ") + "."
                paragraphs.append(paragraph)
                currentParagraph = []
            }
        }
        
        // Add any remaining sentences as the last paragraph
        if !currentParagraph.isEmpty {
            let paragraph = currentParagraph.joined(separator: ". ") + "."
            paragraphs.append(paragraph)
        }
        
        // If no paragraphs were created, return the original text
        return paragraphs.isEmpty ? [text] : paragraphs
    }
    // MARK: - Auto-title indicator state
    private var isAutoTitling: Bool {
        switch titleTracker.state(for: memo.id) {
        case .inProgress:
            let hasCustomTitle: Bool = {
                if let latest = DIContainer.shared.memoRepository().getMemo(by: memo.id),
                   let t = latest.customTitle, !t.isEmpty { return true }
                return false
            }()
            let show = !hasCustomTitle
            if show { print("🧠 UI[Detail]: showing auto-title spinner for memo=\(memo.id)") }
            return show
        case .success(let title):
            print("🧠 UI[Detail]: received title for memo=\(memo.id) -> \(title)")
            return false
        case .failed:
            print("🧠 UI[Detail]: auto-title failed for memo=\(memo.id)")
            return false
        case .idle:
            return false
        }
    }
}
