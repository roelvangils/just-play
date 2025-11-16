//
//  TranscriptionBubbleView.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// A custom NSVisualEffectView for the transcription bubble background
class TranscriptionVisualEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
}

/// SwiftUI wrapper for transcription bubble visual effect
struct TranscriptionBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> TranscriptionVisualEffectView {
        let view = TranscriptionVisualEffectView()

        // Use hudWindow material for darker vibrancy
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true

        return view
    }

    func updateNSView(_ nsView: TranscriptionVisualEffectView, context: Context) {
        // Keep effect constant
    }
}

/// View displaying real-time transcription in a floating bubble (two-line subtitle-style)
struct TranscriptionBubbleView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var textChangeID = UUID()

    var body: some View {
        Group {
            if viewModel.isVisible && !viewModel.firstLine.isEmpty {
                // Two-line transcription text with blur transition (no background)
                VStack(spacing: 2) {
                    // First line
                    Text(viewModel.firstLine)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .id("\(viewModel.firstLine)-first-\(textChangeID)")

                    // Second line (if exists)
                    if !viewModel.secondLine.isEmpty {
                        Text(viewModel.secondLine)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .id("\(viewModel.secondLine)-second-\(textChangeID)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .blur(radius: 0) // Base state for blur animation
                .animation(.easeInOut(duration: 0.2), value: textChangeID)
                .frame(minWidth: 150, maxWidth: 400)
                .frame(height: viewModel.secondLine.isEmpty ? 55 : 80)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: viewModel.isVisible)
                .onChange(of: viewModel.firstLine) { _ in
                    // Trigger blur transition on text change
                    withAnimation(.easeInOut(duration: 0.15)) {
                        textChangeID = UUID()
                    }
                }
                .onChange(of: viewModel.secondLine) { _ in
                    // Trigger blur transition on text change
                    withAnimation(.easeInOut(duration: 0.15)) {
                        textChangeID = UUID()
                    }
                }
            }
        }
    }
}

#Preview {
    let viewModel = TranscriptionViewModel(parentPlayerId: UUID())
    viewModel.updateText("Hello world this is a test of transcription")
    viewModel.isVisible = true

    return TranscriptionBubbleView(viewModel: viewModel)
        .frame(width: 400, height: 200)
        .background(Color.gray.opacity(0.3))
}
