import XCTest
@testable import SMBWatcher

/// Mock PortReachability for testing MountHealthChecker without network calls.
private class MockPortReachability: PortReachability {
    var isReachable = false

    init(reachable: Bool) {
        self.isReachable = reachable
        super.init(timeout: 1)
    }

    override func check(host: String, port: UInt16) async -> Bool {
        return isReachable
    }
}

/// Tests for MountHealthChecker's three-state health model.
///
/// Tests the three states: unreachable, healthy, and unreachable-when-mount-missing.
/// Uses temp directories and mock port checker — no real SMB server needed.
final class MountHealthCheckerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Port unreachable → .unreachable

    func testPortUnreachableReturnsUnreachable() async {
        let portChecker = MockPortReachability(reachable: false)
        let checker = MountHealthChecker(portChecker: portChecker)

        let instance = WatchedInstance(
            name: "Test",
            host: "192.168.1.1",
            port: 445,
            sharePath: "/share",
            mountPoint: "/Volumes/share"
        )

        let status = await checker.check(instance: instance)
        XCTAssertEqual(status, .unreachable)
    }

    // MARK: - Port reachable, mount missing → .unreachable

    func testPortReachableMountMissingReturnsUnreachable() async {
        let portChecker = MockPortReachability(reachable: true)
        let checker = MountHealthChecker(portChecker: portChecker)

        let instance = WatchedInstance(
            name: "Test",
            host: "192.168.1.1",
            port: 445,
            sharePath: "/share",
            mountPoint: "/nonexistent/path/\(UUID().uuidString)"
        )

        let status = await checker.check(instance: instance)
        XCTAssertEqual(status, .unreachable)
    }

    // MARK: - Port reachable, mount present and responsive → .healthy

    func testPortReachableMountResponsiveReturnsHealthy() async {
        let portChecker = MockPortReachability(reachable: true)
        let checker = MountHealthChecker(portChecker: portChecker)

        // Use a real temp directory that's readable
        let instance = WatchedInstance(
            name: "Test",
            host: "192.168.1.1",
            port: 445,
            sharePath: "/share",
            mountPoint: tempDir.path
        )

        let status = await checker.check(instance: instance)
        XCTAssertEqual(status, .healthy)
    }

    // MARK: - Port reachable, mount point exists but is a file (not directory) → .unreachable

    func testPortReachableMountPointIsFileReturnsUnreachable() async {
        let portChecker = MockPortReachability(reachable: true)
        let checker = MountHealthChecker(portChecker: portChecker)

        // Create a file (not a directory) at the mount point path
        let fileURL = tempDir.appendingPathComponent("not_a_dir")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8))

        let instance = WatchedInstance(
            name: "Test",
            host: "192.168.1.1",
            port: 445,
            sharePath: "/share",
            mountPoint: fileURL.path
        )

        let status = await checker.check(instance: instance)
        XCTAssertEqual(status, .unreachable)
    }
}
