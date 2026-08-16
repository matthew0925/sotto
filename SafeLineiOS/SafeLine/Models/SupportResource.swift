import Foundation

struct SupportResource: Codable, Identifiable {
    var id: String { title }
    let title: String
    let desc: String
    /// "contact" or "info". Contact cards expose one or more explicit actions
    /// rather than using informational tags as ambiguous tap targets.
    let type: String
    let actions: [SupportAction]
}

struct SupportAction: Codable, Identifiable {
    var id: String { "\(type):\(value):\(label)" }
    let label: String
    /// "tel", "url", or "directory". Web actions open in the shared
    /// in-app browser; telephone actions hand off to the Phone app.
    let type: String
    let value: String

    var actionURL: URL? {
        switch type {
        case "tel": return URL(string: "tel:\(value)")
        case "url": return URL(string: value)
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
