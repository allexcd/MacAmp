import Foundation

/// A skin is a named set of colors plus a player "face" (layout). Skins are JSON files:
///
///     { "name": "Midnight", "face": "classic", "basedOn": "classic",
///       "colors": { "display": "#7FD0FF", "panelTop": "#20242C" } }
///
/// Any color left out falls back to the `basedOn` skin, then to Classic.
public struct Skin: Codable, Equatable, Identifiable, Sendable {
    public enum Face: String, Codable, Sendable { case classic, cassette }
    /// "classic", "cassette", or "file:<name>.json" for skins in the Skins folder.
    public var id = ""
    public var name: String
    public var face: Face?
    public var basedOn: String?
    public var colors: [String: String]
    enum CodingKeys: String, CodingKey { case name, face, basedOn, colors }

    public init(id: String, name: String, face: Face? = nil, basedOn: String? = nil, colors: [String: String]) {
        self.id = id; self.name = name; self.face = face; self.basedOn = basedOn; self.colors = colors
    }

    /// Every color a skin can set, with what it paints.
    public static let tokens: [(name: String, use: String)] = [
        ("display", "LCD text, spectrum base, playlist titles"),
        ("displayBackground", "LCD, playlist and slider backgrounds"),
        ("displayDim", "secondary LCD text (track numbers, formats)"),
        ("displayHighlight", "the playing track's title"),
        ("playingRow", "background of the playing playlist row"),
        ("panelTop", "window gradient, top-left"),
        ("panelMid", "window gradient, middle"),
        ("panelBottom", "window gradient, bottom-right"),
        ("border", "window outline and title-bar lines"),
        ("text", "window titles and labels"),
        ("panelAccent", "highlighted labels on the window body (EQ values, track count)"),
        ("buttonTop", "button gradient, top"),
        ("buttonBottom", "button gradient, bottom"),
        ("buttonPressed", "pressed button"),
        ("buttonText", "button labels"),
        ("sliderFillStart", "slider fill, left"),
        ("sliderFillEnd", "slider fill, right"),
        ("knob", "slider and fader knobs"),
        ("spectrumHigh", "spectrum bar tops"),
        ("spectrumMid", "spectrum bar middles"),
        ("cassetteShell", "cassette body (cassette face)"),
        ("cassetteLabel", "cassette label (cassette face)"),
        ("cassetteStripe1", "label stripe (cassette face)"),
        ("cassetteStripe2", "label stripe (cassette face)"),
        ("cassetteInk", "handwriting on the label (cassette face)"),
        ("tape", "tape ribbon and reel packs (cassette face)"),
        ("reel", "reel hubs (cassette face)"),
        ("deck", "tape-well background behind the cassette (cassette face)")
    ]

    public static let classic = Skin(id: "classic", name: "Classic", face: .classic, colors: [
        "display": "#80F247", "displayBackground": "#000000", "displayDim": "#808080", "displayHighlight": "#FFFFFF",
        "playingRow": "#173D0D", "panelTop": "#4A4D59E6", "panelMid": "#212121", "panelBottom": "#4A4D59",
        "border": "#A6A6A6", "text": "#DBDBDB", "panelAccent": "#80F247", "buttonTop": "#999999", "buttonBottom": "#4A4D59",
        "buttonPressed": "#000000", "buttonText": "#FFFFFF", "sliderFillStart": "#408C33", "sliderFillEnd": "#FFFF00",
        "knob": "#D9D9D9", "spectrumHigh": "#FF0000", "spectrumMid": "#FFFF00",
        "cassetteShell": "#2A2A2E", "cassetteLabel": "#EDE6D3", "cassetteStripe1": "#E07A1F", "cassetteStripe2": "#C0392B",
        "cassetteInk": "#1F2A6B", "tape": "#3B2416", "reel": "#F2F2F2", "deck": "#111111"
    ])

