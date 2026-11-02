import AppKit
import SwiftUI
import AVFoundation
import SFBAudioEngine
#if canImport(MacAmpCore)
import MacAmpCore
#endif

@MainActor final class Model: ObservableObject {
    @Published var session: Session
    @Published var playing = false
    @Published var duration: Double = 0
    @Published var position: Double = 0
    @Published var bars: [Float] = Array(repeating: 0, count: 20)
    @Published var message: String?
    @Published var remaining = false
    @Published var importing = false
    let audio = Playback()
    private var timer: Timer?
    private var scopes: [URL] = []
    private var failed = Set<UUID>()
    private var loaded: UUID?
    private var pendingSeek: Double?
    private var ticks = 0
    private let stateURL: URL
    var current: Track? { session.tracks.first { $0.id == session.selected } }
    init(stateURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacAmp/session.json")) {
        self.stateURL = stateURL
        session = SessionStore.load(from: stateURL)
        session.scale = [1,2,3].contains(session.scale) ? session.scale : 1
        if session.bands.count != 10 { session.bands = Array(repeating: 0, count: 10) }
        position = session.position
        audio.apply(session)
        audio.onEnd = { [weak self] in self?.advance(automatic: true) }
        audio.onError = { [weak self] error in self?.handleFailure(error) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    func tick() {
        playing = audio.player.isPlaying
        if let value = audio.player.totalTime, value.isFinite { duration = value }
        if let target = pendingSeek, audio.player.supportsSeeking { _ = audio.player.seek(time: target); pendingSeek = nil }
        if loaded != nil, pendingSeek == nil, let value = audio.player.currentTime, value.isFinite { position = value }
        bars = playing ? audio.spectrum.read() : Array(repeating: 0, count: 20)
        ticks += 1; if ticks % 50 == 0 { save() }
    }
    func save() { session.position = position; do { try SessionStore.save(session, to: stateURL) } catch { message = "Could not save session: \(error.localizedDescription)" } }
    func changed() { audio.apply(session); save() }
    func toggle() {
        if audio.player.isPlaying { _ = audio.player.pause() }
        else if audio.player.isPaused { _ = audio.player.resume() }
        else if let id = session.selected ?? session.tracks.first?.id { play(id, resume: true) }
        else { choose() }
    }
    func play(_ id: UUID, resume: Bool = false, recovery: Bool = false) {
        guard let track = session.tracks.first(where: { $0.id == id }) else { return }
        if !recovery { failed.removeAll() }
        audio.player.stop(); releaseScopes(); loaded = nil
        session.selected = id
        let target = resume ? position : 0
        do {
            var url = track.url
            if let data = track.bookmark {
                var stale = false
                let root = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
                if root.startAccessingSecurityScopedResource() { scopes.append(root) }
                url = track.relativePath.map { root.appendingPathComponent($0) } ?? root
                if stale, let index = session.tracks.firstIndex(where: { $0.id == id }) {
                    session.tracks[index].bookmark = try root.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
                }
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else { throw CocoaError(.fileReadNoPermission) }
            if url.pathExtension.lowercased() == "aac" {
                let decoder = try AudioDecoder(url: url, decoderName: .coreAudio)
                try audio.player.play(decoder)
            } else { try audio.player.play(url) }
            loaded = id; pendingSeek = target; position = target; duration = 0; save()
        } catch { handleFailure("\(track.title): \(error.localizedDescription)") }
    }
    func handleFailure(_ error: String) {
        message = error
        guard let id = session.selected, failed.insert(id).inserted else { return }
        audio.player.stop(); loaded = nil; pendingSeek = nil
        let count = session.tracks.count
        let start = session.tracks.firstIndex(where: { $0.id == id }) ?? 0
        let candidates = session.tracks.indices.map { session.tracks[(start + 1 + $0) % count] }
        if let next = candidates.first(where: { !failed.contains($0.id) }) {
            Task { @MainActor [weak self] in
                guard let self, self.session.selected == id, self.failed.contains(id) else { return }
                self.play(next.id, recovery: true)
            }
        } else { stop() }
    }
    func releaseScopes() { for url in scopes { url.stopAccessingSecurityScopedResource() }; scopes.removeAll() }
    func stop() { audio.player.stop(); releaseScopes(); loaded = nil; pendingSeek = nil; position = 0; playing = false; save() }
    func advance(automatic: Bool = false, backwards: Bool = false) {
        if let id = session.next(after: session.selected, backwards: backwards, automatic: automatic) { play(id) } else { stop() }
    }
    func seek(_ value: Double) { position = value; if loaded != nil { _ = audio.player.seek(time: value) }; save() }
    func remove(_ ids: Set<UUID>) {
        if let selected = session.selected, ids.contains(selected) { stop(); session.selected = nil }
        session.tracks.removeAll { ids.contains($0.id) }; save()
    }
    func choose() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.message = "Add local music files or folders"
        panel.begin { result in if result == .OK { self.add(panel.urls) } }
    }
    nonisolated static func scan(_ root: URL) -> [URL] {
        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey,.isSymbolicLinkKey], options: [.skipsHiddenFiles,.skipsPackageDescendants]) {
            for case let url as URL in enumerator {
                let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey,.isRegularFileKey])
                if values?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                if values?.isRegularFile == true { files.append(url) }
            }
        }
        return files
    }
    func add(_ urls: [URL]) {
        importing = true
        Task {
            let tracks = await Task.detached(priority: .userInitiated) { () -> [Track] in
                var result: [Track] = []
                let extensions: Set<String> = ["wav","mp3","opus","flac","m4a","aac","aif","aiff","ogg"]
                for root in urls {
                    let access = root.startAccessingSecurityScopedResource(); defer { if access { root.stopAccessingSecurityScopedResource() } }
                    let bookmark = try? root.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
                    let info = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    guard info?.isSymbolicLink != true else { continue }
                    var files = [root]
                    if info?.isDirectory == true {
                        files = []
                        files = Self.scan(root)
                    }
                    for url in files.sorted(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) where extensions.contains(url.pathExtension.lowercased()) {
                        var title = url.deletingPathExtension().lastPathComponent
                        let metadata = (try? await AVURLAsset(url: url).load(.commonMetadata)) ?? []
                        var artist: String?; var name: String?
                        for item in metadata {
                            if item.commonKey == .commonKeyTitle { name = try? await item.load(.stringValue) }
                            if item.commonKey == .commonKeyArtist { artist = try? await item.load(.stringValue) }
                        }
                        if let name { title = artist.map { "\($0) — \(name)" } ?? name }
                        result.append(Track(url: url, title: title, bookmark: bookmark, relativePath: info?.isDirectory == true ? String(url.path.dropFirst(root.path.count + 1)) : nil))
                    }
                }
                return result
            }.value
            let existing = Set(session.tracks.map(\.url)); session.tracks.append(contentsOf: tracks.filter { !existing.contains($0.url) })
            if session.selected == nil { session.selected = session.tracks.first?.id }
            importing = false; if tracks.isEmpty { message = "No supported audio files found." }; save()
        }
    }
}
