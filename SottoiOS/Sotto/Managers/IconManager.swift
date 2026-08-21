import UIKit

/// Alternate App Icons (`UIApplication.setAlternateIconName`) — an Apple-supported
/// mechanism, not a disguise. The app's Display Name ("そっと") still shows under
/// whichever icon is active; this only changes the icon artwork so it can sit
/// unremarkably among other apps on a busy home screen, in whatever color scheme
/// the rest of the layout happens to use.
///
/// Five icon images and matching picker previews are included in Assets.xcassets.
/// Xcode registers the four non-primary App Icon sets as alternate icons.
enum AppIconOption: String, CaseIterable, Identifiable {
    case primary = "AppIconClean"
    case pastelWarm = "IconPastelWarmClean"
    case pastelCool = "IconPastelCoolClean"
    // Keep the identifier versioned when artwork changes. iOS can retain an
    // alternate icon's old rendered bitmap when the identifier is reused.
    case mono = "IconMonoClean"
    case minimal = "IconMinimalClean"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: return "デフォルト"
        case .pastelWarm: return "暖色"
        case .pastelCool: return "寒色"
        case .mono: return "モノクロ"
        case .minimal: return "シンプル"
        }
    }

    /// Asset catalog image set name used for the picker's own preview thumbnail
    /// (separate from the actual home-screen icon assets referenced in Info.plist).
    var previewAssetName: String {
        switch self {
        case .primary: return "AppIconPreview"
        case .pastelWarm: return "IconPastelWarmPreview"
        case .pastelCool: return "IconPastelCoolPreview"
        case .mono: return "IconMonoPreview"
        case .minimal: return "IconMinimalPreview"
        }
    }

    var accessibilityName: String {
        switch self {
        case .pastelWarm: return "パステル 暖色"
        case .pastelCool: return "パステル 寒色"
        default: return displayName
        }
    }
}

final class IconManager: ObservableObject {
    @Published private(set) var current: AppIconOption
    @Published var lastErrorMessage: String?

    init() {
        if let name = UIApplication.shared.alternateIconName,
           let option = AppIconOption(rawValue: name) {
            current = option
        } else if let legacyName = UIApplication.shared.alternateIconName,
                  let option = Self.legacyOptions[legacyName] {
            current = option
            // Reapply renamed artwork once so devices do not keep the old
            // pre-rounded icon in SpringBoard's alternate-icon cache.
            DispatchQueue.main.async {
                UIApplication.shared.setAlternateIconName(option.rawValue)
            }
        } else {
            current = .primary
        }
    }

    private static let legacyOptions: [String: AppIconOption] = [
        "IconPastelWarm": .pastelWarm,
        "IconPastelCool": .pastelCool,
        "IconMono": .mono,
        "IconMinimal": .minimal,
    ]

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
