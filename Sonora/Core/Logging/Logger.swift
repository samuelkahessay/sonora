import Foundation
import os.log

/// Log levels for filtering and prioritizing log messages
public enum LogLevel: Int, CaseIterable, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning, .error: return .error
        case .critical: return .fault
        }
    }
}

/// Categories for structured logging to group related log messages
public enum LogCategory: String, CaseIterable {
    case viewModel = "ViewModel"
    case useCase = "UseCase"
    case repository = "Repository"
    case service = "Service"
    case network = "Network"
    case audio = "Audio"
    case transcription = "Transcription"
    case analysis = "Analysis"
    case performance = "Performance"
    case error = "Error"
    case system = "System"
    
    var emoji: String {
        switch self {
        case .viewModel: return "📱"
        case .useCase: return "⚙️"
        case .repository: return "💾"
        case .service: return "🔧"
        case .network: return "🌐"
        case .audio: return "🎵"
        case .transcription: return "📝"
        case .analysis: return "📊"
        case .performance: return "⏱️"
        case .error: return "🚫"
        case .system: return "🖥️"
        }
    }
}

/// Log output destination configuration
public enum LogDestination: Hashable {
    case console
    case osLog
    case file(URL)
    case remote(URL)
    
    // Custom Hashable implementation
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .console:
            hasher.combine("console")
        case .osLog:
            hasher.combine("osLog")
        case .file(let url):
            hasher.combine("file")
            hasher.combine(url.absoluteString)
        case .remote(let url):
            hasher.combine("remote")
            hasher.combine(url.absoluteString)
        }
    }
    
    public static func == (lhs: LogDestination, rhs: LogDestination) -> Bool {
        switch(lhs, rhs) {
        case(.console, .console), (.osLog, .osLog):
            return true
        case (.file(let lhsURL), .file(let rhsURL)):
            return lhsURL == rhsURL
        case (.remote(let lhsURL), .remote(let rhsURL)):
            return lhsURL == rhsURL
        default:
            return false
        }
    }
}

/// Context information for error logging
public struct LogContext {
    public let file: String
    public let line: Int
    public let function: String
    public let correlationId: String?
    public let additionalInfo: [String: Any]?
    
    public init(
        file: String = #file,
        line: Int = #line,
        function: String = #function,
        correlationId: String? = nil,
        additionalInfo: [String: Any]? = nil
    ) {
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.line = line
        self.function = function
        self.correlationId = correlationId
        self.additionalInfo = additionalInfo
    }
}

/// Protocol for dependency injection and testability
public protocol LoggerProtocol {
    func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        context: LogContext?,
        error: Error?
    )
    
    func verbose(_ message: String, category: LogCategory, context: LogContext?)
    func debug(_ message: String, category: LogCategory, context: LogContext?)
    func info(_ message: String, category: LogCategory, context: LogContext?)
    func warning(_ message: String, category: LogCategory, context: LogContext?, error: Error?)
    func error(_ message: String, category: LogCategory, context: LogContext?, error: Error?)
    func critical(_ message: String, category: LogCategory, context: LogContext?, error: Error?)
}

/// High-performance, thread-safe logging system following Clean Architecture
public final class Logger: LoggerProtocol {
    
    // MARK: - Singleton
    public static let shared = Logger()
    
    // MARK: - Configuration
    private let queue = DispatchQueue(label: "com.sonora.logger", qos: .utility)
    private var currentLogLevel: LogLevel = .info
    private var destinations: Set<LogDestination> = [.console, .osLog]
    private let dateFormatter: DateFormatter
    private let osLog: OSLog
    
    // MARK: - Privacy & Performance
    private let maxMessageLength = 1000
    private let sensitivePatterns: [NSRegularExpression] = {
        let patterns = [
            "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", // Email
            "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b", // Credit card
            "\\b\\d{3}-\\d{2}-\\d{4}\\b", // SSN
            "Bearer\\s+[A-Za-z0-9\\-\\._~\\+\\/]+=*", // Bearer tokens
            "api[_-]?key[\"']?\\s*[:=]\\s*[\"']?[A-Za-z0-9]{20,}", // API keys
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()
    
    // MARK: - Initialization
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        osLog = OSLog(subsystem: "com.sonora.app", category: "General")
        
        #if DEBUG
        currentLogLevel = .verbose
        #else
        currentLogLevel = .info
        #endif
    }
    
    // MARK: - Configuration Methods
    public func configure(logLevel: LogLevel, destinations: Set<LogDestination> = [.console, .osLog]) {
        queue.async {
            self.currentLogLevel = logLevel
            self.destinations = destinations
        }
    }
    
    // MARK: - Core Logging Method
    public func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        guard level >= currentLogLevel else { return }
        
        queue.async {
            let sanitizedMessage = self.sanitizeMessage(message)
            let formattedMessage = self.formatMessage(
                level: level,
                category: category,
                message: sanitizedMessage,
                context: context,
                error: error
            )
            
            self.writeToDestinations(formattedMessage, level: level, category: category)
        }
    }
    
