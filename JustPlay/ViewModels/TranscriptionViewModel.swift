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

    /// Whether circular transcription mode is enabled
    @Published var isCircularMode: Bool = false

    /// Active words for circular transcription mode
    @Published var activeWords: [TranscriptionWord] = []

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
    private var previousText: String = ""
    private var cleanupTimer: Timer?

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

        if isCircularMode {
            // Circular mode: Extract new words and add to circular queue
            updateCircularTranscription(newText: text)
        } else {
            // Linear mode: Split text into two lines (max ~5 words per line)
            updateLinearTranscription(text: text)
        }

        // Show bubble and reset auto-hide timer
        show()
        resetHideTimer()
    }

    /// Update linear (two-line) transcription display
    private func updateLinearTranscription(text: String) {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if words.count <= 3 {
            // Single line if 3 words or less
            firstLine = text
            secondLine = ""
        } else {
            // Split into two lines - distribute words evenly, max 10 per line
            let wordsPerLine = min(10, (words.count + 1) / 2) // Round up for first line
            let firstWords = words.prefix(wordsPerLine)
            let secondWords = words.suffix(words.count - wordsPerLine).prefix(10) // Max 10 on second line

            firstLine = firstWords.joined(separator: " ")
            secondLine = secondWords.joined(separator: " ")
        }

        NSLog("📝 [BUBBLE-VM] Lines updated - Line 1: '\(firstLine)' | Line 2: '\(secondLine)'")
    }

    /// Update circular transcription by adding new words to the queue
    private func updateCircularTranscription(newText: String) {
        // Extract new words that weren't in the previous text
        let newWords = extractNewWords(previous: previousText, current: newText)

        // Add each new word to the circular queue
        for word in newWords {
            let transcriptionWord = TranscriptionWord(
                text: word,
                angle: -.pi / 2,  // Start at top of circle
                opacity: 1.0,
                timestamp: Date()
            )
            activeWords.append(transcriptionWord)
            NSLog("🔄 [BUBBLE-VM-CIRCULAR] Added word to queue: '\(word)'")
        }

        // Update previous text for next diff
        previousText = newText

        // Start cleanup timer if not already running
        startCleanupTimer()

        NSLog("🔄 [BUBBLE-VM-CIRCULAR] Active words count: \(activeWords.count)")
    }

    /// Extract words that are new in the current text compared to previous
    private func extractNewWords(previous: String, current: String) -> [String] {
        let previousWords = previous.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let currentWords = current.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // If current is shorter, user might have restarted - clear and return all words
        guard currentWords.count > previousWords.count else {
            // Check if it's a completely different text
            if !current.hasPrefix(previous) && !previous.isEmpty {
                // Text changed completely, return all current words
                return currentWords
            }
            return []
        }

        // Return words that are new (assumes text is appended, which is typical for speech recognition)
        let newWordsCount = currentWords.count - previousWords.count
        return Array(currentWords.suffix(newWordsCount))
    }

    /// Start timer to periodically clean up fully faded words
    private func startCleanupTimer() {
        // If timer already running, don't start another
        guard cleanupTimer == nil else { return }

        // Run on main thread to ensure thread safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                // Remove words that have fully faded (older than fade duration)
                let fadeDuration: TimeInterval = 3.5
                let now = Date()

                self.activeWords.removeAll { word in
                    let elapsed = now.timeIntervalSince(word.timestamp)
                    return elapsed > fadeDuration
                }

                // Stop timer if no active words
                if self.activeWords.isEmpty {
                    timer.invalidate()
                    self.cleanupTimer = nil
                }
            }
        }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.firstLine = ""
            self.secondLine = ""
            self.activeWords.removeAll()
            self.previousText = ""
            self.cleanupTimer?.invalidate()
            self.cleanupTimer = nil
            self.hide()
        }
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
        cleanupTimer?.invalidate()
        cancellables.removeAll()
    }
}
