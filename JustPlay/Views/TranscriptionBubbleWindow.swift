//
//  TranscriptionBubbleWindow.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// Helper class for creating transcription bubble windows
class TranscriptionBubbleWindowHelper {
    /// Create a floating transcription bubble window for a player
    static func createWindow(for viewModel: TranscriptionViewModel, playerWindow: NSWindow) -> NSWindow {
        NSLog("🪟 [BUBBLE-CREATE] Creating transcription bubble window")

        let contentView = TranscriptionBubbleView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false  // Transcription bubble has its own shadow
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = true
        NSLog("🪟 [BUBBLE-CREATE] Window configured: level=.floating, ignoresMouseEvents=true")

        // Position below player window (centered)
        NSLog("🪟 [BUBBLE-CREATE] Positioning window below player")
        positionWindow(window, below: playerWindow)

        NSLog("✅ [BUBBLE-CREATE] Transcription bubble window created successfully")
        return window
    }

    /// Position transcription window below the player window
    static func positionWindow(_ transcriptionWindow: NSWindow, below playerWindow: NSWindow) {
        let playerFrame = playerWindow.frame
        NSLog("🪟 [BUBBLE-POSITION] Positioning transcription window, player frame: \(playerFrame)")

        // Calculate position: centered horizontally, positioned below player
        let transcriptionWidth: CGFloat = 300
        let transcriptionHeight: CGFloat = 60
        let verticalGap: CGFloat = 10  // Gap between player and transcription

        let transcriptionOrigin = NSPoint(
            x: playerFrame.midX - (transcriptionWidth / 2),  // Center horizontally
            y: playerFrame.minY - transcriptionHeight - verticalGap  // Position below player
        )
        NSLog("🪟 [BUBBLE-POSITION] Calculated origin: \(transcriptionOrigin)")

        transcriptionWindow.setFrame(
            NSRect(origin: transcriptionOrigin, size: NSSize(width: transcriptionWidth, height: transcriptionHeight)),
            display: true
        )
        NSLog("✅ [BUBBLE-POSITION] Transcription window positioned at: \(transcriptionWindow.frame)")
    }
}