    // MARK: - Convenience Methods
    public func verbose(
        _ message: String,
        category: LogCategory = .system,
        context: LogContext? = nil
    ) {
        log(level: .verbose, category: category, message: message, context: context, error: nil)
    }
    
    public func debug(
        _ message: String,
        category: LogCategory = .system,
        context: LogContext? = nil
    ) {
        log(level: .debug, category: category, message: message, context: context, error: nil)
    }
    
    public func info(
        _ message: String,
        category: LogCategory = .system,
        context: LogContext? = nil
    ) {
        log(level: .info, category: category, message: message, context: context, error: nil)
    }
    
    public func warning(
        _ message: String,
        category: LogCategory = .error,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: .warning, category: category, message: message, context: context, error: error)
    }
    
    public func error(
        _ message: String,
        category: LogCategory = .error,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: .error, category: category, message: message, context: context, error: error)
    }
    
    public func critical(
        _ message: String,
        category: LogCategory = .error,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: .critical, category: category, message: message, context: context, error: error)
    }
    
    // MARK: - Private Implementation
    private func formatMessage(
        level: LogLevel,
        category: LogCategory,
        message: String,
        context: LogContext?,
        error: Error?
    ) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let levelEmoji = level.emoji
        let categoryEmoji = category.emoji
        let thread = Thread.isMainThread ? "Main" : "Background"
        
        var components = [
            timestamp,
            "[\(thread)]",
            "\(levelEmoji) \(level.displayName)",
            "\(categoryEmoji) \(category.rawValue):",
            message
        ]
        
        if let context = context {
            var contextInfo = "[\(context.file):\(context.line) \(context.function)]"
            if let correlationId = context.correlationId {
                contextInfo += " [ID: \(correlationId)]"
            }
            components.append(contextInfo)
        }
        
        if let error = error {
            components.append("Error: \(error.localizedDescription)")
        }
        
        return components.joined(separator: " ")
    }
    
    private func sanitizeMessage(_ message: String) -> String {
        var sanitized = String(message.prefix(maxMessageLength))
        
        for pattern in sensitivePatterns {
            let range = NSRange(location: 0, length: sanitized.utf16.count)
            sanitized = pattern.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "[REDACTED]"
            )
        }
        
        return sanitized
    }
    
    private func writeToDestinations(_ message: String, level: LogLevel, category: LogCategory) {
        for destination in destinations {
            switch destination {
            case .console:
                print(message)
                
            case .osLog:
                os_log("%{public}@", log: osLog, type: level.osLogType, message)
                
            case .file(let url):
                writeToFile(message, url: url)
                
            case .remote(let url):
                sendToRemoteService(message, url: url, level: level, category: category)
            }
        }
    }
    
    private func writeToFile(_ message: String, url: URL) {
        do {
            let data = (message + "\n").data(using: .utf8) ?? Data()
            
            if FileManager.default.fileExists(atPath: url.path) {
                let fileHandle = try FileHandle(forWritingTo: url)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: url)
            }
        } catch {
            print("Logger: Failed to write to file: \(error)")
        }
    }
    
    private func sendToRemoteService(_ message: String, url: URL, level: LogLevel, category: LogCategory) {
        // Placeholder for remote logging implementation
        // Could integrate with services like Sentry, LogRocket, etc.
    }
}

// MARK: - Performance Timer

/// High-precision timer for measuring performance of operations
public final class PerformanceTimer {
    private let startTime: CFAbsoluteTime
    private let operation: String
    private let category: LogCategory
    private let logger: LoggerProtocol
    
    public init(
        operation: String,
        category: LogCategory = .performance,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operation = operation
        self.category = category
        self.logger = logger
        self.startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Started: \(operation)", category: category, context: LogContext())
    }
    
    public func finish(additionalInfo: String? = nil) -> TimeInterval {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let durationMs = duration * 1000
        
        var message = "Completed: \(operation) in \(String(format: "%.2f", durationMs))ms"
        if let info = additionalInfo {
            message += " - \(info)"
        }
        
        let level: LogLevel = durationMs > 1000 ? .warning : .info
        logger.log(level: level, category: category, message: message, context: LogContext(), error: nil)
        
        return duration
    }
    
    deinit {
        let _ = finish()
    }
}

// MARK: - Convenience Extensions

public extension LoggerProtocol {
    
    /// Log audio-related operations
    func audio(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .audio, message: message, context: context, error: error)
    }
    
    /// Log transcription operations
    func transcription(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .transcription, message: message, context: context, error: error)
    }
    
    /// Log analysis operations
    func analysis(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .analysis, message: message, context: context, error: error)
    }
    
    /// Log repository operations
    func repository(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .repository, message: message, context: context, error: error)
    }
    
    /// Log use case execution
    func useCase(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .useCase, message: message, context: context, error: error)
    }
    
    /// Log view model operations
    func viewModel(
        _ message: String,
        level: LogLevel = .info,
        context: LogContext? = nil,
        error: Error? = nil
    ) {
        log(level: level, category: .viewModel, message: message, context: context, error: error)
    }
}
