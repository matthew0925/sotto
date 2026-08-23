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
        case "tel":
            // `#` starts a URL fragment unless percent-encoded, which would
            // silently turn official short codes such as #8891 into the wrong
            // destination. Strip visual separators and encode the hash.
            let dialable = value.filter { "0123456789+#*".contains($0) }
            guard !dialable.isEmpty else { return nil }
            return URL(string: "tel:\(dialable.replacingOccurrences(of: "#", with: "%23"))")
        case "url": return URL(string: value)
        default: return nil
        }
    }
}

enum SupportResourceLoader {
    /// GitHub Pages already serves `docs/` for the privacy policy and support
    /// pages, so the same static hosting carries this JSON — no separate
    /// backend needed, and updating a hotline number is a one-line edit +
    /// push rather than an App Store release.
    private static let remoteURL = URL(string: "https://matthew0925.github.io/sotto/resources.json")!
    private static let cacheFilename = "resources_cache.json"

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFilename)
    }

    /// Synchronous, always-available fast path: a previously-fetched remote
    /// copy if one exists, otherwise the bundled JSON shipped with the app.
    /// Callers show this immediately, then optionally call `refreshFromRemote()`
    /// to pick up anything newer.
    static func load() -> [SupportResource] {
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([SupportResource].self, from: data) {
            return decoded
        }
        return loadBundled()
    }

    static func loadBundled() -> [SupportResource] {
        guard let url = Bundle.main.url(forResource: "resources", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SupportResource].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Fetches the latest copy and, if it decodes successfully, writes it to
    /// the on-disk cache and returns it. Returns nil on any failure (offline,
    /// malformed response, etc.) — callers keep showing whatever `load()`
    /// already returned rather than blocking or showing an error for a
    /// resources list that isn't safety-time-critical on any single launch.
    @discardableResult
    static func refreshFromRemote() async -> [SupportResource]? {
        // A silent background refresh has no business holding the default
        // 60s timeout on a bad connection — this file is a few KB, so 8s is
        // generous, and giving up quickly means less battery/data spent on
        // a request whose result the UI doesn't wait on anyway.
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode([SupportResource].self, from: data),
              !decoded.isEmpty else {
            return nil
        }
        if let cacheURL {
            try? data.write(to: cacheURL, options: .atomic)
        }
        return decoded
    }
}
