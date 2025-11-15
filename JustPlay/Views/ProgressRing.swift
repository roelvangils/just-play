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
    private let ringColor = Color.blue

    private var ringOpacity: Double {
        if isPlaying {
            return 1.0  // Full opacity when playing
        } else if isPaused && progress > 0 {
            return 0.5  // 50% opacity when paused
        } else {
            return 0.0  // Hidden when stopped
        }
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                ringColor,
                style: StrokeStyle(
                    lineWidth: ringWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90)) // Start from top (12 o'clock)
            .opacity(ringOpacity)
            .animation(.linear(duration: 0.1), value: progress)  // Smooth linear progress animation
            .animation(.smooth(duration: 0.5), value: ringOpacity)  // Smooth opacity transition
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
