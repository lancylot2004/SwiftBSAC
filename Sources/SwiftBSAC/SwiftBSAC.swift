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
    private(set) var minFreq: Double
    private(set) var maxFreq: Double
    private(set) var ignoreMin: Int
    
    // Programme Arrays
    private(set) var data: [Float]
    private(set) var squareData: [UInt8]
    private(set) var zeroCrossedData: [UInt8]
    private(set) var correlation: [Int]

    public init(_ batchSize: Int = 3096, _ sampleRate: Int = 44100, _ maxFreq: Double = 12000) throws {
        guard batchSize > 1 else { throw BSACError.invalidBatchSizeIsOne }
        guard batchSize % 2 == 0 else { throw BSACError.invalidBatchSizeMulTwo }
        guard sampleRate > 1 else { throw BSACError.invalidSampleRateIsOne }
        
        self.batchSize = batchSize
        self.sampleRate = sampleRate
        self.minFreq = Double(self.sampleRate) / (Double(batchSize) / 2)
            
        guard maxFreq > self.minFreq else { throw BSACError.invalidMaxFreqLowerThanMin }
        
        self.maxFreq = maxFreq
        self.ignoreMin = Int((Double(self.sampleRate) / self.maxFreq).rounded(.up))
            
        guard self.ignoreMin < self.batchSize else { throw BSACError.invalidMaxFreqIgnoreOverflow }
        
        self.data = []
        self.squareData = []
        self.zeroCrossedData = Array(repeating: 0, count: self.batchSize / 8)
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
    }
    
    public mutating func supplyData(_ data: [Float]) {
        // TODO: Take into account the impact of different lengths of data
        self.data = data
        self.batchSize = data.count
    }
    
    public mutating func detect() -> Double {
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
            
        self.zeroCross()
        self.autocorrelate()
        
        var sampleOffset: Int = 0
        sampleOffset = Array(self.correlation[ignoreMin...]).min() ?? -1
        
        return Double(self.sampleRate) / Double(sampleOffset)
    }
    
    
    private mutating func zeroCross() {
        self.squareData = self.data.map { $0 < 0 ? 0 : 1 }
        
        for (index, sample) in self.squareData.enumerated() {
            self.zeroCrossedData[index / 8] = (self.zeroCrossedData[index / 8] << 1) | sample
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
