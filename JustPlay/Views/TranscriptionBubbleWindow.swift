//
//  TranscriptionBubbleWindow.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// Helper class for creating transcription bubble windows
class TranscriptionBubbleWindowHelper {
    /// Create a floating transcription bubble window for a player
    static func createWindow(for viewModel: TranscriptionViewModel, playerWindow: NSWindow, isCircularMode: Bool = false) -> NSWindow {
        NSLog("🪟 [BUBBLE-CREATE] Creating transcription window - mode: \(isCircularMode ? "circular" : "linear")")

        // Create appropriate view based on mode
        let hostingController: NSHostingController<AnyView>

        if isCircularMode {
            // Circular mode - show words rotating around circle
            viewModel.isCircularMode = true
            let circularView = CircularTranscriptionView(viewModel: viewModel)
            hostingController = NSHostingController(rootView: AnyView(circularView))
        } else {
            // Linear mode - show traditional two-line subtitles
            viewModel.isCircularMode = false
            let linearView = TranscriptionBubbleView(viewModel: viewModel)
            hostingController = NSHostingController(rootView: AnyView(linearView))
        }

        // Window size depends on mode
        let windowSize: NSSize
        if isCircularMode {
            // Larger for circular display
            windowSize = NSSize(width: 200, height: 200)
        } else {
            // Wider for linear display to accommodate more words
            windowSize = NSSize(width: 550, height: 60)
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false  // Views have their own shadows
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = true
        NSLog("🪟 [BUBBLE-CREATE] Window configured: level=.floating, ignoresMouseEvents=true")

        // Position window based on mode
        if isCircularMode {
            NSLog("🪟 [BUBBLE-CREATE] Positioning circular window as overlay")
            positionCircularWindow(window, over: playerWindow)
        } else {
            NSLog("🪟 [BUBBLE-CREATE] Positioning linear window below player")
            positionLinearWindow(window, below: playerWindow)
        }

        NSLog("✅ [BUBBLE-CREATE] Transcription window created successfully")
        return window
    }

    /// Position linear transcription window below the player window
    static func positionLinearWindow(_ transcriptionWindow: NSWindow, below playerWindow: NSWindow) {
        let playerFrame = playerWindow.frame
        NSLog("🪟 [BUBBLE-POSITION-LINEAR] Positioning linear window, player frame: \(playerFrame)")

        // Calculate position: centered horizontally, positioned below player
        let transcriptionWidth: CGFloat = 550
        let transcriptionHeight: CGFloat = 60
        let verticalGap: CGFloat = 10  // Gap between player and transcription

        let transcriptionOrigin = NSPoint(
            x: playerFrame.midX - (transcriptionWidth / 2),  // Center horizontally
            y: playerFrame.minY - transcriptionHeight - verticalGap  // Position below player
        )
        NSLog("🪟 [BUBBLE-POSITION-LINEAR] Calculated origin: \(transcriptionOrigin)")

        transcriptionWindow.setFrame(
            NSRect(origin: transcriptionOrigin, size: NSSize(width: transcriptionWidth, height: transcriptionHeight)),
            display: true
        )
        NSLog("✅ [BUBBLE-POSITION-LINEAR] Window positioned at: \(transcriptionWindow.frame)")
    }

    /// Position circular transcription window as overlay on player window
    static func positionCircularWindow(_ transcriptionWindow: NSWindow, over playerWindow: NSWindow) {
        let playerFrame = playerWindow.frame
        NSLog("🪟 [BUBBLE-POSITION-CIRCULAR] Positioning circular window, player frame: \(playerFrame)")

        // Calculate position: centered on player (overlay)
        let transcriptionSize: CGFloat = 200  // Square window
        let transcriptionOrigin = NSPoint(
            x: playerFrame.midX - (transcriptionSize / 2),  // Center horizontally
            y: playerFrame.midY - (transcriptionSize / 2)   // Center vertically
        )
        NSLog("🪟 [BUBBLE-POSITION-CIRCULAR] Calculated origin: \(transcriptionOrigin)")

        transcriptionWindow.setFrame(
            NSRect(origin: transcriptionOrigin, size: NSSize(width: transcriptionSize, height: transcriptionSize)),
            display: true
        )
        NSLog("✅ [BUBBLE-POSITION-CIRCULAR] Window positioned at: \(transcriptionWindow.frame)")
    }

    /// Legacy method - delegates to positionLinearWindow for backward compatibility
    static func positionWindow(_ transcriptionWindow: NSWindow, below playerWindow: NSWindow) {
        positionLinearWindow(transcriptionWindow, below: playerWindow)
    }
}
