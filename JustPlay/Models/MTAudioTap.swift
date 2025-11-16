//
//  MTAudioTap.swift
//  JustPlay
//

import Foundation
import AVFoundation
import MediaToolbox

/// Wrapper for MTAudioProcessingTap to capture audio from AVPlayer
class MTAudioTap {
    // MARK: - Properties

    private(set) var tap: MTAudioProcessingTap?
    fileprivate weak var transcriptionManager: AudioTranscriptionManager?

    /// Audio format for the tap (original format from MTAudioProcessingTap)
    fileprivate var audioFormat: AVAudioFormat?

    /// Mono audio format for speech recognition
    fileprivate var monoFormat: AVAudioFormat?

    /// Audio converter for stereo → mono conversion (if needed)
    fileprivate var audioConverter: AVAudioConverter?

    /// Target format for speech recognition (16kHz, Int16, mono, interleaved)
    fileprivate var speechRecognitionFormat: AVAudioFormat?

    /// Audio converter for format conversion to speech recognition format
    fileprivate var recognitionFormatConverter: AVAudioConverter?

    /// Pre-allocated buffer pool for performance
    fileprivate var bufferPool: [AVAudioPCMBuffer] = []
    fileprivate let bufferPoolSize: Int = 10

    /// Thread-safe shutdown flag to prevent race conditions during cleanup
    private let shutdownLock = NSLock()
    private var _isShuttingDown: Bool = false

    /// Thread-safe getter/setter for shutdown state
    fileprivate var isShuttingDown: Bool {
        get {
            shutdownLock.lock()
            defer { shutdownLock.unlock() }
            return _isShuttingDown
        }
        set {
            shutdownLock.lock()
            _isShuttingDown = newValue
            shutdownLock.unlock()
        }
    }

    // MARK: - Initialization

    init(transcriptionManager: AudioTranscriptionManager) {
        self.transcriptionManager = transcriptionManager
        NSLog("🎯 [TAP-INIT] MTAudioTap instance created: \(Unmanaged.passUnretained(self).toOpaque())")
    }

    deinit {
        NSLog("🗑️ [TAP-DEINIT] MTAudioTap instance deallocating: \(Unmanaged.passUnretained(self).toOpaque())")
        tap = nil  // Release the tap
        bufferPool.removeAll()
    }

    // MARK: - Public Methods

    /// Prepare the tap for shutdown by setting the shutdown flag
    /// This prevents new audio buffers from being processed
    func prepareForShutdown() {
        NSLog("🛑 [TAP-SHUTDOWN] Setting shutdown flag to prevent buffer processing")
        isShuttingDown = true
    }

    /// Create the audio processing tap for an audio track
    func createTap(for audioTrack: AVAssetTrack) -> MTAudioProcessingTap? {
        NSLog("🎯 [TAP-CREATE] Creating tap with passRetained for: \(Unmanaged.passUnretained(self).toOpaque())")

        // Use passRetained to keep the object alive for the tap's lifetime
        // The extra retain will be released in tapFinalize
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        NSLog("🎯 [TAP-CREATE] Callbacks configured, calling MTAudioProcessingTapCreate...")

        var tapRef: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapRef
        )

        guard status == noErr, let createdTap = tapRef else {
            NSLog("❌ [TAP-CREATE] Failed to create MTAudioProcessingTap: OSStatus \(status)")
            return nil
        }

        // Store the tap
        self.tap = createdTap
        NSLog("✅ [TAP-CREATE] Stored tap reference: \(Unmanaged.passUnretained(self).toOpaque())")

        NSLog("✅ [TAP-CREATE] MTAudioProcessingTap created successfully")

        return createdTap
    }

    // MARK: - Private Methods (fileprivate for C callbacks)

    /// Counter for process callback logging (to avoid spam)
    fileprivate var processCallCount: Int = 0

    /// Pre-allocate buffer pool for performance
    fileprivate func allocateBufferPool(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        bufferPool.removeAll()

        for _ in 0..<bufferPoolSize {
            if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) {
                bufferPool.append(buffer)
            }
        }

        NSLog("📦 [TAP] Allocated buffer pool with \(bufferPool.count) buffers")
    }

    /// Get a buffer from the pool or create a new one
    fileprivate func getBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        // Try to reuse from pool
        if let buffer = bufferPool.first {
            bufferPool.removeFirst()
            buffer.frameLength = 0 // Reset frame length
            return buffer
        }

        // Create new buffer if pool is empty
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
    }

    /// Return buffer to pool
    fileprivate func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        if bufferPool.count < bufferPoolSize {
            buffer.frameLength = 0
            bufferPool.append(buffer)
        }
    }
}

