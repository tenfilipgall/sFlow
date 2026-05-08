import Foundation

struct AsarFile {
    let path: String
    let offset: UInt64
    let size: Int
}

enum AsarReader {

    /// Parses the .asar binary header and returns a flat file list + data section offset.
    /// Returns nil if the file is missing, too short, or has invalid JSON.
    static func readHeader(from url: URL) -> (files: [AsarFile], dataOffset: UInt64)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // Read outer pickle (8 bytes): bytes 0-3 = always 4, bytes 4-7 = S (inner pickle size)
        guard let first8 = try? handle.read(upToCount: 8), first8.count == 8 else { return nil }
        let S = first8.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }

        // Read inner pickle (S bytes starting at position 8)
        guard let inner = try? handle.read(upToCount: Int(S)), inner.count == Int(S) else { return nil }

        // Inner pickle: bytes 0-3 = payload size (P), bytes 4-7 = JSON string length (L)
        guard inner.count >= 8 else { return nil }
        let L = inner.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
        guard inner.count >= 8 + Int(L) else { return nil }

        let jsonData = inner[8 ..< (8 + Int(L))]
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let root = json["files"] as? [String: Any] else { return nil }

        var files: [AsarFile] = []
        flatten(root, prefix: "", into: &files)
        return (files: files, dataOffset: UInt64(8 + S))
    }

    /// Reads the raw bytes of a single file from the archive.
    static func readFile(_ entry: AsarFile, in url: URL, dataOffset: UInt64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: dataOffset + entry.offset)) != nil else { return nil }
        return try? handle.read(upToCount: entry.size)
    }

    // MARK: - Private

    private static func flatten(_ dict: [String: Any], prefix: String, into files: inout [AsarFile]) {
        for (name, value) in dict {
            guard let info = value as? [String: Any] else { continue }
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if let nested = info["files"] as? [String: Any] {
                flatten(nested, prefix: path, into: &files)
            } else if info["unpacked"] as? Bool != true,
                      let offsetStr = info["offset"] as? String,
                      let offset = UInt64(offsetStr),
                      let size = info["size"] as? Int {
                files.append(AsarFile(path: path, offset: offset, size: size))
            }
        }
    }
}
