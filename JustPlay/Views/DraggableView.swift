//
//  DraggableView.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// A transparent view that makes the entire area draggable
struct DraggableView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Allow hit testing to pass through for subviews
        return super.hitTest(point) ?? self
    }
}