// MARK: - MTAudioProcessingTap Callbacks

/// Initialize callback
private func tapInit(tap: MTAudioProcessingTap, clientInfo: UnsafeMutableRawPointer?, tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) {
    NSLog("🎯 [TAP-CALLBACK-INIT] Init callback called")
    // Store the client info in tap storage so other callbacks can access it
    tapStorageOut.pointee = clientInfo
    NSLog("🎯 [TAP-CALLBACK-INIT] Stored clientInfo in tap storage")
}

/// Finalize callback
private func tapFinalize(tap: MTAudioProcessingTap) {
    NSLog("🎯 [TAP-CALLBACK-FINALIZE] Finalize callback START")

    // Balance the passRetained from createTap by consuming the extra retain
    // This releases the manual retain but doesn't deallocate (audioTap property still holds a reference)
    let storage = MTAudioProcessingTapGetStorage(tap)
    NSLog("🎯 [TAP-CALLBACK-FINALIZE] Storage: \(storage), releasing retained reference")

    // This consumes the extra retain from passRetained
    _ = Unmanaged<MTAudioTap>.fromOpaque(storage).takeRetainedValue()

    NSLog("🎯 [TAP-CALLBACK-FINALIZE] Finalize callback END - retained reference released")
}

/// Prepare callback - called when audio format is known
private func tapPrepare(tap: MTAudioProcessingTap, maxFrames: CMItemCount, processingFormat: UnsafePointer<AudioStreamBasicDescription>) {
    NSLog("🎯 [TAP-CALLBACK-PREPARE] Prepare callback START - maxFrames: \(maxFrames)")
    TranscriptionLogger.shared.log("=== TAP PREPARE STARTED ===", category: "TAP-PREPARE")

    // Get the MTAudioTap instance from storage
    let storage = MTAudioProcessingTapGetStorage(tap)
    NSLog("🎯 [TAP-CALLBACK-PREPARE] Got storage: \(storage)")

    let audioTap = Unmanaged<MTAudioTap>.fromOpaque(storage).takeUnretainedValue()
    NSLog("🎯 [TAP-CALLBACK-PREPARE] Got MTAudioTap instance from storage")

    // Create AVAudioFormat from AudioStreamBasicDescription
    let format = AVAudioFormat(streamDescription: processingFormat)

    guard let format = format else {
        NSLog("❌ [TAP-CALLBACK-PREPARE] Failed to create AVAudioFormat from stream description")
        TranscriptionLogger.shared.log("FAILED to create AVAudioFormat", category: "TAP-PREPARE")
        return
    }

    audioTap.audioFormat = format
    NSLog("🎯 [TAP-CALLBACK-PREPARE] Set audio format")
    TranscriptionLogger.shared.logAudioFormat(format, label: "SOURCE AUDIO FORMAT")

    // CRITICAL: Create mono format and converter if source is stereo
    // SFSpeechRecognizer requires MONO audio - stereo will silently fail
    if format.channelCount > 1 {
        NSLog("🔄 [TAP-CALLBACK-PREPARE] Source audio is STEREO (\(format.channelCount) channels) - creating mono converter")
        TranscriptionLogger.shared.log("Source is STEREO with \(format.channelCount) channels - will convert to MONO", category: "TAP-PREPARE")

        // Create mono format at the same sample rate
        guard let monoFormat = AVAudioFormat(
            commonFormat: format.commonFormat,
            sampleRate: format.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            NSLog("❌ [TAP-CALLBACK-PREPARE] Failed to create mono audio format")
            return
        }

        audioTap.monoFormat = monoFormat
        NSLog("✅ [TAP-CALLBACK-PREPARE] Created mono format: \(monoFormat.sampleRate) Hz, 1 channel")

        // Create audio converter for stereo → mono conversion
        guard let converter = AVAudioConverter(from: format, to: monoFormat) else {
            NSLog("❌ [TAP-CALLBACK-PREPARE] Failed to create audio converter")
            return
        }

        audioTap.audioConverter = converter
        NSLog("✅ [TAP-CALLBACK-PREPARE] Created stereo → mono converter")
        TranscriptionLogger.shared.log("Audio converter created successfully", category: "TAP-PREPARE")
        TranscriptionLogger.shared.logAudioFormat(monoFormat, label: "MONO TARGET FORMAT")
    } else {
        NSLog("✅ [TAP-CALLBACK-PREPARE] Source audio is already MONO - no conversion needed")
        TranscriptionLogger.shared.log("Source is already MONO - no conversion needed", category: "TAP-PREPARE")
        audioTap.monoFormat = format
        audioTap.audioConverter = nil
    }

    // CRITICAL: Create speech recognition format (16kHz, Int16, mono, interleaved)
    // This is the native format expected by SFSpeechRecognizer
    NSLog("🔄 [TAP-CALLBACK-PREPARE] Creating speech recognition format (16kHz, Int16, interleaved)")
    TranscriptionLogger.shared.log("Creating speech recognition format: 16kHz, Int16, mono, interleaved", category: "TAP-PREPARE")

    guard let recognitionFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,  // Int16 PCM
        sampleRate: 16000,               // 16kHz
        channels: 1,                     // Mono
        interleaved: true                // Interleaved
    ) else {
        NSLog("❌ [TAP-CALLBACK-PREPARE] Failed to create speech recognition format")
        TranscriptionLogger.shared.log("FAILED to create speech recognition format", category: "TAP-PREPARE")
        return
    }

    audioTap.speechRecognitionFormat = recognitionFormat
    TranscriptionLogger.shared.logAudioFormat(recognitionFormat, label: "SPEECH RECOGNITION TARGET FORMAT")

    // Create converter from mono format → speech recognition format
    guard let monoFormat = audioTap.monoFormat else {
        NSLog("❌ [TAP-CALLBACK-PREPARE] Mono format is nil")
        return
    }

    guard let formatConverter = AVAudioConverter(from: monoFormat, to: recognitionFormat) else {
        NSLog("❌ [TAP-CALLBACK-PREPARE] Failed to create format converter")
        TranscriptionLogger.shared.log("FAILED to create format converter", category: "TAP-PREPARE")
        return
    }

    audioTap.recognitionFormatConverter = formatConverter
    NSLog("✅ [TAP-CALLBACK-PREPARE] Created format converter: \(monoFormat.sampleRate)Hz Float32 → 16kHz Int16")
    TranscriptionLogger.shared.log("Format converter created: \(monoFormat.sampleRate)Hz Float32 → 16kHz Int16", category: "TAP-PREPARE")

    // Pre-allocate buffer pool using RECOGNITION format (16kHz Int16)
    // Calculate frame capacity for 16kHz (will be smaller than original)
    let recognitionFrameCapacity = AVAudioFrameCount(Double(maxFrames) * (16000.0 / monoFormat.sampleRate))
    audioTap.allocateBufferPool(format: recognitionFormat, frameCapacity: recognitionFrameCapacity)
    TranscriptionLogger.shared.log("Buffer pool allocated with capacity: \(recognitionFrameCapacity) frames at 16kHz", category: "TAP-PREPARE")

    NSLog("✅ [TAP-CALLBACK-PREPARE] Prepare complete - Source: \(format.sampleRate) Hz, \(format.channelCount) channels → Output: 16kHz, Int16, mono, interleaved")
    TranscriptionLogger.shared.log("=== TAP PREPARE COMPLETE === Output: 16kHz, Int16, mono, interleaved", category: "TAP-PREPARE")
    TranscriptionLogger.shared.separator()
}

