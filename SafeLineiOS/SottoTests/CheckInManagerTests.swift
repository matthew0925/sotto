import XCTest
@testable import Sotto

final class CheckInManagerTests: XCTestCase {

    override func tearDown() {
        CheckInManager().eraseSavedData()
        KeychainStore.delete("sotto.checkin.contact") // legacy single-contact key
        super.tearDown()
    }

    func testContactsPersistAcrossInstances() {
        let manager = CheckInManager()
        manager.eraseSavedData()
        manager.contacts = [EmergencyContact(name: "母", phoneNumber: "09011112222")]

        let reloaded = CheckInManager()
        XCTAssertEqual(reloaded.contacts.count, 1)
        XCTAssertEqual(reloaded.contacts.first?.name, "母")
        XCTAssertEqual(reloaded.contacts.first?.phoneNumber, "09011112222")
    }

    /// A user who saved a single contact before multi-contact support
    /// shipped must not silently lose it — CheckInManager.init() migrates
    /// the old single-value Keychain entry into the new array format.
    func testLegacySingleContactMigratesIntoContactsArray() {
        CheckInManager().eraseSavedData()
        KeychainStore.setString("08099998888", for: "sotto.checkin.contact")

        let manager = CheckInManager()
        XCTAssertEqual(manager.contacts.count, 1)
        XCTAssertEqual(manager.contacts.first?.phoneNumber, "08099998888")
    }

    func testEraseSavedDataResetsEverything() {
        let manager = CheckInManager()
        manager.contacts = [EmergencyContact(name: "テスト", phoneNumber: "0900000000")]
        manager.contactMessage = "カスタムメッセージ"
        manager.dailyReminderEnabled = true

        manager.eraseSavedData()

        XCTAssertTrue(manager.contacts.isEmpty)
        XCTAssertFalse(manager.contactMessage.isEmpty, "message resets to the default prompt, not blank")
        XCTAssertFalse(manager.dailyReminderEnabled)
        XCTAssertFalse(manager.isActive)
    }

    func testEmergencyContactRoundTripsThroughJSON() throws {
        let original = [
            EmergencyContact(name: "父", phoneNumber: "09011112222"),
            EmergencyContact(name: "友人", phoneNumber: "08033334444"),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([EmergencyContact].self, from: data)
        XCTAssertEqual(decoded.map(\.name), original.map(\.name))
        XCTAssertEqual(decoded.map(\.phoneNumber), original.map(\.phoneNumber))
    }
}
