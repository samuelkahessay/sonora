import Foundation

struct MultipartForm {
    private enum Part {
        case data(Data)
        case file(header: Data, url: URL)
    }

    let boundary = "Boundary-\(UUID().uuidString)"
    private var parts: [Part] = []

    mutating func addFileField(name: String, filename: String, mimeType: String, fileURL: URL) throws {
        var header = Data()
        header.append("--\(boundary)\r\n")
        header.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        header.append("Content-Type: \(mimeType)\r\n\r\n")
        parts.append(.file(header: header, url: fileURL))
    }

    mutating func addTextField(name: String, value: String) {
        var data = Data()
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.append("\(value)\r\n")
        parts.append(.data(data))
    }

    /// Materialize the multipart body in memory.
    /// Retained for compatibility in tests and diagnostics.
    func finalize() throws -> Data {
        var body = Data()
        for part in parts {
            switch part {
            case .data(let data):
                body.append(data)
            case .file(let header, let url):
                body.append(header)
                body.append(try Data(contentsOf: url))
                body.append("\r\n")
            }
        }
        body.append("--\(boundary)--\r\n")
        return body
    }

    /// Writes the multipart body to a temporary file to avoid loading large audio chunks into memory.
    /// - Returns: The file URL and the resulting file length, if available.
    func writeBodyToTemporaryFile(bufferSize: Int = 256 * 1024) throws -> (url: URL, length: UInt64?) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipart-\(UUID().uuidString)", isDirectory: false)

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        for part in parts {
            switch part {
            case .data(let data):
                handle.write(data)
            case .file(let header, let url):
                handle.write(header)
                try writeFileContents(of: url, to: handle, bufferSize: bufferSize)
                handle.write(Data("\r\n".utf8))
            }
        }

        handle.write(Data("--\(boundary)--\r\n".utf8))
        try handle.synchronize()

        let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
        let length = (attributes?[.size] as? NSNumber)?.uint64Value
        return (tempURL, length)
    }

    private func writeFileContents(of url: URL, to handle: FileHandle, bufferSize: Int) throws {
        let readHandle = try FileHandle(forReadingFrom: url)
        defer { try? readHandle.close() }

        while true {
            let chunk = try readHandle.read(upToCount: bufferSize)
            guard let chunk, !chunk.isEmpty else { break }
            handle.write(chunk)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) { self.append(Data(string.utf8)) }
}
