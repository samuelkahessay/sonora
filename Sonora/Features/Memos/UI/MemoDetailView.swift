// Moved to Features/Memos/UI
import SwiftUI
import AVFoundation
import UIKit

struct MemoDetailView: View {
    let memo: Memo
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createMemoDetailViewModel()
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    @FocusState private var isTitleEditingFocused: Bool
    
    enum AccessibleElement {
        case playButton
        case transcribeButton
        case transcriptionText
        case analysisResults
        case memoTitle
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                languageBannerView
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                // Auto-detection banner for events/reminders
                if viewModel.showEventDetectionBanner {
                    NotificationBanner.info(
                        message: "📅 Found \(viewModel.eventDetectionCount) event\(viewModel.eventDetectionCount == 1 ? "" : "s") — Tap to review"
                    ) {
                        viewModel.dismissEventDetectionBanner()
                    }
                    .onTapGesture {
                        // Present quick add flow
                        let events = viewModel.latestDetectedEvents()
                        if !events.isEmpty { quickAddEvents = events; showQuickAddSheet = true }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if viewModel.showReminderDetectionBanner {
                    NotificationBanner.info(
                        message: "⏰ Found \(viewModel.reminderDetectionCount) reminder\(viewModel.reminderDetectionCount == 1 ? "" : "s") — Tap to review"
                    ) {
                        viewModel.dismissReminderDetectionBanner()
                    }
                    .onTapGesture {
                        let reminders = viewModel.latestDetectedReminders()
                        if !reminders.isEmpty { quickAddReminders = reminders; showQuickAddRemindersSheet = true }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                headerInfoView
                    .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                    audioControlsView

                    // Inline status/error banners
                    if case .failed(let err) = viewModel.transcriptionState, !dismissTranscriptionErrorBanner {
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
                }
                .padding(.horizontal)
            }
        }
        // Add a small top inset so content doesn't touch nav bar hairline
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .navigationTitle("Memo Details")
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
        .sheet(isPresented: $showQuickAddSheet) {
            EventConfirmationView(detectedEvents: quickAddEvents)
                .withDIContainer()
        }
        .sheet(isPresented: $showQuickAddRemindersSheet) {
            ReminderConfirmationView(detectedReminders: quickAddReminders)
                .withDIContainer()
        }
        .onAppear {
            viewModel.configure(with: memo)
            viewModel.onViewAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AnalysisCopyTriggered"))) { _ in
            isTranscriptExpanded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.restoreAnalysisStateIfNeeded()
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
        .onKeyPress(.escape) {
            if viewModel.isRenamingTitle {
                viewModel.cancelRenaming()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Extracted Sections
    @State private var showQuickAddSheet: Bool = false
    @State private var quickAddEvents: [EventsData.DetectedEvent] = []
    @State private var showQuickAddRemindersSheet: Bool = false
    @State private var quickAddReminders: [RemindersData.DetectedReminder] = []
    
    // Collapsed transcript + banners state
    @State private var isTranscriptExpanded: Bool = false
    @State private var dismissTranscriptionErrorBanner: Bool = false
    
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
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    HapticManager.shared.playSelection()
                    viewModel.playMemo()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.playButtonIcon)
                            .font(.title2)
                            .foregroundColor(.semantic(.textOnColored))
                            .frame(minWidth: 50, minHeight: 50)
                            .background(Color.semantic(.brandPrimary))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isPlaying ? "Now Playing" : "Play Recording")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(memo.durationString)
                                .font(.subheadline)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isPlaying ? "Pause \(viewModel.currentMemoTitle)" : "Play \(viewModel.currentMemoTitle)")
                .accessibilityHint("Double tap to \(viewModel.isPlaying ? "pause" : "play") this memo")
                .accessibilityFocused($focusedElement, equals: .playButton)
                .accessibilityAddTraits(.startsMediaSession)
            }
        }
        .padding()
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(12)
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
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.warning))
                        .font(.body)
                        .accessibilityLabel("Transcription failed")
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
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.semantic(.warning))
                            .font(.body)
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.semantic(.warning))
                Text("This AI-generated transcription may contain sensitive or harmful content.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            .padding(8)
            .background(Color.semantic(.warning).opacity(0.08))
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
            AIDisclaimerView.transcription()
            HStack {
                Spacer()
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    copyText(text)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy transcription text")
                .accessibilityHint("Double tap to copy the transcribed text to clipboard")
            }
        }
    }
    
    @ViewBuilder
    private func failedTranscriptionView(error: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.semantic(.warning))
                Text(getErrorTitle(for: error))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.warning))
            }
            if error == TranscriptionError.noSpeechDetected.errorDescription {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We couldn't detect any speech in this recording.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) { Text("•").bold(); Text("Try re-recording closer to the microphone.").font(.caption).foregroundColor(.semantic(.textSecondary)) }
                        HStack(alignment: .top, spacing: 6) { Text("•").bold(); Text("Move to a quieter area to reduce background noise.").font(.caption).foregroundColor(.semantic(.textSecondary)) }
                        HStack(alignment: .top, spacing: 6) { Text("•").bold(); Text("Start speaking right away to avoid long silence at the beginning.").font(.caption).foregroundColor(.semantic(.textSecondary)) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
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
        .background(Color.semantic(.warning).opacity(0.05))
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
}
