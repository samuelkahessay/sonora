import Foundation

struct MultipartForm {
    let boundary = "Boundary-\(UUID().uuidString)"
    private var parts: [Data] = []

    mutating func addFileField(name: String, filename: String, mimeType: String, fileURL: URL) throws {
        var d = Data()
        d.append("--\(boundary)\r\n")
        d.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        d.append("Content-Type: \(mimeType)\r\n\r\n")
        d.append(try Data(contentsOf: fileURL))
        d.append("\r\n")
        parts.append(d)
    }

    mutating func addTextField(name: String, value: String) {
        var d = Data()
        d.append("--\(boundary)\r\n")
        d.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        d.append("\(value)\r\n")
        parts.append(d)
    }

    func finalize() -> Data {
        var body = Data()
        for p in parts { body.append(p) }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) { self.append(Data(string.utf8)) }
}