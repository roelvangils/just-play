//
//  CircularTranscriptionView.swift
//  JustPlay
//

import SwiftUI

/// Model representing a single word in the circular transcription
struct TranscriptionWord: Identifiable {
    let id = UUID()
    var text: String
    var angle: Double          // Current angle in radians (0 = top, increases clockwise)
    var opacity: Double        // Current opacity (1.0 = fully visible, 0.0 = invisible)
    let timestamp: Date        // When this word was added
}

/// Circular transcription view that displays words rotating around in a circle
struct CircularTranscriptionView: View {
    @ObservedObject var viewModel: TranscriptionViewModel

    // Visual configuration
    private let radius: CGFloat = 60
    private let fontSize: CGFloat = 16
    private let fadeDuration: TimeInterval = 3.5  // 3.5 seconds for full rotation
    private let angularVelocity: Double = .pi / 2  // 90 degrees per second (π/2 radians/sec)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Draw each active word
                for word in viewModel.activeWords {
                    // Calculate elapsed time since word was added
                    let elapsed = timeline.date.timeIntervalSince(word.timestamp)

                    // Calculate current angle (starts at top -π/2, rotates clockwise)
                    let currentAngle = word.angle + (elapsed * angularVelocity)

                    // Calculate current opacity (fades from 1.0 to 0.0)
                    let currentOpacity = max(0, 1.0 - (elapsed / fadeDuration))

                    // Skip if fully faded
                    guard currentOpacity > 0.01 else { continue }

                    // Calculate position on circle
                    let x = center.x + radius * cos(currentAngle)
                    let y = center.y + radius * sin(currentAngle)
                    let position = CGPoint(x: x, y: y)

                    // Calculate rotation for text to face outward
                    let rotation = calculateTextRotation(angle: currentAngle)

                    // Create text with styling
                    let text = context.resolve(
                        Text(word.text)
                            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )

                    // Draw shadow
                    var shadowContext = context
                    shadowContext.opacity = currentOpacity * 0.7
                    shadowContext.translateBy(x: position.x, y: position.y + 1)
                    shadowContext.rotate(by: Angle(radians: rotation))
                    shadowContext.draw(text, at: .zero, anchor: .center)

                    // Draw main text
                    var textContext = context
                    textContext.opacity = currentOpacity
                    textContext.translateBy(x: position.x, y: position.y)
                    textContext.rotate(by: Angle(radians: rotation))
                    textContext.draw(text, at: .zero, anchor: .center)
                }
            }
            .frame(width: 160, height: 160)
        }
    }

    /// Calculate the rotation angle for text so it always faces outward
    private func calculateTextRotation(angle: Double) -> Double {
        // Normalize angle to 0-2π range
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)

        // For bottom half of circle (π/2 to 3π/2), flip text 180 degrees
        if normalizedAngle > .pi / 2 && normalizedAngle < 3 * .pi / 2 {
            return angle + .pi
        }

        return angle
    }
}

/// Preview
#Preview {
    let viewModel = TranscriptionViewModel(parentPlayerId: UUID())
    viewModel.isCircularMode = true

    // Add some sample words
    viewModel.activeWords = [
        TranscriptionWord(text: "Hello", angle: -.pi / 2, opacity: 1.0, timestamp: Date().addingTimeInterval(-0.5)),
        TranscriptionWord(text: "world", angle: -.pi / 2, opacity: 1.0, timestamp: Date().addingTimeInterval(-1.0)),
        TranscriptionWord(text: "how", angle: -.pi / 2, opacity: 1.0, timestamp: Date().addingTimeInterval(-1.5)),
        TranscriptionWord(text: "are", angle: -.pi / 2, opacity: 1.0, timestamp: Date().addingTimeInterval(-2.0)),
        TranscriptionWord(text: "you", angle: -.pi / 2, opacity: 1.0, timestamp: Date().addingTimeInterval(-2.5))
    ]

    return CircularTranscriptionView(viewModel: viewModel)
        .frame(width: 200, height: 200)
        .background(Color.gray.opacity(0.3))
}
