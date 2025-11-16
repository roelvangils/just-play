//
//  WindowManager.swift
//  JustPlay
//

import Foundation
import SwiftUI
import AppKit

/// Manages the creation and lifecycle of player windows
class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published private(set) var playerViewModels: [PlayerViewModel] = []
    @Published var recentItems: [URL] = []
    @Published var currentlyHoveredViewModel: PlayerViewModel?
    private var windows: [UUID: NSWindow] = [:]
    private var transcriptionWindows: [UUID: NSWindow] = [:]
    private var alwaysOnTop: Bool = false

    private let recentItemsKey = "RecentAudioFiles"
    private let maxRecentItems = 10

    private init() {
        loadRecentItems()
    }

    func setHoveredViewModel(_ viewModel: PlayerViewModel?) {
        currentlyHoveredViewModel = viewModel
    }

    func window(for id: UUID) -> NSWindow? {
        return windows[id]
    }

    func configure() {
        // Load always on top setting from UserDefaults
        alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        alwaysOnTop = enabled
        NSLog("🔝 JustPlay WindowManager: Setting always on top to: \(enabled)")

        // Update all existing windows
        for window in windows.values {
            window.level = enabled ? .floating : .normal
        }
    }

    func openPlayer(for fileURL: URL, autoPlay: Bool = true) {
        NSLog("🎵 JustPlay WindowManager: Opening player for: \(fileURL.lastPathComponent)")
        let viewModel = PlayerViewModel(fileURL: fileURL, autoPlay: autoPlay)
        playerViewModels.append(viewModel)
        NSLog("📊 JustPlay WindowManager: Total players: \(playerViewModels.count)")

        // Add to recent items
        addRecentItem(fileURL)

        createWindow(for: viewModel, offsetIndex: 0)
    }

    func openMultiplePlayers(for fileURLs: [URL], autoPlayFirst: Bool = false) {
        NSLog("🎵 JustPlay WindowManager: Opening \(fileURLs.count) players (autoPlayFirst: \(autoPlayFirst))")

        for (index, fileURL) in fileURLs.enumerated() {
            NSLog("   - Opening player \(index + 1)/\(fileURLs.count): \(fileURL.lastPathComponent)")

            // Only autoplay the first file if autoPlayFirst is true
            let shouldAutoPlay = autoPlayFirst && index == 0
            let viewModel = PlayerViewModel(fileURL: fileURL, autoPlay: shouldAutoPlay)
            playerViewModels.append(viewModel)

            // Add to recent items
            addRecentItem(fileURL)

            // Create window with organic offset based on index
            createWindow(for: viewModel, offsetIndex: index)
        }

        NSLog("📊 JustPlay WindowManager: Total players: \(playerViewModels.count)")
    }

    private func addRecentItem(_ url: URL) {
        // Remove if already exists to move it to top
        recentItems.removeAll { $0 == url }

        // Add to beginning
        recentItems.insert(url, at: 0)

        // Keep only max items
        if recentItems.count > maxRecentItems {
            recentItems = Array(recentItems.prefix(maxRecentItems))
        }

        saveRecentItems()
    }

    func clearRecentItems() {
        recentItems.removeAll()
        saveRecentItems()
    }

    private func saveRecentItems() {
        let bookmarks = recentItems.compactMap { url -> Data? in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: recentItemsKey)
    }

    private func loadRecentItems() {
        guard let bookmarks = UserDefaults.standard.array(forKey: recentItemsKey) as? [Data] else {
            return
        }

        recentItems = bookmarks.compactMap { data -> URL? in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            return url
        }
    }

    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mp3,
            .wav,
            .aiff,
            .mpeg4Audio,
            .audio
        ]

        panel.begin { [weak self] response in
            if response == .OK {
                if panel.urls.count == 1 {
                    // Single file - open normally at mouse position
                    self?.openPlayer(for: panel.urls[0])
                } else if panel.urls.count > 1 {
                    // Multiple files - distribute organically around mouse
                    // When using file picker, autoplay first file
                    self?.openMultiplePlayers(for: panel.urls, autoPlayFirst: true)
                }
            }
        }
    }

    private func calculateOrganicOffset(for index: Int) -> CGPoint {
        // First window is centered on mouse
        if index == 0 {
            return .zero
        }

        // Create organic spiral pattern around the mouse
        // Use golden angle (~137.5°) for natural distribution
        let goldenAngle = 137.5 * .pi / 180.0
        let angle = Double(index) * goldenAngle

        // Gradually increase radius with each window
        // Add some randomness for organic feel
        let baseRadius: CGFloat = 100.0
        let radiusIncrement: CGFloat = 60.0
        let randomOffset = CGFloat.random(in: -15...15)
        let radius = baseRadius + (CGFloat(index) * radiusIncrement / 3.0) + randomOffset

        let offsetX = cos(angle) * radius
        let offsetY = sin(angle) * radius

        return CGPoint(x: offsetX, y: offsetY)
    }

    private func createWindow(for viewModel: PlayerViewModel, offsetIndex: Int) {
        NSLog("🪟 JustPlay WindowManager: Creating window for \(viewModel.fileName)")
        let contentView = PlayerWindowView(viewModel: viewModel)
            .frame(width: 160, height: 160)  // Match the view frame

        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 80  // 160/2
        hostingController.view.layer?.masksToBounds = false  // Allow close button to extend beyond circle

        let window = KeyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 160),  // Increased to match
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        NSLog("🔧 JustPlay WindowManager: Configuring window properties")
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = alwaysOnTop ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces]
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Disable window restoration for player windows
        window.isRestorable = false
        window.restorationClass = nil

        // Prevent window from being released when closed
        window.isReleasedWhenClosed = false

        // Set window title for Window menu (important for discoverability)
        window.title = viewModel.fileName
        window.isExcludedFromWindowsMenu = false

        // Position window at mouse cursor with organic offset
        let mouseLocation = NSEvent.mouseLocation
        NSLog("🖱️ JustPlay WindowManager: Mouse location: \(mouseLocation)")

        let offset = calculateOrganicOffset(for: offsetIndex)
        let windowOrigin = NSPoint(
            x: mouseLocation.x - 80 + offset.x,  // Center on mouse (160/2) + organic offset
            y: mouseLocation.y - 80 + offset.y   // Center on mouse (160/2) + organic offset
        )

        // Find the screen containing the mouse cursor
        let screenWithMouse = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main

        NSLog("🖥️ JustPlay WindowManager: Using screen: \(screenWithMouse?.localizedName ?? "unknown")")

        // Ensure window stays within screen bounds
        if let screen = screenWithMouse {
            let screenFrame = screen.visibleFrame
            var adjustedOrigin = windowOrigin

            // Keep window within horizontal bounds
            if adjustedOrigin.x < screenFrame.minX {
                adjustedOrigin.x = screenFrame.minX
            } else if adjustedOrigin.x + 160 > screenFrame.maxX {
                adjustedOrigin.x = screenFrame.maxX - 160
            }

            // Keep window within vertical bounds
            if adjustedOrigin.y < screenFrame.minY {
                adjustedOrigin.y = screenFrame.minY
            } else if adjustedOrigin.y + 160 > screenFrame.maxY {
                adjustedOrigin.y = screenFrame.maxY - 160
            }

            NSLog("📍 JustPlay WindowManager: Final window origin: \(adjustedOrigin)")
            window.setFrameOrigin(adjustedOrigin)
        } else {
            window.setFrameOrigin(windowOrigin)
        }

        // Store window reference
        windows[viewModel.id] = window
        NSLog("💾 JustPlay WindowManager: Stored window reference. Total windows: \(windows.count)")

        // Set up window close handler to clean up
        // Use weak references to avoid retain cycles and crashes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] notification in
            guard let self = self else { return }
            guard window != nil else { return }

            // Find the viewModel by ID to avoid capturing it
            if let vm = self.playerViewModels.first(where: { $0.id == viewModel.id }) {
                self.handleWindowClosed(viewModel: vm)
            }
        }

        NSLog("🎬 JustPlay WindowManager: Making window visible")
        window.makeKeyAndOrderFront(nil)
        NSLog("✅ JustPlay WindowManager: Window should now be visible!")
    }

    func closeWindow(id: UUID) {
        NSLog("🚪 JustPlay WindowManager: closeWindow called for id: \(id)")

        // Cleanup immediately without waiting for notification
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let window = self.windows[id] {
                NSLog("🔍 JustPlay WindowManager: Found window, closing it")

                // Close transcription window first
                self.closeTranscriptionWindow(for: id)

                // Remove from our tracking first
                self.windows.removeValue(forKey: id)
                self.playerViewModels.removeAll { $0.id == id }

                // Then close the window (notification will fire but cleanup already done)
                window.close()

                NSLog("✅ JustPlay WindowManager: Window closed. Remaining windows: \(self.windows.count)")
            } else {
                NSLog("⚠️ JustPlay WindowManager: Window not found for id: \(id)")
            }
        }
    }

    private func handleWindowClosed(viewModel: PlayerViewModel) {
        NSLog("🧹 JustPlay WindowManager: handleWindowClosed for: \(viewModel.fileName)")

        // Perform cleanup on main thread to avoid race conditions
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Close transcription window if it exists
            self.closeTranscriptionWindow(for: viewModel.id)

            // Window might already be removed by closeWindow, so just ensure cleanup
            self.windows.removeValue(forKey: viewModel.id)
            self.playerViewModels.removeAll { $0.id == viewModel.id }

            NSLog("🧹 JustPlay WindowManager: Cleanup complete. Remaining windows: \(self.windows.count)")
        }
    }

    func closeAllWindows() {
        transcriptionWindows.values.forEach { $0.close() }
        transcriptionWindows.removeAll()
        windows.values.forEach { $0.close() }
        windows.removeAll()
        playerViewModels.removeAll()
    }

    func showKeyboardShortcuts() {
        let contentView = KeyboardShortcutsView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "Keyboard Shortcuts"
        window.center()
        window.isReleasedWhenClosed = true
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Transcription Window Management

    /// Create and show a transcription window for a player
    func showTranscriptionWindow(for viewModel: PlayerViewModel) {
        NSLog("🪟 [WINDOW-SHOW] showTranscriptionWindow() called for: \(viewModel.fileName)")

        guard let playerWindow = windows[viewModel.id] else {
            NSLog("❌ [WINDOW-SHOW] Cannot create transcription window: player window not found for id: \(viewModel.id)")
            return
        }
        NSLog("✅ [WINDOW-SHOW] Found player window")

        // Close existing transcription window if any
        NSLog("🪟 [WINDOW-SHOW] Closing any existing transcription window...")
        closeTranscriptionWindow(for: viewModel.id)

        // Create transcription window
        NSLog("🪟 [WINDOW-SHOW] Creating transcription bubble window...")
        let transcriptionWindow = TranscriptionBubbleWindowHelper.createWindow(
            for: viewModel.transcriptionViewModel!,
            playerWindow: playerWindow
        )
        NSLog("🪟 [WINDOW-SHOW] Transcription window created")

        // Store reference
        transcriptionWindows[viewModel.id] = transcriptionWindow
        NSLog("🪟 [WINDOW-SHOW] Stored transcription window reference")

        // Observe player window frame changes to update transcription position
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: playerWindow,
            queue: .main
        ) { [weak self] _ in
            self?.updateTranscriptionWindowPosition(for: viewModel.id)
        }
        NSLog("🪟 [WINDOW-SHOW] Added observer for player window movement")

        // Show the window
        NSLog("🪟 [WINDOW-SHOW] Calling orderFront on transcription window...")
        transcriptionWindow.orderFront(nil)

        NSLog("✅ [WINDOW-SHOW] Transcription window created and shown for player: \(viewModel.fileName)")
    }

    /// Update transcription window position when player window moves
    func updateTranscriptionWindowPosition(for playerId: UUID) {
        guard let playerWindow = windows[playerId],
              let transcriptionWindow = transcriptionWindows[playerId] else {
            return
        }

        NSLog("🪟 [WINDOW-POSITION] Updating transcription window position for player: \(playerId)")
        TranscriptionBubbleWindowHelper.positionWindow(transcriptionWindow, below: playerWindow)
    }

    /// Close transcription window for a specific player
    func closeTranscriptionWindow(for playerId: UUID) {
        if let window = transcriptionWindows[playerId] {
            NSLog("🗑️ [WINDOW-CLOSE] Closing transcription window for player: \(playerId)")
            window.close()
            transcriptionWindows.removeValue(forKey: playerId)
            NSLog("🗑️ [WINDOW-CLOSE] Transcription window closed")
        } else {
            NSLog("⚠️ [WINDOW-CLOSE] No transcription window found for player: \(playerId)")
        }
    }
}
