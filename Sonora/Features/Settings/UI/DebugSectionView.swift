import AVFoundation
import SwiftData
import SwiftUI

struct DebugSectionView: View {
    init() {}
    @SwiftUI.Environment(\.diContainer)
    private var container: DIContainer
    @State private var showEventsSheet = false
    @State private var showRemindersSheet = false
    @State private var sampleEvents: [EventsData.DetectedEvent] = []
    @State private var sampleReminders: [RemindersData.DetectedReminder] = []
    @State private var alertMessage: String?
    @State private var showTimeAdjuster = false
    @State private var selectedMemoForTimeAdjust: Memo?
    @State private var hoursToAdjust: Double = 0

    // Rich sample transcript for testing Distill analysis
    private let sampleRichTranscript = """
I've been thinking a lot about work-life balance lately, especially after that conversation with my therapist last week. She made this really insightful point about how I tend to pour all my energy into projects and then crash afterwards. It's like I'm either at 100% or completely burned out. There's no middle ground.

The new product launch is coming up next Tuesday at 2pm, and I need to prepare the presentation deck. I should probably block out Monday afternoon to focus on that. Oh, and I need to remember to call the dentist this week to schedule that checkup I've been putting off for months.

What's interesting is that I'm noticing a pattern in how I approach challenges. When something feels difficult, my first instinct is to avoid it and focus on easier tasks instead. Like right now with the API integration - I know it's the hardest part of the project, but I keep finding other "urgent" things to work on. Maybe that's another form of procrastination I need to address.

On a positive note, I had a breakthrough moment yesterday while walking through the park. I realized that my fear of failure isn't actually about the failure itself - it's about what I think it says about me as a person. That's a pretty big insight for me. I wonder if I can use that understanding to approach things differently going forward.

I should also follow up with Sarah about the mentorship opportunity she mentioned. Meeting with her next Thursday at 10am would be perfect timing. She's been in the industry for 15 years and could really help me navigate this career transition I'm considering.

The meditation practice I started two weeks ago is starting to show results. I'm sleeping better and feel less reactive during stressful moments. It's subtle, but I can tell there's a shift happening. Maybe consistency really is the key - doing something small every day rather than big sporadic efforts.
"""

