import SwiftUI
#if canImport(MacAmpCore)
import MacAmpCore
#endif

/// The active skin's colors as SwiftUI values. Views read it from the environment.
struct Palette {
    let face: Skin.Face
    private let colors: [String: Color]
    init(_ skin: Skin) {
        face = skin.face ?? .classic
        colors = skin.colors.compactMapValues { hex in
            SkinLibrary.rgba(hex).map { Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha) }
        }
    }
    subscript(_ token: String) -> Color { colors[token] ?? .pink }

    var display: Color { self["display"] }
    var displayBackground: Color { self["displayBackground"] }
    var displayDim: Color { self["displayDim"] }
    var displayHighlight: Color { self["displayHighlight"] }
    var playingRow: Color { self["playingRow"] }
    var border: Color { self["border"] }
    var text: Color { self["text"] }
    var panelAccent: Color { self["panelAccent"] }
    var panel: LinearGradient { LinearGradient(colors: [self["panelTop"], self["panelMid"], self["panelBottom"]], startPoint: .topLeading, endPoint: .bottomTrailing) }
    func button(pressed: Bool) -> LinearGradient {
        LinearGradient(colors: [pressed ? self["buttonPressed"] : self["buttonTop"], self["buttonBottom"]], startPoint: .top, endPoint: .bottom)
    }
    var buttonText: Color { self["buttonText"] }
    var sliderFill: LinearGradient { LinearGradient(colors: [self["sliderFillStart"], self["sliderFillEnd"]], startPoint: .leading, endPoint: .trailing) }
    var knob: LinearGradient { LinearGradient(colors: [self["knob"], self["buttonBottom"]], startPoint: .top, endPoint: .bottom) }
    var spectrum: LinearGradient { LinearGradient(colors: [self["spectrumHigh"], self["spectrumMid"], display], startPoint: .top, endPoint: .bottom) }

    static let classic = Palette(Skin.classic)
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.classic }
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
