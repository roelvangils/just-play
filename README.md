# JustPlay

A lightweight, minimalist audio player for macOS that focuses on simplicity and quick playback.

## Features

- **Quick Audio Playback**: Double-click any audio file to open it instantly in a floating mini player
- **Multiple Players**: Open multiple audio files simultaneously, each in its own independent player window
- **Floating Windows**: Player windows stay on top of other applications (optional)
- **Hover-Based Controls**: Intuitive keyboard shortcuts that work when hovering over any player window
- **Mini Player Design**: Clean, unobtrusive interface showing only essential information
- **Always-On-Top Mode**: Keep player windows visible while working in other applications
- **Recent Files**: Quick access to recently played audio files
- **Auto-Close**: Automatically close mini players when playback finishes (optional)

## Keyboard Shortcuts

Hover over any player window and use these shortcuts:

| Action | Keys |
|--------|------|
| Play/Pause | `SPACE` or `P` |
| Rewind | `R` |
| Skip backward 1 second | `B` |
| Skip forward 1 second | `F` |
| Close Player | `X` or `Q` |

## Global Shortcuts

| Action | Keys |
|--------|------|
| Open Audio File | `⌘O` |
| Quit JustPlay | `⌘Q` |
| Keyboard Shortcuts Help | `⌘?` |
| Toggle Auto-Close Mini Players | `⌘⇧A` |
| Toggle Always on Top | `⌘⇧T` |

## Installation

### Option 1: Download Pre-built Binary
1. Download the latest release from the [Releases](../../releases) page
2. Open the DMG file
3. Drag JustPlay to your Applications folder
4. Right-click and select "Open" the first time to bypass Gatekeeper

### Option 2: Build from Source
1. Clone this repository:
   ```bash
   git clone https://github.com/roelvangils/just-play.git
   cd just-play
   ```

2. Open the project in Xcode:
   ```bash
   open JustPlay.xcodeproj
   ```

3. Build and run (`⌘R`)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)

## Usage

### Opening Audio Files

There are several ways to open audio files:

1. **Double-click** any audio file in Finder (if JustPlay is set as the default application)
2. **Right-click** an audio file → Open With → JustPlay
3. **Drag and drop** audio files onto the JustPlay menu bar icon
4. Use **File → Open** (`⌘O`) from the menu bar
5. Select from **Recent Items** in the menu bar

### Playing Multiple Files

- Select multiple audio files in Finder and open them all with JustPlay
- Each file opens in its own independent player window
- The first file starts playing automatically

### Settings

Access settings from the menu bar icon:

- **Auto-Close Mini Players**: Automatically close player windows when playback finishes
- **Always on Top**: Keep all player windows floating above other applications

## Supported Audio Formats

JustPlay supports all audio formats natively supported by macOS AVFoundation, including:

- MP3 (.mp3)
- AAC (.m4a, .aac)
- ALAC (.m4a)
- WAV (.wav)
- AIFF (.aif, .aiff)
- FLAC (.flac)
- And many more...

## Technology Stack

- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Audio playback engine
- **AppKit**: Native macOS window management and keyboard event handling

## Architecture

JustPlay is built with a clean separation of concerns:

- **Models**: `AudioPlayer` - Core AVPlayer wrapper for audio playback
- **ViewModels**: `PlayerViewModel` - Business logic and state management
- **Views**: SwiftUI views for the player interface
- **Managers**: `WindowManager` - Centralized window and player lifecycle management
- **App**: `AppDelegate` - Global keyboard shortcuts and app lifecycle

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built with SwiftUI and AVFoundation on macOS.

---

Made with ❤️ for quick and simple audio playback
