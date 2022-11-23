//
//  Extensions.swift
//  
//
//  Created by lancylot2004 on 13/08/2022.
//

import Foundation

// Sizing Helpers for Bitshift
protocol Accessor {}
extension Accessor {
    static var size: Int {
        MemoryLayout<Self>.size
    }
}

struct ProtocolTypeContainer {
    let type: Any.Type
    let witnessTable = 0
}

func size(of type: Any.Type) -> Int {
    let container = ProtocolTypeContainer(type: type)
    return unsafeBitCast(container, to: Accessor.Type.self).size * 8
}

// Custom Error Type with Descriptions
enum BSACError: Error {
    case invalidBatchSizeMulTwo, invalidBatchSizeIsOne
    case invalidSampleRateIsOne
    case invalidMaxFreqLowerThanMin, invalidMaxFreqIgnoreOverflow
    case audioEngineInitFailed
}

extension BSACError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidBatchSizeMulTwo:
            return "Batch size must be a multiple of 2!"
        case .invalidBatchSizeIsOne:
            return "Batch size must be greater than 1!"
        case .invalidSampleRateIsOne:
            return "Sample rate must be greater than 1!"
        case .invalidMaxFreqLowerThanMin:
            return "Maximum frequency must be greater than minimum frequency!"
        case .invalidMaxFreqIgnoreOverflow:
            return "Maximum frequency generates a range to ignore than is out of bounds for the batch size specified!"
        case .audioEngineInitFailed:
            return "Failed to initialise AVAudioEngine!"
        }
    }
}
