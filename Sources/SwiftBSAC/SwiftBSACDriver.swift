//
//  SwiftBSACDriver.swift
//  
//
//  Created by lancylot2004 on 21/08/2022.
//

import AVFoundation

@available(iOS 13.0, *)
public class SwiftBSACDriver: ObservableObject {
    
    var audioEngine: AVAudioEngine
    var bsac: SwiftBSAC
    
    private(set) var batchSize: Int
    @Published public var pitch: Double = 0
    
    public init(_ batchSize: Int = 6192, _ sampleRate: Double = 96000, _ maxFreq: Double = 10000) throws {
        
        guard batchSize > 1 else { throw BSACError.invalidBatchSizeIsOne }
        guard batchSize % 2 == 0 else { throw BSACError.invalidBatchSizeMulTwo }
        guard sampleRate > 1 else { throw BSACError.invalidSampleRateIsOne }
        
        self.audioEngine = AVAudioEngine()
        self.bsac = try SwiftBSAC(batchSize, sampleRate, maxFreq)
        self.batchSize = batchSize
        
        // Tap to supply newest data from microphone to bsac.data
        // Writes directly to bsac.data, which is not recommended typically.
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(batchSize),
            format: .none
        ) { buffer, time in
            self.processBuffer(buffer: buffer, time: time)
        }
    }
    
    @discardableResult
    public func start() -> Bool {
        do {
            try self.audioEngine.start()
            return true
        } catch let error as NSError {
            print(error.description)
            return false
        }
    }
    
    public func stop() {
        self.audioEngine.stop()
    }
    
    private func processBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let bufferCount: Int = Int(buffer.frameLength)
        var startIndex: Int = 0 {
            didSet {
                if startIndex >= bufferCount  { return }
            }
        }
        
        // Find first positive edge of a waveform, then go back one
        while (buffer.floatChannelData?.pointee[startIndex])! >= 0 { startIndex += 1 }
        while (buffer.floatChannelData?.pointee[startIndex])! < 0 { startIndex += 1 }
        startIndex -= 1
        
        for i in 0 ..< min(bufferCount, batchSize) {
            self.bsac.data[i] = (buffer.floatChannelData?.pointee[i + startIndex])!
        }

        self.bsac.run()
        self.pitch = self.bsac.pitch
    }
}
