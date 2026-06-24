import XCTest
@testable import PolishCore

final class HTTPTransportTests: XCTestCase {
    func test_polishError_httpMessage_isReadable() {
        let err = PolishError.http(status: 401, message: "invalid key")
        XCTAssertTrue(err.userMessage.contains("401"))
        XCTAssertTrue(err.userMessage.contains("invalid key"))
    }

    func test_polishError_emptyResponse_hasMessage() {
        XCTAssertFalse(PolishError.emptyResponse.userMessage.isEmpty)
    }
}
