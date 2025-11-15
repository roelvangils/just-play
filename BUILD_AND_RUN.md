# Build and Run Instructions

## Quick Start (5 minutes)

### Option 1: Build and Run in Xcode (Recommended)

1. **Open the project**:
   ```bash
   open JustPlay.xcodeproj
   ```

2. **In Xcode**:
   - Wait for indexing to complete
   - Select the "JustPlay" scheme (should be selected by default)
   - Click the Run button (▶️) or press ⌘R

3. **The app will launch**:
   - You'll see the menu bar with "JustPlay"
   - No window appears initially (as designed)
   - Choose File → Open Audio File... (⌘O)
   - Select an MP3, WAV, or AAC file
   - A circular player window appears!

### Option 2: Build from Command Line

```bash
# Navigate to the project directory
cd /Users/roelvangils/Repos/just-play

# Clean build (optional)
xcodebuild clean -project JustPlay.xcodeproj -scheme JustPlay

# Build Debug version
xcodebuild -project JustPlay.xcodeproj -scheme JustPlay -configuration Debug build

# Run the app
open ~/Library/Developer/Xcode/DerivedData/JustPlay-*/Build/Products/Debug/JustPlay.app
```

### Option 3: Build Release Version

```bash
# Build optimized Release version
xcodebuild -project JustPlay.xcodeproj -scheme JustPlay -configuration Release build

# Find the built app
ls -la ~/Library/Developer/Xcode/DerivedData/JustPlay-*/Build/Products/Release/

# Copy to Applications (optional)
cp -r ~/Library/Developer/Xcode/DerivedData/JustPlay-*/Build/Products/Release/JustPlay.app /Applications/
```

## First Run Checklist

### 1. Verify Build Success

After building, you should see:
```
** BUILD SUCCEEDED **
```

If you see build errors:
- Ensure you're using Xcode 15.1 or later
- Check that macOS SDK 14.0 is installed
- Try: Product → Clean Build Folder (⌘⇧K)

### 2. Test Basic Functionality

**Open a file**:
- File → Open Audio File... (⌘O)
- Choose any MP3, WAV, or AAC file
- A circular window should appear

**Test playback**:
- Click the play button (▶️ icon)
- Audio should start playing
- Button changes to pause (⏸ icon)
- Click again to pause

**Test multiple files**:
- Open another file (⌘O)
- You should now have two circular windows
- Each plays independently

**Test window behavior**:
- Drag a window around the screen
- It should stay on top of other apps
- Switch to another app - window still visible

### 3. Test File Associations (Optional)

**Set as default app**:
1. Right-click an MP3 file in Finder
2. Choose "Get Info"
3. Under "Open with:", select "JustPlay"
4. Click "Change All..."

**Test double-click**:
1. Double-click an audio file
2. Just Play should launch (if not running)
3. Circular player window appears

## Verifying Spatial Audio Support

### Requirements:
- AirPods Pro or AirPods Max
- macOS with Spatial Audio enabled
- Stereo audio file (not mono)

### Test Procedure:

1. **Connect AirPods**:
   - Open Bluetooth settings
   - Connect AirPods Pro or AirPods Max
   - Ensure Spatial Audio is enabled in Settings

2. **Play audio in Just Play**:
   - Open a stereo audio file (most MP3s are stereo)
   - Click play

3. **Check Control Center**:
   - Click Control Center in menu bar
   - Click the sound/volume control
   - Look for "Spatialize Stereo" option
   - If visible, Spatial Audio is working!

4. **Verify it's working**:
   - Turn "Spatialize Stereo" on/off
   - You should hear a difference in the audio spatialization
   - The app itself doesn't show this - it's system-controlled

### Troubleshooting Spatial Audio:

**No "Spatialize Stereo" option?**
- Ensure AirPods firmware is up to date
- Check that Spatial Audio is enabled in Bluetooth settings
- Try a different stereo audio file
- Restart the app and try again

**Option appears but no difference?**
- Some audio files may not benefit noticeably from spatialization
- Try with headphone/studio recordings for best effect
- Ensure the audio file is actually stereo (not mono)

## Project Structure Verification

After building, verify these files exist:

