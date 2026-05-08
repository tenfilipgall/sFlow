import XCTest
@testable import SFlow

final class AsarReaderTests: XCTestCase {

    // MARK: - Fixture helpers

    private func makeAsarData(files: [(path: String, content: String)]) -> Data {
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
            let u = UInt32(v); return [UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]
        }
        var bytes = [UInt8]()
        bytes += uint32LE(4); bytes += uint32LE(S); bytes += uint32LE(P); bytes += uint32LE(L)
        bytes += jsonBytes; bytes += [UInt8](repeating: 0, count: paddedL - L)
        for data in fileDataParts { bytes += Array(data) }
        return Data(bytes)
    }

    private func writeAsar(files: [(path: String, content: String)]) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".asar")
        try! makeAsarData(files: files).write(to: url)
        return url
    }

    // MARK: - Tests

    func test_readHeader_singleFile_returnsEntry() {
        let url = writeAsar(files: [("test.js", "hello world")])
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else {
            XCTFail("readHeader returned nil"); return
        }
        XCTAssertEqual(result.files.count, 1)
        guard let file = result.files.first(where: { $0.path == "test.js" }) else {
            XCTFail("test.js not found in file list"); return
        }
        XCTAssertEqual(file.size, 11)
        XCTAssertEqual(file.offset, 0)
    }

    func test_readHeader_dataOffset_isCorrect() {
        let url = writeAsar(files: [("a.js", "hi")])
        defer { try? FileManager.default.removeItem(at: url) }
        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        let data = try! Data(contentsOf: url)
        let fileBytes = data[Int(result.dataOffset)...]
        XCTAssertEqual(fileBytes.prefix(2), Data("hi".utf8))
    }

    func test_readHeader_nestedDirectory_flattensPath() {
        let json = #"{"files":{"app":{"files":{"main.js":{"offset":"0","size":5}}}}}"#
        let jsonBytes = Array(json.utf8)
        let L = jsonBytes.count
        let paddedL = (L + 3) & ~3
        let P = 4 + paddedL; let S = 4 + P
        func u32(_ v: Int) -> [UInt8] {
            let u=UInt32(v); return [UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]
        }
        var bytes = [UInt8]()
        bytes += u32(4); bytes += u32(S); bytes += u32(P); bytes += u32(L)
        bytes += jsonBytes; bytes += [UInt8](repeating:0,count:paddedL-L)
        bytes += Array("hello".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "app/main.js")
    }

    func test_readHeader_malformedData_returnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data([0,1,2,3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(AsarReader.readHeader(from: url))
    }

    func test_readHeader_unpackedFile_isSkipped() {
        let json = #"{"files":{"packed.js":{"offset":"0","size":5},"skip.js":{"offset":"5","size":3,"unpacked":true}}}"#
        let jsonBytes = Array(json.utf8)
        let L = jsonBytes.count; let paddedL = (L+3) & ~3
        let P = 4+paddedL; let S = 4+P
        func u32(_ v:Int)->[UInt8]{let u=UInt32(v);return[UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]}
        var bytes=[UInt8](); bytes+=u32(4); bytes+=u32(S); bytes+=u32(P); bytes+=u32(L)
        bytes+=jsonBytes; bytes+=[UInt8](repeating:0,count:paddedL-L); bytes+=Array("hellobye".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "packed.js")

        // Verify packed file data is readable and correct
        if let packedFile = result.files.first(where: { $0.path == "packed.js" }) {
            let data = AsarReader.readFile(packedFile, in: url, dataOffset: result.dataOffset)
            XCTAssertEqual(data, Data("hello".utf8))
        }
    }
}
