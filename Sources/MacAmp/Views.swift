import SwiftUI
import UniformTypeIdentifiers
#if canImport(MacAmpCore)
import MacAmpCore
#endif

let phosphor = Color(red: 0.5, green: 0.95, blue: 0.28)
let metal = Color(red: 0.29, green: 0.30, blue: 0.35)
/// Title-bar drag; Windows.drag moves the panel (and its attached panels) in screen coordinates.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func mouseDown(with event: NSEvent) {
            (window as? PlayerWindow)?.titleDrag?(event)
        }
    }
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}
struct Chrome<Content: View>: View {
    var title: String
    var close: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                HStack(spacing: 4) {
                    Rectangle().fill(.gray).frame(height: 1)
                    Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).fixedSize()
                    Rectangle().fill(.gray).frame(height: 1)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(WindowDragArea().accessibilityLabel("Drag window"))
                Button("×", action: close).buttonStyle(RetroButton()).accessibilityLabel("Close \(title)")
            }.frame(height: 11)
            content
        }.padding(5).background(LinearGradient(colors: [metal.opacity(0.9), .init(white: 0.13), metal], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(Rectangle().strokeBorder(Color(white: 0.65), lineWidth: 1))
        .foregroundStyle(Color(white: 0.86))
    }
}
struct RetroButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 8, weight: .bold, design: .monospaced)).padding(.horizontal, 4).frame(minHeight: 12)
            .background(LinearGradient(colors: configuration.isPressed ? [.black, metal] : [Color(white: 0.6), metal], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.7)).foregroundStyle(.white)
    }
}

struct RetroSlider<Value: BinaryFloatingPoint>: View {
    @Binding var value: Value
    var range: ClosedRange<Value>
    var body: some View {
        GeometryReader { proxy in
            let fraction = Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let width = max(1, proxy.size.width - 9)
            ZStack(alignment: .leading) {
                Rectangle().fill(.black).frame(height: 4)
                Rectangle().fill(LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 0.2), .yellow], startPoint: .leading, endPoint: .trailing)).frame(width: max(0, width * min(1,max(0,fraction)) + 4), height: 2)
                Rectangle().fill(LinearGradient(colors: [Color(white: 0.85), metal], startPoint: .top, endPoint: .bottom)).frame(width: 9, height: 8).overlay(Rectangle().stroke(.black, lineWidth: 0.5)).offset(x: width * min(1,max(0,fraction)))
            }.frame(height: proxy.size.height).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    value = range.lowerBound + Value(min(1,max(0,(event.location.x - 4.5) / width))) * (range.upperBound - range.lowerBound)
                })
        }.frame(height: 10)
        .accessibilityElement().accessibilityValue("\(Int(Double(value) * 100))")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            value = min(range.upperBound,max(range.lowerBound,value + (direction == .increment ? step : -step)))
        }
    }
}

