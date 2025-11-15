//
//  CloseButton.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// A small circular close button that appears on hover
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                CloseButtonBackground()
                    .frame(width: 36, height: 36)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Close")
        .help("Close player")
    }
}

/// Background for close button using same material as Mini Player
struct CloseButtonBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> CloseButtonEffectView {
        let view = CloseButtonEffectView()

        // Use same hudWindow material as Mini Player
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 18  // Half of 36 for circular effect
        view.layer?.masksToBounds = true

        return view
    }

    func updateNSView(_ nsView: CloseButtonEffectView, context: Context) {
        // Keep effect constant
    }
}

/// NSVisualEffectView that doesn't move the window
class CloseButtonEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool {
        return false  // Don't move window when clicking close button
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // Accept first mouse for immediate interaction
    }
}

#Preview {
    ZStack {
        Circle()
            .fill(.regularMaterial)
            .frame(width: 150, height: 150)

        VStack {
            Spacer()
            HStack {
                Spacer()
                CloseButton {
                    print("Close tapped")
                }
                .padding(8)
            }
        }
    }
    .frame(width: 150, height: 150)
}
