import AppKit
import SwiftUI
#if canImport(MacAmpCore)
import MacAmpCore
#endif

@MainActor final class Windows: NSObject, NSWindowDelegate {
    enum Panel: String { case player, playlist, equalizer }
    private var dragging: Panel?
    private var dragFrames: [Panel: CGRect] = [:]
    private var followers = Set<Panel>()
    private var movingGroup = false
    let model: Model
    var panels: [Panel: NSWindow] = [:]
    init(model: Model) { self.model = model; super.init() }
    func show() {
        make(.player, size: NSSize(width: 275,height: 116), origin: NSPoint(x: 240,y: 600))
        make(.equalizer, size: NSSize(width: 275,height: 116), origin: NSPoint(x: 240,y: 474))
        make(.playlist, size: NSSize(width: 275,height: 245), origin: NSPoint(x: 240,y: 219))
        panels[.player]?.makeKeyAndOrderFront(nil)
        if !model.session.eqVisible { panels[.equalizer]?.orderOut(nil) }
        if !model.session.playlistVisible { panels[.playlist]?.orderOut(nil) }
    }
    func make(_ panel: Panel, size: NSSize, origin: NSPoint) {
        let window = PlayerWindow(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .miniaturizable], backing: .buffered, defer: false)
        window.beginDrag = { [weak self] in self?.beginDrag(panel) }
        window.endDrag = { [weak self] in self?.endDrag(panel) }
        window.title = "Mac-Amp \(panel.rawValue)"; window.isReleasedWhenClosed = false; window.isMovableByWindowBackground = true; window.delegate = self
        window.setFrameAutosaveName("MacAmp.\(panel.rawValue)")
        panels[panel] = window; update(panel); window.orderFront(nil)
    }
    func update(_ panel: Panel) {
        guard let window = panels[panel] else { return }
        let scale = model.session.scale
        (window as? PlayerWindow)?.titleDragHeight = (panel == .player ? 24 : 18) * scale
        (window as? PlayerWindow)?.closeButtonWidth = 24 * scale
        let size = NSSize(width: 275, height: panel == .playlist ? 245 : 116)
        let view: AnyView
        switch panel {
        case .player: view = AnyView(PlayerView(model: model, windows: self))
        case .playlist: view = AnyView(PlaylistView(model: model, windows: self))
        case .equalizer: view = AnyView(EqualizerView(model: model, windows: self))
        }
        window.contentView = NSHostingView(rootView: view.scaleEffect(scale, anchor: .topLeading).frame(width: size.width * scale,height: size.height * scale, alignment: .topLeading))
        let top = window.frame.maxY; window.setContentSize(NSSize(width: size.width * scale,height: size.height * scale)); window.setFrameOrigin(NSPoint(x: window.frame.minX,y: top - window.frame.height))
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: max(visible.minX,min(window.frame.minX,visible.maxX - window.frame.width)), y: max(visible.minY,min(window.frame.minY,visible.maxY - window.frame.height))))
        }
    }
    func scale(_ value: Double) {
        let old = panels.mapValues(\.frame)
        let connected = WindowDocking.connected(to: Panel.player.rawValue, frames: Dictionary(uniqueKeysWithValues: old.map { ($0.key.rawValue, $0.value) }))
        let ratio = value / model.session.scale
        model.session.scale = value
        for panel in panels.keys { update(panel) }
        if let anchor = panels[.player]?.frame.origin, let original = old[.player]?.origin {
            for (panel, frame) in old where panel != .player && connected.contains(panel.rawValue) {
                panels[panel]?.setFrameOrigin(CGPoint(x: anchor.x + (frame.minX-original.x)*ratio, y: anchor.y + (frame.minY-original.y)*ratio))
            }
        }
        saveFrames(); model.save()
    }
    func beginDrag(_ panel: Panel) {
        dragging = panel; dragFrames = panels.mapValues(\.frame)
        let connected = WindowDocking.connected(to: panel.rawValue, frames: Dictionary(uniqueKeysWithValues: dragFrames.map { ($0.key.rawValue, $0.value) }))
        followers = panel == .player ? Set(panels.keys.filter { $0 != panel && connected.contains($0.rawValue) }) : []
    }
    func windowDidMove(_ notification: Notification) {
        guard !movingGroup, dragging == .player, let window = notification.object as? NSWindow,
              window === panels[.player], let start = dragFrames[.player] else { return }
        movingGroup = true
        for panel in followers {
            if let frame = dragFrames[panel] {
                panels[panel]?.setFrameOrigin(CGPoint(x: frame.minX + window.frame.minX-start.minX, y: frame.minY + window.frame.minY-start.minY))
            }
        }
        movingGroup = false
    }
    func endDrag(_ panel: Panel) {
        if panel != .player, let window = panels[panel] {
            let targets = [Panel.player, .equalizer, .playlist].filter { $0 != panel }.compactMap { panels[$0] }.filter(\.isVisible).map(\.frame)
            window.setFrame(WindowDocking.snapped(window.frame, to: targets), display: true)
        }
        dragging = nil; followers.removeAll(); dragFrames.removeAll(); saveFrames()
    }
    private func saveFrames() {
        for (panel, window) in panels { window.saveFrame(usingName: "MacAmp.\(panel.rawValue)") }
    }
    func toggle(_ panel: Panel) {
        guard let window = panels[panel] else { return }
        if window.isVisible { window.orderOut(nil) } else { window.makeKeyAndOrderFront(nil) }
        model.session.eqVisible = panels[.equalizer]?.isVisible ?? false; model.session.playlistVisible = panels[.playlist]?.isVisible ?? false; model.save()
    }
}
final class PlayerWindow: NSWindow {
    var titleDragHeight: CGFloat = 24
    var closeButtonWidth: CGFloat = 24
    override func sendEvent(_ event: NSEvent) {
        let point = event.locationInWindow
        if event.type == .leftMouseDown, point.y >= frame.height - titleDragHeight,
           point.x >= 0, point.x < frame.width - closeButtonWidth {
            beginDrag?(); performDrag(with: event); endDrag?()
            return
        }
        super.sendEvent(event)
    }
    var beginDrag: (() -> Void)?
    var endDrag: (() -> Void)?
    override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { true } }
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: Model!
    var windows: Windows!
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = Model(); windows = Windows(model: model); windows.show(); menus(); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) { model.save() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { windows.panels[.player]?.makeKeyAndOrderFront(nil); return true }
    func application(_ sender: NSApplication, openFiles filenames: [String]) { model.add(filenames.map { URL(filePath: $0) }); sender.reply(toOpenOrPrint: .success) }
    func menus() {
        let main = NSMenu(); NSApp.mainMenu = main
        func menu(_ name: String) -> NSMenu { let item = NSMenuItem(); let sub = NSMenu(title: name); item.submenu = sub; main.addItem(item); return sub }
        func item(_ menu: NSMenu, _ name: String, _ action: Selector, _ key: String = "", modifiers: NSEvent.ModifierFlags = .command) { let i = NSMenuItem(title: name,action: action,keyEquivalent: key); i.target = self; i.keyEquivalentModifierMask = modifiers; menu.addItem(i) }
        let app = menu("Mac-Amp"); item(app,"About Mac-Amp",#selector(about)); app.addItem(.separator()); item(app,"Hide Mac-Amp",#selector(hide),"h"); item(app,"Quit Mac-Amp",#selector(quit),"q")
        let file = menu("File"); item(file,"Add Files or Folders…",#selector(add),"o")
        let edit = menu("Edit")
        for (name, action, key) in [("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] { edit.addItem(NSMenuItem(title: name, action: action, keyEquivalent: key)) }
        let playback = menu("Playback"); item(playback,"Play / Pause",#selector(toggle)," ",modifiers: []); item(playback,"Stop",#selector(stop),"."); item(playback,"Next",#selector(next),"]"); item(playback,"Previous",#selector(previous),"[")
        let view = menu("View"); item(view,"Playlist",#selector(playlist),"l"); item(view,"Equalizer",#selector(eq),"e")
        for scale in 1...3 { let i = NSMenuItem(title: "\(scale)× Size",action: #selector(resize(_:)),keyEquivalent: "\(scale)"); i.target = self; i.tag = scale; view.addItem(i) }
        let window = menu("Window"); NSApp.windowsMenu = window; item(window,"Minimize Player",#selector(minimize),"m"); item(window,"Show Player",#selector(showPlayer),"0")
    }
    @objc func minimize() { windows.panels[.player]?.miniaturize(nil) }
    @objc func showPlayer() { windows.panels[.player]?.deminiaturize(nil); windows.panels[.player]?.makeKeyAndOrderFront(nil) }
    @objc func add() { model.choose() }; @objc func toggle() { model.toggle() }; @objc func stop() { model.stop() }
    @objc func next() { model.advance() }; @objc func previous() { model.advance(backwards: true) }
    @objc func playlist() { windows.toggle(.playlist) }; @objc func eq() { windows.toggle(.equalizer) }
    @objc func resize(_ sender: NSMenuItem) { windows.scale(Double(sender.tag)) }
    @objc func hide() { NSApp.hide(nil) }; @objc func quit() { NSApp.terminate(nil) }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName:"Mac-Amp", .applicationVersion:"0.1.0", .credits:NSAttributedString(string:"Local music. Familiar little windows.\nOriginal retro artwork. Audio powered by SFBAudioEngine.\nSee THIRD_PARTY_NOTICES.md in the app resources.")]) }
}
@main struct MacAmpApp {
    @MainActor static func main() {
        let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run(); withExtendedLifetime(delegate) {}
    }
}
