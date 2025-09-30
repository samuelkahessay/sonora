import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Share Functionality Methods (moved)

extension MemoDetailViewModel {
    /// Prepare share content based on selected options
    /// Build share items asynchronously, creating files as needed.
    fileprivate func buildShareItems() async -> [Any] {
        guard let memo = currentMemo else { return [] }
        var shareItems: [Any] = []
        lastShareTempURLs.removeAll()

        // Add audio file if selected (copy to temp with friendly name and wrap as provider)
        if shareAudioEnabled {
            let ext = memo.fileExtension
            let filename = memo.preferredShareableFileName + ".\(ext)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: tempURL.path) { try fm.removeItem(at: tempURL) }
                try fm.copyItem(at: memo.fileURL, to: tempURL)
                lastShareTempURLs.append(tempURL)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: tempURL as NSSecureCoding, typeIdentifier: UTType.mpeg4Audio.identifier)
                    provider.suggestedName = filename
                    shareItems.append(provider)
                } else {
                    shareItems.append(tempURL)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating temp audio share file: \(error.localizedDescription)")
                // Fallback to original URL if copy fails
                shareItems.append(memo.fileURL)
            }
        }

        // Add transcription as a .txt file if selected and available
        if shareTranscriptionEnabled, let transcriptText = transcriptionText {
            let formatted = formatTranscriptionForSharing(text: transcriptText)
            do {
                let url = try await createTranscriptShareFileUseCase.execute(memo: memo, text: formatted)
                lastShareTempURLs.append(url)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: url as NSSecureCoding, typeIdentifier: UTType.plainText.identifier)
                    provider.suggestedName = memo.preferredShareableFileName + ".txt"
                    shareItems.append(provider)
                } else {
                    shareItems.append(url)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating transcript file: \(error.localizedDescription)")
            }
        }

        // Add AI analysis as a consolidated .txt file if enabled and available
        if shareAnalysisEnabled {
            do {
                // With Distill-only analysis, restrict export to Distill content
                let url = try await createAnalysisShareFileUseCase.execute(memo: memo, includeTypes: [.distill])
                lastShareTempURLs.append(url)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: url as NSSecureCoding, typeIdentifier: UTType.plainText.identifier)
                    provider.suggestedName = memo.preferredShareableFileName + "_analysis.txt"
                    shareItems.append(provider)
                } else {
                    shareItems.append(url)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating analysis share file: \(error.localizedDescription)")
            }
        }

        return shareItems
    }

    /// Prepare share items asynchronously; presentation occurs after sheet dismiss.
    func shareSelectedContent() async {
        isPreparingShare = true
        let items = await buildShareItems()
        await MainActor.run {
            self.isPreparingShare = false
            self.pendingShareItems = items
            print("📤 MemoDetailViewModel: Prepared \(items.count) share item(s)")
        }
    }

    /// Called after Share sheet (SwiftUI) dismisses, to present the system share UI
    func presentPendingShareIfReady() {
        let items = pendingShareItems
        pendingShareItems.removeAll()
        guard !items.isEmpty else {
            print("📤 MemoDetailViewModel: No items to present after dismiss")
            return
        }
        presentShareSheet(with: items)
    }

    /// Present the native iOS share sheet with items
    fileprivate func presentShareSheet(with items: [Any]) {
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Clean up any temporary transcript files regardless of completion result
        activityController.completionWithItemsHandler = { [weak self] _, _, _, _ in
            guard let self = self else { return }
            let fm = FileManager.default
            for url in self.lastShareTempURLs {
                do { if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) } } catch { print("⚠️ MemoDetailViewModel: Failed to remove temp share file: \(error)") }
            }
            self.lastShareTempURLs.removeAll()
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true) {
                print("📤 MemoDetailViewModel: Share sheet presented successfully")
            }
        }
    }

    /// Format transcription text for sharing
    fileprivate func formatTranscriptionForSharing(text: String) -> String {
        guard let memo = currentMemo else { return text }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let header = """
        \(currentMemoTitle)
        Recorded: \(dateFormatter.string(from: memo.creationDate))

        --- TRANSCRIPTION ---

        """

        return header + text
    }
}

