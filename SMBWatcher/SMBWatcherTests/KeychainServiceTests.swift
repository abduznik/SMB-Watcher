import XCTest
@testable import SMBWatcher

/// Tests for KeychainService round-trip save/load/delete.
///
/// Uses a test-specific service name to avoid touching real user credentials.
final class KeychainServiceTests: XCTestCase {
    private var keychain: KeychainService!
    private let testInstanceID = UUID()

    override func setUp() {
        super.setUp()
        keychain = KeychainService()
        // Clean up any leftover test credentials
        try? keychain.delete(for: testInstanceID)
    }

    override func tearDown() {
        try? keychain.delete(for: testInstanceID)
        super.tearDown()
    }

    func testSaveAndLoadCredentials() throws {
        try keychain.save(username: "testuser", password: "testpass123", for: testInstanceID)

        let loaded = keychain.load(for: testInstanceID)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.username, "testuser")
        XCTAssertEqual(loaded?.password, "testpass123")
    }

    func testLoadReturnsNilWhenNoCredentials() {
        let result = keychain.load(for: UUID())
        XCTAssertNil(result)
    }

    func testDeleteRemovesCredentials() throws {
        try keychain.save(username: "user", password: "pass", for: testInstanceID)

        // Confirm saved
        XCTAssertNotNil(keychain.load(for: testInstanceID))

        // Delete
        try keychain.delete(for: testInstanceID)

        // Confirm gone
        XCTAssertNil(keychain.load(for: testInstanceID))
    }

    func testSaveOverwritesExistingCredentials() throws {
        try keychain.save(username: "old_user", password: "old_pass", for: testInstanceID)
        try keychain.save(username: "new_user", password: "new_pass", for: testInstanceID)

        let loaded = keychain.load(for: testInstanceID)
        XCTAssertEqual(loaded?.username, "new_user")
        XCTAssertEqual(loaded?.password, "new_pass")
    }

    func testDeleteNonExistentDoesNotThrow() throws {
        // Deleting a non-existent item should not throw
        try keychain.delete(for: UUID())
    }

    func testMultipleInstancesHaveIndependentCredentials() throws {
        let id1 = UUID()
        let id2 = UUID()
        defer {
            try? keychain.delete(for: id1)
            try? keychain.delete(for: id2)
        }

        try keychain.save(username: "user1", password: "pass1", for: id1)
        try keychain.save(username: "user2", password: "pass2", for: id2)

        let loaded1 = keychain.load(for: id1)
        let loaded2 = keychain.load(for: id2)

        XCTAssertEqual(loaded1?.username, "user1")
        XCTAssertEqual(loaded2?.username, "user2")
        XCTAssertNotEqual(loaded1?.password, loaded2?.password)
    }
}
