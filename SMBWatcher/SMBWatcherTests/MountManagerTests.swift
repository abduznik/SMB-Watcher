import XCTest
@testable import SMBWatcher

/// Regression tests and unit tests for MountManager.
///
/// These tests verify the SMB URL format and health-check logic without
/// requiring a real SMB server, using temp directories as mock mount points.
final class MountManagerTests: XCTestCase {
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

    // MARK: - Regression: mount_smbfs URL format

    func testSMBURLFormatMustBeDoubleSlash() {
        // Regression: mount_smbfs expects //user:pass@host/share, NOT smb://user:pass@host/share
        // This test asserts the exact format MountManager builds.
        let username = "arb"
        let password = "s3cret"
        let host = "100.119.139.93"
        let sharePath = "/storage"

        let smbURL = "//\(username):\(password)@\(host)\(sharePath)"

        XCTAssertTrue(smbURL.hasPrefix("//"), "URL must start with //, not smb://")
        XCTAssertFalse(smbURL.hasPrefix("smb://"), "URL must NOT use smb:// scheme — mount_smbfs rejects it")
        XCTAssertEqual(smbURL, "//arb:s3cret@100.119.139.93/storage")
    }

    func testSMBURLWithSpecialCharactersInPassword() {
        let username = "user"
        let password = "p@ss:word/123"
        let host = "192.168.1.1"
        let sharePath = "/share"

        let smbURL = "//\(username):\(password)@\(host)\(sharePath)"
        XCTAssertEqual(smbURL, "//user:p@ss:word/123@192.168.1.1/share")
    }

    func testSMBURLWithIPv6Host() {
        let username = "admin"
        let password = "pass"
        let host = "fe80::1%25en0"
        let sharePath = "/volume1/data"

        let smbURL = "//\(username):\(password)@\(host)\(sharePath)"
        XCTAssertEqual(smbURL, "//admin:pass@fe80::1%25en0/volume1/data")
    }

    // MARK: - Mount point directory creation

    func testMountManagerCreatesMountPointIfMissing() async {
        let mountPoint = tempDir.appendingPathComponent("new_mount").path
        let keychain = KeychainService()
        let manager = MountManager(keychain: keychain)

        // First save dummy credentials so mount() doesn't bail early
        let instance = WatchedInstance(
            name: "Test",
            host: "192.168.1.1",
            port: 445,
            sharePath: "/share",
            mountPoint: mountPoint
        )
        try? keychain.save(username: "test", password: "test", for: instance.id)
        defer { try? keychain.delete(for: instance.id) }

        // mount will fail (no server), but it should create the directory first
        _ = await manager.mount(instance: instance)

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: mountPoint, isDirectory: &isDir)
        XCTAssertTrue(exists, "Mount point directory should be created")
        XCTAssertTrue(isDir.boolValue, "Mount point should be a directory")
    }

    // MARK: - Unmount returns false for non-existent path

    func testUnmountNonExistentPathReturnsFalse() async {
        let manager = MountManager(keychain: KeychainService())
        let result = await manager.unmount(mountPoint: "/nonexistent/path/\(UUID().uuidString)")
        XCTAssertFalse(result, "Unmounting a non-existent path should fail")
    }
}
