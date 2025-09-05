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
        
        var playButtonIcon: String {
            isPlaying ? "pause.fill" : "play.fill"
        }
    }
    
    /// Transcription processing state
    struct TranscriptionProcessingState: Equatable {
        var state: Sonora.TranscriptionState = .notStarted
        var progressPercent: Double? = nil
        var progressStep: String? = nil
        var moderationFlagged: Bool = false
        var moderationCategories: [String: Bool] = [:]
        
        var isCompleted: Bool {
            state.isCompleted
        }
        
        var isInProgress: Bool {
            state.isInProgress
        }
        
        var isFailed: Bool {
            state.isFailed
        }
    }
    
    /// Analysis processing state
    struct AnalysisState: Equatable {
        var selectedMode: AnalysisMode? = nil
        var result: AnyHashable? = nil
        var envelope: AnyHashable? = nil
        var isAnalyzing: Bool = false
        var error: String? = nil
        var cacheStatus: String? = nil
        var performanceInfo: String? = nil
        
        // Parallel Distill specific
        var isParallelDistillEnabled: Bool = true
        var distillProgress: DistillProgressUpdate? = nil
        var partialDistillData: PartialDistillData? = nil
        
    }
    
    /// Language detection and display state
    struct LanguageState: Equatable {
        var detectedLanguage: String? = nil
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
        var error: SonoraError? = nil
        var isLoading: Bool = false
        
    }
    
    // MARK: - State Properties
    
    var audio: AudioState = AudioState()
    var transcription: TranscriptionProcessingState = TranscriptionProcessingState()
    var analysis: AnalysisState = AnalysisState()
    var language: LanguageState = LanguageState()
    var titleEditing: TitleEditingState = TitleEditingState()
    var share: ShareState = ShareState()
    var operations: OperationState = OperationState()
    var ui: UIState = UIState()
    
    // MARK: - Convenience Computed Properties
    
    /// Whether transcription text is available and completed
    var hasCompletedTranscription: Bool {
        transcription.isCompleted
    }
    
    /// Whether any analysis has been completed
    var hasAnalysisAvailable: Bool {
        analysis.result != nil
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