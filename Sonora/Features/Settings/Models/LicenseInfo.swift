import Foundation

struct LicenseInfo: Identifiable, Hashable {
    let id: String
    let libraryName: String
    let copyright: String
    let licenseType: String
    let licenseText: String

    init(id: String? = nil, libraryName: String, copyright: String, licenseType: String, licenseText: String) {
        self.id = id ?? libraryName
        self.libraryName = libraryName
        self.copyright = copyright
        self.licenseType = licenseType
        self.licenseText = licenseText
    }
}

extension LicenseInfo {
    // WhisperKit (MIT) and Phi‑4 Mini (MIT)
    static let all: [LicenseInfo] = [
        LicenseInfo(
            libraryName: "WhisperKit",
            copyright: "© 2024 Argmax, Inc.",
            licenseType: "MIT License",
            licenseText: Self.mitText(
                holder: "Argmax, Inc.",
                year: "2024",
                project: "WhisperKit"
            )
        ),
        LicenseInfo(
            libraryName: "Phi‑4 Mini",
            copyright: "© Microsoft Corporation",
            licenseType: "MIT License",
            licenseText: Self.mitText(
                holder: "Microsoft Corporation",
                year: "",
                project: "Phi‑4 Mini"
            )
        )
    ]

    // Returns a standard MIT license text personalized for the holder/year
    private static func mitText(holder: String, year: String, project: String) -> String {
        let copyrightLine: String
        if year.isEmpty {
            copyrightLine = "Copyright (c) \(holder)"
        } else {
            copyrightLine = "Copyright (c) \(year) \(holder)"
        }
        return """
        \(project)\n\n\(copyrightLine)\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.
        """
    }
}

