//
//  AppDelegate.swift
//  JustPlay
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // Hidden window to keep app alive
    private var hiddenWindow: NSWindow?
    private var keyboardMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSLog("🔧 Application will finish launching")

        // Ensure app appears in Dock and has menu bar
        // This must be done in willFinishLaunching for proper file opening
        NSApp.setActivationPolicy(.regular)

        // Create a hidden window that stays open to prevent app from quitting
        createHiddenWindow()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 Application did finish launching")

        // Set up global keyboard monitor for hover-based shortcuts
        setupKeyboardMonitor()

        // Listen for menu updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateColorMenu),
            name: NSNotification.Name("UpdateColorMenu"),
            object: nil
        )

        // Set up menu delegate to customize on open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupMenuDelegate()
        }
    }

    @objc private func updateColorMenu() {
        NSLog("🎨 UpdateColorMenu notification received")
        customizeAllColorMenus()
    }

    private func setupMenuDelegate() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Find and customize all color menus
        customizeAllColorMenus()
    }

    private func customizeAllColorMenus() {
        NSLog("🎨 Customizing color menus...")
        guard let mainMenu = NSApp.mainMenu else {
            NSLog("❌ No main menu")
            return
        }

        for menuItem in mainMenu.items {
            if let submenu = menuItem.submenu {
                customizeMenu(submenu)
            }
        }
    }

    private func customizeMenu(_ menu: NSMenu) {
        for item in menu.items {
            // Check if this is the "New Player Color" submenu
            if item.title == "New Player Color", let colorSubmenu = item.submenu {
                NSLog("✅ Found New Player Color submenu")
                customizeColorMenu(colorSubmenu)
            }

            // Recursively check submenus
            if let submenu = item.submenu {
                customizeMenu(submenu)
            }
        }
    }

    private func createColorCircleImage(hexColor: String) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)

        image.lockFocus()

        // Convert hex to NSColor
        let hex = hexColor.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0

        let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        color.setFill()

        let rect = NSRect(x: 2, y: 2, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)
        path.fill()

        image.unlockFocus()

        return image
    }


    private func customizeColorMenu(_ menu: NSMenu) {
        let colors: [(String, String)] = [
            ("Random", ""),
            ("Green", "6ba64e"),
            ("Gold", "daa843"),
            ("Orange", "e3873a"),
            ("Red", "bb413e"),
            ("Purple", "7e3b84"),
            ("Blue", "3f8bc2")
        ]

        NSLog("   Customizing \(menu.items.count) menu items")

        for item in menu.items {
            // Skip separators
            if item.isSeparatorItem {
                continue
            }

            let originalTitle = item.title
            NSLog("      Processing: '\(originalTitle)'")

            // Find matching color
            for (name, hex) in colors {
                if originalTitle.contains(name) {
                    NSLog("         Matched: \(name)")

                    // Set the image
                    if !hex.isEmpty {
                        item.image = self.createColorCircleImage(hexColor: hex)
                        NSLog("         Set colored circle for \(hex)")
                    }

                    break
                }
            }
        }

        NSLog("   ✅ Color menu customization complete")
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle if there's a hovered view model and no modifiers
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  let hoveredVM = WindowManager.shared.currentlyHoveredViewModel else {
                return event
            }

            // Get the character from the key press
            guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            // Handle keyboard shortcuts for the hovered player
            switch characters {
            case " ": // Space bar
                hoveredVM.togglePlayPause()
                return nil // Consume the event
            case "p":
                hoveredVM.togglePlayPause()
                return nil
            case "r":
                hoveredVM.rewind()
                return nil
            case "b":
                NSLog("⌨️ B pressed - skipping backward 1 second")
                hoveredVM.skip(by: -1.0)
                return nil
            case "f":
                NSLog("⌨️ F pressed - skipping forward 1 second")
                hoveredVM.skip(by: 1.0)
                return nil
            case "t":
                NSLog("⌨️ T pressed - toggling transcription")
                hoveredVM.toggleTranscription()
                return nil
            case "l":
                NSLog("⌨️ L pressed - toggling transcription language")
                hoveredVM.toggleLanguage()
                return nil
            case "x":
                hoveredVM.close()
                return nil
            case "q":
                hoveredVM.close()
                return nil
            default:
                return event // Pass through other keys
            }
        }

        NSLog("⌨️ Global keyboard monitor set up for hover-based shortcuts")
    }

    private func createHiddenWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .normal
        window.ignoresMouseEvents = true
        window.isRestorable = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        // Keep this window open but invisible
        window.orderOut(nil)

        hiddenWindow = window
        NSLog("🪟 Created hidden window to keep app alive")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSLog("📋 JustPlay: applicationShouldTerminateAfterLastWindowClosed called")
        // Don't quit when all windows are closed - allow opening more files
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NSLog("⚠️ JustPlay: applicationShouldTerminate called")
        // Only allow termination if user explicitly quits
        return .terminateNow
    }

    // Modern method - receives all URLs at once
    func application(_ application: NSApplication, open urls: [URL]) {
        NSLog("📂 JustPlay: application:open called with \(urls.count) file(s)")
        for (index, url) in urls.enumerated() {
            NSLog("   [\(index + 1)/\(urls.count)] \(url.lastPathComponent)")
        }

        if urls.count == 1 {
            NSLog("   Opening single file with autoplay")
            WindowManager.shared.openPlayer(for: urls[0], autoPlay: true)
        } else {
            NSLog("   Opening \(urls.count) files, autoplay first only")
            WindowManager.shared.openMultiplePlayers(for: urls, autoPlayFirst: true)
        }

        NSLog("✅ JustPlay: Finished opening files")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up keyboard monitor
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }

        WindowManager.shared.closeAllWindows()
    }
}
