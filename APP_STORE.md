Sonora App Store Readiness Report

Summary

- Purpose: Voice memo recording with background recording, playback, and server-side transcription. Optional Live Activity shows recording state and a stop shortcut.
- Platforms: iOS (iPhone only).
- Minimum OS: iOS 17.6 (main app and Live Activity extension).
- Bundle IDs:
  - App: com.samuelkahessay.Sonora
  - Live Activity Extension: com.samuelkahessay.Sonora.SonoraLiveActivity

Key Features Implemented

- Recording: Uses `AVAudioSession` (.playAndRecord) and `AVAudioRecorder` with UIBackgroundModes `audio` to continue recording when backgrounded.
- Playback: Basic playback via `AVAudioPlayer`.
- Transcription/Analysis: Uploads audio to `https://sonora.fly.dev/transcribe` (OpenAI Whisper) and analyzes transcripts via `https://sonora.fly.dev/analyze` (OpenAI GPT-4o-mini). All AI outputs are labeled in-app as “AI-generated,” and content safeguards (moderation) are applied to reduce harmful or deceptive content.
- Live Activities: ActivityKit Live Activity and Dynamic Island UI for recording state; deep link to stop recording (`sonora://stopRecording`).
- MVVM + Clean Architecture: Repositories + use cases; DI container; event bus; main actor isolation fixes.

Capabilities, Entitlements, and Info.plist

- Permissions (Info.plist):
  - `NSMicrophoneUsageDescription`: present and descriptive.
  - `UIBackgroundModes`: contains `audio` (required for background recording).
  - `NSSupportsLiveActivities`: YES (main app).
- `NSSupportsLiveActivitiesFrequentUpdates`: NO (disabled to align with App Review guidance).
  - CFBundleURLTypes includes custom scheme `sonora` (used by Live Activity link to stop recording).
- Entitlements:
  - App: No App Groups (removed; not required for current functionality).
  - Live Activity extension: No App Groups (removed; not required).

Privacy and Data Practices (App Store “App Privacy”)

- Microphone Audio: The app records user audio and (when transcription is requested) uploads the audio file to a backend for processing.
  - Data type: “User Content > Audio Data”.
  - Purpose: “App Functionality” (transcription feature).
  - Linked to user: Typically “No” (unless you add user accounts or link audio to identity server-side).
  - Tracking: None.
- Network: Uses HTTPS only. No ATS exceptions are configured or required.
- Pasteboard: The app writes to the pasteboard to copy transcript text (no reading). This is not a Required Reason API use case, but call it out in review notes to preempt questions.
- AI Disclosures: The app discloses AI functionality in Settings (AI Features card). Transcripts and analysis are machine-generated and may contain errors. We label AI-generated content and show a safety notice if content is flagged by moderation.
- Required Reason APIs / Privacy Manifests:
  - The code uses standard APIs (URLSession, FileManager). If you add any “Required Reason API” usage (e.g., reading pasteboard contents, disk space, system boot time, etc.), include a `PrivacyInfo.xcprivacy` manifest with proper reasons before submission. For now, a manifest is optional but recommended for forward-compatibility.
  - Policy URLs: Provide a Privacy Policy URL in App Store Connect (recommended since audio leaves device for transcription).

App Privacy Labels Mapping (for App Store Connect)

| Data Type                          | Collected | Purpose            | Linked to User | Tracking |
|------------------------------------|-----------|--------------------|----------------|----------|
| User Content > Audio Data (Voice)  | Yes       | App Functionality  | No             | No       |
| User Content > Other User Content (Transcripts, text derived from audio) | Yes | App Functionality | No | No |
| Diagnostics (Crash data)           | No        | —                  | —              | —        |
| Usage Data (Product interaction)   | No        | —                  | —              | —        |
| Identifiers (Device/User)          | No        | —                  | —              | —        |
| Contact Info                       | No        | —                  | —              | —        |
| Location                           | No        | —                  | —              | —        |

Notes
- Audio recording happens on-device; when the user initiates transcription/analysis, the audio file is uploaded to the Sonora backend strictly to perform that feature (App Functionality). No advertising/marketing use.
- Transcripts (text) are derived from the user’s audio; treated as User Content; used only for App Functionality.
- No user accounts; we do not link data to identity. No third-party tracking SDKs.
- Logging is local (console) only; no crash reporting SDK is integrated. If a crash reporting SDK is added later, update this table accordingly.

