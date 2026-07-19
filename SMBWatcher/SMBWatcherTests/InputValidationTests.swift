import XCTest
@testable import SMBWatcher

/// Tests for input validation logic used by AddInstanceView.
///
/// Extracts the isValid and port-validation rules into testable assertions.
final class InputValidationTests: XCTestCase {

    // MARK: - Instance field validation (mirrors AddInstanceView.isValid)

    private func isValid(name: String, host: String, sharePath: String, mountPoint: String) -> Bool {
        !name.isEmpty && !host.isEmpty && !sharePath.isEmpty && !mountPoint.isEmpty
    }

    func testValidInputAccepts() {
        XCTAssertTrue(isValid(name: "NAS", host: "192.168.1.1", sharePath: "/share", mountPoint: "/Volumes/share"))
    }

    func testEmptyNameRejects() {
        XCTAssertFalse(isValid(name: "", host: "192.168.1.1", sharePath: "/share", mountPoint: "/Volumes/share"))
    }

    func testEmptyHostRejects() {
        XCTAssertFalse(isValid(name: "NAS", host: "", sharePath: "/share", mountPoint: "/Volumes/share"))
    }

    func testEmptySharePathRejects() {
        XCTAssertFalse(isValid(name: "NAS", host: "192.168.1.1", sharePath: "", mountPoint: "/Volumes/share"))
    }

    func testEmptyMountPointRejects() {
        XCTAssertFalse(isValid(name: "NAS", host: "192.168.1.1", sharePath: "/share", mountPoint: ""))
    }

    func testAllFieldsEmptyRejects() {
        XCTAssertFalse(isValid(name: "", host: "", sharePath: "", mountPoint: ""))
    }

    // MARK: - Port validation (mirrors AddInstanceView.save)

    private func isValidPort(_ port: String) -> Bool {
        guard let portValue = UInt16(port) else { return false }
        return portValue > 0
    }

    func testValidPortAccepts() {
        XCTAssertTrue(isValidPort("445"))
        XCTAssertTrue(isValidPort("1"))
        XCTAssertTrue(isValidPort("65535"))
    }

    func testZeroPortRejects() {
        XCTAssertFalse(isValidPort("0"))
    }

    func testNegativePortRejects() {
        XCTAssertFalse(isValidPort("-1"))
    }

    func testNonNumericPortRejects() {
        XCTAssertFalse(isValidPort("abc"))
        XCTAssertFalse(isValidPort("445.5"))
        XCTAssertFalse(isValidPort(""))
    }

    func testPortTooLargeRejects() {
        XCTAssertFalse(isValidPort("65536"))
        XCTAssertFalse(isValidPort("99999"))
    }

    // MARK: - WatchedInstance defaults

    func testDefaultPortIs445() {
        let instance = WatchedInstance(name: "Test", host: "1.2.3.4", sharePath: "/s", mountPoint: "/m")
        XCTAssertEqual(instance.port, 445)
    }

    func testDefaultPollIntervalIs30() {
        let instance = WatchedInstance(name: "Test", host: "1.2.3.4", sharePath: "/s", mountPoint: "/m")
        XCTAssertEqual(instance.pollIntervalSeconds, 30)
    }

    func testDefaultIsEnabled() {
        let instance = WatchedInstance(name: "Test", host: "1.2.3.4", sharePath: "/s", mountPoint: "/m")
        XCTAssertTrue(instance.isEnabled)
    }
}