    /// A 70s silver tape deck: brushed aluminium, amber counter, smoked cassette with a cream label.
    public static let cassette = Skin(id: "cassette", name: "Cassette Deck", face: .cassette, basedOn: "classic", colors: [
        "display": "#FFB238", "displayBackground": "#1A120C", "displayDim": "#8C6A3F", "displayHighlight": "#FFE7B8",
        "playingRow": "#43290F", "panelTop": "#D9D8D2", "panelMid": "#A3A29C", "panelBottom": "#C4C3BD",
        "border": "#5E5D58", "text": "#2B2A27", "panelAccent": "#9A4A12", "buttonTop": "#F2F1EC", "buttonBottom": "#9E9D97",
        "buttonPressed": "#6E6D68", "buttonText": "#1E1E1C", "sliderFillStart": "#B5651D", "sliderFillEnd": "#FFB238",
        "knob": "#F7F6F1", "spectrumHigh": "#FF4A1C", "spectrumMid": "#FFB238",
        "cassetteShell": "#2B2A2ED9", "cassetteLabel": "#F1E9D2", "cassetteStripe1": "#E8892B", "cassetteStripe2": "#C2412D",
        "cassetteInk": "#22306E", "tape": "#3A2213", "reel": "#F4F4F0", "deck": "#121110"
    ])

    public static let builtIn = [classic, cassette]
}

public enum SkinLibrary {
    /// Built-in skins followed by valid JSON skins from `folder` (invalid files are skipped).
    public static func all(in folder: URL?) -> [Skin] {
        var skins = Skin.builtIn
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return skins }
        for file in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) where file.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: file), var skin = try? JSONDecoder().decode(Skin.self, from: data) else { continue }
            skin.id = "file:" + file.lastPathComponent
            skins.append(skin)
        }
        return skins
    }

    /// Flattens `basedOn` chains so every token has a value. Unknown ids fall back to Classic.
    public static func resolved(_ id: String?, in skins: [Skin]) -> Skin {
        var skin = skins.first { $0.id == id } ?? Skin.classic
        var colors = skin.colors
        var face = skin.face
        var seen: Set<String> = [skin.id]
        var base = skin.basedOn
        while let next = base, !seen.contains(next), let parent = skins.first(where: { $0.id == next || $0.name == next }) {
            seen.insert(parent.id)
            colors.merge(parent.colors) { mine, _ in mine }
            face = face ?? parent.face
            base = parent.basedOn
        }
        colors.merge(Skin.classic.colors) { mine, _ in mine }
        skin.colors = colors; skin.face = face ?? .classic
        return skin
    }

    /// Parses "#RRGGBB" or "#RRGGBBAA" into 0...1 components.
    public static func rgba(_ hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let full = text.count == 6 ? value << 8 | 0xFF : value
        return (Double(full >> 24 & 0xFF) / 255, Double(full >> 16 & 0xFF) / 255, Double(full >> 8 & 0xFF) / 255, Double(full & 0xFF) / 255)
    }

    /// A commented starting point users can copy, written into the Skins folder.
    public static func exampleJSON() -> String {
        let colors = Skin.tokens.map { token in
            "    \"\(token.name)\": \"\(Skin.cassette.colors[token.name] ?? Skin.classic.colors[token.name]!)\""
        }.joined(separator: ",\n")
        return "{\n  \"name\": \"My Tape Deck\",\n  \"face\": \"cassette\",\n  \"basedOn\": \"cassette\",\n  \"colors\": {\n\(colors)\n  }\n}\n"
    }

    public static func readme() -> String {
        """
        Mac-Amp skins
        =============
        Put .json skin files in this folder, then pick them from the Skins menu
        (the menu re-reads this folder each time it opens).

        {
          "name": "Shown in the Skins menu",
          "face": "classic" or "cassette",
          "basedOn": "classic", "cassette", or another skin's name (optional),
          "colors": { "<token>": "#RRGGBB" or "#RRGGBBAA", ... }
        }

        Colors you leave out come from the basedOn skin, then from Classic.
        "Example.json" lists every color token with the Cassette Deck values.

        Tokens:
        \(Skin.tokens.map { "  \($0.name) — \($0.use)" }.joined(separator: "\n"))
        """
    }
}