struct Ticker: View {
    var text: String
    var running = true
    var body: some View {
        GeometryReader { proxy in
            let travel = max(0, CGFloat(text.count) * 6 - proxy.size.width)
            // Only animate while playing and when the title is too long to fit.
            TimelineView(.animation(minimumInterval: 0.05, paused: travel == 0 || !running)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: max(1, Double(travel / 16 + 4)))
                Text(text).font(.system(size: 9, design: .monospaced)).fixedSize().offset(x: running ? -min(travel, max(0, phase - 2) * 16) : 0)
            }
        }.frame(height: 12).clipped().foregroundStyle(phosphor)
    }
}
struct PlayerView: View {
    @ObservedObject var model: Model
    @ObservedObject var live: LiveState
    var windows: Windows
    func time(_ value: Double) -> String { let n = Int(max(0, value)); return String(format: "%02d:%02d", n / 60, n % 60) }
    var body: some View {
        Chrome(title: "Mac-Amp", close: { NSApp.hide(nil) }) {
            HStack(spacing: 5) {
                VStack(spacing: 1) {
                    Button { model.remaining.toggle() } label: {
                        Text((model.remaining ? "−" : "") + time(model.remaining ? model.duration - model.position : model.position)).font(.system(size: 23, weight: .regular, design: .monospaced)).foregroundStyle(phosphor)
                    }.buttonStyle(.plain).accessibilityLabel("Toggle elapsed or remaining time")
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(0..<20) { i in Rectangle().fill(LinearGradient(colors: [.red,.yellow,phosphor], startPoint: .top, endPoint: .bottom)).frame(width: 4, height: max(1, CGFloat(model.bars[i]) * 18)) }
                    }.frame(height: 18)
                }.frame(width: 104).background(Color.black)
                VStack(spacing: 2) {
                    Ticker(text: model.current?.title ?? "DROP YOUR MUSIC HERE • Mac-Amp", running: live.playing)
                    HStack { Text(model.current?.url.pathExtension.uppercased() ?? "LOCAL AUDIO"); Spacer(); Text(model.playing ? "STEREO ▶" : "READY") }.font(.system(size: 7, design: .monospaced)).foregroundStyle(phosphor).padding(2).background(.black)
                    HStack(spacing: 2) {
                        RetroSlider(value: $model.session.volume, range: 0...1).accessibilityLabel("Volume")
                        RetroSlider(value: $model.session.balance, range: -1...1).frame(width: 44).accessibilityLabel("Balance")
                    }.controlSize(.mini).onChange(of: model.session.volume) { model.changed() }.onChange(of: model.session.balance) { model.changed() }
                    HStack { Button("EQ") { windows.toggle(.equalizer) }; Button("PL") { windows.toggle(.playlist) }; Spacer(); Text("●").foregroundStyle(phosphor).font(.system(size: 7)) }.buttonStyle(RetroButton())
                }
            }.frame(height: 49)
            RetroSlider(value: Binding(get: { min(model.position, max(1,model.duration)) }, set: { model.seek($0) }), range: 0...max(1,model.duration)).controlSize(.mini).frame(height: 10).accessibilityLabel("Playback position")
            HStack(spacing: 2) {
                Button("|◀") { model.advance(backwards: true) }.accessibilityLabel("Previous")
                Button("▶") { model.toggle() }.accessibilityLabel("Play or pause")
                Button("Ⅱ") { model.pause() }.accessibilityLabel("Pause")
                Button("■") { model.stop() }.accessibilityLabel("Stop")
                Button("▶|") { model.advance() }.accessibilityLabel("Next")
                Button("⏏") { model.choose() }.accessibilityLabel("Add music")
                Spacer(minLength: 0)
                Button(model.session.shuffle ? "SHUF ●" : "SHUF") { model.session.shuffle.toggle(); model.session.shuffleOrder = nil; model.save() }
                Button("R:\(model.session.repeatMode.rawValue.uppercased())") {
                    let modes = RepeatMode.allCases; model.session.repeatMode = modes[(modes.firstIndex(of: model.session.repeatMode)! + 1) % modes.count]; model.save()
                }.accessibilityLabel("Repeat \(model.session.repeatMode.rawValue)")
            }.buttonStyle(RetroButton())
        }.frame(width: 275, height: 116)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: receive)
        .alert("Mac-Amp", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
    }
    func receive(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in model.add([url]) } } } }; return true
    }
}
struct PlaylistView: View {
    @ObservedObject var model: Model
    var windows: Windows
    @State private var selection = Set<UUID>()
    @State private var visible = Set<UUID>()
    @State private var searching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    private let playingRow = Color(red: 0.09, green: 0.24, blue: 0.05)