/// Unprepare callback
private func tapUnprepare(tap: MTAudioProcessingTap) {
    NSLog("🎯 [TAP-CALLBACK-UNPREPARE] Unprepare callback called")
}

/// Process callback - called for each audio buffer (REAL-TIME - NO ALLOCATIONS!)
private func tapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    // CRITICAL: Check shutdown flag IMMEDIATELY before processing
    // This must be checked BEFORE getting source audio to prevent race condition
    let storage = MTAudioProcessingTapGetStorage(tap)
    let audioTap = Unmanaged<MTAudioTap>.fromOpaque(storage).takeUnretainedValue()

    // If shutting down, abort immediately without processing
    guard !audioTap.isShuttingDown else {
        // Don't log here - this is a real-time callback
        return
    }

    // Get the source audio (this fills bufferListInOut with audio data)
    var timeRange = CMTimeRange()
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        &timeRange,
        numberFramesOut
    )

    guard status == noErr else {
        NSLog("❌ [TAP-CALLBACK-PROCESS] Failed to get source audio: OSStatus \(status)")
        return
    }

    // audioTap instance already retrieved at the start of function for shutdown check

    // Log every 100th call to avoid spam
    audioTap.processCallCount += 1
    if audioTap.processCallCount % 100 == 0 {
        NSLog("🎯 [TAP-CALLBACK-PROCESS] Process callback #\(audioTap.processCallCount), frames: \(numberFrames)")
    }

    guard let audioFormat = audioTap.audioFormat else {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("⚠️ [TAP-CALLBACK-PROCESS] audioFormat is nil")
        }
        return
    }

    guard let transcriptionManager = audioTap.transcriptionManager else {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("⚠️ [TAP-CALLBACK-PROCESS] transcriptionManager is nil")
        }
        return
    }

    // Convert AudioBufferList to AVAudioPCMBuffer
    // CRITICAL: Must copy buffer data SYNCHRONOUSLY before dispatching async
    let frameCount = AVAudioFrameCount(numberFramesOut.pointee)

    // Create or get buffer from pool (synchronously)
    guard let pcmBuffer = audioTap.getBuffer(format: audioFormat, frameCapacity: frameCount) else {
        return
    }

    pcmBuffer.frameLength = frameCount

    // Copy audio data from AudioBufferList to AVAudioPCMBuffer SYNCHRONOUSLY
    // This must happen in the callback while bufferListInOut is still valid
    let audioBufferList = bufferListInOut.pointee
    let audioBufferCount = Int(audioBufferList.mNumberBuffers)

    for bufferIndex in 0..<min(audioBufferCount, Int(audioFormat.channelCount)) {
        // Access buffer using withUnsafePointer for safe access
        withUnsafePointer(to: audioBufferList.mBuffers) { buffersPtr in
            let audioBuffer = UnsafeBufferPointer(start: buffersPtr, count: audioBufferCount)[bufferIndex]

            if let channelData = pcmBuffer.floatChannelData?[bufferIndex],
               let sourceData = audioBuffer.mData?.assumingMemoryBound(to: Float.self) {
                // Copy samples synchronously while pointer is valid
                channelData.update(from: sourceData, count: Int(frameCount))
            }
        }
    }

    // Step 1: Convert stereo to mono if needed
    let monoBuffer: AVAudioPCMBuffer
    if let converter = audioTap.audioConverter, let monoFormat = audioTap.monoFormat {
        // Convert stereo buffer to mono
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: frameCount) else {
            if audioTap.processCallCount % 100 == 0 {
                NSLog("❌ [TAP-CALLBACK-PROCESS] Failed to create mono buffer for conversion")
            }
            audioTap.returnBuffer(pcmBuffer)
            return
        }

        convertedBuffer.frameLength = frameCount

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return pcmBuffer
        }

        let conversionStatus = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            if audioTap.processCallCount % 100 == 0 {
                NSLog("❌ [TAP-CALLBACK-PROCESS] Stereo→mono conversion error: \(error.localizedDescription)")
            }
            audioTap.returnBuffer(pcmBuffer)
            return
        }

        if conversionStatus == .error {
            if audioTap.processCallCount % 100 == 0 {
                NSLog("❌ [TAP-CALLBACK-PROCESS] Stereo→mono conversion failed with status: \(conversionStatus.rawValue)")
            }
            audioTap.returnBuffer(pcmBuffer)
            return
        }

        if audioTap.processCallCount % 100 == 0 {
            NSLog("🔄 [TAP-CALLBACK-PROCESS] Converted stereo → mono successfully")
            TranscriptionLogger.shared.log("Buffer #\(audioTap.processCallCount): Converted STEREO → MONO", category: "TAP-PROCESS")
        }

        monoBuffer = convertedBuffer
        // Return stereo buffer to pool since we're using mono buffer
        audioTap.returnBuffer(pcmBuffer)
    } else {
        // No stereo→mono conversion needed (already mono)
        monoBuffer = pcmBuffer
    }

    // Step 2: Convert to speech recognition format (16kHz Int16)
    guard let recognitionConverter = audioTap.recognitionFormatConverter,
          let recognitionFormat = audioTap.speechRecognitionFormat else {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("❌ [TAP-CALLBACK-PROCESS] Recognition format converter not available")
        }
        if audioTap.audioConverter != nil {
            // monoBuffer is not from pool, don't return
        } else {
            audioTap.returnBuffer(monoBuffer)
        }
        return
    }

    // Calculate output frame count for 16kHz conversion
    let outputFrameCount = AVAudioFrameCount(Double(monoBuffer.frameLength) * (16000.0 / monoBuffer.format.sampleRate))

    guard let recognitionBuffer = AVAudioPCMBuffer(pcmFormat: recognitionFormat, frameCapacity: outputFrameCount) else {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("❌ [TAP-CALLBACK-PROCESS] Failed to create recognition format buffer")
        }
        return
    }

    recognitionBuffer.frameLength = outputFrameCount

    var conversionError: NSError?
    let recognitionInputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
        outStatus.pointee = .haveData
        return monoBuffer
    }

    let recognitionConversionStatus = recognitionConverter.convert(to: recognitionBuffer, error: &conversionError, withInputFrom: recognitionInputBlock)

    if let error = conversionError {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("❌ [TAP-CALLBACK-PROCESS] Format conversion error: \(error.localizedDescription)")
            TranscriptionLogger.shared.log("Format conversion error: \(error.localizedDescription)", category: "TAP-PROCESS")
        }
        return
    }

    if recognitionConversionStatus == .error {
        if audioTap.processCallCount % 100 == 0 {
            NSLog("❌ [TAP-CALLBACK-PROCESS] Format conversion failed with status: \(recognitionConversionStatus.rawValue)")
        }
        return
    }

    if audioTap.processCallCount % 100 == 0 {
        NSLog("🔄 [TAP-CALLBACK-PROCESS] Converted to recognition format: \(monoBuffer.format.sampleRate)Hz Float32 → 16kHz Int16")
        TranscriptionLogger.shared.log("Buffer #\(audioTap.processCallCount): Converted to 16kHz Int16 (frames: \(monoBuffer.frameLength) → \(recognitionBuffer.frameLength))", category: "TAP-PROCESS")
    }

    let bufferToSend = recognitionBuffer

    // NOW dispatch async with the already-filled buffer (mono if converted, original if already mono)
    DispatchQueue.global(qos: .userInitiated).async {
        autoreleasepool {
            // Double-check shutdown flag in async block too (defensive)
            guard !audioTap.isShuttingDown else {
                // Note: bufferToSend might not be in pool if it's a converted buffer
                if audioTap.audioConverter == nil {
                    audioTap.returnBuffer(bufferToSend)
                }
                return
            }

            // Send buffer to speech recognition (only if still recognizing)
            // Check if recognition is still active to avoid enqueueing during shutdown
            guard transcriptionManager.isRecognizing else {
                if audioTap.processCallCount % 100 == 0 {
                    NSLog("⚠️ [TAP-CALLBACK-PROCESS] Recognition not active, skipping buffer #\(audioTap.processCallCount)")
                }
                // Note: bufferToSend might not be in pool if it's a converted buffer
                if audioTap.audioConverter == nil {
                    audioTap.returnBuffer(bufferToSend)
                }
                return
            }

            // CRITICAL: Final check right before appending to prevent race conditions
            guard !audioTap.isShuttingDown && transcriptionManager.isRecognizing else {
                if audioTap.processCallCount % 100 == 0 {
                    NSLog("⚠️ [TAP-CALLBACK-PROCESS] Final check failed - shutting down or not recognizing")
                }
                return
            }

            if audioTap.processCallCount % 100 == 0 {
                NSLog("📤 [TAP-CALLBACK-PROCESS] Sending 16kHz Int16 buffer #\(audioTap.processCallCount) to transcription manager")
                TranscriptionLogger.shared.log("Buffer #\(audioTap.processCallCount): Sending to transcription manager (frames: \(bufferToSend.frameLength), format: 16kHz Int16)", category: "TAP-PROCESS")
            }
            transcriptionManager.appendAudioBuffer(bufferToSend)

            // Note: Recognition buffers are created fresh each time, not from pool
        }
    }
}
