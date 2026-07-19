import XCTest
@testable import SMBWatcher

final class ConfigStoreTests: XCTestCase {
    var store: ConfigStore!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ConfigStore()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() throws {
        let instance = WatchedInstance(
            name: "Test NAS",
            host: "192.168.1.100",
            port: 445,
            sharePath: "/volume1/media",
            mountPoint: "/Volumes/media",
            isEnabled: true,
            pollIntervalSeconds: 30
        )

        store.add(instance)

        // Create a new store to test loading from disk
        let newStore = ConfigStore()
        try newStore.load()

        XCTAssertEqual(newStore.instances.count, 1)
        XCTAssertEqual(newStore.instances.first?.name, "Test NAS")
        XCTAssertEqual(newStore.instances.first?.host, "192.168.1.100")
        XCTAssertEqual(newStore.instances.first?.port, 445)
        XCTAssertEqual(newStore.instances.first?.sharePath, "/volume1/media")
        XCTAssertEqual(newStore.instances.first?.mountPoint, "/Volumes/media")
        XCTAssertTrue(newStore.instances.first?.isEnabled == true)
        XCTAssertEqual(newStore.instances.first?.pollIntervalSeconds, 30)
    }

    func testLoadEmptyFile() throws {
        // Clean up any existing file first
        try? FileManager.default.removeItem(at: store.instancesFileURL)
        
        let newStore = ConfigStore()
        try newStore.load()
        XCTAssertTrue(newStore.instances.isEmpty)
    }

    func testAddInstance() {
        let instance = WatchedInstance(name: "Test")
        store.add(instance)
        XCTAssertEqual(store.instances.count, 1)
        XCTAssertEqual(store.instances.first?.name, "Test")
    }

    func testUpdateInstance() {
        let instance = WatchedInstance(name: "Original")
        store.add(instance)

        var updated = instance
        updated.name = "Updated"
        store.update(updated)

        XCTAssertEqual(store.instances.first?.name, "Updated")
    }

    func testRemoveInstance() {
        let instance = WatchedInstance(name: "To Remove")
        store.add(instance)
        store.remove(id: instance.id)
        XCTAssertTrue(store.instances.isEmpty)
    }

    func testInstanceLookup() {
        let instance = WatchedInstance(name: "Lookup Test")
        store.add(instance)

        let found = store.instance(withID: instance.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Lookup Test")

        let notFound = store.instance(withID: UUID())
        XCTAssertNil(notFound)
    }

    func testMultipleInstances() {
        let instance1 = WatchedInstance(name: "First")
        let instance2 = WatchedInstance(name: "Second")
        store.add(instance1)
        store.add(instance2)

        XCTAssertEqual(store.instances.count, 2)
    }
}
