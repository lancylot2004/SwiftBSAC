//
//  SwiftBSAC.swift
//
//
//  Created by lancylot2004 on 10/08/2022.
//

import SwiftUI
import AVFoundation

public struct SwiftBSAC {
    
    // Configuration
    private(set) var batchSize: Int
    private(set) var sampleRate: Double
    private(set) var minFreq: Double
    private(set) var maxFreq: Double
    private(set) var minPeriod: Double
    
    // Programme Arrays
    private(set) var data: [Float]
    private(set) var squareData: [UInt8]
    private(set) var zeroCrossedData: [UInt8]
    private(set) var shiftedData: [[UInt8]]
    private(set) var correlation: [Int]
    
    private(set) var pitch: Double

    public init(_ batchSize: Int = 3096, _ sampleRate: Double = 44100, _ maxFreq: Double = 10000) throws {
        guard batchSize > 1 else { throw BSACError.invalidBatchSizeIsOne }
        guard batchSize % 2 == 0 else { throw BSACError.invalidBatchSizeMulTwo }
        guard sampleRate > 1 else { throw BSACError.invalidSampleRateIsOne }
        
        self.batchSize = batchSize
        self.sampleRate = sampleRate
        self.minFreq = self.sampleRate / (Double(batchSize) / 2)
            
        guard maxFreq > self.minFreq else { throw BSACError.invalidMaxFreqLowerThanMin }
        
        self.maxFreq = maxFreq
        self.minPeriod = self.sampleRate / self.maxFreq
            
        guard self.minPeriod < Double(self.batchSize) else { throw BSACError.invalidMaxFreqIgnoreOverflow }
        
        self.data = []
        self.squareData = []
        self.zeroCrossedData = Array(repeating: 0, count: self.batchSize / 8)
        self.shiftedData = []
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
        
        self.pitch = 0
    }
    
    /// Provide data to process.
    public mutating func supplyData(_ data: [Float]) {
        // TODO: Take into account the impact of different lengths of data
        self.data = data
        self.batchSize = data.count
    }
    
    /// Performs one full sequence of bitstream autocorrelation, stores detected pitch to `self.pitch`
    public mutating func run() {
        self.correlation = Array(repeating: 0, count: self.batchSize / 2)
            
        self.zeroCross()
        self.autocorrelate()
        
        self.estimate()
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
            let chunkOffset: Int = i / 8
            let shiftOffset: Int = i % 8
            var sum: Int = 0
            var index: Int = 0
            while index < (self.shiftedData[shiftOffset].count - chunkOffset - 1) {
                sum += (self.zeroCrossedData[index] ^ self.shiftedData[shiftOffset][index + chunkOffset]).nonzeroBitCount
                index += 1
            }
            
            self.correlation[i] = sum
        }
    }
    
    /// Pitch estimation using... magic?
    // TODO: Not be dumb
    private mutating func estimate() {
        // Process the pesky harmonics first.
        // `minCorrelation` is, counterintuitively, the maximum value of correlation,
        // since the XOR operator is used to calculate correlation.
        let minCorrelation: Int = self.correlation.max() ?? 0
        let maxCorrelation: Int = self.correlation[Int(self.minPeriod)...].min() ?? 0
        var maxCorrelationIndex: Int = self.correlation[Int(self.minPeriod)...].firstIndex(of: maxCorrelation) ?? 0
        
        let harmonicThreshold: Double = 0.15 * Double(minCorrelation)
        let maxDivision: Int = maxCorrelationIndex / Int(self.minPeriod)
        
        for division in (1 ... maxDivision).reversed() {
            var strongHarmonic: Bool = true
            
            for i in 1 ..< division {
                if self.correlation[(i * maxCorrelationIndex) / division] > Int(harmonicThreshold) {
                    strongHarmonic = false
                    break
                }
            }
            
            if strongHarmonic {
                maxCorrelationIndex /= division
                break
            }
        }
        
        // Estimate the pitch
        var prevSample: Float = 0
        var startEdge: Int = 0
        
        for (index, sample) in self.data.enumerated() {
            if sample > 0 {
                prevSample = self.data[index == 0 ? 0 : index - 1]
                startEdge = index
                break
            }
        }
        
        var deltaY: Float = self.data[startEdge] - prevSample
        let deltaXOne: Float = -prevSample / deltaY
        
        var nextEdge: Int = maxCorrelationIndex - 1
        while self.data[nextEdge] < 0 {
            prevSample = self.data[nextEdge]
            nextEdge += 1
        }
        
        deltaY = self.data[nextEdge] - prevSample
        let deltaXTwo = -prevSample / deltaY
        
        let lagSamples: Float = Float(nextEdge - startEdge) + (deltaXTwo - deltaXOne)
        self.pitch = self.sampleRate / Double(lagSamples)
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
