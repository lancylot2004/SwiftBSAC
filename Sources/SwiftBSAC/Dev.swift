//
//  Dev.swift
//  
//
//  Created by lancylot2004 on 12/08/2022.
//

import Foundation
import AVFoundation

func calculateTime(_ name: String, block: (() -> Void)) {
    let start = DispatchTime.now()
    block()
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000_000
    print("[\(name)] Time: \(timeInterval) seconds")
}

func readDev(_ url: URL) -> [Float] {
    let file = try! AVAudioFile(forReading: url)
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)!
    let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(file.length))
    try! file.read(into: buf!) // You probably want better error handling
    return Array(UnsafeBufferPointer(start: buf!.floatChannelData![0], count:Int(buf!.frameLength)))
}
