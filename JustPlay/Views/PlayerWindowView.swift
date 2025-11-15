//
//  PlayerWindowView.swift
//  JustPlay
//

import SwiftUI
import AppKit

/// A transparent view that makes the window draggable
class DraggableNSViewForWindow: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

/// SwiftUI wrapper for draggable background
struct DraggableBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSViewForWindow {
        let view = DraggableNSViewForWindow()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: DraggableNSViewForWindow, context: Context) {
        // Nothing to update
    }
}

/// A custom NSVisualEffectView that enables window dragging
class DraggableVisualEffectView: NSVisualEffectView {
    override public var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

/// A SwiftUI view that wraps NSVisualEffectView for glass/blur effects with dragging support
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableVisualEffectView {
        let view = DraggableVisualEffectView()

        // Use hudWindow material for darker vibrancy that respects system appearance
        view.material = .hudWindow

        view.blendingMode = .behindWindow
        view.state = .active  // Always active, never changes
        view.wantsLayer = true
        view.layer?.cornerRadius = 60  // Half of 120 for circular effect
        view.layer?.masksToBounds = true

        return view
    }

    func updateNSView(_ nsView: DraggableVisualEffectView, context: Context) {
        // Do NOT update - keep the effect constant
        // This prevents changes during play/pause
    }
}

/// The main content view for a circular player window
struct PlayerWindowView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var hasAppeared = false

    private var isWindowActive: Bool {
        controlActiveState == .key
    }

    private var scale: CGFloat {
        if !hasAppeared {
            return 0.6  // Start small for pop animation
        } else if viewModel.isClosing {
            return 0.8  // Shrink when closing
        } else if !isWindowActive && !viewModel.isHovered {
            return 0.75  // 25% smaller when inactive and not hovered
        } else {
            return 1.0  // Normal size
        }
    }

    private var windowOpacity: Double {
        if viewModel.isClosing {
            return 0  // Fade out when closing
        } else if !isWindowActive && !viewModel.isHovered {
            return 0.6  // Semi-transparent when inactive and not hovered
        } else {
            return 1.0  // Full opacity when active or hovered
        }
    }

    var body: some View {
        ZStack {
            // Main circular player content
            ZStack {
                // Visual effect background with dragging
                VisualEffectBackground()
                    .frame(width: 120, height: 120)

                // Progress ring (appears when playing)
                ProgressRing(
                    progress: viewModel.progress,
                    isPlaying: viewModel.state.isPlaying,
                    isPaused: viewModel.state == .paused
                )
                .frame(width: 80, height: 80)  // Smaller for more padding
                .allowsHitTesting(false)  // Let clicks pass through to background

                PlayPauseButton(
                    iconName: viewModel.playPauseIconName,
                    accessibilityLabel: viewModel.playPauseAccessibilityLabel,
                    isHovered: viewModel.isHovered,
                    action: viewModel.togglePlayPause
                )
            }
            .frame(width: 120, height: 120)
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            // Close button overlay (appears on hover, positioned inside the frame)
            if viewModel.isHovered {
                VStack {
                    HStack {
                        Spacer()
                        CloseButton(action: viewModel.close)
                            .padding(.trailing, 8)  // 8px from right edge
                            .padding(.top, 8)        // 8px from top edge
                    }
                    Spacer()
                }
                .frame(width: 160, height: 160)  // Match outer frame
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 160, height: 160)  // Increased from 120 to 160 to accommodate close button
        .blur(radius: viewModel.isClosing ? 10 : 0)
        .opacity(windowOpacity)
        .scaleEffect(scale)
        .contentShape(Rectangle()) // Make entire area interactive
        .animation(.smooth(duration: 0.2), value: viewModel.isHovered)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isClosing)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: hasAppeared)
        .animation(.smooth(duration: 0.3), value: isWindowActive)
        .onHover { hovering in
            viewModel.isHovered = hovering

            if hovering {
                // Notify WindowManager which player is currently hovered
                WindowManager.shared.setHoveredViewModel(viewModel)

                // Make the window key after a tiny delay to handle rapid transitions
                // This ensures hover state is stable before activating the window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak viewModel] in
                    guard let vm = viewModel, vm.isHovered else { return }

                    // Only make key if still hovered
                    if let window = WindowManager.shared.window(for: vm.id) {
                        window.makeKey()
                    }
                }
            } else {
                // Clear hovered view model after a delay to allow for rapid transitions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak viewModel] in
                    // Only clear if this view model is still the current one and not hovered
                    if let vm = viewModel,
                       !vm.isHovered,
                       WindowManager.shared.currentlyHoveredViewModel?.id == vm.id {
                        WindowManager.shared.setHoveredViewModel(nil)
                    }
                }
            }
        }
        .onAppear {
            // Trigger pop animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                hasAppeared = true
            }
        }
    }
}

#Preview {
    PlayerWindowView(viewModel: PlayerViewModel(fileURL: URL(fileURLWithPath: "/tmp/test.mp3")))
        .frame(width: 200, height: 200)
        .background(Color.gray.opacity(0.3))
}
