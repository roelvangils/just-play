//
//  TranscriptionViewModel.swift
//  JustPlay
//

import Foundation
import Combine
import SwiftUI

/// View model for managing transcription bubble UI state
class TranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// First line of transcription text (up to 5 words)
    @Published var firstLine: String = "Listening..."

    /// Second line of transcription text (up to 5 words)
    @Published var secondLine: String = ""

    /// Whether the transcription bubble is visible
    @Published var isVisible: Bool = true

    /// Parent player ID for associating transcription with player
    let parentPlayerId: UUID

    /// Legacy property for compatibility (combined text)
    var displayText: String {
        if secondLine.isEmpty {
            return firstLine
        }
        return "\(firstLine)\n\(secondLine)"
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var hideTimer: Timer?

    // MARK: - Initialization

    init(parentPlayerId: UUID) {
        self.parentPlayerId = parentPlayerId
    }

    // MARK: - Public Methods

    /// Update the displayed transcription text
    func updateText(_ text: String) {
        NSLog("📝 [BUBBLE-VM] updateText() called with: '\(text)'")

        // Ignore empty text updates - keep showing "Listening..." or previous text
        guard !text.isEmpty else {
            NSLog("⚠️ [BUBBLE-VM] Ignoring empty text update")
            return
        }

        // Split text into two lines (max ~5 words per line)
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if words.count <= 2 {
            // Single line if 2 words or less
            firstLine = text
            secondLine = ""
        } else {
            // Split into two lines - distribute words evenly, max 5 per line
            let wordsPerLine = min(5, (words.count + 1) / 2) // Round up for first line
            let firstWords = words.prefix(wordsPerLine)
            let secondWords = words.suffix(words.count - wordsPerLine).prefix(5) // Max 5 on second line

            firstLine = firstWords.joined(separator: " ")
            secondLine = secondWords.joined(separator: " ")
        }

        NSLog("📝 [BUBBLE-VM] Lines updated - Line 1: '\(firstLine)' | Line 2: '\(secondLine)'")

        // Show bubble and reset auto-hide timer
        show()
        resetHideTimer()
    }

    /// Show the transcription bubble
    func show() {
        NSLog("👁️ [BUBBLE-VM] show() called, setting isVisible = true")
        isVisible = true
    }

    /// Hide the transcription bubble
    func hide() {
        NSLog("🙈 [BUBBLE-VM] hide() called, setting isVisible = false")
        isVisible = false
        hideTimer?.invalidate()
    }

    /// Clear transcription text
    func clear() {
        NSLog("🧹 [BUBBLE-VM] clear() called")
        firstLine = ""
        secondLine = ""
        hide()
    }

    // MARK: - Private Methods

    /// Reset the auto-hide timer
    private func resetHideTimer() {
        NSLog("⏱️ [BUBBLE-VM] resetHideTimer() called, will hide bubble in 3 seconds")
        hideTimer?.invalidate()

        // Auto-hide after 3 seconds of no new text
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            NSLog("⏱️ [BUBBLE-VM] Hide timer fired, fading out bubble")
            DispatchQueue.main.async {
                // Fade out the bubble
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isVisible = false
                }
            }
        }
    }

    deinit {
        hideTimer?.invalidate()
        cancellables.removeAll()
    }
}
