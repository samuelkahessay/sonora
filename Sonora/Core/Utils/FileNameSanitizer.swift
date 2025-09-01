//
//  FileNameSanitizer.swift
//  Sonora
//
//  Utility for sanitizing user input into safe filenames
//

import Foundation

/// Utility for converting user input into safe, filesystem-compatible filenames
struct FileNameSanitizer {
    
    // MARK: - Constants
    
    /// Maximum length for generated filenames (excluding extension)
    private static let maxFileNameLength = 100
    
    /// Characters that are invalid in filenames on most filesystems
    private static let invalidCharacters: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "<>:\"|?*\\/")
        set.formUnion(.newlines)
        set.formUnion(.controlCharacters)
        return set
    }()
    
    /// Reserved filename components that should be avoided
    private static let reservedNames = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]
    
    // MARK: - Public Methods
    
    /// Converts a user-provided string into a safe filename
    /// - Parameters:
    ///   - input: The user input to sanitize
    ///   - fileExtension: The file extension to append (with dot, e.g., ".m4a")
    /// - Returns: A sanitized filename safe for filesystem use
    static func sanitize(_ input: String, withExtension fileExtension: String = ".m4a") -> String {
        guard !input.isEmpty else {
            return "untitled\(fileExtension)"
        }
        
        // Step 1: Trim whitespace
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 2: Replace spaces with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        
        // Step 3: Remove invalid characters
        sanitized = String(sanitized.unicodeScalars.filter { scalar in
            !Self.invalidCharacters.contains(scalar)
        })
        
        // Step 4: Handle multiple consecutive underscores
        sanitized = sanitized.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        
        // Step 5: Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // Step 6: Handle empty result after sanitization
        if sanitized.isEmpty {
            sanitized = "untitled"
        }
        
        // Step 7: Check for reserved names
        if Self.reservedNames.contains(sanitized.uppercased()) {
            sanitized = "memo_\(sanitized)"
        }
        
        // Step 8: Truncate if too long
        if sanitized.count > Self.maxFileNameLength {
            let endIndex = sanitized.index(sanitized.startIndex, offsetBy: Self.maxFileNameLength)
            sanitized = String(sanitized[..<endIndex])
            // Remove trailing underscore if truncation created one
            sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }
        
        // Step 9: Final fallback check
        if sanitized.isEmpty {
            sanitized = "untitled"
        }
        
        // Step 10: Add file extension
        return "\(sanitized)\(fileExtension)"
    }
    
    /// Validates if a filename is safe without modification
    /// - Parameter filename: The filename to validate
    /// - Returns: True if the filename is safe to use as-is
    static func isValid(_ filename: String) -> Bool {
        let nameWithoutExtension = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let sanitized = sanitize(nameWithoutExtension, withExtension: "")
        return nameWithoutExtension == sanitized.replacingOccurrences(of: URL(fileURLWithPath: filename).pathExtension, with: "")
    }
    
    /// Generates a unique filename if the proposed name already exists
    /// - Parameters:
    ///   - baseName: The base filename (without extension)
    ///   - fileExtension: The file extension
    ///   - existingNames: Set of existing filenames to avoid
    /// - Returns: A unique filename
    static func makeUnique(baseName: String, fileExtension: String, avoiding existingNames: Set<String>) -> String {
        let baseFilename = sanitize(baseName, withExtension: fileExtension)
        
        if !existingNames.contains(baseFilename) {
            return baseFilename
        }
        
        let nameWithoutExt = URL(fileURLWithPath: baseFilename).deletingPathExtension().lastPathComponent
        var counter = 1
        
        while counter < 1000 { // Reasonable upper limit
            let numberedName = "\(nameWithoutExt)_\(counter)\(fileExtension)"
            if !existingNames.contains(numberedName) {
                return numberedName
            }
            counter += 1
        }
        
        // Fallback with timestamp if we somehow hit the limit
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(nameWithoutExt)_\(timestamp)\(fileExtension)"
    }
}

// MARK: - Preview Helper

#if DEBUG
extension FileNameSanitizer {
    /// Test cases for validation during development
    static var testCases: [(input: String, expected: String)] {
        return [
            ("Meeting Notes", "Meeting_Notes.m4a"),
            ("File<>Name", "FileName.m4a"),
            ("CON", "memo_CON.m4a"),
            ("Multiple   Spaces", "Multiple_Spaces.m4a"),
            ("", "untitled.m4a"),
            ("Very Long Filename That Exceeds The Maximum Character Limit And Should Be Truncated Properly Without Breaking", "Very_Long_Filename_That_Exceeds_The_Maximum_Character_Limit_And_Should_Be_Truncated_Pr.m4a"),
            ("___Leading_Trailing___", "Leading_Trailing.m4a"),
            ("Special@#$%Characters", "Special@#$%Characters.m4a"),
            ("Final Meeting Jan 2, 2025", "Final_Meeting_Jan_2,_2025.m4a")
        ]
    }
}
#endif