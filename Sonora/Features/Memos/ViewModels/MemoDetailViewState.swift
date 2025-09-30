//
//  MemoDetailViewState.swift
//  Sonora
//
//  Consolidated state management for MemoDetailViewModel
//  Replaces 32 individual @Published properties with structured state
//

import Foundation
import SwiftUI

/// Consolidated state for MemoDetailView
/// Groups related properties into logical state structures for better maintainability
struct MemoDetailViewState: Equatable {

    // MARK: - Nested State Structures

    /// Audio playback state
    struct AudioState: Equatable {
        var isPlaying: Bool = false
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 0

        var playButtonIcon: String {
            isPlaying ? "pause.fill" : "play.fill"
        }

        var progressFraction: Double {
            guard duration > 0 else { return 0 }
            return min(1.0, max(0.0, currentTime / duration))
        }
    }

    /// Transcription processing state
    struct TranscriptionProcessingState: Equatable {
        var state: Sonora.TranscriptionState = .notStarted
        var progressPercent: Double?
        var progressStep: String?
        var moderationFlagged: Bool = false
        var moderationCategories: [String: Bool] = [:]
        var service: TranscriptionServiceType?

        var isCompleted: Bool {
            state.isCompleted
        }

        var isInProgress: Bool {
            state.isInProgress
        }

        var isFailed: Bool {
            state.isFailed
        }

        var serviceDisplayName: String? {
            service.map { _ in "Cloud" }
        }

        var serviceIconName: String? {
            service.map { _ in "cloud" }
        }
    }

    /// Analysis processing state
    struct AnalysisState: Equatable {
        var selectedMode: AnalysisMode?
        // Typed payload replacing Any-based result/envelope
        var payload: AnalysisResultPayload?
        var isAnalyzing: Bool = false
        var error: String?
        var cacheStatus: String?
        var performanceInfo: String?

        // Parallel Distill specific
        var isParallelDistillEnabled: Bool = true
        var distillProgress: DistillProgressUpdate?
        var partialDistillData: PartialDistillData?

        // Custom Equatable: intentionally ignore `payload`
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.selectedMode == rhs.selectedMode
            && lhs.isAnalyzing == rhs.isAnalyzing
            && lhs.error == rhs.error
            && lhs.cacheStatus == rhs.cacheStatus
            && lhs.performanceInfo == rhs.performanceInfo
            && lhs.isParallelDistillEnabled == rhs.isParallelDistillEnabled
            && lhs.distillProgress == rhs.distillProgress
            && lhs.partialDistillData == rhs.partialDistillData
        }
    }

    /// Language detection and display state
    struct LanguageState: Equatable {
        var detectedLanguage: String?
        var showNonEnglishBanner: Bool = false
        var bannerMessage: String = ""
        var bannerDismissedForMemo: [UUID: Bool] = [:]
    }

    /// Title editing state
    struct TitleEditingState: Equatable {
        var isRenaming: Bool = false
        var editedTitle: String = ""
        var currentMemoTitle: String = ""
    }

    /// Share functionality state
    struct ShareState: Equatable {
        var showShareSheet: Bool = false
        var audioEnabled: Bool = true
        var transcriptionEnabled: Bool = false
        var analysisEnabled: Bool = false
        var analysisSelectedTypes: Set<DomainAnalysisType> = []
        var isPreparingShare: Bool = false
    }

    /// Operation tracking state
    struct OperationState: Equatable {
        var activeOperations: [UUID] = []  // Just track operation IDs
        var memoOperationSummaries: [UUID] = []  // Just track operation IDs

        var hasActiveOperations: Bool {
            !activeOperations.isEmpty
        }
    }

    /// General UI state
    struct UIState: Equatable {
        var error: SonoraError?
        var isLoading: Bool = false
        // Deletion state for memo details
        var didDeleteMemo: Bool = false

    }

    // MARK: - State Properties

    var audio = AudioState()
    var transcription = TranscriptionProcessingState()
    var analysis = AnalysisState()
    var language = LanguageState()
    var titleEditing = TitleEditingState()
    var share = ShareState()
    var operations = OperationState()
    var ui = UIState()

    // MARK: - Convenience Computed Properties

    /// Whether transcription text is available and completed
    var hasCompletedTranscription: Bool {
        transcription.isCompleted
    }

    /// Whether any analysis has been completed
    var hasAnalysisAvailable: Bool {
        analysis.payload != nil
    }

    /// Whether there are any active operations
    var hasActiveOperations: Bool {
        operations.hasActiveOperations
    }
}

// MARK: - State Mutation Helpers

extension MemoDetailViewState {

    /// Reset all state to initial values (except persistent settings)
    mutating func reset() {
        audio = AudioState()
        transcription = TranscriptionProcessingState()
        analysis = AnalysisState()
        // Keep language.bannerDismissedForMemo as it's persistent
        language.detectedLanguage = nil
        language.showNonEnglishBanner = false
        language.bannerMessage = ""
        titleEditing = TitleEditingState()
        share = ShareState()
        operations = OperationState()
        ui = UIState()
    }

    /// Update transcription state with progress
    mutating func updateTranscriptionProgress(percent: Double?, step: String?) {
        transcription.progressPercent = percent
        transcription.progressStep = step
    }

    /// Update analysis progress
    mutating func updateAnalysisProgress(isAnalyzing: Bool, error: String? = nil) {
        analysis.isAnalyzing = isAnalyzing
        analysis.error = error
    }

    /// Set share options based on available content
    mutating func configureShareOptions(hasTranscription: Bool, hasAnalysis: Bool) {
        share.audioEnabled = true // Always available
        share.transcriptionEnabled = hasTranscription
        share.analysisEnabled = hasAnalysis
    }
}
