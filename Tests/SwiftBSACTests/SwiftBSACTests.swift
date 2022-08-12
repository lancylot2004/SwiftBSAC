import XCTest
@testable import SwiftBSAC

final class SwiftBSACTests: XCTestCase {
    func testExample() throws {
        var currentPos = 0
        var bsac = SwiftBSAC()
        let data = SwiftBSAC.readDev(Bundle.module.url(forResource: "440vio", withExtension: "wav")!)
        while currentPos < data.count - 3000 {
            bsac.supplyData(Array(data[currentPos...currentPos + 2999]))
            print("Pitch: \(bsac.detect())")
            currentPos += 3000
        }
    }
}
