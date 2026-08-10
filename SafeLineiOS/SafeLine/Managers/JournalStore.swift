import Foundation
import CryptoKit

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    /// True if a photo was attached. The photo itself is never stored inside
    /// this JSON blob — it lives as its own encrypted file (see
    /// `JournalStore.photoFileURL(for:)`) so a journal with several photos
    /// doesn't force the whole entry list to be re-encrypted/re-written on
    /// every save.
    var hasPhoto: Bool = false
}

/// Entries are JSON-encoded, then sealed with AES-GCM before touching disk.
/// The symmetric key lives in the Keychain under
/// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` — it simply won't exist
/// (and the journal will read as empty) on a device with no passcode set, which
/// is intentional: an unlocked, passcode-less phone is not a safe place for this
/// key to be usable at all. NSFileProtectionComplete + isExcludedFromBackup
/// remain as a second layer under the encryption.
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    /// Set whenever the most recent add/delete failed to persist to disk — the
    /// in-memory `entries` array is still updated optimistically (so the user
    /// sees their entry immediately), but silently losing that on the next
    /// launch without telling anyone would be worse than an ugly error banner.
    /// JournalView surfaces this.
    @Published private(set) var lastSaveError: String?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("journal.enc")
    }()

    private let photosDirURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("journal_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let keychainKey = "sotto.journal.key"

    // Not `lazy var` on purpose: eraseAll() needs to force a fresh key to be
    // generated (and persisted) on the very next save, not reuse whatever key
    // happened to already be cached in memory. A `lazy var` has no supported
    // way to be "un-cached", which previously meant that adding an entry right
    // after erasing would silently encrypt it with a key that no longer existed
    // in the Keychain — unrecoverable on the next app launch.
    private var cachedSymmetricKey: SymmetricKey?

    /// Returns nil if a key isn't already in the Keychain AND we failed to
    /// persist a newly generated one (e.g. SecItemAdd rejected it because the
    /// device has no passcode set, or some other Keychain error). Callers must
    /// treat nil as "cannot save right now" rather than falling back to an
    /// unpersisted, in-memory-only key — encrypting with a key that was never
    /// actually written to the Keychain would make that data permanently
    /// unrecoverable the moment the process exits.
    private var symmetricKey: SymmetricKey? {
        if let cachedSymmetricKey { return cachedSymmetricKey }
        if let data = KeychainStore.get(Self.keychainKey) {
            let key = SymmetricKey(data: data)
            cachedSymmetricKey = key
            return key
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        guard KeychainStore.set(keyData, for: Self.keychainKey,
                                 accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) else {
            return nil
        }
        cachedSymmetricKey = key
        return key
    }

    init() {
        load()
        applyFileProtection()
    }

    func add(text: String, date: Date = Date(), photoData: Data? = nil) {
        let entry = JournalEntry(id: UUID(), date: date, text: text, hasPhoto: photoData != nil)
        if let photoData {
            guard savePhoto(photoData, for: entry.id) else {
                lastSaveError = "写真を保存できませんでした。もう一度試してみてください。"
                return
            }
        }
        entries.append(entry)
        save()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        try? FileManager.default.removeItem(at: photoFileURL(for: entry.id))
        save()
    }

    /// Decrypts and returns the photo for an entry, if it has one. Called
    /// on-demand from the view rather than kept in memory for every entry.
    func photo(for entry: JournalEntry) -> Data? {
        guard entry.hasPhoto, let key = symmetricKey else { return nil }
        guard let sealed = try? Data(contentsOf: photoFileURL(for: entry.id)) else { return nil }
        guard let box = try? AES.GCM.SealedBox(combined: sealed) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    private func savePhoto(_ data: Data, for id: UUID) -> Bool {
        guard let key = symmetricKey else { return false }
        guard let sealed = try? AES.GCM.seal(data, using: key), let combined = sealed.combined else { return false }
        do {
            try combined.write(to: photoFileURL(for: id), options: .completeFileProtection)
            var url = photoFileURL(for: id)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
            return true
        } catch {
            return false
        }
    }

    private func photoFileURL(for id: UUID) -> URL {
        photosDirURL.appendingPathComponent("\(id.uuidString).enc")
    }

    /// Used by the "この端末からすべてのデータを削除" setting — wipes both the
    /// in-memory list and the encrypted file, and drops the Keychain key so a
    /// stale key can't later decrypt a file that no longer represents it.
    func eraseAll() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: photosDirURL)
        try? FileManager.default.createDirectory(at: photosDirURL, withIntermediateDirectories: true)
        KeychainStore.delete(Self.keychainKey)
        cachedSymmetricKey = nil
    }

    private func load() {
        guard let sealed = try? Data(contentsOf: fileURL) else { return }
        guard let key = symmetricKey else {
            // No usable key at all (Keychain unavailable) — fail closed rather
            // than crash or leak plaintext. There's nothing to show the user
            // here since this runs at launch, before any view is visible.
            entries = []
            return
        }
        do {
            let box = try AES.GCM.SealedBox(combined: sealed)
            let decrypted = try AES.GCM.open(box, using: key)
            entries = try JSONDecoder().decode([JournalEntry].self, from: decrypted)
                .sorted { $0.date > $1.date }
        } catch {
            // Corrupt file, or the Keychain key is gone (e.g. restored onto a new
            // device without passcode-protected Keychain items carrying over).
            // Fail closed — start empty rather than crash or leak plaintext.
            entries = []
        }
    }

    private func save() {
        guard let key = symmetricKey else {
            lastSaveError = "うまく保存できませんでした。この端末にパスコードが設定されているか確認してみてください。"
            return
        }
        do {
            let plain = try JSONEncoder().encode(entries)
            let sealed = try AES.GCM.seal(plain, using: key)
            guard let combined = sealed.combined else {
                lastSaveError = "うまく保存できませんでした。"
                return
            }
            try combined.write(to: fileURL, options: .completeFileProtection)
            applyFileProtection()
            excludeFromBackup()
            lastSaveError = nil
        } catch {
            // If sealing/writing fails for any reason, skip the write rather
            // than ever persisting plaintext — but tell the user, since
            // `entries` (already updated in memory) will otherwise look saved
            // right up until the app is relaunched and this entry is gone.
            lastSaveError = "うまく保存できませんでした。もう一度試してみてください。"
        }
    }

    private func applyFileProtection() {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
    }

    private func excludeFromBackup() {
        var url = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
    }
}
