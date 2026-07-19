import XCTest
@testable import SMBWatcher

final class PortReachabilityTests: XCTestCase {
    var checker: PortReachability!

    override func setUp() {
        super.setUp()
        checker = PortReachability(timeout: 2)
    }

    func testCheckWithInvalidHost() async {
        // Testing with a non-existent host should return false
        let result = await checker.check(host: "192.0.2.1", port: 445) // TEST-NET-1, should be unreachable
        XCTAssertFalse(result)
    }

    func testCheckWithClosedPort() async {
        // Testing with a host that's not listening on the port
        // Using a well-known non-SMB host
        let result = await checker.check(host: "127.0.0.1", port: 1) // Port 1 is typically closed
        XCTAssertFalse(result)
    }

    func testCheckTimeout() async {
        // Test that timeout works by using a very short timeout
        let shortTimeoutChecker = PortReachability(timeout: 0.001) // 1ms timeout
        let result = await shortTimeoutChecker.check(host: "192.0.2.1", port: 445)
        XCTAssertFalse(result)
    }

    func testPortReachabilityInitialization() {
        let defaultChecker = PortReachability()
        XCTAssertNotNil(defaultChecker)

        let customChecker = PortReachability(timeout: 10)
        XCTAssertNotNil(customChecker)
    }
}
