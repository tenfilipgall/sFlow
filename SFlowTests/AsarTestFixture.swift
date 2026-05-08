import Foundation

func makeAsarData(files: [(path: String, content: String)]) -> Data {
    var offset = 0
    var filesDict: [String: Any] = [:]
    var fileDataParts: [Data] = []
    for (path, content) in files {
        let data = Data(content.utf8)
        filesDict[path] = ["offset": "\(offset)", "size": data.count]
        offset += data.count
        fileDataParts.append(data)
    }
    let headerJSON = try! JSONSerialization.data(withJSONObject: ["files": filesDict])
    let jsonBytes = Array(headerJSON)
    let L = jsonBytes.count
    let paddedL = (L + 3) & ~3
    let P = 4 + paddedL
    let S = 4 + P
    func uint32LE(_ v: Int) -> [UInt8] {
        let u = UInt32(v)
        return [UInt8(u & 0xFF), UInt8((u >> 8) & 0xFF), UInt8((u >> 16) & 0xFF), UInt8((u >> 24) & 0xFF)]
    }
    var bytes = [UInt8]()
    bytes += uint32LE(4)
    bytes += uint32LE(S)
    bytes += uint32LE(P)
    bytes += uint32LE(L)
    bytes += jsonBytes
    bytes += [UInt8](repeating: 0, count: paddedL - L)
    for data in fileDataParts { bytes += Array(data) }
    return Data(bytes)
}

func writeAsar(files: [(path: String, content: String)]) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".asar")
    try! makeAsarData(files: files).write(to: url)
    return url
}
