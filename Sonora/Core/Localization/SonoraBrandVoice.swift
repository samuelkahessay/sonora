//
//  SonoraBrandVoice.swift
//  Sonora
//
//  Brand voice implementation following "Conversational yet Considered" tone
//  Transforms system messages to be personally meaningful and encouraging
//

import Foundation

// MARK: - Brand Voice Copy

/// Brand voice copy that embodies "Clarity through Voice" philosophy
/// Uses conversational yet considered tone, focusing on personal growth
enum SonoraBrandVoice {
    
    // MARK: - Recording States
    
    enum Recording {
        /// Idle state - inviting and encouraging
        static let readyToRecord = "Share your thoughts"
        static let tapToBegin = "Your voice matters—let's capture it"
        static let microphoneReady = "Ready to listen"
        
        /// Active recording
        static let recordingActive = "Listening to your voice..."
        static let captureInProgress = "Your thoughts are being captured"
        static let speakFreely = "Speak your mind freely"
        
        /// Recording completion
        static let recordingStopped = "Another thought captured"
        static let memoSaved = "Your voice memo is safe"
        static let thoughtPreserved = "That insight has been preserved"
        
        /// Timer and duration
        static let timeRemaining = "moments remaining"
        static let recordingEndsIn = "Wrapping up in"
        static let durationFormat = "Your reflection lasted %@"
    }
    
    // MARK: - Insights and Analysis
    
    enum Insights {
        /// Analysis states
        static let analyzingThoughts = "Discovering insights in your words..."
        static let processingWisdom = "Finding patterns in your thoughts"
        static let extractingMeaning = "Uncovering the essence of your reflection"
        
        /// Insight presentation
        static let insightsReady = "Your insights are ready"
        static let keyThemes = "Themes that emerged:"
        static let meaningfulMoments = "Moments of clarity:"
        static let reflectionSummary = "What your reflection revealed"
        
        /// Confidence and quality
        static let highConfidence = "Clear insights detected"
        static let moderateConfidence = "Some patterns emerge"
        static let lowConfidence = "Gentle hints discovered"
        static let noInsights = "Sometimes silence speaks volumes"
    }
    
    // MARK: - Permissions and Setup
    
    enum Permissions {
        /// Microphone access
        static let microphoneNeeded = "Sonora listens with intention"
        static let microphoneDescription = "To capture your voice for transcription and thoughtful analysis, Sonora needs access to your microphone."
        static let allowMicrophone = "Enable Voice Capture"
        static let microphoneDenied = "Your voice can't reach us yet"
        static let microphoneDeniedDescription = "Enable microphone access in Settings so we can capture your thoughts and insights."
        static let openSettings = "Open Settings"
        
        /// Restricted access
        static let microphoneRestricted = "Voice capture is limited"
        static let restrictedDescription = "Check your device settings to allow voice recording for personal reflection."
        static let checkRestrictions = "Review Settings"
    }
    
    // MARK: - Memo Management
    
    enum Memos {
        /// List states
        static let noMemos = "Your first thought awaits"
        static let noMemosSubtitle = "Every great insight begins with a single voice memo"
        static let loadingMemos = "Gathering your thoughts..."
        static let memosLoaded = "Your reflections are ready"
        
        /// Memo actions
        static let deleteMemo = "Release this thought"
        static let confirmDelete = "Let go of this reflection?"
        static let deleteConfirmed = "Thought released with gratitude"
        static let shareMemo = "Share your insight"
        static let renameMemo = "Give this thought a name"
        
        /// Playback
        static let playMemo = "Revisit this moment"
        static let pausePlayback = "Pause your reflection"
        static let playbackComplete = "Your voice has been heard again"
        
        /// Metadata
        static let createdMoments = "moments ago"
        static let createdHours = "hours ago"
        static let createdToday = "earlier today"
        static let createdYesterday = "yesterday"
        static let duration = "duration"
    }
    
    // MARK: - Transcription Process
    
    enum Transcription {
        /// Processing states
        static let preparing = "Preparing to understand your words..."
        static let transcribing = "Converting your voice to text..."
        static let almostReady = "Nearly there—polishing your words"
        static let complete = "Your words are now text"
        
        /// Quality indicators
        static let highQuality = "Crystal clear transcription"
        static let goodQuality = "Your words came through clearly"
        static let fairQuality = "Most of your message captured"
        static let retryNeeded = "Let's try capturing that again"
        
        /// Suggestions for better quality
        static let moveCloser = "Try speaking closer to your device"
        static let findQuietSpace = "A quieter space might help"
        static let speakClearly = "Speak at your natural pace"
        static let checkMicrophone = "Ensure your microphone is clear"
    }
    
    // MARK: - Settings and Preferences
    
    enum Settings {
        /// Categories
        static let voiceSettings = "Voice & Recording"
        static let insightSettings = "Analysis & Insights"
        static let privacySettings = "Privacy & Data"
        static let personalSettings = "Personal Preferences"
        
