//
//  AudioEngineModel.swift
//  XRMapTest
//
//  Created by Michael A Edgcumbe on 12/18/23.
//

import SwiftUI
import AudioKit
import AudioKitEX
import AVFoundation

public struct AudioEngineModel {

    let engine = AudioEngine()
    let player = AudioPlayer()
    let buffer: AVAudioPCMBuffer
    static let url = Bundle.main.resourceURL?.appendingPathComponent("shadowDancing.aif")
    
    static var sourceBuffer: AVAudioPCMBuffer {
        let file = try! AVAudioFile(forReading: url!)
        return try! AVAudioPCMBuffer(file: file)!
    }

    init() {
        buffer = AudioEngineModel.sourceBuffer
        player.buffer = buffer
        player.isLooping = true
        engine.output = player
    }
}

