import XCTest
@testable import SMBWatcher

final class WatcherEngineTests: XCTestCase {

    func testBackoffIntervalBaseCase() {
        let interval = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 0)
        XCTAssertEqual(interval, 30, accuracy: 0.1)
    }

    func testBackoffIntervalExponentialGrowth() {
        let interval0 = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 0)
        let interval1 = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 1)
        let interval2 = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 2)
        let interval3 = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 3)

        XCTAssertEqual(interval0, 30, accuracy: 0.1)
        XCTAssertEqual(interval1, 60, accuracy: 0.1)
        XCTAssertEqual(interval2, 120, accuracy: 0.1)
        XCTAssertEqual(interval3, 240, accuracy: 0.1)
    }

    func testBackoffIntervalMaxCap() {
        let interval = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 10)
        XCTAssertEqual(interval, 600, accuracy: 0.1) // 10 minutes max
    }

    func testBackoffIntervalResetsAfterSuccess() {
        // Simulate: retry 3 times, then reset
        let interval3 = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 3)
        XCTAssertEqual(interval3, 240, accuracy: 0.1)

        // After successful check, retry count resets to 0
        let intervalReset = WatcherEngine.calculateBackoff(baseInterval: 30, retryCount: 0)
        XCTAssertEqual(intervalReset, 30, accuracy: 0.1)
    }

    func testBackoffWithDifferentBaseIntervals() {
        let interval10 = WatcherEngine.calculateBackoff(baseInterval: 10, retryCount: 2)
        XCTAssertEqual(interval10, 40, accuracy: 0.1)

        let interval60 = WatcherEngine.calculateBackoff(baseInterval: 60, retryCount: 1)
        XCTAssertEqual(interval60, 120, accuracy: 0.1)
    }

    func testBackoffNeverExceedsMax() {
        // Even with very large retry counts, should cap at max
        let interval = WatcherEngine.calculateBackoff(baseInterval: 300, retryCount: 100)
        XCTAssertEqual(interval, 600, accuracy: 0.1)
    }
}
