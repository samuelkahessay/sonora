import XCTest
@testable import Sonora

final class PromptLocalizationGenerationTests: XCTestCase {
    func testCatalogLocalizationStringsAreGenerated() throws {
        let definitions = PromptCatalogStatic.promptDefinitions()
        XCTAssertFalse(definitions.isEmpty, "Prompt catalog should not be empty")
        let expectedKeys = Set(definitions.map { $0.prompt.localizationKey })

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Prompts
            .deletingLastPathComponent() // SonoraTests
            .deletingLastPathComponent()
        let stringsURL = repoRoot
            .appendingPathComponent("Sonora")
            .appendingPathComponent("Localizable.strings")

        let content = try String(contentsOf: stringsURL, encoding: .utf8)
        guard
            let beginRange = content.range(of: "/* === AUTO-GENERATED PROMPTS BEGIN === */"),
            let endRange = content.range(of: "/* === AUTO-GENERATED PROMPTS END === */"),
            beginRange.upperBound < endRange.lowerBound
        else {
            XCTFail("Localization file missing auto-generated prompt markers: \(stringsURL.path)")
            return
        }

        let generatedSection = content[beginRange.upperBound..<endRange.lowerBound]
        let foundKeys = Set(generatedSection.split(separator: "\n").compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"") else { return nil }
            let parts = trimmed.split(separator: "\"", omittingEmptySubsequences: true)
            return parts.first
        })

        if expectedKeys != foundKeys {
            let missing = expectedKeys.subtracting(foundKeys)
            let extra = foundKeys.subtracting(expectedKeys)
            var message = "Prompt localization block is out of date. Run ./ci_scripts/generate_prompt_strings.sh\n"
            if !missing.isEmpty {
                message += "Missing keys: \(missing.sorted()).\n"
            }
            if !extra.isEmpty {
                message += "Unexpected keys: \(extra.sorted()).\n"
            }
            XCTFail(message)
        }
    }
}
