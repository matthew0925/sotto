import XCTest
@testable import Sotto

/// Covers the journal's two safety-critical properties: entries actually
/// round-trip through encryption intact, and the tamper-evidence hash
/// genuinely reflects the stored content rather than being decorative.
final class JournalStoreTests: XCTestCase {

    override func tearDown() {
        // Each test starts from a clean slate — eraseAll() also drops the
        // Keychain key, so nothing leaks between tests or into a real run
        // of the app on the same simulator.
        JournalStore().eraseAll()
        super.tearDown()
    }

    func testAddedEntryIsReadableAfterReload() {
        let store = JournalStore()
        store.eraseAll()
        store.add(text: "テストの記録です", date: Date())

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertNil(store.lastSaveError, "save should not report an error on a normal add")

        // Simulate an app relaunch: a *new* JournalStore instance reading
        // the same on-disk file must decrypt it correctly.
        let reloaded = JournalStore()
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.text, "テストの記録です")

        reloaded.eraseAll()
    }

    func testHashIsDeterministicAndContentSensitive() {
        let hashA = JournalStore.hash(text: "hello", photoData: nil)
        let hashB = JournalStore.hash(text: "hello", photoData: nil)
        let hashC = JournalStore.hash(text: "hello!", photoData: nil)

        XCTAssertEqual(hashA, hashB, "hashing the same text twice must produce the same digest")
        XCTAssertNotEqual(hashA, hashC, "changing even one character must change the hash")
        XCTAssertEqual(hashA.count, 64, "SHA-256 hex digest should be 64 characters")
    }

    func testHashIncludesPhotoBytes() {
        let textOnly = JournalStore.hash(text: "note", photoData: nil)
        let withPhoto = JournalStore.hash(text: "note", photoData: Data([0x01, 0x02, 0x03]))
        XCTAssertNotEqual(textOnly, withPhoto, "attaching a photo must change the hash, not just the text")
    }

    func testVerifyDetectsIntactEntry() {
        let store = JournalStore()
        store.eraseAll()
        store.add(text: "改ざん検知のテスト", date: Date())

        guard let entry = store.entries.first else {
            return XCTFail("entry should have been saved")
        }
        XCTAssertEqual(store.verify(entry), true, "a freshly-saved, untouched entry must verify as intact")
        store.eraseAll()
    }

    /// Regression test for the bug fixed in an earlier session: eraseAll()
    /// used to leave a stale in-memory key cached, so an entry added right
    /// after erasing would be encrypted with a key that no longer existed
    /// in the Keychain — unrecoverable on the next launch. This test would
    /// fail (reloaded.entries would be empty) if that bug came back.
    func testEntryAddedRightAfterEraseAllSurvivesReload() {
        let store = JournalStore()
        store.add(text: "before erase", date: Date())
        store.eraseAll()
        store.add(text: "after erase", date: Date())

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.text, "after erase")

        let reloaded = JournalStore()
        XCTAssertEqual(reloaded.entries.count, 1, "the post-erase entry must still be decryptable after a fresh launch")
        XCTAssertEqual(reloaded.entries.first?.text, "after erase")

        reloaded.eraseAll()
    }

    func testDeleteRemovesEntry() {
        let store = JournalStore()
        store.eraseAll()
        store.add(text: "entry one", date: Date())
        store.add(text: "entry two", date: Date())
        XCTAssertEqual(store.entries.count, 2)

        guard let toDelete = store.entries.first else { return XCTFail() }
        store.delete(toDelete)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries.contains { $0.id == toDelete.id })

        store.eraseAll()
    }
}
