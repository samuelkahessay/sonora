import Combine
import Foundation
import SwiftData

/// Implementation maintains @MainActor isolation for Combine subjects and SwiftData context.
/// Protocol callers can call from any actor; Swift automatically hops to main actor.
@MainActor
final class TranscriptionRepositoryImpl: TranscriptionRepository {
    private let transcriptionStatesSubject = CurrentValueSubject<[String: TranscriptionState], Never>([:])

    var transcriptionStates: [String: TranscriptionState] {
        get async {
            transcriptionStatesSubject.value
        }
    }

    // MARK: - Event-Driven State Changes (Swift 6 Compliant)

    /// Subject for publishing transcription state changes
    /// NOTE: nonisolated(unsafe) because Combine publishers are accessed from multiple contexts
    /// but the underlying state management is on main actor
    nonisolated(unsafe) private let stateChangesSubject = PassthroughSubject<TranscriptionStateChange, Never>()

    /// Publisher for transcription state changes - eliminates need for polling
    nonisolated var stateChangesPublisher: AnyPublisher<TranscriptionStateChange, Never> {
        stateChangesSubject.eraseToAnyPublisher()
    }

    /// Get state changes for a specific memo
    nonisolated func stateChangesPublisher(for memoId: UUID) -> AnyPublisher<TranscriptionStateChange, Never> {
        stateChangesPublisher
            .filter { $0.memoId == memoId }
            .eraseToAnyPublisher()
    }

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

    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID) async {
        let key = memoIdKey(for: memoId)
        var states = transcriptionStatesSubject.value
        let previousState = states[key]
        states[key] = state
        transcriptionStatesSubject.send(states)

        // Publish state change event - Swift 6 compliant MainActor isolation
        let stateChange = TranscriptionStateChange(
            memoId: memoId,
            previousState: previousState,
            currentState: state
        )
        stateChangesSubject.send(stateChange)

        logger.debug("Published transcription state change event",
                    category: .repository,
                    context: LogContext(additionalInfo: [
                        "memoId": memoId.uuidString,
                        "previousState": previousState?.statusText ?? "nil",
                        "currentState": state.statusText
                    ]))

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

    func getTranscriptionState(for memoId: UUID) async -> TranscriptionState {
        let key = memoIdKey(for: memoId)
        var states = transcriptionStatesSubject.value
        if let cached = states[key] { return cached }

        guard let model = fetchTranscriptionModel(for: memoId) else {
            let state = TranscriptionState.notStarted
            states[key] = state
            transcriptionStatesSubject.send(states)

            // Publish initial state discovery event
            let stateChange = TranscriptionStateChange(
                memoId: memoId,
                previousState: nil,
                currentState: state
            )
            stateChangesSubject.send(stateChange)

            return state
        }

        let state = mapModelToState(model)
        states[key] = state
        transcriptionStatesSubject.send(states)

        // Publish state discovery event when loading from persistent storage
        let stateChange = TranscriptionStateChange(
            memoId: memoId,
            previousState: nil,
            currentState: state
        )
        stateChangesSubject.send(stateChange)

        return state
    }

    func deleteTranscriptionData(for memoId: UUID) async {
        let key = memoIdKey(for: memoId)
        var states = transcriptionStatesSubject.value
        let previousState = states[key]
        states.removeValue(forKey: key)
        transcriptionStatesSubject.send(states)

        if let model = fetchTranscriptionModel(for: memoId) {
            context.delete(model)
            do { try context.save() } catch { logger.error("Failed to delete transcription model", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error) }
        }

        // Publish deletion event - state change to notStarted
        if let previous = previousState {
            let stateChange = TranscriptionStateChange(
                memoId: memoId,
                previousState: previous,
                currentState: .notStarted
            )
            stateChangesSubject.send(stateChange)
        }

        logger.info("Deleted transcription data for memo (SwiftData)", category: .repository, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]))
    }

    func getTranscriptionText(for memoId: UUID) async -> String? {
        let state = await getTranscriptionState(for: memoId)
        return state.text
    }

    func saveTranscriptionText(_ text: String, for memoId: UUID) async {
        await saveTranscriptionState(.completed(text), for: memoId)
    }

    func getTranscriptionMetadata(for memoId: UUID) async -> TranscriptionMetadata? {
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
            originalText: state.text,
            lastUpdated: model.lastUpdated,
            detectedLanguage: model.language
        )
    }

    func saveTranscriptionMetadata(_ metadata: TranscriptionMetadata, for memoId: UUID) async {
        let existing = await getTranscriptionMetadata(for: memoId)
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

    func clearTranscriptionCache() async {
        transcriptionStatesSubject.send([:])
        logger.debug("Cleared transcription cache", category: .repository, context: LogContext())
    }

    func getTranscriptionStates(for memoIds: [UUID]) async -> [UUID: TranscriptionState] {
        guard !memoIds.isEmpty else { return [:] }
        var result: [UUID: TranscriptionState] = [:]
        // Use cache first
        let states = transcriptionStatesSubject.value
        for id in memoIds {
            let key = memoIdKey(for: id)
            if let cached = states[key] { result[id] = cached }
        }
        let missing = memoIds.filter { result[$0] == nil }
        guard !missing.isEmpty else { return result }
        // Query store for missing in a single fetch
        if let models = try? context.fetch(FetchDescriptor<TranscriptionModel>()) {
            for model in models {
                let id = model.memo?.id ?? model.id
                if missing.contains(id) {
                    result[id] = mapModelToState(model)
                }
            }
        }
        return result
    }
}
