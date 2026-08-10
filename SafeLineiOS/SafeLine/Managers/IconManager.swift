import UIKit

/// Alternate App Icons (`UIApplication.setAlternateIconName`) — an Apple-supported
/// mechanism, not a disguise. The app's Display Name ("そっと") still shows under
/// whichever icon is active; this only changes the icon artwork so it can sit
/// unremarkably among other apps on a busy home screen, in whatever color scheme
/// the rest of the layout happens to use.
///
/// The actual icon images are NOT included in this source drop — they need to be
/// designed and added as image sets in Xcode's Asset Catalog, then declared under
/// `CFBundleIcons > CFBundleAlternateIcons` in Info.plist. See SafeLineiOS/README.md
/// §5 for the exact keys and file names this code expects.
enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case pastel = "IconPastel"
    case mono = "IconMono"
    case minimal = "IconMinimal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: return "デフォルト"
        case .pastel: return "パステル"
        case .mono: return "モノクロ"
        case .minimal: return "シンプル"
        }
    }

    /// Asset catalog image set name used for the picker's own preview thumbnail
    /// (separate from the actual home-screen icon assets referenced in Info.plist).
    var previewAssetName: String { "\(rawValue)Preview" }
}

final class IconManager: ObservableObject {
    @Published private(set) var current: AppIconOption
    @Published var lastErrorMessage: String?

    init() {
        if let name = UIApplication.shared.alternateIconName,
           let option = AppIconOption(rawValue: name) {
            current = option
        } else {
            current = .primary
        }
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func setIcon(_ option: AppIconOption) {
        guard supportsAlternateIcons else { return }
        guard option != current else { return }
        let name = option == .primary ? nil : option.rawValue
        UIApplication.shared.setAlternateIconName(name) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.lastErrorMessage = error.localizedDescription
                } else {
                    self?.current = option
                    self?.lastErrorMessage = nil
                }
            }
        }
    }
}