    var body: some View {
        SettingsCard {
            Text("Debug Tools")
                .font(SonoraDesignSystem.Typography.headingSmall)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    OnboardingConfiguration.shared.forceShowOnboardingForTesting()
                } label: {
                    HStack { Label("Show Onboarding Again", systemImage: "rectangle.on.rectangle"); Spacer() }
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)

                Button {
                    prepareSampleEvents()
                    showEventsSheet = true
                } label: {
                    HStack {
                        Label("Open Event Confirmation (Sample)", systemImage: "calendar.badge.plus")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.semantic(.textTertiary))
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    prepareSampleReminders()
                    showRemindersSheet = true
                } label: {
                    HStack {
                        Label("Open Reminder Confirmation (Sample)", systemImage: "bell.badge")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.semantic(.textTertiary))
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await runAutoDetectionSample() }
                } label: {
                    HStack { Label("Run Auto-Detection (Sample Transcript)", systemImage: "wand.and.stars"); Spacer() }
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await createTestMemoWithTranscript() }
                } label: {
                    HStack { Label("Create Test Memo (Pre-transcribed)", systemImage: "waveform.badge.plus"); Spacer() }
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)

                Button {
                    Task { await createMockMemoDay() }
                } label: {
                    HStack { Label("Create Mock Memo Day", systemImage: "calendar.badge.checkmark"); Spacer() }
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button {
                    showTimeAdjuster = true
                } label: {
                    HStack { Label("Adjust Memo Timestamps", systemImage: "clock.arrow.circlepath"); Spacer() }
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .sheet(isPresented: $showEventsSheet) {
            EventConfirmationView(detectedEvents: sampleEvents).withDIContainer()
        }
        .sheet(isPresented: $showRemindersSheet) {
            ReminderConfirmationView(detectedReminders: sampleReminders).withDIContainer()
        }
        .sheet(isPresented: $showTimeAdjuster) {
            TimeAdjusterSheet(container: container, onComplete: { message in
                alertMessage = message
            })
        }
        .alert("Auto-Detection", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func prepareSampleEvents() {
        sampleEvents = [
            EventsData.DetectedEvent(
                title: "Meet John Doe",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                location: "Conference Room A",
                participants: ["John Doe", "You"],
                confidence: 0.92,
                sourceText: "Let's meet John tomorrow at 3 PM in Conference Room A"
            ),
            EventsData.DetectedEvent(
                title: "Project Sync",
                startDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                location: "Zoom",
                participants: ["Team"],
                confidence: 0.85,
                sourceText: "Schedule a project sync Friday at 10am via Zoom"
            )
        ]
    }

    private func prepareSampleReminders() {
        sampleReminders = [
            RemindersData.DetectedReminder(
                title: "Buy groceries",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                priority: .medium,
                confidence: 0.9,
                sourceText: "Don't forget to buy groceries tomorrow"
            ),
            RemindersData.DetectedReminder(
                title: "Send report",
                dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                priority: .high,
                confidence: 0.82,
                sourceText: "Remember to send the quarterly report this week"
            )
        ]
    }

    private func runAutoDetectionSample() async {
        let sample = "Meet John tomorrow at 3pm about the project. Also remember to send the report this week."
        let memoId = UUID()
        do {
            let result = try await container.detectEventsAndRemindersUseCase().execute(transcript: sample, memoId: memoId)
            let eCount = result.events?.events.count ?? 0
            let rCount = result.reminders?.reminders.count ?? 0
            alertMessage = "Detected: \(eCount) event(s), \(rCount) reminder(s)."
        } catch {
            alertMessage = "Detection failed: \(error.localizedDescription)"
        }
    }

    private func createTestMemoWithTranscript() async {
        do {
            // Generate unique ID for the test memo
            let memoId = UUID()
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let memosDirectory = documentsPath.appendingPathComponent("Memos")
            let memoDirectory = memosDirectory.appendingPathComponent(memoId.uuidString)

            // Create memo directory
            try FileManager.default.createDirectory(at: memoDirectory, withIntermediateDirectories: true)

            // Create a minimal silent audio file (1 second of silence)
            let audioURL = memoDirectory.appendingPathComponent("audio.m4a")
            try await createSilentAudioFile(at: audioURL, duration: 1.0)

            // Create memo via repository
            let memoRepo = container.memoRepository()
            let newMemo = memoRepo.handleNewRecording(at: audioURL)

            // Inject completed transcription state
            let transcriptionRepo = container.transcriptionRepository()
            await transcriptionRepo.saveTranscriptionState(.completed(sampleRichTranscript), for: newMemo.id)
            await transcriptionRepo.saveTranscriptionText(sampleRichTranscript, for: newMemo.id)

            // Notify success
            alertMessage = "✅ Test memo created successfully! Check the memo list."

            print("✅ Debug: Created test memo with ID \(newMemo.id)")

        } catch {
            await MainActor.run {
                alertMessage = "❌ Failed to create test memo: \(error.localizedDescription)"
            }
            print("❌ Debug: Failed to create test memo: \(error)")
        }
    }

    private func createSilentAudioFile(at url: URL, duration: TimeInterval) async throws {
        // Create a simple silent M4A audio file using AVAudioRecorder
        // This is simpler than AVAssetWriter and produces a valid playable file

        // Remove existing file if present
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)

        // Create recorder
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()

        // Record silence for the specified duration
        recorder.record()
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        recorder.stop()

        // Deactivate audio session
        try? audioSession.setActive(false)
    }

    private func createMockMemoDay() async {
        let now = Date()
        let calendar = Calendar.current

        // Define mock memos matching the screenshot
        struct MockMemoData {
            let title: String
            let durationMinutes: Int
            let hoursAgo: Double
            let transcript: String
        }

        let mockMemos: [MockMemoData] = [
            MockMemoData(
                title: "Morning gratitude practice",
                durationMinutes: 0,
                hoursAgo: 9,
                transcript: "Today I'm grateful for the beautiful sunrise, my health, and the opportunity to work on meaningful projects. I feel centered and ready for the day ahead."
            ),
            MockMemoData(
                title: "Grocery list and meal prep",
                durationMinutes: 0,
                hoursAgo: 2,
                transcript: "Need to pick up milk, eggs, chicken, spinach, tomatoes, pasta, and olive oil. Planning to meal prep some grilled chicken and roasted vegetables for the week."
            ),
            MockMemoData(
                title: "DJ set mix ideas",
                durationMinutes: 0,
                hoursAgo: 38.0/60.0,  // 38 minutes
                transcript: "Thinking about opening with some deep house, building up the energy with tech house in the middle, and closing with melodic techno. Need to find that perfect transition track between progressive and peak time."
            ),
            MockMemoData(
                title: "Mom's birthday planning",
                durationMinutes: 0,
                hoursAgo: 29.0/60.0,  // 29 minutes
                transcript: "Mom's birthday is coming up next month. Thinking about organizing a family dinner at her favorite Italian restaurant. Need to coordinate with my siblings and make a reservation."
            ),
            MockMemoData(
                title: "Language practice - Spanish",
                durationMinutes: 0,
                hoursAgo: 4.0/60.0,  // 4 minutes
                transcript: "Practicando español hoy. Quiero mejorar mi pronunciación y ampliar mi vocabulario. Estoy aprendiendo nuevas frases para conversaciones cotidianas."
            )
        ]

        var createdCount = 0
        var failedCount = 0

        for mockData in mockMemos {
            do {
                // Calculate creation date
                let creationDate = calendar.date(byAdding: .second, value: -Int(mockData.hoursAgo * 3600), to: now) ?? now

                // Calculate duration in seconds (convert from minutes)
                let durationSeconds: TimeInterval
                switch mockData.title {
                case "Language practice - Spanish":
                    durationSeconds = 30
                case "Mom's birthday planning":
                    durationSeconds = 17
                case "DJ set mix ideas":
                    durationSeconds = 31
                case "Grocery list and meal prep":
                    durationSeconds = 23
                case "Morning gratitude practice":
                    durationSeconds = 39
                default:
                    durationSeconds = 30
                }

                // Generate unique ID for the memo
                let memoId = UUID()
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let memosDirectory = documentsPath.appendingPathComponent("Memos")
                let memoDirectory = memosDirectory.appendingPathComponent(memoId.uuidString)

                // Create memo directory
                try FileManager.default.createDirectory(at: memoDirectory, withIntermediateDirectories: true)

                // Create silent audio file with appropriate duration
                let audioURL = memoDirectory.appendingPathComponent("audio.m4a")
                try await createSilentAudioFile(at: audioURL, duration: durationSeconds)

                // Create memo via repository
                let memoRepo = container.memoRepository()
                let newMemo = memoRepo.handleNewRecording(at: audioURL)

                // Update creation date in SwiftData (need to access the model directly)
                let context = container.modelContext()
                let memoIdToFind = newMemo.id
                let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == memoIdToFind })
                if let memoModel = try? context.fetch(descriptor).first {
                    memoModel.creationDate = creationDate
                    try? context.save()
                }

                // Set custom title
                memoRepo.renameMemo(newMemo, newTitle: mockData.title)

                // Inject completed transcription
                let transcriptionRepo = container.transcriptionRepository()
                await transcriptionRepo.saveTranscriptionState(.completed(mockData.transcript), for: newMemo.id)
                await transcriptionRepo.saveTranscriptionText(mockData.transcript, for: newMemo.id)

                createdCount += 1
                print("✅ Debug: Created mock memo '\(mockData.title)' with ID \(newMemo.id)")

            } catch {
                failedCount += 1
                print("❌ Debug: Failed to create mock memo '\(mockData.title)': \(error)")
            }
        }

        await MainActor.run {
            if failedCount == 0 {
                alertMessage = "✅ Successfully created \(createdCount) mock memos! Check the memo list."
            } else {
                alertMessage = "⚠️ Created \(createdCount) memos, but \(failedCount) failed. Check console for details."
            }
        }
    }
}

