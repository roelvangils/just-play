//
//  KeyWindow.swift
//  JustPlay
//

import AppKit

/// Custom NSWindow that can become key to receive keyboard events
class KeyWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}
