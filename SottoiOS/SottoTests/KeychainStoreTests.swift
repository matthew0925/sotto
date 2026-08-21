import XCTest
@testable import Sotto

final class KeychainStoreTests: XCTestCase {
    private let testKey = "sotto.tests.keychain.roundtrip"

    override func tearDown() {
        KeychainStore.delete(testKey)
        super.tearDown()
    }

    func testSetAndGetStringRoundTrip() {
        let success = KeychainStore.setString("見守り太郎", for: testKey)
        XCTAssertTrue(success, "writing a fresh Keychain item should succeed on a simulator/device")
        XCTAssertEqual(KeychainStore.getString(testKey), "見守り太郎")
    }

    func testGetReturnsNilForMissingKey() {
        KeychainStore.delete(testKey)
        XCTAssertNil(KeychainStore.getString(testKey))
    }

    func testSetOverwritesPreviousValue() {
        KeychainStore.setString("first", for: testKey)
        KeychainStore.setString("second", for: testKey)
        XCTAssertEqual(KeychainStore.getString(testKey), "second", "set() must replace, not duplicate, an existing item")
    }

    func testDeleteRemovesValue() {
        KeychainStore.setString("temporary", for: testKey)
        KeychainStore.delete(testKey)
        XCTAssertNil(KeychainStore.getString(testKey))
    }
}
