//
//  PlayPauseButton.swift
//  JustPlay
//

import SwiftUI

/// A circular button displaying play or pause icon with hover effects
struct PlayPauseButton: View {
    let iconName: String
    let accessibilityLabel: String
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace.offUp))
        }
        .buttonStyle(.borderless)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isHovered)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: 20) {
        PlayPauseButton(iconName: "play.fill", accessibilityLabel: "Play", isHovered: false) {
            print("Play tapped")
        }

        PlayPauseButton(iconName: "pause.fill", accessibilityLabel: "Pause", isHovered: true) {
            print("Pause tapped")
        }
    }
    .padding()
}