xcprivacy (Privacy Manifest) Review

- Current third-party SDKs: ZIPFoundation (SPM) only.
  - Purpose: ZIP archive creation for user export.
  - Required Reason APIs: None (standard file I/O only). No manifest entries required.
- Project manifest: `Sonora/PrivacyInfo.xcprivacy` is present and currently minimal (no tracking, no accessed APIs). This is acceptable with the current codebase.
- If later you integrate SDKs that access Required Reason APIs (e.g., clipboard read, disk space, file timestamping beyond normal use), add the appropriate entries to `PrivacyInfo.xcprivacy` and document them here.

Test Plan (Privacy)

1) Verify Settings shows Privacy Policy + Terms links (real URLs in release).
2) Export Data: select Memos/Transcripts/Analysis; generate ZIP; confirm contents include selected folders and settings/settings.json; share via iOS share sheet.
3) Delete All Data: confirm prompt warning; accept; verify Memos tab is empty and export contains no user content.
4) Confirm App Privacy answers in App Store Connect match the mapping table above.

Live Activities Compliance

- Live Activity frequent updates: Disabled. Apple restricts “Frequent Updates” to narrow use cases (e.g., live sports, ridesharing). A recording timer generally does not qualify; standard update cadence is appropriate.

Background Behavior

- Audio background mode is correctly declared. Recording continues in background with a properly configured audio session; UIBackgroundTask is also used for safety.
- No background Bluetooth, location, or other background modes are declared (good).

Assets and UI

- App Icon: Uses Xcode single-size app icon (1024×1024) in the app asset catalog.
- Launch Screen: Generated by Xcode (no storyboard required).
- iPad Support: `TARGETED_DEVICE_FAMILY = 1` (iPhone only). This is acceptable; you do not need to support iPad.
- Live Activity Extension: Contains WidgetBundle + Live Activity views and assets. Configured for iOS 17.6.

Build and Signing

- Deployment Target: iOS 17.6 for all targets.
- Signing: Automatic. Ensure the following before archive:
  - App ID includes the “Live Activities” capability.
  - App Groups are not used; entitlements were removed to simplify signing.
  - Prepare an App Store Distribution profile and set the app’s team to match.

Export Compliance

- Uses standard TLS/HTTPS. For export compliance, answer “Yes” to using encryption and indicate only standard encryption, which qualifies for the exemption. No proprietary cryptography in code.

Open Technical Risks Before Submission

- Frequent Live Activity Updates: Addressed by disabling frequent updates.
- App Group Entitlement: Removed.
- Server Availability: The transcription service at `sonora.fly.dev` must be reachable to exercise the feature during review; otherwise, provide clear in-app error handling (already present) and mention in Review Notes if the server is temporarily offline.
- Privacy Manifest: Not strictly required for current usage, but recommended to add proactively if you anticipate adding any Required Reason APIs.

Quality and Stability Notes

- Crash safety: No obvious use of private APIs. Error mapping is comprehensive. Logging is verbose but acceptable.
- Permissions: Microphone usage prompt text is present and user-friendly.
- Offline handling: Network errors are surfaced and mapped; transcription gracefully reports failures.
- Tests: Unit/UI test targets exist; no requirement to ship tests. Consider a smoke test pass on-device for background recording + Live Activity start/stop.

Submission Checklist

- [x] Disable `NSSupportsLiveActivitiesFrequentUpdates`.
- [x] Remove App Group entitlements (not required for current features).
- [ ] Confirm Privacy Policy URL and support URL in App Store Connect (audio leaves device for transcription).
- [ ] Confirm AI disclosure text is visible in Settings and that “AI-generated” labels appear on transcription and analysis views.
- [ ] Review “App Privacy” questionnaire: declare upload of user audio for App Functionality; no tracking.
- [ ] Confirm backend availability (sonora.fly.dev) during review window.
- [ ] Verify archive and code sign (Release, Distribution signing) and that Live Activity capability is enabled.
- [ ] Optional: Add a `PrivacyInfo.xcprivacy` manifest (future-proofing) if you plan to read pasteboard or use other Required Reason APIs.

Conclusion

Functionally, the app is submission-ready. Previously identified risks have been addressed: Live Activity frequent updates are disabled, and unused App Group entitlements were removed. Ensure a Privacy Policy is supplied in App Store Connect and proceed to archive and submit.
