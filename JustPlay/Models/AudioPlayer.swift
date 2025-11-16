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

    // Transcription support
    var transcriptionManager: AudioTranscriptionManager?
    private var audioTap: MTAudioTap?
    private(set) var isTranscriptionEnabled: Bool = false

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

    // MARK: - Transcription Methods

    /// Enable transcription for this audio player
    func enableTranscription(locale: Locale = Locale(identifier: "en-US")) {
        NSLog("🎤 [ENABLE] Starting transcription enable for: \(fileURL.lastPathComponent)")
        TranscriptionLogger.shared.log("================ ENABLE TRANSCRIPTION ================", category: "ENABLE")
        TranscriptionLogger.shared.log("File: \(fileURL.lastPathComponent)", category: "ENABLE")

        guard !isTranscriptionEnabled else {
            NSLog("⚠️ [ENABLE] Transcription already enabled, skipping")
            TranscriptionLogger.shared.log("Already enabled, skipping", category: "ENABLE")
            return
        }

        NSLog("🎤 [ENABLE] Current state - isEnabled: \(isTranscriptionEnabled), manager: \(transcriptionManager != nil), audioTap: \(audioTap != nil)")

        // Create transcription manager if needed
        if transcriptionManager == nil {
            NSLog("🎤 [ENABLE] Creating new transcription manager")
            transcriptionManager = AudioTranscriptionManager()
        }

        guard let transcriptionManager = transcriptionManager else {
            NSLog("❌ [ENABLE] Failed to create transcription manager")
            return
        }

        NSLog("🎤 [ENABLE] Transcription manager exists: \(transcriptionManager)")

        // Request authorization if needed
        NSLog("🎤 [ENABLE] Checking authorization status: \(transcriptionManager.authorizationStatus.rawValue)")

        if transcriptionManager.authorizationStatus == .notDetermined {
            NSLog("🎤 [ENABLE] Authorization not determined, requesting...")
            transcriptionManager.requestAuthorization { [weak self] authorized in
                NSLog("🎤 [ENABLE] Authorization callback - authorized: \(authorized)")
                if authorized {
                    self?.attachAudioTapAndStartRecognition(locale: locale)
                } else {
                    NSLog("❌ [ENABLE] Speech recognition not authorized")
                }
            }
        } else if transcriptionManager.authorizationStatus == .authorized {
            NSLog("🎤 [ENABLE] Already authorized, attaching audio tap")
            attachAudioTapAndStartRecognition(locale: locale)
        } else {
            NSLog("❌ [ENABLE] Speech recognition not authorized: \(transcriptionManager.authorizationStatus.rawValue)")
        }
    }

    /// Disable transcription for this audio player
    func disableTranscription() {
        NSLog("🛑 [DISABLE] Starting transcription disable for: \(fileURL.lastPathComponent)")
        TranscriptionLogger.shared.log("================ DISABLE TRANSCRIPTION ================", category: "DISABLE")
        TranscriptionLogger.shared.log("File: \(fileURL.lastPathComponent)", category: "DISABLE")

        guard isTranscriptionEnabled else {
            NSLog("⚠️ [DISABLE] Transcription already disabled, skipping")
            TranscriptionLogger.shared.log("Already disabled, skipping", category: "DISABLE")
            return
        }

        NSLog("🛑 [DISABLE] Current state - isEnabled: \(isTranscriptionEnabled), manager: \(transcriptionManager != nil), audioTap: \(audioTap != nil)")
        TranscriptionLogger.shared.log("State before disable - isEnabled: \(isTranscriptionEnabled), manager exists: \(transcriptionManager != nil), audioTap exists: \(audioTap != nil)", category: "DISABLE")

        // Mark as disabled immediately to prevent re-entry
        isTranscriptionEnabled = false
        TranscriptionLogger.shared.log("Set isTranscriptionEnabled = false", category: "DISABLE")

        // CRITICAL FIX: Set shutdown flag FIRST to stop new buffer processing
        NSLog("🛑 [DISABLE] Setting shutdown flag on audio tap...")
        TranscriptionLogger.shared.log("Setting shutdown flag...", category: "DISABLE")
        audioTap?.prepareForShutdown()
        NSLog("🛑 [DISABLE] Shutdown flag set")
        TranscriptionLogger.shared.log("Shutdown flag set", category: "DISABLE")

        // Stop recognition immediately - the shutdown flag prevents new buffers
        NSLog("🛑 [DISABLE] Stopping recognition...")
        transcriptionManager?.stopRecognition()
        NSLog("🛑 [DISABLE] Recognition stopped")

        // Use async dispatch to allow in-flight callbacks to complete without blocking main thread
        // Increased drainage time to 150ms to allow all async buffer operations to complete
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }

            NSLog("🛑 [DISABLE] Async (after 150ms drain): Removing audio mix from playerItem...")
            DispatchQueue.main.async {
                self.playerItem?.audioMix = nil
                NSLog("🛑 [DISABLE] Audio mix removed, finalize will be called asynchronously")

                // Schedule final cleanup after finalize completes
                // Increased to 250ms to ensure finalize callback completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    NSLog("🛑 [DISABLE] Final cleanup (after 250ms): Clearing audioTap reference...")
                    TranscriptionLogger.shared.log("Final cleanup - clearing audioTap reference", category: "DISABLE")
                    self?.audioTap = nil
                    NSLog("✅ [DISABLE] Transcription disabled completely")
                    TranscriptionLogger.shared.log("================ TRANSCRIPTION DISABLED ================", category: "DISABLE")
                    TranscriptionLogger.shared.separator()
                    TranscriptionLogger.shared.flush()
                }
            }
        }
    }

    /// Switch transcription language
    func setTranscriptionLanguage(_ locale: Locale) {
        guard isTranscriptionEnabled else {
            NSLog("⚠️ Cannot change language: transcription not enabled")
            return
        }

        NSLog("🌍 Changing transcription language to: \(locale.identifier)")
        transcriptionManager?.setLanguage(locale)
    }

    // MARK: - Private Transcription Methods

    private func attachAudioTapAndStartRecognition(locale: Locale) {
        NSLog("🔗 [ATTACH] Starting audio tap attachment for locale: \(locale.identifier)")

        NSLog("🔗 [ATTACH] Checking prerequisites - PlayerItem: \(playerItem != nil), Manager: \(transcriptionManager != nil)")

        guard let playerItem = playerItem,
              let transcriptionManager = transcriptionManager else {
            NSLog("❌ [ATTACH] Missing player item or transcription manager")
            return
        }

        // Get the first audio track
        NSLog("🔗 [ATTACH] Looking for audio track in asset...")
        guard let audioTrack = playerItem.asset.tracks(withMediaType: .audio).first else {
            NSLog("❌ [ATTACH] No audio track found in asset")
            return
        }
        NSLog("✅ [ATTACH] Found audio track")

        // Create audio tap
        NSLog("🔗 [ATTACH] Creating MTAudioTap instance...")
        let tap = MTAudioTap(transcriptionManager: transcriptionManager)
        NSLog("🔗 [ATTACH] MTAudioTap instance created, calling createTap()...")

        guard let mtTap = tap.createTap(for: audioTrack) else {
            NSLog("❌ [ATTACH] Failed to create MTAudioProcessingTap")
            return
        }
        NSLog("✅ [ATTACH] MTAudioProcessingTap created successfully")

        audioTap = tap
        NSLog("🔗 [ATTACH] Stored audioTap reference")

        // Create audio mix with the tap
        NSLog("🔗 [ATTACH] Creating AVMutableAudioMix...")
        let audioMix = AVMutableAudioMix()
        let audioMixInputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
        audioMixInputParameters.audioTapProcessor = mtTap
        audioMix.inputParameters = [audioMixInputParameters]
        NSLog("🔗 [ATTACH] Audio mix configured with tap processor")

        // Apply audio mix to player item
        NSLog("🔗 [ATTACH] Applying audio mix to playerItem...")
        playerItem.audioMix = audioMix
        NSLog("🔗 [ATTACH] Audio mix applied to playerItem")

        // Set language and start recognition
        NSLog("🔗 [ATTACH] Setting language to: \(locale.identifier)")
        transcriptionManager.setLanguage(locale)

        NSLog("🔗 [ATTACH] Starting recognition...")
        transcriptionManager.startRecognition()

        isTranscriptionEnabled = true
        NSLog("✅ [ATTACH] Audio tap attached and recognition started, isEnabled = true")
        TranscriptionLogger.shared.log("================ TRANSCRIPTION ENABLED ================", category: "ENABLE")
        TranscriptionLogger.shared.separator()
        TranscriptionLogger.shared.flush()
    }

    private func cleanup() {
        NSLog("🧹 AudioPlayer: Cleaning up player for: \(fileURL.lastPathComponent)")

        // Stop transcription if enabled
        if isTranscriptionEnabled {
            transcriptionManager?.stopRecognition()
        }

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

        // Release transcription resources
        audioTap = nil
        transcriptionManager = nil
    }
}
