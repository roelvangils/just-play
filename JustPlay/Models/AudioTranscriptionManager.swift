//
//  AudioTranscriptionManager.swift
//  JustPlay
//

import Foundation
import Speech
import AVFoundation

/// Manages real-time speech recognition and transcription of audio playback
class AudioTranscriptionManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Current transcription text (last 2-3 words for subtitle display)
    @Published var currentTranscription: String = ""

    /// Full transcription text (all words)
    @Published var fullTranscription: String = ""

    /// Authorization status for speech recognition
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// Whether speech recognition is currently active
    @Published var isRecognizing: Bool = false

    /// Error message if recognition fails
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Current locale for recognition
    private var currentLocale: Locale = Locale(identifier: "en-US")

    /// Supported languages for transcription
    private let supportedLanguages: [Locale] = [
        Locale(identifier: "en-US"),  // English (US)
        Locale(identifier: "nl-NL")   // Dutch (Netherlands)
    ]

    /// Current language index
    private var currentLanguageIndex: Int = 0

    /// Timer for 1-minute timeout workaround
    private var restartTimer: Timer?

    /// Timestamp when recognition started
    private var recognitionStartTime: Date?

    /// Number of words to display at once (2-3 for subtitle effect)
    private let wordWindowSize: Int = 3

    /// Counter for buffer appending (to avoid log spam)
    private var bufferCount: Int = 0

    // MARK: - Initialization

    override init() {
        super.init()
        setupRecognizer(locale: currentLocale)
    }

    deinit {
        stopRecognition()
        restartTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Request authorization for speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status

                switch status {
                case .authorized:
                    NSLog("✅ Speech recognition authorized")
                    completion(true)
                case .denied:
                    NSLog("❌ Speech recognition denied by user")
                    self?.errorMessage = "Speech recognition access denied. Please enable it in System Settings > Privacy & Security > Speech Recognition."
                    completion(false)
                case .restricted:
                    NSLog("❌ Speech recognition restricted")
                    self?.errorMessage = "Speech recognition is restricted on this device."
                    completion(false)
                case .notDetermined:
                    NSLog("⚠️ Speech recognition not determined")
                    completion(false)
                @unknown default:
                    NSLog("❌ Unknown speech recognition authorization status")
                    completion(false)
                }
            }
        }
    }

    /// Change the recognition language
    func setLanguage(_ locale: Locale) {
        NSLog("🌍 Changing transcription language to: \(locale.identifier)")
        TranscriptionLogger.shared.log("Changing language to: \(locale.identifier)", category: "LANGUAGE")

        // CRITICAL: If changing language while recognizing, we need to carefully handle the restart timer
        let wasRecognizing = isRecognizing

        if wasRecognizing {
            NSLog("🌍 [LANGUAGE] Recognition is active, stopping cleanly...")
            TranscriptionLogger.shared.log("Stopping recognition before language change", category: "LANGUAGE")

            // Stop recognition and timer
            stopRecognition()

            // Give a moment for everything to fully stop
            // This prevents race conditions with the restart timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }

                NSLog("🌍 [LANGUAGE] Setting new locale and recognizer...")

                // Set new locale and recognizer
                self.currentLocale = locale
                self.setupRecognizer(locale: locale)

                // Update language index to match
                if let index = self.supportedLanguages.firstIndex(where: { $0.identifier == locale.identifier }) {
                    self.currentLanguageIndex = index
                }

                // Restart recognition with new language
                NSLog("🌍 [LANGUAGE] Restarting recognition with new language...")
                TranscriptionLogger.shared.log("Restarting recognition with locale: \(locale.identifier)", category: "LANGUAGE")
                self.startRecognition()

                TranscriptionLogger.shared.log("Language changed successfully to: \(locale.identifier)", category: "LANGUAGE")
            }
        } else {
            // Not currently recognizing, just update the locale
            currentLocale = locale
            setupRecognizer(locale: locale)

            // Update language index to match
            if let index = supportedLanguages.firstIndex(where: { $0.identifier == locale.identifier }) {
                currentLanguageIndex = index
            }

            TranscriptionLogger.shared.log("Language changed to: \(locale.identifier) (recognition not active)", category: "LANGUAGE")
        }
    }

    /// Toggle to the next supported language
    func toggleLanguage() {
        NSLog("🌍 [TOGGLE] toggleLanguage() called in AudioTranscriptionManager")
        NSLog("🌍 [TOGGLE] Current language index: \(currentLanguageIndex)")
        NSLog("🌍 [TOGGLE] Supported languages count: \(supportedLanguages.count)")

        currentLanguageIndex = (currentLanguageIndex + 1) % supportedLanguages.count
        let newLocale = supportedLanguages[currentLanguageIndex]

        NSLog("🌍 [TOGGLE] New language index: \(currentLanguageIndex)")
        NSLog("🌍 [TOGGLE] Toggling language to: \(newLocale.identifier)")
        TranscriptionLogger.shared.log("Toggling language to: \(newLocale.identifier)", category: "LANGUAGE")

        // CRITICAL: Update currentLocale IMMEDIATELY so getCurrentLanguageName() returns the correct language
        // This must happen before the async delay in setLanguage()
        currentLocale = newLocale

        setLanguage(newLocale)
    }

    /// Get current language display name
    func getCurrentLanguageName() -> String {
        // Get the language name in English for consistency
        let englishLocale = Locale(identifier: "en-US")
        let languageCode = currentLocale.language.languageCode?.identifier ?? currentLocale.identifier

        // Return the language name in English
        if let languageName = englishLocale.localizedString(forLanguageCode: languageCode) {
            return languageName
        }

        // Fallback to identifier if localization fails
        return currentLocale.identifier
    }

    /// Get list of supported locales for on-device recognition
    static func getSupportedLocales() -> [Locale] {
        let allLocales = SFSpeechRecognizer.supportedLocales()

        // Filter for on-device support
        return allLocales.filter { locale in
            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                return false
            }
            return recognizer.supportsOnDeviceRecognition
        }.sorted { $0.identifier < $1.identifier }
    }

    /// Start speech recognition
    func startRecognition() {
        NSLog("🎤 [RECOGNITION] startRecognition() called")
        TranscriptionLogger.shared.log("=== START RECOGNITION CALLED ===", category: "RECOGNITION")
        NSLog("🎤 [RECOGNITION] Current authorization status: \(authorizationStatus.rawValue)")
        TranscriptionLogger.shared.log("Authorization status: \(authorizationStatus.rawValue)", category: "RECOGNITION")

        guard authorizationStatus == .authorized else {
            NSLog("❌ [RECOGNITION] Cannot start recognition: not authorized (\(authorizationStatus.rawValue))")
            errorMessage = "Speech recognition not authorized"
            return
        }
        NSLog("✅ [RECOGNITION] Authorization confirmed")

        NSLog("🎤 [RECOGNITION] Checking speech recognizer availability...")
        guard let speechRecognizer = speechRecognizer else {
            NSLog("❌ [RECOGNITION] speechRecognizer is nil")
            errorMessage = "Speech recognizer not available"
            return
        }

        guard speechRecognizer.isAvailable else {
            NSLog("❌ [RECOGNITION] Speech recognizer not available (isAvailable = false)")
            errorMessage = "Speech recognizer not available. Please enable Voice Control or Dictation in System Settings."
            return
        }
        NSLog("✅ [RECOGNITION] Speech recognizer available")

        // Note: AVAudioSession is iOS-only and not needed on macOS
        // MTAudioProcessingTap provides audio directly to the speech recognizer

        // Stop any existing recognition
        NSLog("🎤 [RECOGNITION] Stopping any existing recognition...")
        stopRecognition()

        // Create and configure the recognition request
        NSLog("🎤 [RECOGNITION] Creating SFSpeechAudioBufferRecognitionRequest...")
        let request = SFSpeechAudioBufferRecognitionRequest()

        // Use on-device recognition if available, otherwise fall back to cloud
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            NSLog("🎤 [RECOGNITION] Configured for ON-DEVICE recognition")
            TranscriptionLogger.shared.log("Using on-device recognition", category: "RECOGNITION")
        } else {
            request.requiresOnDeviceRecognition = false
            NSLog("☁️ [RECOGNITION] Configured for CLOUD-BASED recognition")
            TranscriptionLogger.shared.log("Using cloud-based recognition (requires internet)", category: "RECOGNITION")
        }

        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        NSLog("🎤 [RECOGNITION] Request configured - onDevice: \(request.requiresOnDeviceRecognition), partialResults: \(request.shouldReportPartialResults)")

        // Log the native audio format that the recognizer expects
        NSLog("🎤 [RECOGNITION] Native audio format: \(request.nativeAudioFormat)")
        TranscriptionLogger.shared.logAudioFormat(request.nativeAudioFormat, label: "RECOGNITION NATIVE FORMAT (EXPECTED)")

        recognitionRequest = request
        recognitionStartTime = Date()

        // Start the recognition task
        NSLog("🎤 [RECOGNITION] Starting recognition task...")
        TranscriptionLogger.shared.log("Creating recognition task...", category: "RECOGNITION")
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                NSLog("📝 [RECOGNITION] Got result: '\(transcription)' (isFinal: \(result.isFinal))")
                TranscriptionLogger.shared.log("RESULT: '\(transcription)' (isFinal: \(result.isFinal), segments: \(result.bestTranscription.segments.count))", category: "RECOGNITION")

                DispatchQueue.main.async {
                    // Update full transcription
                    self.fullTranscription = transcription

                    // Extract last 2-3 words for subtitle display
                    let recentWords = self.extractRecentWords(from: transcription)
                    self.currentTranscription = recentWords
                    NSLog("📝 [RECOGNITION] Extracted recent words: '\(recentWords)'")
                }
            }

            if let error = error {
                let nsError = error as NSError
                NSLog("❌ [RECOGNITION] Recognition error: \(error.localizedDescription)")
                NSLog("❌ [RECOGNITION] Error domain: \(nsError.domain), code: \(nsError.code)")
                TranscriptionLogger.shared.log("ERROR: \(error.localizedDescription) | Domain: \(nsError.domain), Code: \(nsError.code)", category: "RECOGNITION")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isRecognizing = false
                }
            } else {
                // Log when callback is called but no result and no error
                if result == nil {
                    NSLog("⚠️ [RECOGNITION] Callback invoked with NO result and NO error")
                    TranscriptionLogger.shared.log("WARNING: Callback invoked with nil result and nil error", category: "RECOGNITION")
                }
            }

            // Check if task is finished
            if result?.isFinal == true || error != nil {
                NSLog("🎤 [RECOGNITION] Task finished (isFinal: \(result?.isFinal ?? false), error: \(error != nil))")
                DispatchQueue.main.async {
                    self.isRecognizing = false
                }
            }
        }

        DispatchQueue.main.async {
            self.isRecognizing = true
            self.errorMessage = nil
        }
        NSLog("🎤 [RECOGNITION] Set isRecognizing = true")
        TranscriptionLogger.shared.log("isRecognizing = true", category: "RECOGNITION")

        // Log recognition task state
        if let task = recognitionTask {
            NSLog("🎤 [RECOGNITION] Recognition task state: \(task.state.rawValue) (0=starting, 1=running, 2=finishing, 3=canceling, 4=completed)")
            TranscriptionLogger.shared.log("Recognition task state: \(task.state.rawValue)", category: "RECOGNITION")
        }

        // Set up timer for 1-minute timeout workaround (restart at 50 seconds)
        // This allows continuous transcription for any length audio
        setupRestartTimer()

        NSLog("✅ [RECOGNITION] Speech recognition started successfully for locale: \(currentLocale.identifier)")
        TranscriptionLogger.shared.log("=== RECOGNITION STARTED SUCCESSFULLY === Locale: \(currentLocale.identifier)", category: "RECOGNITION")
        TranscriptionLogger.shared.separator()
    }

    /// Stop speech recognition
    func stopRecognition() {
        NSLog("🛑 [RECOGNITION] stopRecognition() called")
        TranscriptionLogger.shared.log("=== STOP RECOGNITION CALLED ===", category: "RECOGNITION")

        // CRITICAL: Invalidate restart timer FIRST and SYNCHRONOUSLY to prevent race conditions
        if let timer = restartTimer {
            NSLog("🛑 [RECOGNITION] Invalidating restart timer SYNCHRONOUSLY...")
            TranscriptionLogger.shared.log("Invalidating restart timer", category: "RECOGNITION")
            timer.invalidate()
            restartTimer = nil
            NSLog("🛑 [RECOGNITION] Restart timer invalidated and set to nil")
        } else {
            NSLog("🛑 [RECOGNITION] No restart timer to invalidate")
        }

        // Set isRecognizing to false SYNCHRONOUSLY (not async) to stop buffer processing immediately
        isRecognizing = false
        NSLog("🛑 [RECOGNITION] Set isRecognizing = false (synchronous)")
        TranscriptionLogger.shared.log("isRecognizing set to false", category: "RECOGNITION")

        // Now stop the recognition task and request
        if recognitionTask != nil {
            NSLog("🛑 [RECOGNITION] Cancelling recognition task...")
            recognitionTask?.cancel()
            recognitionTask = nil
            NSLog("🛑 [RECOGNITION] Recognition task cancelled")
        } else {
            NSLog("🛑 [RECOGNITION] No recognition task to cancel")
        }

        if recognitionRequest != nil {
            NSLog("🛑 [RECOGNITION] Ending audio on recognition request...")
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            NSLog("🛑 [RECOGNITION] Recognition request ended")
        } else {
            NSLog("🛑 [RECOGNITION] No recognition request to end")
        }

        TranscriptionLogger.shared.log("=== RECOGNITION STOPPED ===", category: "RECOGNITION")
        NSLog("✅ [RECOGNITION] Speech recognition stopped completely")
    }

    /// Append audio buffer for recognition
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // CRITICAL: Check if recognition is active and request exists before appending
        guard isRecognizing, let request = recognitionRequest else {
            if bufferCount % 100 == 0 {
                NSLog("⚠️ [RECOGNITION] Skipping buffer append - isRecognizing: \(isRecognizing), request exists: \(recognitionRequest != nil)")
            }
            return
        }

        bufferCount += 1
        if bufferCount % 100 == 0 {
            NSLog("📥 [RECOGNITION] Appended buffer #\(bufferCount) to recognition request (frames: \(buffer.frameLength))")
            TranscriptionLogger.shared.log("Buffer #\(bufferCount) appended to recognition request (frames: \(buffer.frameLength), channels: \(buffer.format.channelCount), sampleRate: \(buffer.format.sampleRate))", category: "RECOGNITION")
        }

        // Log first buffer in detail
        if bufferCount == 1 {
            TranscriptionLogger.shared.log("FIRST BUFFER RECEIVED!", category: "RECOGNITION")
            TranscriptionLogger.shared.logAudioFormat(buffer.format, label: "FIRST BUFFER FORMAT")
        }

        request.append(buffer)
    }

    // MARK: - Private Methods

    private func setupRecognizer(locale: Locale) {
        NSLog("🔧 [SETUP] Setting up speech recognizer for locale: \(locale.identifier)")
        TranscriptionLogger.shared.log("Setting up recognizer for locale: \(locale.identifier)", category: "SETUP")

        let recognizer = SFSpeechRecognizer(locale: locale)

        guard let recognizer = recognizer else {
            NSLog("❌ [SETUP] Speech recognizer not available for locale: \(locale.identifier)")
            TranscriptionLogger.shared.log("FAILED: Recognizer not available for locale: \(locale.identifier)", category: "SETUP")
            let languageCode = locale.language.languageCode?.identifier ?? locale.identifier
            errorMessage = "Speech recognition not available for language: \(locale.localizedString(forLanguageCode: languageCode) ?? locale.identifier)"
            return
        }

        NSLog("🔧 [SETUP] Recognizer created, checking support...")
        NSLog("🔧 [SETUP] Recognizer.isAvailable: \(recognizer.isAvailable)")
        NSLog("🔧 [SETUP] Recognizer.supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)")
        TranscriptionLogger.shared.log("Recognizer available: \(recognizer.isAvailable), on-device: \(recognizer.supportsOnDeviceRecognition)", category: "SETUP")

        // Allow both on-device and cloud-based recognition
        // On-device is preferred for privacy, but cloud is used when on-device isn't available
        if recognizer.supportsOnDeviceRecognition {
            NSLog("✅ [SETUP] Using on-device recognition for: \(locale.identifier)")
            TranscriptionLogger.shared.log("Using ON-DEVICE recognition", category: "SETUP")
        } else {
            NSLog("☁️ [SETUP] Using cloud-based recognition for: \(locale.identifier) (on-device not available)")
            TranscriptionLogger.shared.log("Using CLOUD-BASED recognition (on-device not supported)", category: "SETUP")
        }

        self.speechRecognizer = recognizer

        // Set delegate to monitor availability
        recognizer.delegate = self

        NSLog("✅ [SETUP] Speech recognizer set up successfully for locale: \(locale.identifier)")
        TranscriptionLogger.shared.log("Recognizer setup complete for: \(locale.identifier)", category: "SETUP")
    }

    /// Extract the last 2-3 words from transcription for subtitle display
    private func extractRecentWords(from transcription: String) -> String {
        let words = transcription.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard !words.isEmpty else {
            return ""
        }

        // Take last N words (up to wordWindowSize)
        let recentWords = words.suffix(wordWindowSize)
        return recentWords.joined(separator: " ")
    }

    /// Set up timer to restart recognition before 1-minute limit
    private func setupRestartTimer() {
        // CRITICAL: Invalidate any existing timer first
        if let existingTimer = restartTimer {
            NSLog("⏱️ [RESTART] Invalidating existing timer before creating new one")
            TranscriptionLogger.shared.log("Invalidating existing restart timer", category: "RESTART")
            existingTimer.invalidate()
            restartTimer = nil
        }

        // Restart recognition every 50 seconds to avoid 1-minute limit
        // 50 seconds gives us a 10-second buffer before the hard limit
        restartTimer = Timer.scheduledTimer(withTimeInterval: 50.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                NSLog("⏱️ [RESTART] Timer fired but self is nil, invalidating timer")
                timer.invalidate()
                return
            }

            // Double-check we're still recognizing
            guard self.isRecognizing else {
                NSLog("⏱️ [RESTART] Timer fired but not recognizing, invalidating timer")
                TranscriptionLogger.shared.log("Timer fired but not recognizing - invalidating", category: "RESTART")
                timer.invalidate()
                self.restartTimer = nil
                return
            }

            NSLog("⏱️ [RESTART] Timer fired - restarting recognition to avoid 1-minute timeout")
            TranscriptionLogger.shared.log("=== RESTART TIMER FIRED === Restarting recognition", category: "RESTART")

            // Seamlessly restart recognition (only the request/task, NOT the audio tap)
            self.restartRecognition()
        }

        NSLog("⏱️ [RESTART] New timer scheduled to fire every 50 seconds")
        TranscriptionLogger.shared.log("New restart timer scheduled (50 second interval)", category: "RESTART")
    }

    /// Restart recognition seamlessly (for 1-minute timeout workaround)
    /// CRITICAL: This ONLY restarts the recognition request/task, NOT the audio tap
    /// The audio tap continues running and sending buffers to the new request
    private func restartRecognition() {
        NSLog("🔄 [RESTART] Starting seamless restart...")
        TranscriptionLogger.shared.log("Starting seamless recognition restart", category: "RESTART")

        guard authorizationStatus == .authorized,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            NSLog("❌ [RESTART] Cannot restart - not authorized or recognizer unavailable")
            TranscriptionLogger.shared.log("FAILED to restart - authorization or recognizer issue", category: "RESTART")
            return
        }

        // Save current full transcription before restarting
        let previousTranscription = fullTranscription
        NSLog("🔄 [RESTART] Saved previous transcription length: \(previousTranscription.count) characters")

        // Finish current request gracefully (don't cancel - let it complete)
        NSLog("🔄 [RESTART] Finishing current request...")
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        // Create new request IMMEDIATELY (no delay) to minimize gap
        NSLog("🔄 [RESTART] Creating new recognition request...")
        TranscriptionLogger.shared.log("Creating new recognition request", category: "RESTART")

        let request = SFSpeechAudioBufferRecognitionRequest()

        // Use on-device if available, otherwise cloud
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            NSLog("🔄 [RESTART] Using on-device recognition")
        } else {
            request.requiresOnDeviceRecognition = false
            NSLog("☁️ [RESTART] Using cloud-based recognition")
        }

        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        // Update the request reference IMMEDIATELY so new buffers go to the new request
        recognitionRequest = request

        NSLog("🔄 [RESTART] Starting new recognition task...")
        TranscriptionLogger.shared.log("Starting new recognition task", category: "RESTART")

        // Start new recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let newTranscription = result.bestTranscription.formattedString

                DispatchQueue.main.async {
                    // Build continuous transcription by appending new results to previous
                    if !previousTranscription.isEmpty && !newTranscription.isEmpty {
                        self.fullTranscription = previousTranscription + " " + newTranscription
                    } else if !newTranscription.isEmpty {
                        self.fullTranscription = newTranscription
                    } else {
                        self.fullTranscription = previousTranscription
                    }

                    // Extract last 2-3 words for subtitle display
                    self.currentTranscription = self.extractRecentWords(from: self.fullTranscription)
                }
            }

            if let error = error {
                let nsError = error as NSError
                NSLog("❌ [RESTART] Recognition error after restart: \(error.localizedDescription)")
                TranscriptionLogger.shared.log("Recognition error after restart: \(error.localizedDescription) | Domain: \(nsError.domain), Code: \(nsError.code)", category: "RESTART")
            }
        }

        NSLog("✅ [RESTART] Recognition restarted seamlessly - audio tap continues sending buffers to new request")
        TranscriptionLogger.shared.log("=== RESTART COMPLETE === New request receiving buffers", category: "RESTART")
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AudioTranscriptionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if available {
                NSLog("✅ Speech recognizer became available")
                self.errorMessage = nil
            } else {
                NSLog("⚠️ Speech recognizer became unavailable")
                self.errorMessage = "Speech recognition temporarily unavailable"
                self.isRecognizing = false
            }
        }
    }
}

