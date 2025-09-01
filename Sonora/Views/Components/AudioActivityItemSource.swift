import UIKit
import UniformTypeIdentifiers

/// Activity item source for sharing audio data without relying on file provider lookups.
/// This reduces system log noise about file provider domains and share modes for file URLs.
final class AudioActivityItemSource: NSObject, UIActivityItemSource {
    private let fileURL: URL
    private let filename: String

    init(fileURL: URL, filename: String) {
        self.fileURL = fileURL
        self.filename = filename
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        Data()
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        (try? Data(contentsOf: fileURL))
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if #available(iOS 14.0, *) {
            return UTType.mpeg4Audio.identifier
        } else {
            return "public.mpeg-4-audio"
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        filename
    }
}
