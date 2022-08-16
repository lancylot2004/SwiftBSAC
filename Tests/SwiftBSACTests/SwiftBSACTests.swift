import XCTest
@testable import SwiftBSAC

final class SwiftBSACTests: XCTestCase {
    func testZeroCross() throws {
        var bsac = try! SwiftBSAC()
        let data = readDev(Bundle.module.url(forResource: "440", withExtension: "wav")!)
        
        bsac.supplyData(Array(data[0..<3072]))
        bsac.publicZeroCross()
        
//        print(bsac.squareData)
//        print(bsac.zeroCrossedData)
    }
    
    // Must only be run if `testZeroCros` succeeds.
    func testAutocorrelation() throws {
        var bsac = try! SwiftBSAC()
        let data = readDev(Bundle.module.url(forResource: "440", withExtension: "wav")!)
        
        bsac.supplyData(Array(data[0..<3072]))
        bsac.publicZeroCross()
        
        bsac.publicAutocorrelate()
        
        print(bsac.correlation)
    }
}
