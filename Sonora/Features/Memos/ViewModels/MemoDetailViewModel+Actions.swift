import Foundation
import SwiftUI

// MARK: - User Actions & Operations
extension MemoDetailViewModel {
    /// Start transcription for the current memo
    func startTranscription() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Starting transcription for: \(memo.filename)")
        Task {
            do {
                try await startTranscriptionUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Retry transcription for the current memo
    func retryTranscription() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Retrying transcription for: \(memo.filename)")
        Task {
            do {
                try await retryTranscriptionUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Play or pause the current memo
    func playMemo() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Playing memo: \(memo.filename)")
        Task {
            do {
                try await playMemoUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Seek within current memo playback
    func seek(to time: TimeInterval) {
        guard let memo = currentMemo else { return }
        memoRepository.seek(to: time, for: memo)
    }

    /// Skip forward/backward by delta seconds
    func skip(by delta: TimeInterval) {
        let cur = currentTime
        let dur = max(totalDuration, 0)
        guard dur > 0 else { return }
        let target = min(max(cur + delta, 0), dur)
        // If target equals current (already at boundary), no-op
        if abs(target - cur) < 0.01 {
            HapticManager.shared.playLightImpact()
            return
        }
        seek(to: target)
    }

    /// Delete the current memo with cascading cleanup
    func deleteCurrentMemo() {
        guard let memo = currentMemo else { return }
        print("🗑️ MemoDetailViewModel: Deleting memo: \(memo.filename)")
        isLoading = true
        Task {
            do {
                try await deleteMemoUseCase.execute(memo: memo)
                await MainActor.run {
                    self.isLoading = false
                    self.state.ui.didDeleteMemo = true
                    HapticManager.shared.playDeletionFeedback()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Perform analysis with the specified mode
    func performAnalysis(mode: AnalysisMode, transcript: String) {
        guard let memo = currentMemo else {
            analysisError = "No memo selected for analysis"
            self.error = .analysisInvalidInput("No memo selected for analysis")
            return
        }

        print("📝 MemoDetailViewModel: Starting \(mode.displayName) analysis for memo \(memo.id)")

        isAnalyzing = true
        analysisError = nil
        selectedAnalysisMode = mode
        analysisPayload = nil
        analysisCacheStatus = "Checking cache..."
        analysisPerformanceInfo = nil

        Task {
            do {
                switch mode {
                case .distill:
                    // Route based on subscription tier
                    // Refresh subscription status to ensure we have the latest entitlements
                    // This prevents routing to Lite Distill when user is actually Pro
                    await storeKitService.refreshEntitlements()
                    let isPro = storeKitService.isPro
                    print("📝 MemoDetailViewModel: Distill routing - isPro: \(isPro)")
                    if isPro {
                        print("📝 MemoDetailViewModel: Routing to Distill (Pro with Pro modes)")
                        await performDistill(transcript: transcript, memoId: memo.id)
                    } else {
                        print("📝 MemoDetailViewModel: Routing to Lite Distill (Free tier)")
                        await performLiteDistill(transcript: transcript, memoId: memo.id)
                    }

                case .distillSummary, .distillActions, .distillThemes, .distillReflection:
                    await performDistill(transcript: transcript, memoId: memo.id)

                case .liteDistill:
                    // Lite Distill should be handled by .distill case above based on subscription tier
                    // This case exists for completeness but shouldn't be directly invoked
                    await performLiteDistill(transcript: transcript, memoId: memo.id)

                case .events:
                    let detection = try await DIContainer.shared.detectEventsAndRemindersUseCase().execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        let data = detection.events ?? EventsData(events: [])
                        analysisPayload = .events(data)
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Events detection completed")
                    }

                case .reminders:
                    let detection = try await DIContainer.shared.detectEventsAndRemindersUseCase().execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        let data = detection.reminders ?? RemindersData(reminders: [])
                        analysisPayload = .reminders(data)
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Reminders detection completed")
                    }

                case .cognitiveClarityCBT, .philosophicalEchoes, .valuesRecognition:
                    // Pro-tier modes are embedded in Distill analysis, shouldn't be called directly
                    Logger.shared.warning("Pro-tier mode called directly, falling back to Distill", category: .analysis)
                    await performDistill(transcript: transcript, memoId: memo.id)
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                    self.error = ErrorMapping.mapError(error)
                    isAnalyzing = false
                }
            }
        }
    }

    /// Cancel specific operation by ID
    func cancelOperation(_ operationId: UUID) {
        Task {
            await operationCoordinator.cancelOperation(operationId)
            await updateOperationStatus() // Refresh status after cancellation
        }
    }

    /// Cancel all operations for current memo
    func cancelAllOperations() {
        guard let memo = currentMemo else { return }

        Task {
            let cancelledCount = await operationCoordinator.cancelAllOperations(for: memo.id)
            print("🚫 MemoDetailViewModel: Cancelled \(cancelledCount) operations for memo: \(memo.filename)")
            await updateOperationStatus()
        }
    }
}
