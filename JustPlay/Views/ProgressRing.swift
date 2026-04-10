//
//  ProgressRing.swift
//  JustPlay
//

import SwiftUI

/// A circular progress ring that fills clockwise from top
struct ProgressRing: View {
    let progress: Double
    let isPlaying: Bool
    let isPaused: Bool

    private let ringWidth: CGFloat = 10  // Increased from 5 to 10

    @State private var animatedOpacity: Double = 1.0

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                Color.white.opacity(0.5),  // White ring with 50% opacity for visibility
                style: StrokeStyle(
                    lineWidth: ringWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90)) // Start from top (12 o'clock)
            .opacity(animatedOpacity)
            .animation(.linear(duration: 0.1), value: progress)  // Smooth linear progress animation
            .onChange(of: isPaused) { oldValue, newValue in
                if newValue && !oldValue {
                    // User just pressed pause - smoothly transition to low opacity, then start pulsing
                    withAnimation(.smooth(duration: 0.8)) {
                        animatedOpacity = 0.15
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        startPulsing()
                    }
                }
            }
            .onChange(of: isPlaying) { oldValue, newValue in
                if newValue && !oldValue {
                    // User just pressed play - stop pulsing and smoothly return to full opacity
                    stopPulsing()
                    withAnimation(.smooth(duration: 0.5)) {
                        animatedOpacity = 1.0
                    }
                }
            }
            .onAppear {
                // Set initial opacity based on state
                if isPlaying {
                    animatedOpacity = 1.0
                } else if isPaused && progress > 0 {
                    animatedOpacity = 0.15
                    startPulsing()
                } else {
                    animatedOpacity = 0.0
                }
            }
            .onChange(of: progress) { oldValue, newValue in
                // Handle visibility when stopped
                if !isPlaying && !isPaused {
                    withAnimation {
                        animatedOpacity = newValue > 0 ? 0.0 : 0.0
                    }
                }
            }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animatedOpacity = 0.75
        }
    }

    private func stopPulsing() {
        // Cancel the repeating animation
        animatedOpacity = animatedOpacity  // Break the animation
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        VStack(spacing: 30) {
            // 0% progress
            ProgressRing(progress: 0, isPlaying: false, isPaused: false)
                .frame(width: 92, height: 92)

            // 25% progress playing
            ProgressRing(progress: 0.25, isPlaying: true, isPaused: false)
                .frame(width: 92, height: 92)

            // 50% progress paused
            ProgressRing(progress: 0.5, isPlaying: false, isPaused: true)
                .frame(width: 92, height: 92)

            // 75% progress playing
            ProgressRing(progress: 0.75, isPlaying: true, isPaused: false)
                .frame(width: 92, height: 92)
        }
    }
    .frame(width: 400, height: 600)
}
