import Foundation
import LocalAuthentication

/// Gates JournalView behind Face ID / Touch ID / device passcode. The view calls
/// `lock()` whenever the app leaves the foreground, so a glance at an unlocked
/// phone left lying around can't expose entries.
final class JournalLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: String?

    func authenticate() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            isUnlocked = true
            lastError = nil
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode/biometrics enrolled at all — there's nothing to gate
            // behind, so don't lock the user out of their own records.
            isUnlocked = true
            return
        }
        let reason = "記録を表示するために本人確認をしてください"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, evalError in
            DispatchQueue.main.async {
                self?.isUnlocked = success
                self?.lastError = success ? nil : evalError?.localizedDescription
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
