//
//  TranscriptionLogger.swift
//  JustPlay
//

import Foundation

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
