# Implementation Notes

## Quick Reference for Just Play Implementation

### Key Implementation Decisions

#### 1. Window Management Strategy

**Chosen Approach**: Singleton WindowManager with manual NSWindow creation

```swift
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    // Creates borderless NSWindow instances manually
}
```

**Why**:
- SwiftUI's WindowGroup doesn't provide enough control for floating, borderless windows
- Need precise control over window styling and behavior
- Each window needs independent lifecycle tied to audio playback

**Alternative Considered**: SwiftUI WindowGroup with handlesExternalEvents
- Rejected because: Limited window customization, harder to make circular/borderless

#### 2. Audio Player Architecture

**Chosen Approach**: AVPlayer with AVPlayerItem

```swift
playerItem?.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
```

**Why**:
- AVPlayer is simpler for basic playback
- Built-in Spatial Audio support
- Automatic format handling via system codecs
- Combine-friendly with KVO publishers

**Alternative Considered**: AVAudioEngine + AVAudioPlayerNode
- Rejected because: More complex, overkill for simple playback

#### 3. State Management

**Chosen Approach**: Combine publishers with @Published properties

```swift
audioPlayer.$state.assign(to: &$state)
```

**Why**:
- Natural SwiftUI integration via ObservableObject
- Reactive updates from AVPlayer to UI
- Clean separation of concerns

#### 4. Circular Window Shape

**Chosen Approach**: NSWindow with borderless style + SwiftUI clipShape

```swift
window.styleMask = [.borderless, .nonactivatingPanel]
hostingController.view.layer?.cornerRadius = 70
```

**Why**:
- Combines NSWindow control with SwiftUI content
- Visual effects (blur) work naturally
- Draggable via isMovableByWindowBackground

#### 5. File Type Handling

**Chosen Approach**: Info.plist document types + NSApplicationDelegate

```swift
func application(_ sender: NSApplication, openFile filename: String) -> Bool
```

**Why**:
- Standard macOS approach
- System handles "Open With" automatically
- Works with Finder double-click

### Critical Implementation Details

#### Avoiding Memory Leaks

1. **Window Cleanup**:
```swift
NotificationCenter.default.addObserver(
    forName: NSWindow.willCloseNotification,
    object: window,
    queue: .main
) { [weak self] _ in
    self?.handleWindowClosed(viewModel: viewModel)
}
```

2. **AVPlayer Cleanup**:
```swift
deinit {
    player?.pause()
    cancellables.removeAll()
}
```

#### Spatial Audio Configuration

Required for macOS to offer Spatial Audio:

```swift
if #available(macOS 12.0, *) {
    playerItem?.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
}
```

This tells the system: "This audio can be spatialized if the user wants it."

#### Floating Window Behavior

```swift
window.level = .floating
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

- `.floating`: Always on top
- `.canJoinAllSpaces`: Appears on all desktops
- `.fullScreenAuxiliary`: Appears even in full-screen apps

#### End-of-File Handling

```swift
NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    .sink { [weak self] _ in
        self?.handlePlaybackEnded()
    }
```

When playback ends:
1. Update state to `.ended`
2. Seek back to zero
3. Icon changes back to play
4. Next click starts from beginning

### SwiftUI Integration Patterns

#### Preview Support

```swift
#Preview {
    PlayerWindowView(viewModel: PlayerViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.mp3")))
        .frame(width: 200, height: 200)
        .background(Color.gray.opacity(0.3))
}
```

Preview works even though file doesn't exist - useful for UI development.

#### Material Effects

```swift
Circle()
    .fill(.ultraThinMaterial)
    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
```

Uses system materials for automatic light/dark mode support.

### Potential Enhancements (Not Implemented)

If you wanted to extend Just Play, here are clean ways to add features:

#### 1. Keyboard Shortcuts

Add to PlayerWindowView:

```swift
.onKeyPress(.space) { _ in
    viewModel.togglePlayPause()
    return .handled
}
```

#### 2. Dock Icon Management

In AppDelegate:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    if playerViewModels.isEmpty {
        NSApp.setActivationPolicy(.accessory) // Hide from dock
    }
}
```