    /// Tracks with their original position; filtered by every word typed in the search field.
    private var rows: [(index: Int, track: Track)] {
        let all = model.session.tracks.enumerated().map { (index: $0.offset, track: $0.element) }
        let words = query.lowercased().split(separator: " ")
        guard !words.isEmpty else { return all }
        return all.filter { row in let title = row.track.title.lowercased(); return words.allSatisfy { title.contains($0) } }
    }
    var body: some View {
        Chrome(title: "Mac-Amp • PLAYLIST", close: { windows.toggle(.playlist) }) {
            ScrollViewReader { scroller in
                if searching {
                    HStack(spacing: 3) {
                        Text("FIND").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(phosphor)
                        TextField("", text: $query, prompt: Text("type a title or artist").foregroundStyle(.gray))
                            .textFieldStyle(.plain).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white)
                            .focused($searchFocused)
                            .onAppear { focusSearch() }
                            .onSubmit { if let first = rows.first { model.play(first.track.id); closeSearch(scroller) } }
                            .onExitCommand { closeSearch(scroller) }
                            .accessibilityLabel("Search playlist")
                        Text("\(rows.count)").font(.system(size: 8, design: .monospaced)).foregroundStyle(.gray)
                        Button("×") { closeSearch(scroller) }.buttonStyle(RetroButton()).accessibilityLabel("Close search")
                    }.padding(.horizontal, 3).frame(height: 14).background(.black)
                }
                List(selection: $selection) {
                    ForEach(rows, id: \.track.id) { row in
                        let track = row.track
                        let isCurrent = track.id == model.session.selected
                        HStack(spacing: 3) {
                            Text(isCurrent ? "▶" : " ").foregroundStyle(phosphor).frame(width: 7)
                            Text(String(format: "%02d.", row.index + 1)).foregroundStyle(.gray)
                            Text(track.title).foregroundStyle(isCurrent ? .white : phosphor).fontWeight(isCurrent ? .bold : .regular).lineLimit(1)
                            Spacer(minLength: 0); Text(track.url.pathExtension.uppercased()).foregroundStyle(.gray)
                        }.font(.system(size: 9, design: .monospaced)).padding(.vertical, 2).tag(track.id)
                        .listRowBackground(isCurrent ? playingRow : Color.black)
                        .onAppear { visible.insert(track.id) }.onDisappear { visible.remove(track.id) }
                        .onTapGesture(count: 2) { model.play(track.id) }
                        .onDrag { NSItemProvider(object: track.id.uuidString as NSString) }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: String.self) { text, _ in
                                guard let text, let id = UUID(uuidString: text) else { return }
                                Task { @MainActor in
                                    guard let source = model.session.tracks.firstIndex(where: { $0.id == id }), let target = model.session.tracks.firstIndex(where: { $0.id == track.id }) else { return }
                                    model.session.tracks.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target); model.save()
                                }
                            }; return true
                        }
                        .contextMenu { Button("Play") { model.play(track.id) }; Button("Remove") { model.remove([track.id]) } }
                    }
                    // Offsets only match the full list, so reordering is off while filtering.
                    .onMove(perform: query.isEmpty ? { source, target in model.session.tracks.move(fromOffsets: source, toOffset: target); model.save() } : nil)
                }.listStyle(.plain).scrollContentBackground(.hidden).background(.black).environment(\.defaultMinListRowHeight, 17)
                    .onDeleteCommand { model.remove(selection); selection.removeAll() }
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in model.add([url]) } } } }; return true
                    }
                    // Follow the playing track when Next/Previous/shuffle jumps to a row that's off-screen.
                    .onChange(of: model.session.selected) { _, id in
                        guard let id, !visible.contains(id) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { scroller.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: model.searchToken) { if searching { focusSearch() } else { searching = true } }
                    .onAppear { if let id = model.session.selected { scroller.scrollTo(id, anchor: .center) } }
            }
            HStack(spacing: 3) {
                Button("+ ADD") { model.choose() }; Button("− REM") { model.remove(selection); selection.removeAll() }
                Button("CLEAR") { model.remove(Set(model.session.tracks.map(\.id))) }
                Button("FIND") { model.findInPlaylist() }.accessibilityLabel("Search playlist")
                Spacer(); Text(model.importing ? "READING…" : "\(model.session.tracks.count) TRACKS").font(.system(size: 8, design: .monospaced)).foregroundStyle(phosphor)
            }.buttonStyle(RetroButton())
        }.frame(width: 275, height: 245)
    }
    /// The field only exists after the next render, and the window must be key to accept typing.
    private func focusSearch() {
        DispatchQueue.main.async {
            windows.panels[.playlist]?.makeKeyAndOrderFront(nil)
            searchFocused = true
        }
    }
    private func closeSearch(_ scroller: ScrollViewProxy) {
        query = ""; searching = false; searchFocused = false
        if let id = model.session.selected { DispatchQueue.main.async { scroller.scrollTo(id, anchor: .center) } }
    }
}
struct EqualizerView: View {
    @ObservedObject var model: Model
    var windows: Windows
    let labels = ["31","62","125","250","500","1K","2K","4K","8K","16K"]
    var body: some View {
        Chrome(title: "Mac-Amp • EQUALIZER", close: { windows.toggle(.equalizer) }) {
            HStack {
                Button(model.session.eqEnabled ? "ON ●" : "OFF") { model.session.eqEnabled.toggle(); model.changed() }
                Button("FLAT") { model.session.bands = Array(repeating: 0, count: 10); model.session.preamp = 0; model.changed() }
                Spacer(); Text("±12 dB").font(.system(size: 7, design: .monospaced)).foregroundStyle(phosphor)
            }.buttonStyle(RetroButton())
            HStack(spacing: 2) {
                fader("PRE", value: $model.session.preamp).help("Preamp automatically reserves headroom for EQ boosts. Applied gain: \(Int(model.session.safePreamp)) dB")
                Rectangle().fill(.gray).frame(width: 1)
                ForEach(0..<10) { i in fader(labels[i], value: $model.session.bands[i]) }
            }
        }.frame(width: 275, height: 116)
    }
    func fader(_ name: String, value: Binding<Float>) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", value.wrappedValue)).font(.system(size: 6, design: .monospaced)).foregroundStyle(phosphor)
            GeometryReader { proxy in
                ZStack {
                    Rectangle().fill(.black).frame(width: 3)
                    Rectangle().fill(.gray).frame(height: 1)
                    Rectangle().fill(LinearGradient(colors: [.white,metal], startPoint: .top, endPoint: .bottom)).frame(width: 15, height: 6).offset(y: -CGFloat(value.wrappedValue / 12) * (proxy.size.height - 6) / 2)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in value.wrappedValue = Float(max(-12, min(12, (0.5 - event.location.y / proxy.size.height) * 24))); model.changed() })
            }.accessibilityElement().accessibilityLabel("\(name) gain").accessibilityValue("\(Int(value.wrappedValue)) decibels")
                .accessibilityAdjustableAction { direction in value.wrappedValue = max(-12,min(12,value.wrappedValue + (direction == .increment ? 1 : -1))); model.changed() }
            Text(name).font(.system(size: 6, design: .monospaced))
        }.frame(maxWidth: .infinity)
    }
}
