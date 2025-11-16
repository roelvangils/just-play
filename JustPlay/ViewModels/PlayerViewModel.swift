//
//  PlayerViewModel.swift
//  JustPlay
//

import Foundation
import SwiftUI
import Combine

/// View model for a single player window
class PlayerViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let audioPlayer: AudioPlayer

    @Published var state: PlayerState = .stopped
    @Published var isHovered: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isClosing: Bool = false

    // Transcription
    @Published var isTranscriptionEnabled: Bool = false
    var transcriptionViewModel: TranscriptionViewModel?

    private var cancellables = Set<AnyCancellable>()

    var fileName: String {
        audioPlayer.fileURL.deletingPathExtension().lastPathComponent
    }

    var playPauseIconName: String {
        state.isPlaying ? "pause.fill" : "play.fill"
    }

    var playPauseAccessibilityLabel: String {
        state.isPlaying ? "Pause" : "Play"
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    init(fileURL: URL, autoPlay: Bool = false) {
        self.audioPlayer = AudioPlayer(fileURL: fileURL, autoPlay: autoPlay)

        // Initialize transcription view model
        transcriptionViewModel = TranscriptionViewModel(parentPlayerId: id)

        // Subscribe to audio player state changes
        audioPlayer.$state
            .sink { [weak self] newState in
                self?.state = newState

                // Auto-close when playback ends (if enabled)
                if newState == .ended {
                    // Check UserDefaults for auto-close setting (default to true if not set)
                    let shouldAutoClose: Bool
                    if let value = UserDefaults.standard.object(forKey: "autoCloseMiniPlayers") as? Bool {
                        shouldAutoClose = value
                    } else {
                        shouldAutoClose = true  // Default to enabled
                    }

                    if shouldAutoClose {
                        // Close with animation (same as manual close)
                        DispatchQueue.main.async {
                            self?.close()
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Subscribe to time updates
        audioPlayer.$currentTime
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)

        audioPlayer.$duration
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)
    }

    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }

    func rewind() {
        audioPlayer.rewind()
    }

    func skip(by seconds: TimeInterval) {
        audioPlayer.skip(by: seconds)
    }

    // MARK: - Transcription Methods

    /// Toggle transcription on/off
    func toggleTranscription() {
        NSLog("🔄 [VM-TOGGLE] toggleTranscription() called, current state: \(isTranscriptionEnabled)")

        if isTranscriptionEnabled {
            NSLog("🔄 [VM-TOGGLE] Transcription currently enabled, calling disableTranscription()")
            disableTranscription()
        } else {
            NSLog("🔄 [VM-TOGGLE] Transcription currently disabled, calling enableTranscription()")
            enableTranscription()
        }
    }

    /// Toggle transcription language (English ↔ Dutch)
    func toggleLanguage() {
        NSLog("🌍 [VM-TOGGLE] toggleLanguage() called")
        NSLog("🌍 [VM-TOGGLE] isTranscriptionEnabled: \(isTranscriptionEnabled)")

        guard isTranscriptionEnabled else {
            NSLog("⚠️ [VM-TOGGLE] Transcription not enabled, cannot toggle language")
            return
        }

        NSLog("🌍 [VM-TOGGLE] Checking transcriptionManager...")
        if let manager = audioPlayer.transcriptionManager {
            NSLog("🌍 [VM-TOGGLE] TranscriptionManager exists, calling toggleLanguage()")
            manager.toggleLanguage()
            NSLog("🌍 [VM-TOGGLE] toggleLanguage() called on manager")

            // Show language change notification in bubble
            let languageName = manager.getCurrentLanguageName()
            NSLog("🌍 [VM-TOGGLE] Current language name: \(languageName)")
            transcriptionViewModel?.updateText("Language: \(languageName)")
        } else {
            NSLog("❌ [VM-TOGGLE] TranscriptionManager is nil!")
        }
    }

    /// Enable transcription
    func enableTranscription(locale: Locale = Locale(identifier: "en-US")) {
        NSLog("🎤 [VM-ENABLE] enableTranscription() called for: \(fileName)")

        guard !isTranscriptionEnabled else {
            NSLog("⚠️ [VM-ENABLE] Transcription already enabled, skipping")
            return
        }

        NSLog("🎤 [VM-ENABLE] Enabling transcription in audio player...")
        audioPlayer.enableTranscription(locale: locale)
        NSLog("🎤 [VM-ENABLE] Called audioPlayer.enableTranscription()")

        // Subscribe to transcription updates
        NSLog("🎤 [VM-ENABLE] Subscribing to transcription updates...")
        subscribeToTranscriptionUpdates()
        NSLog("🎤 [VM-ENABLE] Subscribed to transcription updates")

        // Create transcription window
        NSLog("🎤 [VM-ENABLE] Showing transcription window...")
        WindowManager.shared.showTranscriptionWindow(for: self)
        NSLog("🎤 [VM-ENABLE] Called showTranscriptionWindow()")

        isTranscriptionEnabled = true
        NSLog("✅ [VM-ENABLE] Transcription enabled, isEnabled = true")
    }

    /// Disable transcription
    func disableTranscription() {
        NSLog("🛑 [VM-DISABLE] disableTranscription() called for: \(fileName)")

        guard isTranscriptionEnabled else {
            NSLog("⚠️ [VM-DISABLE] Transcription already disabled, skipping")
            return
        }

        NSLog("🛑 [VM-DISABLE] Current state before disable - isEnabled: \(isTranscriptionEnabled)")

        // Disable transcription in audio player
        NSLog("🛑 [VM-DISABLE] Disabling transcription in audio player...")
        audioPlayer.disableTranscription()
        NSLog("🛑 [VM-DISABLE] Called audioPlayer.disableTranscription()")

        // Close transcription window
        NSLog("🛑 [VM-DISABLE] Closing transcription window...")
        WindowManager.shared.closeTranscriptionWindow(for: id)
        NSLog("🛑 [VM-DISABLE] Closed transcription window")

        // Clear transcription display
        NSLog("🛑 [VM-DISABLE] Clearing transcription view model...")
        transcriptionViewModel?.clear()
        NSLog("🛑 [VM-DISABLE] Cleared transcription view model")

        isTranscriptionEnabled = false
        NSLog("✅ [VM-DISABLE] Transcription disabled, isEnabled = false")
    }

    /// Change transcription language
    func setTranscriptionLanguage(_ locale: Locale) {
        audioPlayer.setTranscriptionLanguage(locale)
    }

    // MARK: - Private Transcription Methods

    private func subscribeToTranscriptionUpdates() {
        NSLog("📡 [VM-SUBSCRIBE] Subscribing to transcription updates")

        guard let transcriptionManager = audioPlayer.transcriptionManager else {
            NSLog("❌ [VM-SUBSCRIBE] No transcription manager available")
            return
        }

        // Subscribe to transcription text updates
        transcriptionManager.$currentTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                NSLog("📝 [VM-SUBSCRIBE] Received transcription text: '\(text)'")
                self?.transcriptionViewModel?.updateText(text)
            }
            .store(in: &cancellables)

        NSLog("✅ [VM-SUBSCRIBE] Subscription established")
    }

    func close() {
        // Prevent double-close
        guard !isClosing else { return }

        // Capture the id before setting isClosing to prevent retain cycle issues
        let windowId = self.id

        isClosing = true

        // Disable transcription if enabled
        if isTranscriptionEnabled {
            disableTranscription()
        }

        // Cancel all Combine subscriptions immediately
        cancellables.removeAll()

        // Immediately pause and cleanup audio to prevent issues during cleanup
        audioPlayer.pause()

        // Wait for animation to complete before actually closing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            WindowManager.shared.closeWindow(id: windowId)
        }
    }

    deinit {
        // Ensure cleanup on deallocation
        cancellables.removeAll()
    }
}
