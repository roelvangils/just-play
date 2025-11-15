//
//  AudioPlayer.swift
//  JustPlay
//

import Foundation
import AVFoundation
import Combine

/// Wrapper around AVPlayer that manages audio playback for a single file
class AudioPlayer: ObservableObject {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var state: PlayerState = .stopped
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    let fileURL: URL

    init(fileURL: URL, autoPlay: Bool = false) {
        self.fileURL = fileURL
        setupPlayer()

        if autoPlay {
            // Start playing once the player is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.play()
            }
        }
    }

    deinit {
        cleanup()
    }

    private func setupPlayer() {
        // Create player item with the audio file
        playerItem = AVPlayerItem(url: fileURL)

        // Configure for Spatial Audio support
        if #available(macOS 12.0, *) {
            playerItem?.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
        }

        guard let playerItem = playerItem else { return }

        // Create player with automatic wait to minimize latency
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = false

        // Add periodic time observer for progress tracking
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let duration = self?.playerItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
            }
        }

        // Observe playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.handlePlaybackEnded()
            }
            .store(in: &cancellables)

        // Observe player status
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .failed {
                    print("Failed to load audio file: \(self?.fileURL.lastPathComponent ?? "")")
                    self?.state = .stopped
                }
            }
            .store(in: &cancellables)
    }

    func play() {
        guard let player = player else { return }

        // If playback ended, seek back to beginning
        if state == .ended {
            player.seek(to: .zero)
        }

        player.play()
        state = .playing
    }

    func pause() {
        player?.pause()
        state = .paused
    }

    func togglePlayPause() {
        if state.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func rewind() {
        player?.seek(to: .zero)
        currentTime = 0
    }

    func skip(by seconds: TimeInterval) {
        guard let player = player else { return }

        let currentSeconds = player.currentTime().seconds
        let newTime = max(0, min(currentSeconds + seconds, duration))

        player.seek(to: CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }

    private func handlePlaybackEnded() {
        state = .ended
        currentTime = 0
        // Seek back to beginning, ready to play again
        player?.seek(to: .zero)
    }

    private func cleanup() {
        NSLog("🧹 AudioPlayer: Cleaning up player for: \(fileURL.lastPathComponent)")

        // Cancel all Combine subscriptions first
        cancellables.removeAll()

        // Remove time observer before pausing/releasing player
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        // Stop playback
        player?.pause()

        // Release player resources
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
    }
}