// MARK: - Transcription Logger

/// Dedicated logger for transcription debugging
class TranscriptionLogger {
    static let shared = TranscriptionLogger()

    private var fileHandle: FileHandle?
    private let logQueue = DispatchQueue(label: "com.justplay.transcription-logger", qos: .utility)
    private let logFilePath: URL

    private init() {
        // Create log file in Documents folder for easy access
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFilePath = documentsPath.appendingPathComponent("JustPlay_Transcription_Debug.log")

        setupLogFile()
    }

    private func setupLogFile() {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // Create or truncate log file
            FileManager.default.createFile(atPath: self.logFilePath.path, contents: nil, attributes: nil)

            do {
                self.fileHandle = try FileHandle(forWritingTo: self.logFilePath)

                // Write header
                let header = """
                ================================================================================
                JustPlay Transcription Debug Log
                Started: \(Date())
                Log file location: \(self.logFilePath.path)
                ================================================================================

                """
                if let data = header.data(using: .utf8) {
                    self.fileHandle?.write(data)
                }

                // Also print to console
                print("📝 [LOGGER] Transcription log file created at: \(self.logFilePath.path)")
            } catch {
                print("❌ [LOGGER] Failed to create log file: \(error)")
            }
        }
    }

    func log(_ message: String, category: String = "GENERAL") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formattedMessage = "[\(timestamp)] [\(category)] \(message)\n"

        // Write to file
        logQueue.async { [weak self] in
            guard let self = self,
                  let data = formattedMessage.data(using: .utf8) else { return }

            self.fileHandle?.write(data)
        }

        // Also print to console for NSLog compatibility
        print("🔍 \(formattedMessage)", terminator: "")
    }

    func logAudioFormat(_ format: AVAudioFormat?, label: String) {
        guard let format = format else {
            log("Audio format is NIL", category: "AUDIO-FORMAT")
            return
        }

        let message = """
        \(label):
          - Sample Rate: \(format.sampleRate) Hz
          - Channels: \(format.channelCount)
          - Common Format: \(format.commonFormat.rawValue)
          - Interleaved: \(format.isInterleaved)
          - Standard: \(format.isStandard)
        """
        log(message, category: "AUDIO-FORMAT")
    }

    func logError(_ error: Error, context: String) {
        log("ERROR in \(context): \(error.localizedDescription)", category: "ERROR")
    }

    func separator() {
        log("--------------------------------------------------------------------------------", category: "SEPARATOR")
    }

    func flush() {
        logQueue.async { [weak self] in
            self?.fileHandle?.synchronizeFile()
        }
    }

    deinit {
        fileHandle?.closeFile()
    }
}
