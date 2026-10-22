import Compression
import Foundation

/// A tiny, read-only ZIP reader that extracts the human-readable text of
/// Office Open XML containers (xlsx, pptx) without unpacking anything to disk.
/// It understands only what it needs: the central directory and DEFLATE/stored
/// entries. Anything unexpected returns `nil`/empty rather than throwing.
struct ZipTextPeek {
    private struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    init?(data: Data) {
        guard data.count > 22 else { return nil }
        self.data = data

        // End Of Central Directory: scan the tail for its signature.
        let tailStart = max(0, data.count - 66_000)
        var eocd: Int?
        var index = data.count - 22
        while index >= tailStart {
            if data.uint32(at: index) == 0x0605_4b50 { eocd = index; break }
            index -= 1
        }
        guard let eocd else { return nil }

        let count = Int(data.uint16(at: eocd + 10))
        var cursor = Int(data.uint32(at: eocd + 16))
        var parsed: [String: Entry] = [:]
        for _ in 0..<count {
            guard cursor + 46 <= data.count, data.uint32(at: cursor) == 0x0201_4b50 else { break }
            let method = data.uint16(at: cursor + 10)
            let compressed = Int(data.uint32(at: cursor + 20))
            let uncompressed = Int(data.uint32(at: cursor + 24))
            let nameLength = Int(data.uint16(at: cursor + 28))
            let extraLength = Int(data.uint16(at: cursor + 30))
            let commentLength = Int(data.uint16(at: cursor + 32))
            let offset = Int(data.uint32(at: cursor + 42))
            guard cursor + 46 + nameLength <= data.count else { break }
            let nameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            if let name = String(data: nameData, encoding: .utf8) {
                parsed[name] = Entry(
                    name: name,
                    method: method,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed,
                    localOffset: offset
                )
            }
            cursor += 46 + nameLength + extraLength + commentLength
        }
        guard !parsed.isEmpty else { return nil }
        self.entries = parsed
    }

    /// Text of the shared strings (xlsx) or the first slides (pptx).
    func readableText() -> String {
        var chunks: [String] = []
        if let shared = read("xl/sharedStrings.xml") {
            chunks.append(Self.extractRuns(from: shared, tag: "t", limit: 4_000))
        }
        for slide in 1...4 {
            if let xml = read("ppt/slides/slide\(slide).xml") {
                chunks.append(Self.extractRuns(from: xml, tag: "a:t", limit: 1_500))
            }
        }
        return chunks.joined(separator: "\n")
    }

    private func read(_ name: String) -> String? {
        guard let entry = entries[name] else { return nil }
        let header = entry.localOffset
        guard header + 30 <= data.count, data.uint32(at: header) == 0x0403_4b50 else { return nil }
        let nameLength = Int(data.uint16(at: header + 26))
        let extraLength = Int(data.uint16(at: header + 28))
        let start = header + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { return nil }
        let payload = data.subdata(in: start..<(start + entry.compressedSize))

        let output: Data
        switch entry.method {
        case 0:
            output = payload
        case 8:
            let capacity = min(max(entry.uncompressedSize, 1), 2_000_000)
            var buffer = [UInt8](repeating: 0, count: capacity)
            let written = payload.withUnsafeBytes { source -> Int in
                guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(&buffer, capacity, base, payload.count, nil, COMPRESSION_ZLIB)
            }
            guard written > 0 else { return nil }
            output = Data(buffer.prefix(written))
        default:
            return nil
        }
        return String(data: output, encoding: .utf8)
    }

    private static func extractRuns(from xml: String, tag: String, limit: Int) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)(?: [^>]*)?>([^<]*)</\(tag)>"
        ) else { return "" }
        let range = NSRange(xml.startIndex..., in: xml)
        var result = ""
        for match in regex.matches(in: xml, range: range) {
            guard let capture = Range(match.range(at: 1), in: xml) else { continue }
            result += xml[capture] + " "
            if result.count >= limit { break }
        }
        return result
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }.littleEndian
    }

    func uint32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }
}