        /// Descriptions
        static let modelSelection = "Choose how deeply to analyze your thoughts"
        static let qualityBalance = "Balance between speed and insight depth"
        static let privacyFirst = "Your voice stays private on your device"
        static let dataProtection = "We protect your personal reflections"
        
        /// Model descriptions
        static let quickModel = "Fast insights for daily thoughts"
        static let balancedModel = "Thoughtful analysis with good speed"
        static let deepModel = "Comprehensive insights for important reflections"
    }
    
    // MARK: - Errors and Recovery
    
    enum Errors {
        /// Recording errors
        static let recordingFailed = "Your voice didn't reach us this time"
        static let recordingFailedSolution = "Let's try again—sometimes the first attempt needs a moment"
        
        /// Transcription errors
        static let transcriptionFailed = "We couldn't quite catch all your words"
        static let transcriptionFailedSolution = "Your voice is valuable—shall we try once more?"
        
        /// Analysis errors
        static let analysisFailed = "The insights are shy today"
        static let analysisFailedSolution = "Your words have meaning even without analysis"
        
        /// Network errors
        static let networkUnavailable = "Connection is taking a quiet moment"
        static let networkSolution = "Your thoughts will be processed when connection returns"
        
        /// Storage errors
        static let storageIssue = "We need a bit more space for your thoughts"
        static let storageSolution = "Free up some space so your insights have room to grow"
        
        /// Generic recovery
        static let tryAgain = "Let's try again"
        static let continueAnyway = "Continue without this step"
        static let getHelp = "Get guidance"
    }
    
    // MARK: - Onboarding and Welcome
    
    enum Onboarding {
        /// Welcome flow
        static let welcomeTitle = "Welcome to Clarity"
        static let welcomeSubtitle = "Transform your thoughts into insights through the power of your voice"
        
        /// Step descriptions
        static let step1Title = "Speak Your Mind"
        static let step1Description = "Capture your thoughts naturally—no need for perfect words"
        
        static let step2Title = "Discover Patterns"
        static let step2Description = "Watch as your reflections reveal themes and insights over time"
        
        static let step3Title = "Grow with Clarity"
        static let step3Description = "Use your insights to understand yourself better and make thoughtful decisions"
        
        /// Completion
        static let onboardingComplete = "Your journey to clarity begins"
        static let getStarted = "Start Reflecting"
        static let skipForNow = "I'll explore on my own"
    }
    
    // MARK: - Notifications and Reminders
    
    enum Notifications {
        /// Gentle reminders
        static let dailyReflection = "Your thoughts are waiting to be heard"
        static let weeklyInsight = "What patterns have emerged this week?"
        static let insightReady = "New insights discovered in your recent reflections"
        
        /// Encouragement
        static let keepReflecting = "Your voice brings clarity—continue when you're ready"
        static let insightGrowth = "Your insights are growing richer over time"
        static let thoughtfulJourney = "Every reflection adds to your understanding"
        
        /// Action items
        static let reviewInsights = "Review Your Insights"
        static let captureThought = "Capture a Thought"
        static let continueReflection = "Continue Reflecting"
    }
    
    // MARK: - Calendar and Reminders Integration
    
    enum Calendar {
        /// Event creation
        static let eventDetected = "I noticed something important in your reflection"
        static let createEvent = "Add to Calendar"
        static let eventCreated = "Your commitment is now in your calendar"
        static let eventFailed = "Couldn't add to calendar this time"
        
        /// Reminder creation
        static let reminderDetected = "This sounds like something to remember"
        static let createReminder = "Create Reminder"
        static let reminderCreated = "You'll be gently reminded"
        static let reminderFailed = "Reminder couldn't be set right now"
        
        /// Confirmation
        static let confirmEvent = "Should this go in your calendar?"
        static let confirmReminder = "Would you like to be reminded about this?"
        static let selectCalendar = "Choose your calendar"
        static let selectList = "Choose your reminder list"
    }
}

// MARK: - Dynamic Copy Generation

extension SonoraBrandVoice {
    
    /// Generate personalized copy based on user patterns
    /// - Parameter context: Context for personalization
    /// - Returns: Personalized message
    static func personalizedMessage(for context: PersonalizationContext) -> String {
        switch context.type {
        case .welcomeBack:
            return personalizedWelcome(context)
        case .insightDiscovered:
            return personalizedInsight(context)
        case .encouragement:
            return personalizedEncouragement(context)
        case .milestone:
            return personalizedMilestone(context)
        }
    }
    
    private static func personalizedWelcome(_ context: PersonalizationContext) -> String {
        let timeOfDay = context.timeOfDay
        let frequency = context.usageFrequency
        
        switch (timeOfDay, frequency) {
        case (.morning, .regular):
            return "Good morning—ready for today's insights?"
        case (.evening, .regular):
            return "How did today's thoughts take shape?"
        case (.morning, .new):
            return "A new day, a fresh perspective awaits"
        case (.evening, .new):
            return "The day's wisdom is ready to be captured"
        default:
            return "Your voice brings clarity—what's on your mind?"
        }
    }
    
