//
//  SwiftBSAC.swift
//
//
//  Created by lancylot2004 on 10/08/2022.
//

import Foundation
import AVFoundation

public struct SwiftBSAC {
    
    // Configuration
    private(set) var batchSize: Int
    private(set) var sampleRate: Int
    private(set) var maxFreq: Int
    private(set) var ignoreFrom: Int
    
    // Programme Arrays
    private(set) var rawAudio: [Float]
    private(set) var zeroCrossings: [Bool]
    private(set) var correlation: [Int]

    public init(_ batchSize: Int = 1500, _ sampleRate: Int = 44100, _ maxFreq: Int = 12000) {
        self.batchSize = batchSize
        self.sampleRate = sampleRate
        self.maxFreq = maxFreq
        self.ignoreFrom = Int(Double(self.sampleRate) / Double(self.maxFreq).rounded(.up))
        
        self.rawAudio = Array(repeating: 0, count: self.batchSize)
        self.zeroCrossings = Array(repeating: false, count: self.batchSize)
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
    }
    
    
    
    public mutating func supplyData(_ data: [Float]) {
        self.rawAudio = data
        self.batchSize = data.count
    }
    
    public mutating func detect() -> Double {
        self.zeroCrossings = Array(repeating: false, count: self.batchSize)
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
        
        self.zeroCross()
        self.autocorrelate()
        
        let sampleOffset = Array(self.correlation[ignoreFrom...]).min() ?? -1
        
        // Algorithm
        return Double(self.sampleRate) / Double(sampleOffset)
    }
    
    private mutating func zeroCross() {
        var pointer = false // true --> +/0
        for (index, value) in self.rawAudio.enumerated() {
            if ((pointer == false) ^ (value < 0)) {
                pointer.toggle()
            }
            
            self.zeroCrossings[index] = pointer
        }
    }
    
    private mutating func autocorrelate() {
        for frequency in self.ignoreFrom..<self.correlation.count - 1 {
            for index in 0..<(self.zeroCrossings.count - frequency) {
                if (self.zeroCrossings[index] ^ self.zeroCrossings[index + frequency]) {
                    self.correlation[frequency] += 1
                }
            }
        }
    }
}

extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
    }
}
