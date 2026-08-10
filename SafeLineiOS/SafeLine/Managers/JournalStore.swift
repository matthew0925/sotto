import Foundation

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
}

/// Stores entries in a single JSON file inside the app's Documents directory.
/// Two things matter here more than the storage format itself:
///   1. NSFileProtectionComplete — unreadable while the device is locked.
///   2. isExcludedFromBackup — never leaves the device via iCloud/iTunes backup.
/// For a production release, swap the raw JSON for SQLCipher or wrap the file
/// contents with CryptoKit (AES-GCM) keyed off a value stored in the Keychain,
/// and gate access behind Face ID / passcode (LAContext) before rendering JournalView.
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("journal.json")
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

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.date > $1.date }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .completeFileProtection)
        applyFileProtection()
        excludeFromBackup()
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