    private static func personalizedInsight(_ context: PersonalizationContext) -> String {
        guard let insightType = context.insightType else {
            return Insights.insightsReady
        }
        
        switch insightType {
        case .pattern:
            return "A meaningful pattern emerged from your reflections"
        case .emotion:
            return "Your emotional journey is becoming clearer"
        case .goal:
            return "Your aspirations are taking shape"
        case .decision:
            return "The path forward is becoming clearer"
        }
    }
    
    private static func personalizedEncouragement(_ context: PersonalizationContext) -> String {
        let streak = context.streakDays
        
        if streak > 7 {
            return "Your consistent reflection is building real wisdom"
        } else if streak > 3 {
            return "You're developing a beautiful practice of self-reflection"
        } else {
            return "Each thought you capture brings more clarity"
        }
    }
    
    private static func personalizedMilestone(_ context: PersonalizationContext) -> String {
        guard let milestone = context.milestone else {
            return "You've reached a meaningful milestone"
        }
        
        switch milestone {
        case .firstMemo:
            return "Your first thought is captured—many insights await"
        case .firstWeek:
            return "A week of reflection—patterns are beginning to emerge"
        case .firstMonth:
            return "A month of voice memos—your inner wisdom is growing"
        case .hundredMemos:
            return "One hundred reflections—you've built something beautiful"
        }
    }
}

// MARK: - Supporting Types

struct PersonalizationContext {
    enum ContextType {
        case welcomeBack, insightDiscovered, encouragement, milestone
    }
    
    enum TimeOfDay {
        case morning, afternoon, evening, night
    }
    
    enum UsageFrequency {
        case new, occasional, regular, frequent
    }
    
    enum InsightType {
        case pattern, emotion, goal, decision
    }
    
    enum Milestone {
        case firstMemo, firstWeek, firstMonth, hundredMemos
    }
    
    let type: ContextType
    let timeOfDay: TimeOfDay
    let usageFrequency: UsageFrequency
    let streakDays: Int
    let insightType: InsightType?
    let milestone: Milestone?
    
    init(
        type: ContextType,
        timeOfDay: TimeOfDay = .afternoon,
        usageFrequency: UsageFrequency = .regular,
        streakDays: Int = 0,
        insightType: InsightType? = nil,
        milestone: Milestone? = nil
    ) {
        self.type = type
        self.timeOfDay = timeOfDay
        self.usageFrequency = usageFrequency
        self.streakDays = streakDays
        self.insightType = insightType
        self.milestone = milestone
    }
}

// MARK: - Usage Examples and Preview

#if DEBUG
struct SonoraBrandVoice_Preview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.lg) {
                brandVoiceSection("Recording", examples: [
                    ("Ready State", SonoraBrandVoice.Recording.readyToRecord),
                    ("Active Recording", SonoraBrandVoice.Recording.recordingActive),
                    ("Completion", SonoraBrandVoice.Recording.recordingStopped)
                ])
                
                brandVoiceSection("Insights", examples: [
                    ("Processing", SonoraBrandVoice.Insights.analyzingThoughts),
                    ("Ready", SonoraBrandVoice.Insights.insightsReady),
                    ("High Confidence", SonoraBrandVoice.Insights.highConfidence)
                ])
                
                brandVoiceSection("Permissions", examples: [
                    ("Microphone Needed", SonoraBrandVoice.Permissions.microphoneNeeded),
                    ("Description", SonoraBrandVoice.Permissions.microphoneDescription),
                    ("Button", SonoraBrandVoice.Permissions.allowMicrophone)
                ])
                
                brandVoiceSection("Personalized", examples: [
                    ("Morning Welcome", SonoraBrandVoice.personalizedMessage(for: PersonalizationContext(
                        type: .welcomeBack,
                        timeOfDay: .morning,
                        usageFrequency: .regular
                    ))),
                    ("Pattern Insight", SonoraBrandVoice.personalizedMessage(for: PersonalizationContext(
                        type: .insightDiscovered,
                        insightType: .pattern
                    ))),
                    ("Milestone", SonoraBrandVoice.personalizedMessage(for: PersonalizationContext(
                        type: .milestone,
                        milestone: .firstWeek
                    )))
                ])
            }
            .breathingRoom()
        }
        .navigationTitle("Brand Voice Examples")
        .brandThemed()
    }
    
    func brandVoiceSection(_ title: String, examples: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text(title)
                .headingStyle(.medium)
            
            VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.sm) {
                ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.0)
                            .bodyStyle(.small)
                            .foregroundColor(.textSecondary)
                        
                        Text(example.1)
                            .bodyStyle(.regular)
                            .foregroundColor(.textPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.whisperBlue.opacity(0.5))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SonoraBrandVoice_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SonoraBrandVoice_Preview()
        }
    }
}
#endif