import Foundation
import Combine
import SwiftData

@MainActor
final class TranscriptionRepositoryImpl: ObservableObject, TranscriptionRepository {
    @Published var transcriptionStates: [String: TranscriptionState] = [:]

    private let context: ModelContext
    private let logger: any LoggerProtocol

    init(context: ModelContext, logger: any LoggerProtocol = Logger.shared) {
        self.context = context
        self.logger = logger
    }

    private func memoIdKey(for memoId: UUID) -> String { memoId.uuidString }

    private func fetchMemoModel(id: UUID) -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == id }, sortBy: [])
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchTranscriptionModel(for memoId: UUID) -> TranscriptionModel? {
        // Prefer by relationship
        if let model = (try? context.fetch(FetchDescriptor<TranscriptionModel>(predicate: #Predicate { $0.memo?.id == memoId })))?.first {
            return model
        }
        // Fallback by matching id to memoId (we may set it like that)
        if let model = (try? context.fetch(FetchDescriptor<TranscriptionModel>(predicate: #Predicate { $0.id == memoId })))?.first {
            return model
        }
        return nil
    }

    private func mapStateToModelFields(_ state: TranscriptionState) -> (status: String, text: String?) {
        switch state {
        case .notStarted: return ("notStarted", nil)
        case .inProgress: return ("inProgress", nil)
        case .completed(let text): return ("completed", text)
        case .failed(let error): return ("failed", error)
        }
    }

    private func mapModelToState(_ model: TranscriptionModel) -> TranscriptionState {
        switch model.status {
        case "completed":
            return .completed(model.fullTranscript)
        case "inProgress":
            return .inProgress
        case "failed":
            return .failed(model.fullTranscript)
        default:
            return .notStarted
        }
    }

    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID) {
        let key = memoIdKey(for: memoId)
        transcriptionStates[key] = state

        let now = Date()
        if let model = fetchTranscriptionModel(for: memoId) {
            let mapped = mapStateToModelFields(state)
            model.status = mapped.status
            model.fullTranscript = mapped.text ?? model.fullTranscript
            model.lastUpdated = now
            do { try context.save() } catch { logger.error("Failed to save transcription model", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
            logger.debug("Updated transcription state in SwiftData", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString, "status": model.status]))
            return
        }

        // Create if not exists
        let mapped = mapStateToModelFields(state)
        let trans = TranscriptionModel(
            id: memoId,
            status: mapped.status,
            language: "",
            fullTranscript: mapped.text ?? "",
            lastUpdated: now
        )
        if let memoModel = fetchMemoModel(id: memoId) { trans.memo = memoModel }
        context.insert(trans)
        do { try context.save() } catch { logger.error("Failed to insert transcription model", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
        logger.debug("Inserted transcription state in SwiftData", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString, "status": trans.status]))
    }

    func getTranscriptionState(for memoId: UUID) -> TranscriptionState {
        let key = memoIdKey(for: memoId)
        if let cached = transcriptionStates[key] { return cached }

        guard let model = fetchTranscriptionModel(for: memoId) else {
            transcriptionStates[key] = .notStarted
            return .notStarted
        }
        let state = mapModelToState(model)
        transcriptionStates[key] = state
        return state
    }

    func deleteTranscriptionData(for memoId: UUID) {
        let key = memoIdKey(for: memoId)
        transcriptionStates.removeValue(forKey: key)
        if let model = fetchTranscriptionModel(for: memoId) {
            context.delete(model)
            do { try context.save() } catch { logger.error("Failed to delete transcription model", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
        }
        logger.info("Deleted transcription data for memo (SwiftData)", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]))
    }

    func hasTranscriptionData(for memoId: UUID) -> Bool {
        let key = memoIdKey(for: memoId)
        if transcriptionStates[key] != nil { return true }
        return fetchTranscriptionModel(for: memoId) != nil
    }

    func getTranscriptionText(for memoId: UUID) -> String? {
        let state = getTranscriptionState(for: memoId)
        return state.text
    }

    func saveTranscriptionText(_ text: String, for memoId: UUID) {
        saveTranscriptionState(.completed(text), for: memoId)
    }

    func getTranscriptionMetadata(for memoId: UUID) -> TranscriptionMetadata? {
        guard let model = fetchTranscriptionModel(for: memoId) else { return nil }
        if let data = model.metadataData, let meta = try? JSONDecoder().decode(TranscriptionMetadata.self, from: data) {
            return meta
        }
        // Fallback derive
        let state = mapModelToState(model)
        return TranscriptionMetadata(
            memoId: memoId,
            state: state.statusText,
            text: state.text,
            lastUpdated: model.lastUpdated,
            detectedLanguage: model.language
        )
    }

    func saveTranscriptionMetadata(_ metadata: TranscriptionMetadata, for memoId: UUID) {
        let existing = getTranscriptionMetadata(for: memoId)
        let merged = existing?.merging(metadata) ?? metadata
        let data = try? JSONEncoder().encode(merged)
        let now = Date()
        if let model = fetchTranscriptionModel(for: memoId) {
            model.metadataData = data
            if let lang = merged.detectedLanguage { model.language = lang }
            model.lastUpdated = now
            do { try context.save() } catch { logger.error("Failed to update transcription metadata", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
            return
        }
        let trans = TranscriptionModel(
            id: memoId,
            status: "notStarted",
            language: merged.detectedLanguage ?? "",
            fullTranscript: merged.text ?? "",
            lastUpdated: now,
            metadataData: data
        )
        if let memoModel = fetchMemoModel(id: memoId) { trans.memo = memoModel }
        context.insert(trans)
        do { try context.save() } catch { logger.error("Failed to insert transcription metadata", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
    }

    func clearTranscriptionCache() {
        transcriptionStates.removeAll()
        logger.debug("Cleared transcription cache", category: .repository, context: LogContext())
    }

    func getAllTranscriptionStates() -> [UUID: TranscriptionState] {
        var states: [UUID: TranscriptionState] = [:]
        // Include cached
        for (key, state) in transcriptionStates { if let uuid = UUID(uuidString: key) { states[uuid] = state } }
        // Fetch from store
        if let models = try? context.fetch(FetchDescriptor<TranscriptionModel>()) {
            for model in models {
                let id = model.memo?.id ?? model.id
                states[id] = mapModelToState(model)
            }
        }
        return states
    }
}
