import XCTest
@testable import Sonora

final class PromptLocalizationGenerationTests: XCTestCase {
    func testCatalogLocalizationStringsAreGenerated() throws {
        struct FilePrompt: Decodable { let id: String; let text: String }

        // Locate the NDJSON in the repo for expected values
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Prompts
            .deletingLastPathComponent() // SonoraTests
            .deletingLastPathComponent()

        let promptsURL = repoRoot
            .appendingPathComponent("Sonora")
            .appendingPathComponent("Resources")
            .appendingPathComponent("prompts.ndjson")

        let fileContents = try String(contentsOf: promptsURL, encoding: .utf8)
        let decoder = JSONDecoder()

        // Build expected (key, text) pairs by mirroring PromptFileLoader's mapping
        let expected: [(key: String, text: String)] = fileContents
            .split(whereSeparator: { $0.isNewline })
            .compactMap { rawLine -> (String, String)? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("//") else { return nil }
                guard let data = line.data(using: .utf8),
                      let prompt = try? decoder.decode(FilePrompt.self, from: data) else { return nil }
                let parts = prompt.id.split(separator: "_")
                guard parts.count >= 2 else { return nil }
                let category = parts.first!.lowercased()
                let slug = parts.dropFirst().joined(separator: "-").lowercased()
                return ("prompt.\(category).\(slug)", prompt.text)
            }

        XCTAssertFalse(expected.isEmpty, "Prompt catalog should not be empty")

        // Verify provider resolves each key to the file-backed text
        let provider = DefaultLocalizationProvider()
        var mismatches: [(String, String, String)] = [] // (key, expected, actual)
        for (key, expectedText) in expected {
            let actual = provider.localizedString(key, locale: Locale(identifier: "en_US"))
            if actual != expectedText {
                mismatches.append((key, expectedText, actual))
            }
        }

        if !mismatches.isEmpty {
            let preview = mismatches.prefix(10)
                .map { "\($0.0) => expected=\($0.1) actual=\($0.2)" }
                .joined(separator: "\n")
            XCTFail("\(mismatches.count) prompt localization mismatches found.\n\(preview)")
        }
    }
}
