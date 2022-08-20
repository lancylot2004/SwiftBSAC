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
        
//        print(bsac.correlation)
    }
    
    func testOverall() throws {
        var bsac = try! SwiftBSAC()
        let data = readDev(Bundle.module.url(forResource: "440vio", withExtension: "wav")!)
        
        var currIndex = 100
        while currIndex + 3072 <= data.count {
            while data[currIndex] > 0 { currIndex += 1 }
            while data[currIndex] < 0 { currIndex += 1 }
            currIndex -= 1
            
            bsac.supplyData(Array(data[currIndex..<currIndex + 3072]))
            bsac.run()
            print(bsac.pitch)
            currIndex += 3072
        }
    }
}
