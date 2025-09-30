import XCTest
import SwiftUI

// MARK: - Snapshot Utilities

enum SnapshotAppearance: String { case light, dark }

final class Snapshotter {
    static let shared = Snapshotter()
    private init() {}

    // Standard iPhone size for consistency (points)
    let snapshotSize = CGSize(width: 390, height: 844) // iPhone 15

    func image<V: View>(for view: V, appearance: SnapshotAppearance) -> UIImage {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: snapshotSize))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds
        controller.view.isOpaque = false

        // Force light/dark appearance
        controller.overrideUserInterfaceStyle = (appearance == .dark) ? .dark : .light
        window.overrideUserInterfaceStyle = controller.overrideUserInterfaceStyle

        // Disable animations during snapshot
        UIView.setAnimationsEnabled(false)
        controller.view.layoutIfNeeded()
        defer { UIView.setAnimationsEnabled(true) }

        let renderer = UIGraphicsImageRenderer(size: snapshotSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - Baseline Management

struct BaselineManager {
    // Baselines live under the test bundle resources: Baselines/<Class>/<name>__<appearance>.png
    static func baselineURL(testCase: XCTestCase, name: String, appearance: SnapshotAppearance) -> URL? {
        let bundle = Bundle(for: type(of: testCase))
        guard let base = bundle.resourceURL?.appendingPathComponent("Baselines", isDirectory: true) else { return nil }
        let classDir = base.appendingPathComponent(String(describing: type(of: testCase)), isDirectory: true)
        let file = classDir.appendingPathComponent("\(name)__\(appearance.rawValue).png")
        return file
    }

    static func loadBaseline(testCase: XCTestCase, name: String, appearance: SnapshotAppearance) -> UIImage? {
        guard let url = baselineURL(testCase: testCase, name: name, appearance: appearance) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func recordBaseline(testCase: XCTestCase, name: String, appearance: SnapshotAppearance, image: UIImage) throws -> URL {
        // Prefer writing to DerivedData mirror of Baselines folder when recording.
        // Fallback to temporary directory and print copy instructions.
        let env = ProcessInfo.processInfo.environment
        let allowWrite = env["RECORD_SNAPSHOTS"] == "1"
        guard allowWrite else { throw NSError(domain: "Snapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording disabled. Set RECORD_SNAPSHOTS=1 to update baselines."]) }

        // Attempt to mirror bundle Baselines path under the current working dir if available
        if let srcPath = Bundle(for: type(of: testCase)).path(forResource: "Baselines", ofType: nil) {
            let baseDir = URL(fileURLWithPath: srcPath).deletingLastPathComponent().appendingPathComponent("Baselines", isDirectory: true)
            let classDir = baseDir.appendingPathComponent(String(describing: type(of: testCase)), isDirectory: true)
            try FileManager.default.createDirectory(at: classDir, withIntermediateDirectories: true)
            let file = classDir.appendingPathComponent("\(name)__\(appearance.rawValue).png")
            if let data = image.pngData() { try data.write(to: file, options: .atomic) }
            return file
        }

        // Fallback temp write
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let classDir = tmp.appendingPathComponent(String(describing: type(of: testCase)), isDirectory: true)
        try FileManager.default.createDirectory(at: classDir, withIntermediateDirectories: true)
        let file = classDir.appendingPathComponent("\(name)__\(appearance.rawValue).png")
        if let data = image.pngData() { try data.write(to: file, options: .atomic) }
        return file
    }
}

// MARK: - Diffing

struct SnapshotDiffResult {
    let matches: Bool
    let differenceCount: Int
    let totalPixels: Int
}

func compare(_ a: UIImage, _ b: UIImage) -> SnapshotDiffResult {
    guard let aCG = a.cgImage, let bCG = b.cgImage, aCG.width == bCG.width, aCG.height == bCG.height else {
        return .init(matches: false, differenceCount: Int.max, totalPixels: 0)
    }
    let width = aCG.width
    let height = aCG.height
    let total = width * height

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let byteCount = bytesPerRow * height

    var aData = [UInt8](repeating: 0, count: byteCount)
    var bData = [UInt8](repeating: 0, count: byteCount)
    guard let aCtx = CGContext(data: &aData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let bCtx = CGContext(data: &bData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return .init(matches: false, differenceCount: Int.max, totalPixels: total)
    }
    aCtx.draw(aCG, in: CGRect(x: 0, y: 0, width: width, height: height))
    bCtx.draw(bCG, in: CGRect(x: 0, y: 0, width: width, height: height))

    var diffs = 0
    for i in stride(from: 0, to: byteCount, by: bytesPerPixel) {
        if aData[i] != bData[i] || aData[i+1] != bData[i+1] || aData[i+2] != bData[i+2] || aData[i+3] != bData[i+3] {
            diffs += 1
        }
    }
    return .init(matches: diffs == 0, differenceCount: diffs, totalPixels: total)
}

// MARK: - Base TestCase

class SnapshotTestCase: XCTestCase {
    func assertSnapshot<V: View>(_ view: V, name: String, appearance: SnapshotAppearance, file: StaticString = #file, line: UInt = #line) {
        let image = Snapshotter.shared.image(for: view, appearance: appearance)

        // Attach actual image
        let actualAttachment = XCTAttachment(image: image)
        actualAttachment.name = "Actual_\(name)_\(appearance.rawValue)"
        actualAttachment.lifetime = .keepAlways
        add(actualAttachment)

        guard let baseline = BaselineManager.loadBaseline(testCase: self, name: name, appearance: appearance) else {
            // Optionally record
            if let url = try? BaselineManager.recordBaseline(testCase: self, name: name, appearance: appearance, image: image) {
                let note = XCTAttachment(string: "Recorded baseline at: \(url.path) — commit it to Baselines")
                note.lifetime = .keepAlways
                add(note)
            }
            XCTFail("Missing baseline for \(name) [\(appearance.rawValue)]. Set RECORD_SNAPSHOTS=1 to generate.", file: file, line: line)
            return
        }

        let result = compare(image, baseline)
        if !result.matches {
            // Attach baseline for comparison
            let expectedAttachment = XCTAttachment(image: baseline)
            expectedAttachment.name = "Expected_\(name)_\(appearance.rawValue)"
            expectedAttachment.lifetime = .keepAlways
            add(expectedAttachment)

            let summary = "Pixels differed: \(result.differenceCount) / \(result.totalPixels)"
            add(XCTAttachment(string: summary))
            XCTFail("Snapshot mismatch for \(name) [\(appearance.rawValue)] — \(summary)", file: file, line: line)
        }
    }
}
