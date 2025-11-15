//
//  AboutView.swift
//  JustPlay
//

import SwiftUI

/// About window showing app information and build details
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    // Build info
    private let buildDate = BuildInfo.buildDate
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 20) {
            Text("JustPlay")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Minimalistic Audio Player")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                HStack {
                    Text("Version:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(buildNumber)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build Date:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(buildDate)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .frame(width: 350)

            Divider()
                .padding(.horizontal, 40)

            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding(30)
        .frame(width: 450)
    }
}

#Preview {
    AboutView()
}
