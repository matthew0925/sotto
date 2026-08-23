import XCTest
import UserNotifications
@testable import Sotto

final class CheckInManagerTests: XCTestCase {
    private let sharedDefaults = UserDefaults(suiteName: CheckInManager.appGroupID)!

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
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(endDate, forKey: "sotto.checkin.endDate")

        let restored = CheckInManager()

        XCTAssertTrue(restored.isActive)
        XCTAssertEqual(restored.endDate?.timeIntervalSince1970 ?? 0,
                       endDate.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertGreaterThan(restored.remainingSeconds, 0)
        restored.markSafe()
    }

    func testOverdueCheckInRequestsComposerAfterProcessRelaunch() {
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")

        let restored = CheckInManager()

        XCTAssertTrue(restored.isActive)
        XCTAssertTrue(restored.wantsToSendAlert)
        restored.markSafe()
    }

    func testMarkSafeClearsPersistedActiveState() {
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(600), forKey: "sotto.checkin.endDate")

        let manager = CheckInManager()
        manager.markSafe()
        let reloaded = CheckInManager()

        XCTAssertFalse(reloaded.isActive)
        XCTAssertNil(reloaded.endDate)
    }

    func testMarkSafeClearsPendingComposerRequest() {
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
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
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(deadline, forKey: "sotto.checkin.endDate")

        let overdue = CheckInManager.automationSnapshot()
        XCTAssertTrue(overdue.isActive)
        XCTAssertTrue(overdue.isOverdue)
        XCTAssertEqual(overdue.recipients, ["09011112222"])
        XCTAssertTrue(overdue.message.contains("帰宅していません。"))
        XCTAssertTrue(overdue.message.contains("見守りの目安時刻"))

        sharedDefaults.set(false, forKey: "sotto.checkin.active")
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
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.removeObject(forKey: "sotto.checkin.endDate")

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
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")

        XCTAssertEqual(CheckInManager.automationSnapshot().recipients,
                       ["09011112222", "+819033334444"])
    }

    func testAutomationDeliveryCanBeClaimedOnlyOncePerSession() throws {
        let contacts = [EmergencyContact(name: "母", phoneNumber: "09011112222")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        sharedDefaults.set("session-a", forKey: "sotto.checkin.sessionID")
        sharedDefaults.removeObject(forKey: "sotto.checkin.automationClaimedSessionID")

        let first = CheckInManager.automationSnapshot(claimForDelivery: true)
        let second = CheckInManager.automationSnapshot(claimForDelivery: true)

        XCTAssertTrue(first.shouldSend)
        XCTAssertEqual(first.deliveryStatus, "送信可能")
        XCTAssertEqual(first.recipients, ["09011112222"])
        XCTAssertFalse(second.shouldSend)
        XCTAssertFalse(second.isOverdue)
        XCTAssertEqual(second.deliveryStatus, "受け渡し済み")
        XCTAssertTrue(second.recipients.isEmpty)
        XCTAssertTrue(second.message.isEmpty)
    }

    func testNewAutomationSessionCanDeliverAfterPreviousSessionWasClaimed() throws {
        let contacts = [EmergencyContact(name: "母", phoneNumber: "09011112222")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        sharedDefaults.set("session-b", forKey: "sotto.checkin.sessionID")
        sharedDefaults.set("session-a", forKey: "sotto.checkin.automationClaimedSessionID")

        let snapshot = CheckInManager.automationSnapshot(claimForDelivery: true)

        XCTAssertTrue(snapshot.shouldSend)
        XCTAssertEqual(snapshot.sessionID, "session-b")
    }

    func testAutomationReportsConfigurationErrorWithoutClaiming() throws {
        let contacts = [EmergencyContact(name: "不正", phoneNumber: "番号なし")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        sharedDefaults.set("session-invalid", forKey: "sotto.checkin.sessionID")
        sharedDefaults.removeObject(forKey: "sotto.checkin.automationClaimedSessionID")

        let snapshot = CheckInManager.automationSnapshot(claimForDelivery: true)

        XCTAssertFalse(snapshot.shouldSend)
        XCTAssertEqual(snapshot.deliveryStatus, "設定不備")
        XCTAssertNil(sharedDefaults.string(forKey: "sotto.checkin.automationClaimedSessionID"))
    }

    func testConcurrentAutomationRunsExposePayloadExactlyOnce() throws {
        let contacts = [EmergencyContact(name: "母", phoneNumber: "09011112222")]
        KeychainStore.set(try JSONEncoder().encode(contacts), for: "sotto.checkin.contacts")
        sharedDefaults.set(true, forKey: "sotto.checkin.active")
        sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
        sharedDefaults.set("session-concurrent", forKey: "sotto.checkin.sessionID")
        sharedDefaults.removeObject(forKey: "sotto.checkin.automationClaimedSessionID")

        let resultLock = NSLock()
        var results: [CheckInManager.AutomationSnapshot] = []
        DispatchQueue.concurrentPerform(iterations: 12) { _ in
            let snapshot = CheckInManager.automationSnapshot(claimForDelivery: true)
            resultLock.lock()
            results.append(snapshot)
            resultLock.unlock()
        }

        XCTAssertEqual(results.filter(\.shouldSend).count, 1)
        XCTAssertEqual(results.filter { !$0.recipients.isEmpty }.count, 1)
        XCTAssertEqual(results.filter { !$0.message.isEmpty }.count, 1)
    }

    /// Pre-App-Group installs persisted active/endDate/sessionID in `.standard`.
    /// An update must not silently drop an in-progress check-in just because
    /// reads moved to the shared App Group container — the first read after
    /// update has to migrate that state across rather than finding it empty.
    func testActiveCheckInPersistedUnderLegacyStandardDefaultsIsMigratedOnFirstRead() {
        UserDefaults.standard.removeObject(forKey: "sotto.checkin.migratedToAppGroup")
        sharedDefaults.removeObject(forKey: "sotto.checkin.active")
        sharedDefaults.removeObject(forKey: "sotto.checkin.endDate")
        sharedDefaults.removeObject(forKey: "sotto.checkin.sessionID")
        let endDate = Date().addingTimeInterval(600)
        UserDefaults.standard.set(true, forKey: "sotto.checkin.active")
        UserDefaults.standard.set(endDate, forKey: "sotto.checkin.endDate")
        UserDefaults.standard.set("legacy-session", forKey: "sotto.checkin.sessionID")

        let restored = CheckInManager()

        XCTAssertTrue(restored.isActive)
        XCTAssertEqual(restored.endDate?.timeIntervalSince1970 ?? 0,
                       endDate.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(sharedDefaults.string(forKey: "sotto.checkin.sessionID"), "legacy-session")
        XCTAssertNil(UserDefaults.standard.object(forKey: "sotto.checkin.active"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "sotto.checkin.endDate"))
        restored.markSafe()
        UserDefaults.standard.removeObject(forKey: "sotto.checkin.migratedToAppGroup")
    }
}

final class NotificationRoutingTests: XCTestCase {
    override func tearDown() {
        UserDefaults(suiteName: CheckInManager.appGroupID)!.removeObject(forKey: "sotto.checkin.active")
        UserDefaults(suiteName: CheckInManager.appGroupID)!.removeObject(forKey: "sotto.checkin.endDate")
        super.tearDown()
    }

    private func makeActiveDelegate() -> AppDelegate {
        UserDefaults(suiteName: CheckInManager.appGroupID)!.set(true, forKey: "sotto.checkin.active")
        UserDefaults(suiteName: CheckInManager.appGroupID)!.set(Date().addingTimeInterval(-60), forKey: "sotto.checkin.endDate")
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
