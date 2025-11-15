//
//  KeyboardShortcutsView.swift
//  JustPlay
//

import SwiftUI

/// Displays available keyboard shortcuts for player windows
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.title)
                .bold()

            Text("Hover over any player window to use these shortcuts:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ShortcutRow(action: "Play/Pause", keys: "SPACE or P")
                ShortcutRow(action: "Rewind", keys: "R")
                ShortcutRow(action: "Close Player", keys: "X or Q")
                ShortcutRow(action: "Skip backward 1 second", keys: "B")
                ShortcutRow(action: "Skip forward 1 second", keys: "F")
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

/// A single row showing a keyboard shortcut
struct ShortcutRow: View {
    let action: String
    let keys: String

    var body: some View {
        HStack {
            Text(action)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
