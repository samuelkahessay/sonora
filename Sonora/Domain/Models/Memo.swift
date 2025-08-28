//
//  Memo.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation

struct Memo: Identifiable, Equatable, Hashable {
    let id: UUID
    let filename: String
    let url: URL
    let createdAt: Date
    
    // MARK: - Initializers
    
    /// Create a new memo with auto-generated ID
    init(filename: String, url: URL, createdAt: Date) {
        self.id = UUID()
        self.filename = filename
        self.url = url
        self.createdAt = createdAt
    }
    
    /// Create a memo with a specific ID (used when loading from storage)
    init(id: UUID, filename: String, url: URL, createdAt: Date) {
        self.id = id
        self.filename = filename
        self.url = url
        self.createdAt = createdAt
    }
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    // Duration-related helpers have been moved to the Data layer to
    // avoid AVFoundation dependency in the Domain layer.
}