```bash
# Check project structure
tree -L 2 JustPlay/

# Should show:
# JustPlay/
# ├── Assets.xcassets/
# ├── Models/
# ├── ViewModels/
# ├── Views/
# ├── JustPlayApp.swift
# ├── AppDelegate.swift
# ├── WindowManager.swift
# ├── Info.plist
# └── JustPlay.entitlements
```

## Common Issues and Solutions

### Issue: "Developer cannot be verified"

**Solution**:
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine ~/Library/Developer/Xcode/DerivedData/JustPlay-*/Build/Products/Debug/JustPlay.app
```

Or: Right-click app → Open → "Open Anyway"

### Issue: No sound when playing

**Checklist**:
- [ ] System volume is not muted
- [ ] Audio output device is correct
- [ ] Audio file is valid (try opening in QuickTime)
- [ ] Check Console.app for AVPlayer errors

### Issue: Window doesn't appear

**Debug**:
1. Check if app is running (look for "JustPlay" in menu bar)
2. Try ⌘O to open a file
3. Check Console.app for errors
4. Verify file is a supported audio format

### Issue: Build fails with "Swift compiler error"

**Solution**:
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/JustPlay-*

# Clean build folder in Xcode
# Product → Clean Build Folder (⌘⇧K)

# Rebuild
xcodebuild -project JustPlay.xcodeproj -scheme JustPlay clean build
```

### Issue: Sandbox violations in Console

**Expected**:
The app is sandboxed. It can only access:
- User-selected files (via NSOpenPanel)
- Downloads folder (read-only)
- Music library (read-only)

**Not expected**:
If you see violations for these, check JustPlay.entitlements.

## Performance Testing

### Memory Usage Test:

```bash
# While app is running with multiple files open:
top -pid $(pgrep JustPlay) -stats pid,command,mem
```

Expected: 20-50 MB with 1-5 files open

### CPU Usage Test:

```bash
# Monitor CPU during playback:
top -pid $(pgrep JustPlay) -stats pid,command,cpu
```

Expected: 0-2% CPU during playback (most work is in audio HAL)

## Development Workflow

### Making Changes:

1. **Edit source files** in Xcode
2. **Build** (⌘B) to check for errors
3. **Run** (⌘R) to test changes
4. **Debug** if needed:
   - Set breakpoints in Xcode
   - Check Console.app for logs
   - Use print() for quick debugging

### Adding Features:

See `IMPLEMENTATION_NOTES.md` for architecture guidance.

### Running Tests:

Currently no unit tests. To add:
1. Product → New → Target → macOS Unit Testing Bundle
2. Create tests for AudioPlayer, PlayerViewModel, etc.

## Distribution

### For Personal Use:

```bash
# Build Release version
xcodebuild -project JustPlay.xcodeproj -scheme JustPlay -configuration Release build

# Copy to Applications
sudo cp -r ~/Library/Developer/Xcode/DerivedData/JustPlay-*/Build/Products/Release/JustPlay.app /Applications/
```

### For Others (Requires Developer Account):

1. Set DEVELOPMENT_TEAM in project settings
2. Choose "Developer ID Application" signing
3. Build Release
4. Notarize with Apple:
   ```bash
   xcrun notarytool submit JustPlay.app --apple-id [email] --password [app-specific-password]
   ```
5. Staple notarization:
   ```bash
   xcrun stapler staple JustPlay.app
   ```

## Next Steps

- Read `README.md` for feature overview
- Read `IMPLEMENTATION_NOTES.md` for technical details
- Open an audio file and enjoy minimal playback!

## Getting Help

**Check these in order**:
1. Console.app - Look for Just Play logs/errors
2. This document - Common issues section
3. IMPLEMENTATION_NOTES.md - Technical details
4. README.md - Feature documentation

**Debug logs**:
```bash
# Watch logs in real-time
log stream --predicate 'processImagePath contains "JustPlay"' --level debug
```

## Success Indicators

You'll know everything is working when:

- ✅ Build succeeds without warnings
- ✅ App launches without errors
- ✅ File → Open brings up file picker
- ✅ Selecting a file creates a circular window
- ✅ Click play starts audio playback
- ✅ Button icon changes to pause
- ✅ Click pause stops audio
- ✅ Can open multiple files simultaneously
- ✅ Windows float above other apps
- ✅ Windows are draggable
- ✅ Closing window stops playback
- ✅ With compatible AirPods: Spatial Audio option appears

Enjoy Just Play!
