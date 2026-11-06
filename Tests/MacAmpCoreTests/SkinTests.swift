import XCTest
@testable import MacAmpCore
final class SkinTests: XCTestCase {
    func testBuiltInsDefineEveryToken() {
        for skin in Skin.builtIn {
            let resolved = SkinLibrary.resolved(skin.id, in: Skin.builtIn)
            for token in Skin.tokens { XCTAssertNotNil(SkinLibrary.rgba(resolved.colors[token.name] ?? ""), "\(skin.name) \(token.name)") }
        }
    }
    func testFileSkinInheritsAndOverrides() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try ##"{"name":"Blue","basedOn":"cassette","colors":{"display":"#0000FF"}}"##.write(to: folder.appendingPathComponent("blue.json"), atomically: true, encoding: .utf8)
        try "not json".write(to: folder.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)
        let skins = SkinLibrary.all(in: folder)
        XCTAssertEqual(skins.map(\.id), ["classic", "cassette", "file:blue.json"])
        let blue = SkinLibrary.resolved("file:blue.json", in: skins)
        XCTAssertEqual(blue.face, .cassette)
        XCTAssertEqual(blue.colors["display"], "#0000FF")
        XCTAssertEqual(blue.colors["tape"], Skin.cassette.colors["tape"])
    }
    func testExampleIsValidAndUnknownFallsBack() throws {
        let example = try JSONDecoder().decode(Skin.self, from: Data(SkinLibrary.exampleJSON().utf8))
        XCTAssertEqual(example.colors.count, Skin.tokens.count)
        XCTAssertEqual(SkinLibrary.resolved("file:gone.json", in: Skin.builtIn).id, "classic")
        XCTAssertEqual(SkinLibrary.rgba("#FF000080")?.alpha ?? 0, 128.0/255, accuracy: 0.001)
        XCTAssertNil(SkinLibrary.rgba("#XYZ"))
    }
    func testOldSessionsStillDecode() throws {
        var session = Session(); session.tracks = [Track(url: URL(fileURLWithPath: "/tmp/a.mp3"))]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        json.removeValue(forKey: "skin")
        let decoded = try JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.tracks.count, 1); XCTAssertNil(decoded.skin)
    }
}
