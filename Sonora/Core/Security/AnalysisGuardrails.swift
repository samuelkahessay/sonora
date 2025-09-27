import Foundation

enum AnalysisGuardrails {
    // MARK: - Sanitization
    /// Escapes risky delimiter patterns and control chars before sending to LLM
    static func sanitizeTranscriptForLLM(_ input: String) -> String {
        var s = input
        // Normalize line endings
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
             .replacingOccurrences(of: "\r", with: "\n")
        // Remove null bytes and control characters except tab/newline
        s = s.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x09, 0x0A: return true // tab, newline
            case 0x20...0x10FFFF: return true
            default: return false
            }
        }.map { String($0) }.joined()
        // Defang prompt-delimiter tokens used server-side
        s = s.replacingOccurrences(of: "<<<", with: "‹‹‹")
        s = s.replacingOccurrences(of: ">>>", with: "›››")
        // Defang common fences
        s = s.replacingOccurrences(of: "```", with: "``\u{200A}") // thin space
        return s
    }

    // MARK: - Validation
    static func validate(analysis: AnalysisData) -> Bool {
        guard !analysis.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard analysis.summary.count <= 10_000 else { return false }
        guard analysis.key_points.count <= 100 else { return false }
        return analysis.key_points.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 2000 }
    }

    static func validate(themes: ThemesData) -> Bool {
        guard themes.themes.count <= 50 else { return false }
        for t in themes.themes {
            if t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if t.name.count > 500 { return false }
            if t.evidence.count > 100 { return false }
            if !t.evidence.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 2000 }) { return false }
        }
        // sentiment is already validated by type on server; be permissive here
        return true
    }

    static func validate(todos: TodosData) -> Bool {
        guard todos.todos.count <= 200 else { return false }
        for td in todos.todos {
            if td.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if td.text.count > 2000 { return false }
            if let due = td.due, due.count > 1000 { return false }
        }
        return true
    }
    
    static func validate(distill: DistillData) -> Bool {
        // Validate summary
        guard !distill.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard distill.summary.count <= 10_000 else { return false }
        
        // Validate action items (optional)
        if let actionItems = distill.action_items {
            guard actionItems.count <= 50 else { return false }
            for item in actionItems {
                if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
                if item.text.count > 2000 { return false }
            }
        }
        
        // Validate reflection questions
        guard distill.reflection_questions.count > 0 && distill.reflection_questions.count <= 5 else { return false }
        guard distill.reflection_questions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 1000 }) else { return false }
        
        return true
    }
}
