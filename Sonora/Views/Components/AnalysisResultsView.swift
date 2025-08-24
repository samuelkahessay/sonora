import SwiftUI

struct AnalysisResultsView: View {
    let mode: AnalysisMode
    let result: Any
    let envelope: Any
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with model info
                if let env = envelope as? AnalyzeEnvelope<TLDRData> {
                    HeaderInfoView(envelope: env)
                } else if let env = envelope as? AnalyzeEnvelope<AnalysisData> {
                    HeaderInfoView(envelope: env)
                } else if let env = envelope as? AnalyzeEnvelope<ThemesData> {
                    HeaderInfoView(envelope: env)
                } else if let env = envelope as? AnalyzeEnvelope<TodosData> {
                    HeaderInfoView(envelope: env)
                }
                
                // Mode-specific content
                switch mode {
                case .tldr, .analysis:
                    if let data = result as? TLDRData {
                        TLDRResultView(data: data)
                    } else if let data = result as? AnalysisData {
                        AnalysisResultView(data: data)
                    }
                case .themes:
                    if let data = result as? ThemesData {
                        ThemesResultView(data: data)
                    }
                case .todos:
                    if let data = result as? TodosData {
                        TodosResultView(data: data)
                    }
                }
            }
            .padding()
        }
    }
}

struct HeaderInfoView<T: Codable>: View {
    let envelope: AnalyzeEnvelope<T>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(envelope.mode.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(envelope.model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(envelope.latency_ms)ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(envelope.tokens.input + envelope.tokens.output) tokens", systemImage: "textformat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(envelope.tokens.input) in, \(envelope.tokens.output) out")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TLDRResultView: View {
    let data: TLDRData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(data.summary)
                    .font(.body)
                    .lineSpacing(4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Points")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(Array(data.key_points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.blue)
                        Text(point)
                            .font(.body)
                            .lineSpacing(2)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct AnalysisResultView: View {
    let data: AnalysisData
    
    var body: some View {
        TLDRResultView(data: TLDRData(summary: data.summary, key_points: data.key_points))
    }
}

struct ThemesResultView: View {
    let data: ThemesData
    
    private var sentimentColor: Color {
        switch data.sentiment.lowercased() {
        case "positive": return .green
        case "negative": return .red
        case "mixed": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sentiment")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(data.sentiment.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(sentimentColor.opacity(0.2))
                    .foregroundColor(sentimentColor)
                    .cornerRadius(20)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Themes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(Array(data.themes.enumerated()), id: \.offset) { _, theme in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(theme.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        ForEach(Array(theme.evidence.enumerated()), id: \.offset) { _, evidence in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(evidence)
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                Text("\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct TodosResultView: View {
    let data: TodosData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Action Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            if data.todos.isEmpty {
                Text("No action items found")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(data.todos.enumerated()), id: \.offset) { _, todo in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle")
                            .font(.body)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(todo.text)
                                .font(.body)
                                .lineSpacing(2)
                            
                            if let dueDate = todo.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(formatDate(dueDate))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}