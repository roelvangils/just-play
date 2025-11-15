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

    func close() {
        // Prevent double-close
        guard !isClosing else { return }

        // Capture the id before setting isClosing to prevent retain cycle issues
        let windowId = self.id

        isClosing = true

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
