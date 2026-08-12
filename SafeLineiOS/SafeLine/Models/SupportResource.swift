import Foundation

struct SupportResource: Codable, Identifiable {
    var id: String { title }
    let title: String
    let desc: String
    /// "tel", "url", or "info" (a notice card — non-actionable unless `value`
    /// carries a link, e.g. to a government page that stays current on its own
    /// rather than data this static bundle would need to keep re-shipping).
    let type: String
    let value: String
    let tags: [String]

    var actionURL: URL? {
        switch type {
        case "tel": return URL(string: "tel:\(value)")
        case "url": return URL(string: value)
        case "info": return value.isEmpty ? nil : URL(string: value)
        default: return nil
        }
    }
}

enum SupportResourceLoader {
    /// Loads the bundled JSON. In production, layer a remote-refresh step on top
    /// (e.g. fetch an updated JSON from your own static hosting) so hotline info
    /// doesn't go stale between App Store releases — flagged in the spec as an
    /// open item worth confirming with a support organization.
    static func load() -> [SupportResource] {
        guard let url = Bundle.main.url(forResource: "resources", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SupportResource].self, from: data) else {
            return []
        }
        return decoded
    }
}