#### 3. Window Position Persistence

Store positions in UserDefaults:

```swift
UserDefaults.standard.set(
    NSStringFromRect(window.frame),
    forKey: "window_\(viewModel.id)"
)
```

#### 4. Visual Playback Indicator

Animate button on playback:

```swift
.scaleEffect(state.isPlaying ? 1.1 : 1.0)
.animation(.easeInOut(duration: 0.2), value: state.isPlaying)
```

### Common Pitfalls Avoided

#### ❌ Don't: Use SwiftUI App init() for async setup

```swift
// WRONG - causes "escaping closure captures mutating self"
init() {
    DispatchQueue.main.async {
        self.appDelegate.windowManager = self.windowManager
    }
}
```

✅ **Solution**: Use singleton pattern instead

#### ❌ Don't: Forget to remove time observers

```swift
// WRONG - causes memory leaks
addPeriodicTimeObserver(...)
// No removal in deinit
```

✅ **Solution**: Always remove in deinit

#### ❌ Don't: Use .m4a directly

```swift
// WRONG - .m4a doesn't exist
panel.allowedContentTypes = [.m4a]
```

✅ **Solution**: Use `.mpeg4Audio` instead

### Testing Checklist

- [x] Build succeeds without warnings
- [x] Can open MP3, WAV, AAC files
- [x] Play/pause button toggles correctly
- [x] Multiple windows work independently
- [x] Windows are draggable
- [x] Windows stay on top
- [x] End-of-file resets to play state
- [x] Closing window cleans up resources
- [ ] Spatial Audio appears in system menu (requires compatible hardware)

### File-by-File Purpose

| File | Purpose | Key Responsibilities |
|------|---------|---------------------|
| JustPlayApp.swift | App entry point | SwiftUI App, commands menu |
| AppDelegate.swift | System integration | Handle "Open With", file associations |
| WindowManager.swift | Window lifecycle | Create, track, destroy player windows |
| AudioPlayer.swift | Audio playback | AVPlayer wrapper, Spatial Audio setup |
| PlayerState.swift | State definition | Enum for playback states |
| PlayerViewModel.swift | Window state | Bridge between model and view |
| PlayerWindowView.swift | Main UI | Circular window layout |
| PlayPauseButton.swift | Button UI | Reusable play/pause button |
| Info.plist | Configuration | File types, sandbox, metadata |
| JustPlay.entitlements | Permissions | Sandbox permissions |

### Build Configuration

#### Debug vs Release

**Debug**:
- Optimization: `-Onone`
- Symbols: Included
- Assertions: Enabled

**Release**:
- Optimization: `-O` (whole-module)
- Symbols: Stripped
- Assertions: Disabled

#### Code Signing

Currently set to "Automatic" for development. For distribution:

1. Set DEVELOPMENT_TEAM
2. Choose "Apple Development" or "Developer ID Application"
3. Ensure provisioning profile is correct

### Performance Considerations

#### Memory Usage

- Each window: ~2-5 MB
- Each audio player: Depends on file size + buffers
- Typically fine for 10-20 simultaneous files

#### CPU Usage

- Playback: Minimal (handled by hardware)
- UI: Negligible (static circular buttons)
- No heavy processing

#### Spatial Audio Impact

Spatial Audio processing is handled by the system, not the app. No additional CPU overhead from app side.

## Conclusion

This implementation prioritizes:
1. **Simplicity**: Minimal feature set, clean code
2. **Native feel**: Uses standard macOS patterns
3. **Reliability**: Proper cleanup, memory management
4. **Modern APIs**: Latest Swift, SwiftUI, AVFoundation

The result is a focused app that does one thing well: play audio files with minimal UI.
