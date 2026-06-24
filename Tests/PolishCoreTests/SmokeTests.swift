import XCTest
@testable import PolishCore

final class SmokeTests: XCTestCase {
    func test_version_isPresent() {
        XCTAssertFalse(PolishCore.version.isEmpty)
    }
}
