import Foundation
import CryptoKit

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
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

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("journal.enc")
    }()

    private static let keychainKey = "sotto.journal.key"

    private lazy var symmetricKey: SymmetricKey = {
        if let data = KeychainStore.get(Self.keychainKey) {
            return SymmetricKey(data: data)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        KeychainStore.set(keyData, for: Self.keychainKey,
                           accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
        return newKey
    }()

    init() {
        load()
        applyFileProtection()
    }

    func add(text: String, date: Date = Date()) {
        let entry = JournalEntry(id: UUID(), date: date, text: text)
        entries.append(entry)
        save()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// Used by the "この端末からすべてのデータを削除" setting — wipes both the
    /// in-memory list and the encrypted file, and drops the Keychain key so a
    /// stale key can't later decrypt a file that no longer represents it.
    func eraseAll() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
        KeychainStore.delete(Self.keychainKey)
    }

    private func load() {
        guard let sealed = try? Data(contentsOf: fileURL) else { return }
        do {
            let box = try AES.GCM.SealedBox(combined: sealed)
            let decrypted = try AES.GCM.open(box, using: symmetricKey)
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
        do {
            let plain = try JSONEncoder().encode(entries)
            let sealed = try AES.GCM.seal(plain, using: symmetricKey)
            guard let combined = sealed.combined else { return }
            try combined.write(to: fileURL, options: .completeFileProtection)
            applyFileProtection()
            excludeFromBackup()
        } catch {
            // If sealing fails for any reason, skip the write rather than ever
            // persisting plaintext.
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
