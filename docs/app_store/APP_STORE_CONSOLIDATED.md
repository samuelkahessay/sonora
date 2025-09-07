# Sonora App Store Documentation - Consolidated

> **Status**: Ready for submission  
> **Bundle ID**: com.samuelkahessay.Sonora  
> **Platform**: iOS 17.6+ (iPhone only)  
> **Category**: Productivity  
> **Last Updated**: August 2025

---

## 📋 Table of Contents

1. [App Overview](#app-overview)
2. [App Store Metadata](#app-store-metadata)
3. [Technical Implementation](#technical-implementation)
4. [Privacy & Compliance](#privacy--compliance)
5. [Screenshots & Assets](#screenshots--assets)
6. [Demo Video](#demo-video)
7. [ASO Strategy](#aso-strategy)
8. [App Store Connect Setup](#app-store-connect-setup)
9. [Submission Checklist](#submission-checklist)
10. [App Review Notes](#app-review-notes)
11. [Quality & Compliance](#quality--compliance)

---

## 🎯 App Overview

### Purpose
Sonora is a voice memo recording app with background recording, playback, and server-side transcription. It features optional Live Activity showing recording state and a stop shortcut.

### Key Features
- **Recording**: Uses `AVAudioSession` (.playAndRecord) and `AVAudioRecorder` with UIBackgroundModes `audio` to continue recording when backgrounded
- **Playback**: Basic playback via `AVAudioPlayer`
- **Transcription/Analysis**: Uploads audio to `https://sonora.fly.dev/transcribe` (OpenAI Whisper) and analyzes transcripts via `https://sonora.fly.dev/analyze` (OpenAI GPT-4o-mini)
- **Live Activities**: ActivityKit Live Activity and Dynamic Island UI for recording state; deep link to stop recording (`sonora://stopRecording`)
- **Architecture**: MVVM + Clean Architecture with repositories + use cases; DI container; event bus; main actor isolation fixes

### Platforms & Requirements
- **Platforms**: iOS (iPhone only)
- **Minimum OS**: iOS 17.6 (main app and Live Activity extension)
- **Bundle IDs**:
  - App: `com.samuelkahessay.Sonora`
  - Live Activity Extension: `com.samuelkahessay.Sonora.SonoraLiveActivity`

---

## 📱 App Store Metadata

### Basic Information
- **App Name**: Sonora
- **Subtitle**: AI Voice Memo & Transcription
- **Category**: Productivity
- **Sub-category**: Business
- **Age Rating**: 4+ (No Objectionable Material)
- **Content Rights**: This app does not use third-party content

### App Store Copy

#### **Short Description (30 chars)**
"AI Voice Memos & Transcription"

#### **Promotional Text (170 chars max)**
🎤 Record voice memos with background recording
🧠 AI transcription & analysis  
📱 Live Activity with Dynamic Island
🔒 Privacy-first, local storage

#### **Full Description**

**Transform your voice into actionable insights with Sonora - the intelligent voice memo app built for privacy.**

🎤 **Smart Recording**
• Background recording with Live Activities
• 3-minute focused recording sessions  
• Dynamic Island integration on iPhone 14 Pro+
• Continue recording when app is backgrounded

🧠 **AI-Powered Analysis**
• Instant transcription with 100+ language support
• Smart summaries and key insights
• Theme extraction and todo identification
• Content moderation for safety

📱 **Native iOS Experience**  
• Beautiful SwiftUI design with Dark Mode
• Seamless system integration
• Full accessibility support
• Optimized for all iPhone models

🔒 **Privacy by Design**
• Local-first storage - your data stays on your device
• Optional cloud transcription (you control when)
• No user tracking or analytics
• Open source architecture

**Perfect for:**
• Students recording lectures
• Professionals capturing meeting notes  
• Journalists conducting interviews
• Anyone who thinks faster than they type

**Why Sonora?**
Unlike other voice apps, Sonora combines powerful AI capabilities with a privacy-first approach. Your recordings stay local until YOU choose to transcribe them. No subscriptions, no tracking, just pure functionality.

---

**Technical Excellence:**
Built with Clean Architecture principles, featuring 95% protocol-based dependency injection and modern async/await concurrency. Sonora represents the gold standard for iOS app development.

---

*Download Sonora today and turn your voice into your most powerful productivity tool.*

#### **Keywords (100 chars max)**
voice memo,transcription,AI,recording,notes,productivity,speech to text,dictation,voice notes

#### **What's New (4000 chars max)**
🎉 **Sonora 1.0 - Your Voice, Supercharged**

**New Features:**
• ✨ Background recording with Live Activities
• 🧠 AI transcription in 100+ languages  
• 📊 Smart analysis: summaries, themes, todos
• 🎯 Dynamic Island integration (iPhone 14 Pro+)
• 🔒 Privacy-first architecture

**Technical Improvements:**
• Built with Clean Architecture (95% compliance)
• Modern async/await concurrency
• Full accessibility support
• Native SwiftUI design

**Privacy & Security:**
• Local-first storage by default
• Optional cloud transcription (user-controlled)
• Content moderation for safety
• Zero tracking or analytics

Record your thoughts, transcribe with AI, and transform voice into actionable insights - all while keeping your privacy intact.

---

## ⚙️ Technical Implementation

### Capabilities, Entitlements, and Info.plist

#### **Permissions (Info.plist)**
- `NSMicrophoneUsageDescription`: present and descriptive
- `UIBackgroundModes`: contains `audio` (required for background recording)
- `NSSupportsLiveActivities`: YES (main app)
- `NSSupportsLiveActivitiesFrequentUpdates`: NO (disabled to align with App Review guidance)
- `CFBundleURLTypes` includes custom scheme `sonora` (used by Live Activity link to stop recording)

#### **Entitlements**
- **App**: No App Groups (removed; not required for current functionality)
- **Live Activity extension**: No App Groups (removed; not required)

### Background Behavior
- Audio background mode is correctly declared
- Recording continues in background with a properly configured audio session
- UIBackgroundTask is also used for safety
- No background Bluetooth, location, or other background modes are declared (good)

### Live Activities Compliance
- Live Activity frequent updates: Disabled
- Apple restricts "Frequent Updates" to narrow use cases (e.g., live sports, ridesharing)
- A recording timer generally does not qualify; standard update cadence is appropriate

### Build and Signing
- **Deployment Target**: iOS 17.6 for all targets
- **Signing**: Automatic
- **Requirements before archive**:
  - App ID includes the "Live Activities" capability
  - App Groups are not used; entitlements were removed to simplify signing
  - Prepare an App Store Distribution profile and set the app's team to match

### Export Compliance
- Uses standard TLS/HTTPS
- For export compliance, answer "Yes" to using encryption and indicate only standard encryption
- No proprietary cryptography in code

---

## 🔒 Privacy & Compliance

### Privacy and Data Practices (App Store "App Privacy")

#### **Microphone Audio**
- The app records user audio and (when transcription is requested) uploads the audio file to a backend for processing
- **Data type**: "User Content > Audio Data"
- **Purpose**: "App Functionality" (transcription feature)
- **Linked to user**: Typically "No" (unless you add user accounts or link audio to identity server-side)
- **Tracking**: None

#### **Network & Security**
- Uses HTTPS only
- No ATS exceptions are configured or required

#### **Pasteboard**
- The app writes to the pasteboard to copy transcript text (no reading)
- This is not a Required Reason API use case, but call it out in review notes to preempt questions

#### **AI Disclosures**
- The app discloses AI functionality in Settings (AI Features card)
- Transcripts and analysis are machine-generated and may contain errors
- We label AI-generated content and show a safety notice if content is flagged by moderation

#### **Required Reason APIs / Privacy Manifests**
- The code uses standard APIs (URLSession, FileManager)
- If you add any "Required Reason API" usage (e.g., reading pasteboard contents, disk space, system boot time, etc.), include a `PrivacyInfo.xcprivacy` manifest with proper reasons before submission
- For now, a manifest is optional but recommended for forward-compatibility
- Policy URLs: Provide a Privacy Policy URL in App Store Connect (recommended since audio leaves device for transcription)

### App Privacy Labels Mapping (for App Store Connect)

| Data Type | Collected | Purpose | Linked to User | Tracking |
|-----------|-----------|---------|----------------|----------|
| User Content > Audio Data (Voice) | Yes | App Functionality | No | No |
| User Content > Other User Content (Transcripts, text derived from audio) | Yes | App Functionality | No | No |
| Diagnostics (Crash data) | No | — | — | — |
| Usage Data (Product interaction) | No | — | — | — |
| Identifiers (Device/User) | No | — | — | — |
| Contact Info | No | — | — | — |
| Location | No | — | — | — |

#### **Notes**
- Audio recording happens on-device; when the user initiates transcription/analysis, the audio file is uploaded to the Sonora backend strictly to perform that feature (App Functionality). No advertising/marketing use
- Transcripts (text) are derived from the user's audio; treated as User Content; used only for App Functionality
- No user accounts; we do not link data to identity. No third-party tracking SDKs
- Logging is local (console) only; no crash reporting SDK is integrated. If a crash reporting SDK is added later, update this table accordingly

### xcprivacy (Privacy Manifest) Review

#### **Current third-party SDKs**
- ZIPFoundation (SPM) only
- **Purpose**: ZIP archive creation for user export
- **Required Reason APIs**: None (standard file I/O only). No manifest entries required

#### **Project manifest**
- `Sonora/PrivacyInfo.xcprivacy` is present and currently minimal (no tracking, no accessed APIs)
- This is acceptable with the current codebase
- If later you integrate SDKs that access Required Reason APIs (e.g., clipboard read, disk space, file timestamping beyond normal use), add the appropriate entries to `PrivacyInfo.xcprivacy` and document them here

---

## 🖼️ Screenshots & Assets

### Required Sizes
- **iPhone 6.7"** (iPhone 15 Pro Max, 14 Pro Max, 13 Pro Max, 12 Pro Max): 1290 x 2796 pixels
- **iPhone 6.1"** (iPhone 15, 15 Pro, 14, 14 Pro, 13, 13 Pro, 12, 12 Pro): 1179 x 2556 pixels  
- **iPhone 5.5"** (iPhone 8 Plus, 7 Plus, 6s Plus, 6 Plus): 1242 x 2208 pixels

### Screenshot Sequence (5-10 screenshots)

#### **Screenshot 1: Main Screen - Ready to Record**
- **Scene**: Memos list with large record button
- **Content**: Empty state or 1-2 sample memos
- **Overlay**: "Tap to start recording" with arrow pointing to record button
- **Features**: Clean list design, native iOS styling

#### **Screenshot 2: Recording in Progress**  
- **Scene**: Recording screen with animated waveform
- **Content**: Timer showing 00:23, pulsing record button
- **Overlay**: "Background recording continues when app is minimized"
- **Features**: Real-time audio visualization

#### **Screenshot 3: Live Activity & Dynamic Island**
- **Scene**: Lock screen or home screen showing Live Activity
- **Content**: "Recording - 01:34" with Stop button
- **Overlay**: "Control recording from anywhere"
- **Features**: Live Activity UI, Dynamic Island (if supported)

#### **Screenshot 4: Memo Detail - Transcription**
- **Scene**: Memo detail with "Transcribe" button or completed transcription
- **Content**: Audio waveform, play button, transcription text
- **Overlay**: "AI transcription in 100+ languages"
- **Features**: Clean typography, "AI-generated" label

#### **Screenshot 5: AI Analysis Results**
- **Scene**: Analysis view showing summary, themes, todos
- **Content**: Structured analysis with clear sections
- **Overlay**: "Transform voice into actionable insights"
- **Features**: Organized layout, easy-to-scan results

#### **Optional Screenshot 6: Settings - Privacy Focus**
- **Scene**: Settings screen highlighting privacy features
- **Content**: Data export, privacy policy links, AI features
- **Overlay**: "Your data, your control"
- **Features**: Privacy-first messaging

### Capture Instructions

1. **Device Setup**:
   - Use iPhone 15 Pro Max for primary screenshots
   - Enable Developer mode for precise screenshot timing
   - Test both Light and Dark mode versions

2. **Content Preparation**:
   - Create sample memos with varied lengths (5-45 seconds)
   - Prepare realistic transcription content (avoid Lorem ipsum)
   - Ensure all text is readable and professional

3. **Technical Requirements**:
   - No notch obstruction of critical UI elements
   - High contrast for text readability
   - Screenshots should be device frames or clean crops
   - Test accessibility with VoiceOver enabled

### Required Assets Checklist

#### **App Icons**
- [x] App Store Icon: 1024×1024px (PNG, no transparency)
- [x] iOS App Icon: Multiple sizes in app bundle

#### **Screenshots** 
- [ ] iPhone 6.7": 1290×2796px (PNG/JPG) - 5-10 images
- [ ] iPhone 6.1": 1179×2556px (PNG/JPG) - 5-10 images  
- [ ] iPhone 5.5": 1242×2208px (PNG/JPG) - 5-10 images

#### **Optional Assets**
- [ ] App Preview videos: Max 30MB each
- [ ] Apple Watch screenshots (if supported)

---

## 🎬 Demo Video

### **Internal Demo Video Script**

**Duration**: 75 seconds  
**Format**: Screen recording with optional voiceover  
**Aspect Ratio**: 16:9 (landscape) or 9:16 (portrait)

#### **Scene 1: App Launch (0-8s)**
- **Action**: Open Sonora from home screen
- **Show**: Clean app icon animation, main memos list
- **Narration**: "Meet Sonora - AI voice memos that respect your privacy"

#### **Scene 2: Start Recording (8-18s)**  
- **Action**: Tap record button, show recording interface
- **Show**: Animated waveform, timer incrementing
- **Narration**: "Record your thoughts with a simple tap"

#### **Scene 3: Background Recording (18-30s)**
- **Action**: Press home button, show Live Activity
- **Show**: Home screen with Live Activity, Dynamic Island
- **Narration**: "Recording continues in background with Live Activities"

#### **Scene 4: Stop Recording (30-38s)**
- **Action**: Tap Stop in Live Activity or return to app
- **Show**: Recording stops, memo appears in list
- **Narration**: "Control recording from anywhere on your phone"

#### **Scene 5: Transcription (38-50s)**
- **Action**: Open memo, tap Transcribe button
- **Show**: Upload progress, transcription appearing
- **Narration**: "AI transcription in over 100 languages"

#### **Scene 6: Analysis (50-62s)**
- **Action**: Tap Analyze, show analysis results
- **Show**: Summary, themes, todos appearing
- **Narration**: "Get smart insights and actionable summaries"

#### **Scene 7: Spotlight Integration (62-70s)**
- **Action**: Use Spotlight search to find and open memo
- **Show**: Search results, deep link to specific memo
- **Narration**: "Deep integration with iOS for instant access"

#### **Scene 8: Closing (70-75s)**
- **Action**: Show app icon, tagline
- **Show**: "Sonora - Your Voice, Supercharged"
- **Narration**: "Download Sonora today"

### **Video Production Notes**

- **Quality**: 1080p minimum, 60fps preferred
- **Audio**: High-quality screen recording audio or professional voiceover
- **Text Overlays**: Use system font (SF Pro) for consistency
- **Branding**: Minimal, focus on functionality over marketing
- **File Size**: Under 500MB for easy sharing

---

## 🔍 ASO (App Store Optimization) Strategy

### **Primary Keywords**
1. **voice memo** - High volume, moderate competition
2. **transcription** - High intent, growing category  
3. **AI recording** - Emerging trend, lower competition
4. **speech to text** - Established category, high volume
5. **voice notes** - Natural user language

### **Secondary Keywords**  
- productivity app
- dictation software  
- meeting recorder
- interview transcription
- student notes
- lecture recording
- voice journaling

### **Long-tail Keywords**
- "background recording app"
- "private voice transcription" 
- "AI voice memo analysis"
- "Live Activity recording"
- "local voice notes"

### **Competitor Analysis**
- **Otter.ai**: Strong in business/meetings (subscription model)
- **Voice Memos (Apple)**: Basic recording (no AI features)
- **Rev Voice Recorder**: Transcription focus (cloud-dependent)
- **Just Press Record**: Simple recording (limited AI)

**Sonora's Differentiators**:
- Privacy-first approach
- Local storage with optional cloud
- Live Activities integration  
- Clean Architecture implementation
- No subscription model

---

## 📋 App Store Connect Setup

### **App Information**
- **Name**: Sonora
- **Subtitle**: AI Voice Memo & Transcription  
- **Primary Category**: Productivity
- **Secondary Category**: Business
- **Content Rights**: This app does not use third-party content

### **Pricing & Availability**
- **Price**: Free
- **Availability**: All territories  
- **Release**: Manual release after approval

### **App Privacy**
Based on privacy mapping:

| Data Type | Collected | Purpose | Linked to User | Used for Tracking |
|-----------|-----------|---------|----------------|-------------------|
| Audio Data | Yes | App Functionality | No | No |
| Other User Content (Transcripts) | Yes | App Functionality | No | No |
| All other categories | No | - | - | - |

### **Age Rating**
- **4+** (No Objectionable Material)
- Contains no restricted content
- User-generated content not shared publicly

---

## ✅ Submission Checklist

### **High Priority TODOs**

#### **Required URLs**
- [ ] **Privacy Policy URL** - Create and host privacy policy
- [ ] **Terms of Use URL** - Create and host terms of service  
- [ ] **Support URL** - Create support page/documentation
- [ ] **Marketing URL** - Optional marketing website

#### **Required Screenshots** 
- [ ] **iPhone 6.7"** (1290×2796px) - 5 screenshots minimum
- [ ] **iPhone 6.1"** (1179×2556px) - 5 screenshots minimum
- [ ] **iPhone 5.5"** (1242×2208px) - 5 screenshots minimum

#### **Demo Video** (Internal Use)
- [ ] **60-90 second** screen recording following provided script
- [ ] Show complete flow: Record → Live Activity → Stop → Transcribe → Analyze → Spotlight

### **Pre-Submission**
- [ ] Complete App Store metadata in App Store Connect
- [ ] Upload all required screenshots (3 device sizes)
- [ ] Verify privacy policy and support URLs are live
- [ ] Test demo flow on physical device
- [ ] Confirm server endpoints are responsive
- [ ] Validate Live Activity functionality

### **Technical Verification**
- [ ] Archive build successfully in Xcode
- [ ] No build warnings or errors
- [ ] App launches without crashes
- [ ] Microphone permission flow works
- [ ] Background recording functions properly
- [ ] Live Activity starts and stops correctly
- [ ] Transcription and analysis endpoints respond

### **Content Review**
- [ ] All text is proofread and professional
- [ ] Screenshots show realistic, appropriate content
- [ ] No placeholder text or Lorem ipsum
- [ ] "AI-generated" labels visible in relevant screens
- [ ] Privacy messaging is clear and accurate

### **Compliance**
- [ ] App Privacy questionnaire completed accurately  
- [ ] Age rating set to 4+ (No Objectionable Material)
- [ ] Export compliance: Standard encryption only
- [ ] Content rights: No third-party content used
- [ ] Review notes include clear testing instructions

### **Launch Day**
- [ ] Submit for App Review
- [ ] Set to "Manual Release" 
- [ ] Monitor App Store Connect for review status
- [ ] Prepare marketing materials for launch
- [ ] Plan social media announcements

---

## 📝 App Review Notes

### **Summary**
Sonora records short voice memos and (optionally) transcribes and analyzes them using our secure backend. The app supports background recording and provides a Live Activity for quick status and an action to stop recording.

### **Core Functionality**
- **Microphone access**: Required to record voice memos
- **Background audio**: Recording can continue when the app is backgrounded; the app declares UIBackgroundModes = audio and configures AVAudioSession appropriately
- **Live Activity**: Shows recording status and a stop button. Frequent Live Activity updates are disabled
- **Networking**: Audio files can be uploaded to our backend for transcription and analysis over HTTPS

### **Server Endpoints**
- **Base**: https://sonora.fly.dev
- **Transcription**: POST /transcribe (OpenAI Whisper)
- **Analysis**: POST /analyze (OpenAI GPT-4o-mini) — returns JSON with optional moderation metadata
- **Moderation**: POST /moderate (OpenAI moderation) — used to check AI outputs (e.g., transcripts) client-side

### **Privacy**
- No tracking. No third-party SDKs
- Audio recorded by the user may be uploaded to our backend for the explicit purpose of transcription and analysis initiated by the user. No personal identifiers are collected in-app
- A Privacy Policy link is provided in App Store Connect (we can supply on request)

### **Review Instructions (Optional)**

1) Launch the app and allow Microphone access when prompted
2) Tap the record button to start recording. Lock the device; recording continues in the background
3) Observe the Live Activity (and Dynamic Island on supported devices). Tap "Stop" or unlock the device and stop from the app
4) Open a memo and choose "Transcribe" to upload and receive a transcription. Optionally "Analyze" to see summarized insights

### **Notes**
- The app does not require App Groups. The Live Activity is managed via ActivityKit APIs and does not share files or preferences with the host app
- Network calls use standard HTTPS only; no ATS exceptions
- AI labeling and moderation: Transcription and analysis screens display an "AI-generated" label. If moderation flags content, a safety notice appears; the app does not present deceptive or harmful content without a warning

---

## 🚀 Quality & Compliance

### **Open Technical Risks Before Submission**

#### **Frequent Live Activity Updates**
- **Status**: Addressed by disabling frequent updates
- **Risk**: Low - Apple restricts "Frequent Updates" to narrow use cases

#### **App Group Entitlement**
- **Status**: Removed
- **Risk**: Low - Not required for current functionality

#### **Server Availability**
- **Status**: The transcription service at `sonora.fly.dev` must be reachable to exercise the feature during review
- **Risk**: Medium - Otherwise, provide clear in-app error handling (already present) and mention in Review Notes if the server is temporarily offline

#### **Privacy Manifest**
- **Status**: Not strictly required for current usage, but recommended to add proactively if you anticipate adding any Required Reason APIs
- **Risk**: Low - Current implementation doesn't require it

### **Quality and Stability Notes**

#### **Crash Safety**
- No obvious use of private APIs
- Error mapping is comprehensive
- Logging is verbose but acceptable

#### **Permissions**
- Microphone usage prompt text is present and user-friendly

#### **Offline Handling**
- Network errors are surfaced and mapped
- Transcription gracefully reports failures

#### **Tests**
- Unit/UI test targets exist
- No requirement to ship tests
- Consider a smoke test pass on-device for background recording + Live Activity start/stop

### **Assets and UI**

#### **App Icon**
- Uses Xcode single-size app icon (1024×1024) in the app asset catalog

#### **Launch Screen**
- Generated by Xcode (no storyboard required)

#### **iPad Support**
- `TARGETED_DEVICE_FAMILY = 1` (iPhone only)
- This is acceptable; you do not need to support iPad

#### **Live Activity Extension**
- Contains WidgetBundle + Live Activity views and assets
- Configured for iOS 17.6

---

## 📞 Contact Information for Review

**Developer**: [Your Name]  
**Email**: [Your Email]  
**Company**: [Your Company/Individual]  
**Phone**: [Your Phone] (Optional)  

**Demo Account**: Not required - core functionality available immediately  
**Special Instructions**: See Review Notes above for testing flow

---

## 🎯 Conclusion

Functionally, the app is submission-ready. Previously identified risks have been addressed: Live Activity frequent updates are disabled, and unused App Group entitlements were removed. 

**Key Requirements Before Submission**:
1. Create and host Privacy Policy, Terms of Use, and Support URLs
2. Capture screenshots for all required device sizes
3. Record demo video following the provided script
4. Ensure server endpoints are operational during review

**Estimated Time to Completion**: 4-6 hours (primarily screenshot creation and URL setup)

Ensure a Privacy Policy is supplied in App Store Connect and proceed to archive and submit.

---

*This consolidated document serves as the complete App Store reference for Sonora. All placeholders marked with brackets should be completed before submission.*
