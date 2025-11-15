//
//  PlayerState.swift
//  JustPlay
//

import Foundation

/// Represents the current playback state of an audio player
enum PlayerState {
    case stopped
    case playing
    case paused
    case ended

    var isPlaying: Bool {
        self == .playing
    }
}
