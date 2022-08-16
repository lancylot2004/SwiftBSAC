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
    private(set) var shiftedData: [[UInt8]]
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
        self.shiftedData = []
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
    }
    
    /// Provide data to process.
    public mutating func supplyData(_ data: [Float]) {
        // TODO: Take into account the impact of different lengths of data
        self.data = data
        self.batchSize = data.count
    }
    
    /// Performs one full sequence of bitstream autocorrelation, returns detected pitch in `Hertz: Double`
    public mutating func run() -> Double {
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
            
        self.zeroCross()
        self.autocorrelate()
        
        // TODO: Actually estimate pitch
        var sampleOffset: Int = 0
        sampleOffset = Array(self.correlation[ignoreMin...]).min() ?? -1
        
        return Double(self.sampleRate) / Double(sampleOffset)
    }
    
    /// Performs zero-crossing on `data`, then maps resulting data into chunks using `UInt8`.
    private mutating func zeroCross() {
        self.squareData = self.data.map { $0 < 0 ? 0 : 1 }
        
        for (index, sample) in self.squareData.enumerated() {
            self.zeroCrossedData[index / 8] = (self.zeroCrossedData[index / 8] << 1) | sample
        }
    }
    
    /// Performs autocorrelation on `zeroCrossedData`.
    private mutating func autocorrelate() {
        /// **Preshifts** the `zeroCrossedData` seven times, so that when XOR operations
        /// are performed with an offset, any offset greater than 8 can be achieved
        /// by cutting off `offset / 8` elements from the `offset % 8` shifted data.
        self.shiftedData = [self.zeroCrossedData]
        for i in 1 ... 7 {
            self.shiftedData.append(self.bitshiftArray(self.zeroCrossedData, i))
        }
        
        /// Performs correlation using XOR operations for each offset, then counts
        /// the number of nonzeroBits in each UInt8, then totals them in the `correlation` array.
        for i in 0 ..< (self.batchSize / 2) {
            self.correlation[i] += zip(self.zeroCrossedData, self.shiftedData[i % 8][(i / 8)...])
                .map { $0 ^ $1 }
                .map { $0.nonzeroBitCount }
                .reduce(0, +)
        }
    }
    
    /// Bitshifts an array of any unsigned integer as if it were one huge integer.
    private func bitshiftArray<T: UnsignedInteger>(_ array: [T], _ distance: Int) -> [T] {
        
        /// `ignoreDistance` is the number of elements to cut off completely, whereas
        /// `shiftDistance` is the number of bits to shift, which is always less than sizeOfT.
        /// `inverseShiftDistance` is used to generate `previousMask`, and only exists
        /// so that it doesn't have to be recalculated every time.
        let sizeOfT = size(of: T.self)
        let ignoreDistance = distance / sizeOfT
        let shiftDistance = distance % sizeOfT
        let inverseShiftDistance = sizeOfT - shiftDistance
        
        /// Clunky, but one extra value is needed so that when bitshifting the last element of
        /// the actual input, `input[index + 1]` is not an IndexError!
        let input: [T] = array + [T.init(clamping: 0)]
        var output: [T] = []
        
        for index in ignoreDistance ... array.count - 1 {
            output.append((input[index] << shiftDistance) | (input[index + 1] >> inverseShiftDistance))
        }
        
        return output
    }
}

// Testing Exposures
// Used for calling private functions in unit tests.

#if DEBUG
extension SwiftBSAC {
    public mutating func publicZeroCross() {
        self.zeroCross()
    }
    
    public mutating func publicAutocorrelate() {
        self.autocorrelate()
    }
}
#endif
