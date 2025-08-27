//
//  Memo.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation
import AVFoundation

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
    
    @available(iOS, introduced: 11.0, deprecated: 16.0)
    var duration: TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    @available(iOS, introduced: 11.0, deprecated: 16.0)
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}