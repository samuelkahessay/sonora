import Foundation

/// Adapter for converting between Memo (data layer) and DomainMemo (domain layer)
/// Provides backward compatibility during the transition to Clean Architecture
struct MemoAdapter {
    
    // MARK: - Memo to DomainMemo Conversion
    
    /// Converts a Memo to DomainMemo
    static func toDomain(_ memo: Memo) -> DomainMemo {
        return DomainMemo(
            id: memo.id,
            filename: memo.filename,
            fileURL: memo.url,
            creationDate: memo.createdAt,
            transcriptionStatus: .notStarted, // Will be updated by transcription service
            analysisResults: [] // Will be populated as analyses are performed
        )
    }
    
    /// Converts an array of Memos to DomainMemos
    static func toDomain(_ memos: [Memo]) -> [DomainMemo] {
        return memos.map { toDomain($0) }
    }
    
    // MARK: - DomainMemo to Memo Conversion
    
    /// Converts a DomainMemo to Memo
    static func fromDomain(_ domainMemo: DomainMemo) -> Memo {
        return Memo(
            filename: domainMemo.filename,
            url: domainMemo.fileURL,
            createdAt: domainMemo.creationDate
        )
    }
    
    /// Converts an array of DomainMemos to Memos
    static func fromDomain(_ domainMemos: [DomainMemo]) -> [Memo] {
        return domainMemos.map { fromDomain($0) }
    }
}

// MARK: - Memo Extension for Domain Compatibility
extension Memo {
    
    /// Convenience method to convert to domain model
    func toDomain() -> DomainMemo {
        return MemoAdapter.toDomain(self)
    }
}

// MARK: - DomainMemo Extension for Data Layer Compatibility  
extension DomainMemo {
    
    /// Convenience method to convert to data model
    func toMemo() -> Memo {
        return MemoAdapter.fromDomain(self)
    }
}