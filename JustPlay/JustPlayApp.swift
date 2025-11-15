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
                // About will be added later via AppKit
                EmptyView()
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
