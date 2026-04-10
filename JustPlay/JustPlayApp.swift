//
//  JustPlayApp.swift
//  JustPlay
//

import SwiftUI

@main
struct JustPlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var windowManager = WindowManager.shared
    @AppStorage("autoCloseMiniPlayers") private var autoCloseMiniPlayers = true
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("audioTranscriptionEnabled") private var audioTranscriptionEnabled = false
    @AppStorage("circularTranscriptionMode") private var circularTranscriptionMode = false
    @AppStorage("newPlayerColor") private var newPlayerColor: String = "random"

    init() {
        // Share the window manager instance
        WindowManager.shared.configure()
    }

    var body: some Scene {
        // MenuBarExtra keeps the app alive even when no windows are open
        MenuBarExtra("JustPlay", systemImage: "music.note") {
            Button("Open Audio File...") {
                WindowManager.shared.openFileDialog()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Menu("Open Recent") {
                if windowManager.recentItems.isEmpty {
                    Text("No Recent Items")
                } else {
                    ForEach(windowManager.recentItems, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            WindowManager.shared.openPlayer(for: url)
                        }
                    }

                    Divider()

                    Button("Clear Recent Items") {
                        WindowManager.shared.clearRecentItems()
                    }
                }
            }

            Divider()

            Toggle("Auto-Close Mini Players", isOn: $autoCloseMiniPlayers)

            Toggle("Always on Top", isOn: $alwaysOnTop)
                .onChange(of: alwaysOnTop) { _, newValue in
                    WindowManager.shared.setAlwaysOnTop(newValue)
                }

            Divider()

            Toggle("Audio Transcription", isOn: $audioTranscriptionEnabled)

            Toggle("Circular Transcription", isOn: $circularTranscriptionMode)
                .disabled(!audioTranscriptionEnabled)
                .onChange(of: circularTranscriptionMode) { _, newValue in
                    WindowManager.shared.setCircularTranscriptionMode(newValue)
                }

            Divider()

            Button("Keyboard Shortcuts") {
                WindowManager.shared.showKeyboardShortcuts()
            }

            Divider()

            Button("Quit JustPlay") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        // Settings scene (required but unused)
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About JustPlay") {
                    WindowManager.shared.showAbout()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("Open Audio File...") {
                    WindowManager.shared.openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                // Recent Items submenu
                Menu("Open Recent") {
                    if windowManager.recentItems.isEmpty {
                        Text("No Recent Items")
                            .disabled(true)
                    } else {
                        ForEach(windowManager.recentItems, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                WindowManager.shared.openPlayer(for: url)
                            }
                        }

                        Divider()

                        Button("Clear Recent Items") {
                            WindowManager.shared.clearRecentItems()
                        }
                    }
                }
            }

            CommandGroup(after: .newItem) {
                Toggle("Auto-Close Mini Players", isOn: $autoCloseMiniPlayers)
                    .keyboardShortcut("a", modifiers: [.command, .shift])

                Toggle("Always on Top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .onChange(of: alwaysOnTop) { _, newValue in
                        WindowManager.shared.setAlwaysOnTop(newValue)
                    }

                Divider()

                Toggle("Audio Transcription", isOn: $audioTranscriptionEnabled)
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Toggle("Circular Transcription", isOn: $circularTranscriptionMode)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!audioTranscriptionEnabled)
                    .onChange(of: circularTranscriptionMode) { _, newValue in
                        WindowManager.shared.setCircularTranscriptionMode(newValue)
                    }

                Divider()

                Menu("New Player Color") {
                    Button(action: {
                        newPlayerColor = "random"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Label("Random", systemImage: "shuffle")
                    }
                    .badge(newPlayerColor == "random" ? Text("✓") : Text(""))

                    Divider()

                    Button(action: {
                        newPlayerColor = "green"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Green")
                    }
                    .badge(newPlayerColor == "green" ? Text("✓") : Text(""))

                    Button(action: {
                        newPlayerColor = "gold"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Gold")
                    }
                    .badge(newPlayerColor == "gold" ? Text("✓") : Text(""))

                    Button(action: {
                        newPlayerColor = "orange"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Orange")
                    }
                    .badge(newPlayerColor == "orange" ? Text("✓") : Text(""))

                    Button(action: {
                        newPlayerColor = "red"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Red")
                    }
                    .badge(newPlayerColor == "red" ? Text("✓") : Text(""))

                    Button(action: {
                        newPlayerColor = "purple"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Purple")
                    }
                    .badge(newPlayerColor == "purple" ? Text("✓") : Text(""))

                    Button(action: {
                        newPlayerColor = "blue"
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateColorMenu"), object: nil)
                    }) {
                        Text("Blue")
                    }
                    .badge(newPlayerColor == "blue" ? Text("✓") : Text(""))
                }
            }

            CommandGroup(before: .help) {
                Button("Keyboard Shortcuts") {
                    WindowManager.shared.showKeyboardShortcuts()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()
            }
        }
    }
}
