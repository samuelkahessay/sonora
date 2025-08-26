import Foundation

/// Adapter for converting between Analysis models (data layer) and DomainAnalysis models (domain layer)
/// Provides backward compatibility during the transition to Clean Architecture
struct AnalysisAdapter {
    
    // MARK: - AnalysisMode to DomainAnalysisType Conversion
    
    /// Converts AnalysisMode to DomainAnalysisType
    static func toDomain(_ mode: AnalysisMode) -> DomainAnalysisType {
        switch mode {
        case .tldr:
            return .summary
        case .analysis:
            return .keyPoints
        case .themes:
            return .themes
        case .todos:
            return .actionItems
        }
    }
    
    /// Converts DomainAnalysisType to AnalysisMode
    static func fromDomain(_ type: DomainAnalysisType) -> AnalysisMode {
        switch type {
        case .summary:
            return .tldr
        case .keyPoints:
            return .analysis
        case .themes:
            return .themes
        case .actionItems:
            return .todos
        }
    }
    
    // MARK: - Analysis Data to DomainAnalysisContent Conversion
    
    /// Converts TLDRData to DomainAnalysisContent
    static func toDomain(_ tldrData: TLDRData) -> DomainAnalysisContent {
        return DomainAnalysisContent(
            summary: tldrData.summary,
            keyPoints: tldrData.key_points,
            themes: [],
            actionItems: [],
            sentiment: nil,
            confidence: nil
        )
    }
    
    /// Converts AnalysisData to DomainAnalysisContent
    static func toDomain(_ analysisData: AnalysisData) -> DomainAnalysisContent {
        return DomainAnalysisContent(
            summary: analysisData.summary,
            keyPoints: analysisData.key_points,
            themes: [],
            actionItems: [],
            sentiment: nil,
            confidence: nil
        )
    }
    
    /// Converts ThemesData to DomainAnalysisContent
    static func toDomain(_ themesData: ThemesData) -> DomainAnalysisContent {
        let domainThemes = themesData.themes.map { theme in
            DomainTheme(
                name: theme.name,
                evidence: theme.evidence,
                confidence: nil
            )
        }
        
        return DomainAnalysisContent(
            summary: nil,
            keyPoints: [],
            themes: domainThemes,
            actionItems: [],
            sentiment: themesData.sentiment,
            confidence: nil
        )
    }
    
    /// Converts TodosData to DomainAnalysisContent
    static func toDomain(_ todosData: TodosData) -> DomainAnalysisContent {
        let domainActionItems = todosData.todos.map { todo in
            DomainActionItem(
                text: todo.text,
                priority: nil,
                dueDate: todo.dueDate,
                isCompleted: false
            )
        }
        
        return DomainAnalysisContent(
            summary: nil,
            keyPoints: [],
            themes: [],
            actionItems: domainActionItems,
            sentiment: nil,
            confidence: nil
        )
    }
    
    // MARK: - Analysis Envelope to DomainAnalysisResult Conversion
    
    /// Converts AnalyzeEnvelope<TLDRData> to DomainAnalysisResult
    static func toDomain(_ envelope: AnalyzeEnvelope<TLDRData>) -> DomainAnalysisResult {
        let metadata = DomainAnalysisMetadata(
            modelUsed: envelope.model,
            tokensConsumed: envelope.tokens.input + envelope.tokens.output,
            processingTimeMs: envelope.latency_ms,
            version: nil,
            parameters: [:]
        )
        
        return DomainAnalysisResult(
            type: toDomain(envelope.mode),
            status: .completed,
            content: toDomain(envelope.data),
            metadata: metadata
        )
    }
    
    /// Converts AnalyzeEnvelope<AnalysisData> to DomainAnalysisResult
    static func toDomain(_ envelope: AnalyzeEnvelope<AnalysisData>) -> DomainAnalysisResult {
        let metadata = DomainAnalysisMetadata(
            modelUsed: envelope.model,
            tokensConsumed: envelope.tokens.input + envelope.tokens.output,
            processingTimeMs: envelope.latency_ms,
            version: nil,
            parameters: [:]
        )
        
        return DomainAnalysisResult(
            type: toDomain(envelope.mode),
            status: .completed,
            content: toDomain(envelope.data),
            metadata: metadata
        )
    }
    
    /// Converts AnalyzeEnvelope<ThemesData> to DomainAnalysisResult
    static func toDomain(_ envelope: AnalyzeEnvelope<ThemesData>) -> DomainAnalysisResult {
        let metadata = DomainAnalysisMetadata(
            modelUsed: envelope.model,
            tokensConsumed: envelope.tokens.input + envelope.tokens.output,
            processingTimeMs: envelope.latency_ms,
            version: nil,
            parameters: [:]
        )
        
        return DomainAnalysisResult(
            type: toDomain(envelope.mode),
            status: .completed,
            content: toDomain(envelope.data),
            metadata: metadata
        )
    }
    
    /// Converts AnalyzeEnvelope<TodosData> to DomainAnalysisResult
    static func toDomain(_ envelope: AnalyzeEnvelope<TodosData>) -> DomainAnalysisResult {
        let metadata = DomainAnalysisMetadata(
            modelUsed: envelope.model,
            tokensConsumed: envelope.tokens.input + envelope.tokens.output,
            processingTimeMs: envelope.latency_ms,
            version: nil,
            parameters: [:]
        )
        
        return DomainAnalysisResult(
            type: toDomain(envelope.mode),
            status: .completed,
            content: toDomain(envelope.data),
            metadata: metadata
        )
    }
}