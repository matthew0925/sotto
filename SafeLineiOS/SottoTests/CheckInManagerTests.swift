import XCTest
import UserNotifications
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
        // A real pre-migration install has no value under the new array key.
        // eraseSavedData() intentionally persists an empty new-format array,
        // so remove it here to reproduce the legacy-only state accurately.
        KeychainStore.delete("sotto.checkin.contacts")
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
        XCTAssertTrue(manager.contactMessage.isEmpty)
        XCTAssertFalse(manager.dailyReminderEnabled)
        XCTAssertFalse(manager.isActive)
    }

    func testPreviousDefaultMessageMigratesToEmptyEditor() {
        CheckInManager().eraseSavedData()
        KeychainStore.setString(CheckInManager.defaultContactMessage, for: "sotto.checkin.message")

        XCTAssertTrue(CheckInManager().contactMessage.isEmpty)
    }

    func testCustomMessageIsNotReplacedDuringMigration() {
        CheckInManager().eraseSavedData()
        KeychainStore.setString("駅に着いたら連絡します。", for: "sotto.checkin.message")

        XCTAssertEqual(CheckInManager().contactMessage, "駅に着いたら連絡します。")
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

    func testActiveCheckInRestoresAfterProcessRelaunch() {
        let endDate = Date().addingTimeInterval(600)
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(endDate, forKey: "sotto.checkin.endDate")

        let restored = CheckInManager()

        XCTAssertTrue(restored.isActive)
        XCTAssertEqual(restored.endDate?.timeIntervalSince1970 ?? 0,
                       endDate.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertGreaterThan(restored.remainingSeconds, 0)
        restored.markSafe()
    }

    func testOverdueCheckInRequestsComposerAfterProcessRelaunch() {
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")

        let restored = CheckInManager()

        XCTAssertTrue(restored.isActive)
        XCTAssertTrue(restored.wantsToSendAlert)
        restored.markSafe()
    }

    func testMarkSafeClearsPersistedActiveState() {
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(Date().addingTimeInterval(600), forKey: "sotto.checkin.endDate")

        let manager = CheckInManager()
        manager.markSafe()
        let reloaded = CheckInManager()

        XCTAssertFalse(reloaded.isActive)
        XCTAssertNil(reloaded.endDate)
    }

    func testMarkSafeClearsPendingComposerRequest() {
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        let manager = CheckInManager()
        XCTAssertTrue(manager.wantsToSendAlert)

        manager.markSafe()

        XCTAssertFalse(manager.wantsToSendAlert)
    }

    func testAutomationSnapshotReturnsSavedDataOnlyWhenOverdue() throws {
        let contacts = [EmergencyContact(name: "母", phoneNumber: "09011112222")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        KeychainStore.setString("帰宅していません。", for: "sotto.checkin.message")
        let deadline = Date().addingTimeInterval(-60)
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(deadline, forKey: "sotto.checkin.endDate")

        let overdue = CheckInManager.automationSnapshot()
        XCTAssertTrue(overdue.isActive)
        XCTAssertTrue(overdue.isOverdue)
        XCTAssertEqual(overdue.recipients, ["09011112222"])
        XCTAssertTrue(overdue.message.contains("帰宅していません。"))
        XCTAssertTrue(overdue.message.contains("見守りの目安時刻"))

        UserDefaults.standard.set(false, forKey: "sotto.checkin.active")
        let inactive = CheckInManager.automationSnapshot()
        XCTAssertFalse(inactive.isActive)
        XCTAssertFalse(inactive.isOverdue)
        XCTAssertNil(inactive.deadline)
        XCTAssertTrue(inactive.recipients.isEmpty)
        XCTAssertTrue(inactive.message.isEmpty)
    }

    func testAutomationSnapshotTreatsMissingDeadlineAsInactive() throws {
        let contacts = [EmergencyContact(name: "母", phoneNumber: "090-1111-2222")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.removeObject(forKey: "sotto.checkin.endDate")

        let snapshot = CheckInManager.automationSnapshot()

        XCTAssertFalse(snapshot.isActive)
        XCTAssertFalse(snapshot.isOverdue)
        XCTAssertNil(snapshot.deadline)
        XCTAssertTrue(snapshot.recipients.isEmpty)
        XCTAssertTrue(snapshot.message.isEmpty)
    }

    func testAutomationSnapshotNormalizesRecipientPhoneNumbers() throws {
        let contacts = [
            EmergencyContact(name: "母", phoneNumber: "090-1111-2222"),
            EmergencyContact(name: "海外", phoneNumber: "+81 (90) 3333 4444"),
            EmergencyContact(name: "不正", phoneNumber: "番号なし")
        ]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")

        XCTAssertEqual(CheckInManager.automationSnapshot().recipients,
                       ["09011112222", "+819033334444"])
    }
}

final class NotificationRoutingTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sotto.checkin.active")
        UserDefaults.standard.removeObject(forKey: "sotto.checkin.endDate")
        super.tearDown()
    }

    private func makeActiveDelegate() -> AppDelegate {
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        return AppDelegate()
    }

    func testSendActionNavigatesAndRequestsComposer() {
        let delegate = makeActiveDelegate()
        let router = AppRouter()
        delegate.router = router

        delegate.handleNotificationAction(identifier: CheckInManager.sendActionId,
                                          category: CheckInManager.timeoutCategoryId)

        XCTAssertEqual(router.selectedTab, .checkin)
        XCTAssertTrue(delegate.checkInManager.wantsToSendAlert)
    }

    func testColdLaunchDefersNavigationUntilRouterExists() {
        let delegate = makeActiveDelegate()

        delegate.handleNotificationAction(identifier: CheckInManager.sendActionId,
                                          category: CheckInManager.timeoutCategoryId)
        let router = AppRouter()
        delegate.router = router

        XCTAssertEqual(router.selectedTab, .checkin)
        XCTAssertTrue(delegate.checkInManager.wantsToSendAlert)
    }

    func testDefaultTimeoutTapNavigatesAndRequestsComposer() {
        let delegate = makeActiveDelegate()
        let router = AppRouter()
        delegate.router = router

        delegate.handleNotificationAction(identifier: UNNotificationDefaultActionIdentifier,
                                          category: CheckInManager.timeoutCategoryId)

        XCTAssertEqual(router.selectedTab, .checkin)
        XCTAssertTrue(delegate.checkInManager.wantsToSendAlert)
    }

    func testStaleTimeoutActionDoesNotRequestComposer() {
        let delegate = AppDelegate()
        let router = AppRouter()
        delegate.router = router

        delegate.handleNotificationAction(identifier: CheckInManager.sendActionId,
                                          category: CheckInManager.timeoutCategoryId)

        XCTAssertFalse(delegate.checkInManager.wantsToSendAlert)
    }
}