// MARK: - Time Adjuster Sheet

struct TimeAdjusterSheet: View {
    let container: DIContainer
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var memos: [Memo] = []
    @State private var selectedMemo: Memo?
    @State private var hoursAgo: Double = 1
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                Section("Select Memo") {
                    if memos.isEmpty {
                        Text("No memos available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Memo", selection: $selectedMemo) {
                            Text("Choose a memo...").tag(nil as Memo?)
                            ForEach(memos) { memo in
                                Text(memo.displayName).tag(memo as Memo?)
                            }
                        }
                    }
                }

                Section("Time Adjustment") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set time to: \(formatTimeAgo(hoursAgo))")
                            .font(.headline)

                        Slider(value: $hoursAgo, in: 0...168, step: 0.25) // Up to 7 days

                        HStack {
                            Text("Just now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("7 days ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        Task {
                            await adjustMemoTime()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text("Update Timestamp")
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedMemo == nil || isProcessing)
                }
            }
            .navigationTitle("Adjust Memo Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMemos()
            }
        }
    }

    private func loadMemos() {
        let repo = container.memoRepository()
        memos = repo.memos.sorted { $0.creationDate > $1.creationDate }
    }

    private func formatTimeAgo(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else if hours < 24 {
            let h = Int(hours)
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        } else {
            let days = Int(hours / 24)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    private func adjustMemoTime() async {
        guard let memo = selectedMemo else { return }

        isProcessing = true

        do {
            let newDate = Date().addingTimeInterval(-hoursAgo * 3600)

            // Update in SwiftData
            let context = container.modelContext()
            let memoIdToFind = memo.id
            let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == memoIdToFind })

            if let memoModel = try context.fetch(descriptor).first {
                memoModel.creationDate = newDate
                try context.save()

                // Reload memos to reflect changes
                container.memoRepository().loadMemos()

                await MainActor.run {
                    onComplete("✅ Updated '\(memo.displayName)' to \(formatTimeAgo(hoursAgo))")
                    dismiss()
                }
            } else {
                await MainActor.run {
                    onComplete("❌ Could not find memo in database")
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                onComplete("❌ Failed to update: \(error.localizedDescription)")
                dismiss()
            }
        }

        isProcessing = false
    }
}

// Preview intentionally omitted to avoid build issues in some environments
