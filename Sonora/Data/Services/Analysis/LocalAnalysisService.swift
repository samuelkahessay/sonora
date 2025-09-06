import Foundation
import UIKit
@preconcurrency import LLM

@MainActor
final class LocalAnalysisService: ObservableObject, AnalysisServiceProtocol {
    
    private var llm: LLM?
    private var currentLoadedModel: LocalModel?
    private let logger = Logger.shared
    
    /// Currently selected model from user settings
    private var selectedModel: LocalModel {
        let modelId = AppConfiguration.shared.selectedLocalModel
        return LocalModel(rawValue: modelId) ?? LocalModel.defaultModel
    }
    
    // Keep model loaded until app backgrounds
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Free memory when app backgrounds
        llm = nil
        currentLoadedModel = nil
        logger.debug("Local AI model unloaded on background")
    }
    
    private func ensureModelLoaded() async throws {
        let targetModel = selectedModel

        // If already loaded for this model, keep using it
        if llm != nil && currentLoadedModel == targetModel { return }

        // If model is likely too large for this device, skip loading and fall back preemptively
        if !isModelViableOnDevice(targetModel) {
            logger.warning("Selected model appears too large for device memory; will try smaller models")
        } else {
            // Try to load target model; if it fails (e.g., memory), fall back
            if try await tryLoadModel(targetModel) { return }
        }

        // Fallback chain: prefer downloaded, compatible models from higher to lower tiers
        // Prefer smaller models first to avoid memory pressure on mobile devices
        let fallbackOrder: [LocalModel] = [
            .llama32_3B, .gemma2_2B, .qwen25_3B, .llama32_1B, .phi4_mini, .tinyllama_1B
        ]
        for candidate in fallbackOrder {
            if candidate == targetModel { continue }
            if try await tryLoadModel(candidate) {
                logger.warning("Falling back to \(candidate.displayName) after load failure of \(targetModel.displayName)")
                return
            }
        }

        // No viable model could be loaded
        throw AnalysisError.modelLoadFailed
    }

    private func tryLoadModel(_ model: LocalModel) async throws -> Bool {
        // Validate device + file present
        guard model.isDeviceCompatible else { return false }
        guard model.isDownloaded else { return false }

        // Unload any previous
        if currentLoadedModel != model { llm = nil; currentLoadedModel = nil }

        // Log file info prior to load
        let path = model.localPath.path
        var sizeInfo = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? NSNumber {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            sizeInfo = formatter.string(fromByteCount: size.int64Value)
        }
        logger.info("Loading \(model.displayName) model (\(sizeInfo))...")
        llm = LLM(
            from: model.localPath,
            topP: 0.95,
            temp: 0.7,
            historyLimit: 2,
            maxTokenCount: 512
        )
        guard llm != nil else { return false }
        currentLoadedModel = model
        logger.info("\(model.displayName) model loaded successfully")
        return true
    }
    
    // MARK: - Memory Viability Heuristic
    
    /// Estimate whether a model's on-disk footprint is likely to exceed practical memory limits for the current device.
    private func isModelViableOnDevice(_ model: LocalModel) -> Bool {
        let estRAM = ProcessInfo.processInfo.physicalMemory // bytes (approx)
        // Heuristic memory budget for weights + runtime (KV cache, context): ~45% of total RAM
        // Debugger attached reduces headroom; be conservative.
        let budget = UInt64(Double(estRAM) * 0.45)
        let modelBytes = totalModelBytesOnDisk(model)
        logger.debug("Memory check: estRAM=\(ByteCountFormatter.string(fromByteCount: Int64(estRAM), countStyle: .memory)), budget=\(ByteCountFormatter.string(fromByteCount: Int64(budget), countStyle: .memory)), model=\(ByteCountFormatter.string(fromByteCount: Int64(modelBytes), countStyle: .memory))")
        return modelBytes <= budget
    }
    
    /// Sum sizes of model GGUF files (handles shards when primary is 00001-of-NN)
    private func totalModelBytesOnDisk(_ model: LocalModel) -> UInt64 {
        let primary = model.localPath.lastPathComponent.lowercased()
        let dir = model.localPath.deletingLastPathComponent()
        do {
            if primary.contains("-00001-of-") {
                // Sum all parts by pattern prefix
                let prefix = primary.replacingOccurrences(of: "-00001-of-", with: "-")
                let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
                let ggufs = files.filter { $0.lowercased().hasSuffix(".gguf") && $0.lowercased().contains(prefix.split(separator: "-gguf").first ?? "") }
                var total: UInt64 = 0
                for f in ggufs {
                    let p = dir.appendingPathComponent(f).path
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: p), let s = attrs[.size] as? UInt64 { total += s }
                }
                return total
            } else {
                let attrs = try FileManager.default.attributesOfItem(atPath: model.localPath.path)
                return (attrs[.size] as? UInt64) ?? 0
            }
        } catch {
            return 0
        }
    }
    
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type
    ) async throws -> AnalyzeEnvelope<T> {
        
        let startTime = Date()
        
        // Basic input validation
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.invalidInput("Empty transcript")
        }
        
        // Ensure model is loaded (cached after first use)
        try await ensureModelLoaded()
        
        guard let llmInstance = llm else {
            throw AnalysisError.modelNotAvailable
        }
        
        // Enhanced structured prompt
        let prompt = buildStructuredPrompt(mode: mode, transcript: transcript)
        
        // Get completion - call directly, preconcurrency import handles Sendable warnings
        let output = await llmInstance.getCompletion(from: prompt)
        
        // Parse structured output
        let parsedData = try parseStructuredOutput(output, mode: mode, responseType: responseType)
        
        let duration = Date().timeIntervalSince(startTime)
        
        return AnalyzeEnvelope(
            mode: mode,
            data: parsedData,
            model: currentLoadedModel?.rawValue ?? "local-llm",
            tokens: TokenUsage(input: 0, output: 0),
            latency_ms: Int(duration * 1000),
            moderation: nil
        )
    }
    
    // MARK: - Parallel Distill Analysis (Local)
    
    /// Parallel implementation of Distill analysis for local models
    /// Executes 4 component analyses concurrently to match cloud performance
    private func analyzeDistillParallel(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        let startTime = Date()
        
        // Basic input validation
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.invalidInput("Empty transcript")
        }
        
        // Ensure model is loaded (cached after first use)
        try await ensureModelLoaded()
        
        guard let llmInstance = llm else {
            throw AnalysisError.modelNotAvailable
        }
        
        // Component modes matching cloud implementation
        let componentModes: [AnalysisMode] = [.distillSummary, .distillActions, .distillThemes, .distillReflection]
        
        // Execute all components in parallel using TaskGroup
        var partialData = PartialDistillData()
        var combinedLatency = 0
        
        try await withThrowingTaskGroup(of: (AnalysisMode, String, Int).self) { group in
            
            // Add tasks for each component
            for mode in componentModes {
                // Build prompt outside the task group to avoid async issues
                let prompt = buildComponentPrompt(mode: mode, transcript: transcript)
                
                group.addTask {
                    let componentStartTime = Date()
                    
                    // Execute the component analysis
                    let output = await llmInstance.getCompletion(from: prompt)
                    
                    let componentDuration = Date().timeIntervalSince(componentStartTime)
                    return (mode, output, Int(componentDuration * 1000))
                }
            }
            
            // Collect results as they complete
            for try await (mode, output, latency) in group {
                combinedLatency = max(combinedLatency, latency) // Use max since parallel
                
                // Parse component output and update partial data
                try updatePartialDataFromOutput(&partialData, mode: mode, output: output)
                
                logger.debug("Local component \(mode.rawValue) completed in \(latency)ms", 
                           category: .analysis)
            }
        }
        
        // Combine results into final DistillData
        guard let finalData = partialData.toDistillData() else {
            logger.error("Failed to combine parallel local component results", 
                        category: .analysis, error: nil)
            throw AnalysisError.parsingFailed("Failed to combine parallel component results")
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        logger.info("Local parallel distill analysis completed in \(Int(totalDuration * 1000))ms", 
                   category: .analysis)
        
        return AnalyzeEnvelope(
            mode: .distill,
            data: finalData,
            model: currentLoadedModel?.rawValue ?? "local-llm",
            tokens: TokenUsage(input: 0, output: 0),
            latency_ms: combinedLatency,
            moderation: nil
        )
    }
    
    // Required protocol methods
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        // Use parallel processing for distill mode to match cloud implementation
        return try await analyzeDistillParallel(transcript: transcript)
    }
    
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> {
        return try await analyze(mode: .analysis, transcript: transcript, responseType: AnalysisData.self)
    }
    
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> {
        return try await analyze(mode: .themes, transcript: transcript, responseType: ThemesData.self)
    }
    
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> {
        return try await analyze(mode: .todos, transcript: transcript, responseType: TodosData.self)
    }
    
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        return try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self)
    }
    
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        return try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self)
    }
    
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        return try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self)
    }
    
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        return try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self)
    }
    
    // MARK: - Enhanced Structured Prompts
    
    private func buildStructuredPrompt(mode: AnalysisMode, transcript: String) -> String {
        // Truncate if too long, but preserve more content for better analysis
        let maxLength = 1200
        let truncated = transcript.count > maxLength 
            ? String(transcript.prefix(maxLength)) + "..."
            : transcript
        
        switch mode {
        case .distill, .distillSummary:
            return """
            You are an executive assistant analyzing a voice memo for a busy professional.
            
            Voice memo transcript:
            "\(truncated)"
            
            Create a comprehensive analysis with these exact components:
            1. Summary: Write 2-3 sentences capturing the main message and purpose
            2. Action items: Extract specific tasks mentioned (write "No clear actions" if none)
            3. Key themes: Identify 2-4 main topics or areas discussed
            4. Reflection questions: Suggest 2 thoughtful follow-up questions
            
            Format your response exactly like this:
            SUMMARY: [Your 2-3 sentence summary focusing on key insights and outcomes]
            ACTIONS: 
            - [Action item 1 with priority: High/Medium/Low]
            - [Action item 2 with priority: High/Medium/Low]
            THEMES: [Theme 1] | [Theme 2] | [Theme 3]
            QUESTIONS: 
            - [Thoughtful question to clarify next steps?]
            - [Question to explore implications or decisions?]
            """
            
        case .analysis:
            return """
            You are a business analyst reviewing meeting notes or discussion content.
            
            Transcript to analyze:
            "\(truncated)"
            
            Provide structured analysis in this exact format:
            OVERVIEW: [One clear sentence summarizing the main point or outcome]
            KEY POINTS:
            1. [Most important insight, decision, or information]
            2. [Second most important point with context]  
            3. [Third key point or supporting detail]
            4. [Additional insight if relevant]
            5. [Final point or implication]
            
            Focus on actionable insights and clear takeaways.
            """
            
        case .themes, .distillThemes:
            return """
            You are a content strategist identifying key themes in a discussion.
            
            Transcript to analyze:
            "\(truncated)"
            
            Identify themes in order of prominence:
            MAIN THEMES:
            1. [Primary theme]: [Brief supporting evidence or context from transcript]
            2. [Secondary theme]: [What was discussed about this topic]  
            3. [Additional theme]: [Key details or examples mentioned]
            4. [Minor theme if present]: [Brief context]
            
            OVERALL SENTIMENT: [Positive/Neutral/Mixed/Negative - based on tone and content]
            CONTEXT: [One sentence about the type of discussion this appears to be]
            """
            
        case .todos, .distillActions:
            return """
            You are a task manager extracting actionable items from a voice memo.
            
            Transcript:
            "\(truncated)"
            
            Instructions:
            - Only include explicitly mentioned tasks, commitments, or next steps
            - Assess priority based on urgency words (ASAP, urgent, soon = High; important, should = Medium; sometime, eventually = Low)
            - If no clear tasks exist, respond with "NO TASKS FOUND"
            
            Format exactly like this:
            TASKS:
            [ ] [Clear, actionable task description] - Priority: High - [Context if helpful]
            [ ] [Another specific task] - Priority: Medium - [When or why mentioned]
            [ ] [Third task if present] - Priority: Low - [Additional context]
            
            If no actionable tasks were mentioned: NO TASKS FOUND
            """
            
        case .distillReflection:
            return """
            You are a thoughtful executive coach helping someone reflect on their ideas.
            
            Based on this voice memo:
            "\(truncated)"
            
            Generate insightful coaching questions that help deepen thinking:
            REFLECTION QUESTIONS:
            1. [Question that challenges assumptions or explores alternatives?]
            2. [Question about implementation, timeline, or resources needed?]
            3. [Question about potential impact, risks, or stakeholders affected?]
            
            Make questions specific to the content discussed, not generic coaching questions.
            """
            
        case .events:
            return """
            You are an AI assistant that extracts calendar events from voice memos.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Extract any mentioned events, meetings, appointments, or scheduled activities.
            Look for dates, times, locations, and participants.
            
            Format your response exactly like this:
            EVENTS:
            Event: [Event title/description]
            Date: [Date if mentioned, or "Not specified"]
            Time: [Time if mentioned, or "Not specified"] 
            Location: [Location if mentioned, or "Not specified"]
            Participants: [People mentioned, or "Not specified"]
            ---
            [Repeat for additional events]
            
            If no events found: NO EVENTS DETECTED
            """
            
        case .reminders:
            return """
            You are an AI assistant that extracts reminders and tasks from voice memos.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Extract any mentioned tasks, reminders, things to remember, or action items.
            Assess priority based on language used (urgent words = High, should/need = Medium, maybe/sometime = Low).
            
            Format your response exactly like this:
            REMINDERS:
            Task: [Clear, actionable reminder description]
            Due: [Due date if mentioned, or "No due date"]
            Priority: [High/Medium/Low based on urgency indicated]
            ---
            [Repeat for additional reminders]
            
            If no reminders found: NO REMINDERS DETECTED
            """
            
        @unknown default:
            // Fallback for any future modes that may be added
            return "Analyze this content: \(truncated)"
        }
    }
    
    // MARK: - Component-Specific Prompts for Parallel Execution
    
    /// Build focused prompts for individual distill components
    private func buildComponentPrompt(mode: AnalysisMode, transcript: String) -> String {
        let maxLength = 1200
        let truncated = transcript.count > maxLength 
            ? String(transcript.prefix(maxLength)) + "..."
            : transcript
        
        switch mode {
        case .distillSummary:
            return """
            You are an executive assistant creating a brief overview.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Create a clear, concise 2-3 sentence summary capturing the main message and purpose.
            Focus on the key outcome, decision, or insight from this voice memo.
            
            SUMMARY: [Your 2-3 sentence overview here]
            """
            
        case .distillActions:
            return """
            You are a task manager extracting actionable items.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Extract specific tasks, commitments, or next steps mentioned.
            Assess priority based on urgency indicators (urgent/ASAP = High, important/should = Medium, eventually/sometime = Low).
            
            ACTIONS:
            - [Action item 1] - Priority: High
            - [Action item 2] - Priority: Medium
            
            If no clear actions: NO ACTIONS FOUND
            """
            
        case .distillThemes:
            return """
            You are a content analyst identifying key themes.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Identify 2-4 main topics, themes, or subject areas discussed.
            List them in order of prominence or time spent discussing.
            
            THEMES: [Theme 1] | [Theme 2] | [Theme 3] | [Theme 4]
            """
            
        case .distillReflection:
            return """
            You are a thoughtful coach generating reflection questions.
            
            Voice memo transcript:
            "\(truncated)"
            
            Task: Create 2-3 insightful questions to help deepen thinking about the content discussed.
            Make questions specific to the topics mentioned, not generic.
            
            QUESTIONS:
            - [Specific question about next steps or implications?]
            - [Question exploring alternatives or deeper considerations?]
            - [Follow-up question for clarity or action planning?]
            """
            
        default:
            return "Analyze this content: \(truncated)"
        }
    }
    
    /// Update partial data from component output
    private func updatePartialDataFromOutput(_ partialData: inout PartialDistillData, mode: AnalysisMode, output: String) throws {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        switch mode {
        case .distillSummary:
            for line in lines {
                if line.hasPrefix("SUMMARY:") {
                    partialData.summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            // Fallback if no SUMMARY: found
            if partialData.summary == nil {
                partialData.summary = lines.first ?? "Summary generated"
            }
            
        case .distillActions:
            var actions: [DistillData.ActionItem] = []
            
            if !output.contains("NO ACTIONS FOUND") {
                for line in lines {
                    if line.hasPrefix("-") {
                        let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                        let priority = extractPriority(from: content)
                        let cleanText = cleanActionText(content)
                        if !cleanText.isEmpty {
                            actions.append(DistillData.ActionItem(text: cleanText, priority: priority))
                        }
                    }
                }
            }
            partialData.actionItems = actions
            
        case .distillThemes:
            for line in lines {
                if line.hasPrefix("THEMES:") {
                    let themeText = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    let themes = themeText.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    partialData.keyThemes = themes.isEmpty ? ["General discussion"] : themes
                    break
                }
            }
            // Fallback
            if partialData.keyThemes == nil {
                partialData.keyThemes = ["General discussion"]
            }
            
        case .distillReflection:
            var questions: [String] = []
            
            var inQuestions = false
            for line in lines {
                if line == "QUESTIONS:" {
                    inQuestions = true
                    continue
                }
                if inQuestions && line.hasPrefix("-") {
                    let question = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                    if !question.isEmpty {
                        questions.append(question)
                    }
                }
            }
            
            if questions.isEmpty {
                questions = ["What are the key next steps?", "How does this align with current priorities?"]
            }
            partialData.reflectionQuestions = questions
            
        default:
            throw AnalysisError.parsingFailed("Unsupported component mode: \(mode)")
        }
    }
    
    // MARK: - Enhanced Structured Output Parsing
    
    private func parseStructuredOutput<T: Codable>(_ output: String, mode: AnalysisMode, responseType: T.Type) throws -> T {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if responseType == DistillData.self {
            var summary = ""
            var actionItems: [DistillData.ActionItem] = []
            var themes: [String] = []
            var questions: [String] = []
            
            var currentSection = ""
            
            for line in lines {
                if line.hasPrefix("SUMMARY:") {
                    summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    currentSection = "summary"
                } else if line == "ACTIONS:" {
                    currentSection = "actions"
                } else if line.hasPrefix("THEMES:") {
                    let themeText = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    themes = themeText.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    currentSection = "themes"
                } else if line == "QUESTIONS:" {
                    currentSection = "questions"
                } else if line.hasPrefix("-") {
                    let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                    if currentSection == "actions" {
                        let priority = extractPriority(from: content)
                        let cleanText = cleanActionText(content)
                        if !cleanText.isEmpty && !cleanText.lowercased().contains("no clear actions") {
                            actionItems.append(DistillData.ActionItem(text: cleanText, priority: priority))
                        }
                    } else if currentSection == "questions" {
                        questions.append(content)
                    }
                }
            }
            
            // Fallbacks for missing data
            if summary.isEmpty {
                summary = lines.first(where: { !$0.hasPrefix("SUMMARY:") && !$0.hasPrefix("ACTIONS:") && !$0.hasPrefix("THEMES:") && !$0.hasPrefix("QUESTIONS:") && !$0.hasPrefix("-") }) ?? "Voice memo analyzed"
            }
            
            if themes.isEmpty {
                themes = ["General discussion"]
            }
            
            if questions.isEmpty {
                questions = ["What are the next steps?", "What resources might be needed?"]
            }
            
            return DistillData(
                summary: summary,
                action_items: actionItems.isEmpty ? nil : actionItems,
                key_themes: themes,
                reflection_questions: questions
            ) as! T
        }
        
        if responseType == AnalysisData.self {
            var summary = ""
            var keyPoints: [String] = []
            
            for line in lines {
                if line.hasPrefix("OVERVIEW:") {
                    summary = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                } else if line.starts(with: /\d+\./) {
                    // Extract numbered points
                    let point = line.drop { !$0.isWhitespace }.trimmingCharacters(in: .whitespaces)
                    if !point.isEmpty {
                        keyPoints.append(point)
                    }
                }
            }
            
            // Fallbacks
            if summary.isEmpty {
                summary = keyPoints.first ?? "Analysis completed"
            }
            
            if keyPoints.isEmpty {
                keyPoints = Array(lines.filter { !$0.hasPrefix("OVERVIEW:") && !$0.isEmpty }.prefix(5))
            }
            
            return AnalysisData(summary: summary, key_points: keyPoints) as! T
        }
        
        if responseType == ThemesData.self {
            var themeObjects: [ThemesData.Theme] = []
            var sentiment = "neutral"
            
            for line in lines {
                if line.starts(with: /\d+\./) && line.contains(":") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let name = parts[0].drop { !$0.isLetter }.trimmingCharacters(in: .whitespaces)
                        let evidence = parts[1].trimmingCharacters(in: .whitespaces)
                        themeObjects.append(ThemesData.Theme(name: name, evidence: [evidence]))
                    }
                } else if line.hasPrefix("OVERALL SENTIMENT:") {
                    let sentimentText = String(line.dropFirst(18)).trimmingCharacters(in: .whitespaces).lowercased()
                    sentiment = sentimentText
                }
            }
            
            // Fallback parsing
            if themeObjects.isEmpty {
                let names = Array(lines.filter { !$0.hasPrefix("OVERALL SENTIMENT:") && !$0.hasPrefix("CONTEXT:") }
                    .prefix(5))
                themeObjects = names.map { ThemesData.Theme(name: String($0), evidence: []) }
            }
            
            return ThemesData(themes: themeObjects, sentiment: sentiment) as! T
        }
        
        if responseType == TodosData.self {
            var todos: [TodosData.Todo] = []
            
            if output.contains("NO TASKS FOUND") {
                return TodosData(todos: []) as! T
            }
            
            for line in lines {
                if line.hasPrefix("[ ]") {
                    let taskText = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    let cleanText = cleanActionText(taskText)
                    if !cleanText.isEmpty {
                        todos.append(TodosData.Todo(text: cleanText, due: nil))
                    }
                }
            }
            
            return TodosData(todos: todos) as! T
        }
        
        if responseType == EventsData.self {
            var events: [EventsData.DetectedEvent] = []
            var current: [String: String] = [:]

            func flush() {
                guard let title = current["Event"], !title.isEmpty else { current.removeAll(); return }
                let startDate: Date? = nil // Parsing natural language datetime is out-of-scope here
                let endDate: Date? = nil
                let location = current["Location"]?.nilIfEmpty
                let participants = current["Participants"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let src = ["Date", "Time", "Location", "Participants"].compactMap { key in
                    if let v = current[key], !v.isEmpty { return "\(key): \(v)" } else { return nil }
                }.joined(separator: " | ")
                events.append(EventsData.DetectedEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    participants: participants,
                    confidence: 0.9,
                    sourceText: src
                ))
                current.removeAll()
            }

            for line in lines {
                if line.hasPrefix("Event:") {
                    flush()
                    current["Event"] = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Date:") {
                    current["Date"] = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Time:") {
                    current["Time"] = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Location:") {
                    current["Location"] = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Participants:") {
                    current["Participants"] = String(line.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                }
            }
            flush()

            return EventsData(events: events) as! T
        }

        if responseType == RemindersData.self {
            var reminders: [RemindersData.DetectedReminder] = []
            var current: [String: String] = [:]

            func flush() {
                guard let title = current["Task"], !title.isEmpty else { current.removeAll(); return }
                var priority: RemindersData.DetectedReminder.Priority = .medium
                if let p = current["Priority"]?.lowercased() {
                    if p.contains("high") { priority = .high }
                    else if p.contains("low") { priority = .low }
                }
                let due: Date? = nil // Natural language to Date parsing omitted
                let src = ["Due", "Priority"].compactMap { key in
                    if let v = current[key], !v.isEmpty { return "\(key): \(v)" } else { return nil }
                }.joined(separator: " | ")
                reminders.append(RemindersData.DetectedReminder(
                    title: title,
                    dueDate: due,
                    priority: priority,
                    confidence: 0.9,
                    sourceText: src
                ))
                current.removeAll()
            }

            for line in lines {
                if line.hasPrefix("Task:") {
                    flush()
                    current["Task"] = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Due:") {
                    current["Due"] = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Priority:") {
                    current["Priority"] = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                }
            }
            flush()

            return RemindersData(reminders: reminders) as! T
        }

        if responseType == DistillSummaryData.self {
            let summary = lines.first(where: { $0.hasPrefix("SUMMARY:") })
                .map { String($0.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
                ?? lines.first
                ?? "Summary generated"
            return DistillSummaryData(summary: summary) as! T
        }
        
        if responseType == DistillActionsData.self {
            var actions: [DistillData.ActionItem] = []
            
            if output.contains("NO ACTIONS") {
                return DistillActionsData(action_items: []) as! T
            }
            
            for line in lines {
                if line.hasPrefix("-") {
                    let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                    let priority = extractPriority(from: content)
                    let cleanText = cleanActionText(content)
                    if !cleanText.isEmpty {
                        actions.append(DistillData.ActionItem(text: cleanText, priority: priority))
                    }
                }
            }
            
            return DistillActionsData(action_items: actions) as! T
        }
        
        if responseType == DistillThemesData.self {
            var themes: [String] = []
            
            for line in lines {
                if line.hasPrefix("THEMES:") {
                    let themeText = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    themes = themeText.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                } else if line.starts(with: /\d+\./) {
                    let theme = line.drop { !$0.isLetter }.components(separatedBy: ":").first?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    if !theme.isEmpty {
                        themes.append(theme)
                    }
                }
            }
            
            if themes.isEmpty {
                themes = ["General discussion"]
            }
            
            return DistillThemesData(key_themes: themes) as! T
        }
        
        if responseType == DistillReflectionData.self {
            var questions: [String] = []
            
            for line in lines {
                if line.starts(with: /\d+\./) || line.hasPrefix("-") {
                    let question = line.drop { !$0.isLetter }.trimmingCharacters(in: .whitespaces)
                    if !question.isEmpty && question.contains("?") {
                        questions.append(question)
                    }
                }
            }
            
            if questions.isEmpty {
                questions = ["What are the key next steps?", "How might this impact other priorities?"]
            }
            
            return DistillReflectionData(reflection_questions: questions) as! T
        }
        
        throw AnalysisError.parsingFailed("Unsupported response type: \(responseType)")
    }
    
    // MARK: - Parsing Helpers
    
    private func extractPriority(from text: String) -> DistillData.ActionItem.Priority {
        let lowercased = text.lowercased()
        if lowercased.contains("high") || lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") {
            return .high
        } else if lowercased.contains("low") || lowercased.contains("sometime") || lowercased.contains("eventually") || lowercased.contains("when possible") {
            return .low
        }
        return .medium
    }
    
    private func cleanActionText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "Priority: High", with: "")
            .replacingOccurrences(of: "Priority: Medium", with: "")
            .replacingOccurrences(of: "Priority: Low", with: "")
            .replacingOccurrences(of: " - ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Small string helper for optional cleanup
private extension String {
    var nilIfEmpty: String? { self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

// MARK: - Enhanced Error Handling

extension AnalysisError {
    static let modelNotDownloaded = AnalysisError.networkError("Model not downloaded")
    static let modelLoadFailed = AnalysisError.networkError("Failed to load local AI model")
    static let modelNotAvailable = AnalysisError.networkError("Local AI model not available")
    
    static func deviceIncompatible(_ reason: String) -> AnalysisError {
        return .networkError("Device incompatible: \(reason)")
    }
    
    static func invalidInput(_ msg: String) -> AnalysisError {
        return .decodingError(msg)
    }
    
    static func parsingFailed(_ msg: String) -> AnalysisError {
        return .decodingError("Failed to parse local AI output: \(msg)")
    }
}
