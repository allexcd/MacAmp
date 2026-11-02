# MacAmp

A native, offline Mac music player with three tiny retro windows: player, playlist, and ten-band equalizer. Original interface artwork; no Winamp skins or assets.

## Run

Requires Apple Silicon, macOS 15 or newer, and Xcode 16 or newer (Swift 6 toolchain). Development was verified on this Mac with Xcode 27.2; macOS 15 still needs a hardware compatibility pass.

Open `MacAmp.xcodeproj` in Xcode, choose the MacAmp scheme, and Run. The app is sandboxed with read-only access to user-selected files and folders. For a self-contained, locally ad-hoc signed app:

```sh
./scripts/build-app.sh
open dist/MacAmp.app
```

The first build downloads SFBAudioEngine 0.14.0 and the codecs pinned in `Package.resolved`. Subsequent playback needs no network. Xcode builds embed and sign the dynamic codec frameworks. The packaging script also includes upstream license notices. `swift run` is useful for development but is not the sandboxed app distribution path.

## Use

- **⌘O** or **⏏** adds files or folders. Drop files/folders on the player or playlist. Folder scans recurse, skip hidden files and packages, and do not follow symlinks.
- **Space** plays/pauses, **⌘.** stops, **⌘[ / ⌘]** selects previous/next.
- **⌘L** shows/hides the playlist; **⌘E** shows/hides the equalizer; **⌘0** brings back the player.
- **⌘1 / ⌘2 / ⌘3** chooses original, double, or triple size. Drag window backgrounds to move them independently. Player × hides the app; use its Dock icon to return.
- Double-click a playlist row to play. Select rows and press Delete or **− REM** to remove; drag rows to reorder. Right-click a track for Play/Remove.
- Click the digital clock to switch elapsed/remaining time. The spectrum analyzes actual output and goes dark while paused/stopped.
- Adjust preamp and ten EQ bands (31 Hz–16 kHz), toggle ON/OFF, or choose FLAT. Automatic preamp attenuation reserves conservative headroom for boosted bands; the preamp tooltip shows applied gain. Balance affects stereo output; mono sources remain mono.
- SHUF traverses a randomized queue without repeating until the cycle ends. R cycles off/all/one. Previous follows the randomized order within a cycle.

Supported: WAV, MP3, Ogg Opus (`.opus`), FLAC, AAC in M4A or raw ADTS (`.aac`), AIFF, and Ogg Vorbis. Unsupported, corrupt, inaccessible, and DRM-protected files show an error and recovery tries other queued entries at most once. Containers and codec profiles vary; support is verified against generated representative fixtures, not every possible encoding.

The queue, selection, position, EQ, volume, balance, shuffle order, window positions, visibility, and size persist. Relaunch is always silent until Play. Security-scoped bookmarks retain file/folder access and allow moved bookmarked roots to resolve; deleting or replacing a file may require re-adding it. Audio files are never copied, changed, or deleted. Removing tracks only changes the queue.

## Validate

With ffmpeg installed:

```sh
./scripts/generate-fixtures.sh
swift test
```

Tests cover actual decoding and seeking for all eight formats, corrupted input, queue boundaries/repeat/shuffle, session round trips, symlink exclusion, silent restore, missing-file recovery, live playback/pause/resume, sample-rate/channel transitions, EQ parameters, volume/balance, spectrum analysis, and mixed-format end-of-track advancement. Audio integration tests briefly play quiet generated tones and require an available audio output device. Fixtures are generated locally and are not bundled in the app.

Manual checks: sandboxed Open panel and bookmark restoration after relaunch; folder drag/drop; playlist selection/reordering; all three windows at 1×/2×/3×; faders with VoiceOver; changing output device; unavailable external drive; very large folders. These are not all automated. No claim is made that macOS 15 or every output device has been tested.

## Structure and release status

`MacAmpCore` owns the Codable session, queue decisions, and atomic JSON persistence. The app separates playback/analysis (`Playback`), file access/import and observable state (`Model`), custom SwiftUI views, and AppKit window/menu coordination. Audio decoding runs in SFBAudioEngine's worker threads; import/metadata and spectrum analysis run off the main thread. Spectrum work is bounded so a slow analyzer cannot accumulate buffers.

This is a local prototype, not an App Store submission. Before publishing: choose and clear a final name/icon, perform the complete codec-license review in `THIRD_PARTY_NOTICES.md`, supply all required codec source/notices or replace dependencies, test minimum-OS and accessibility support, and configure your developer team, distribution signing, privacy declarations, and store listing. The bundled codec frameworks include LGPL software. Collected notices alone do not fulfill all distribution obligations. App Store approval is not guaranteed.

Deferred: named playlists, M3U import/export, full library indexing, streaming, third-party skins, window snapping, guaranteed gapless playback, media keys, and updates.
