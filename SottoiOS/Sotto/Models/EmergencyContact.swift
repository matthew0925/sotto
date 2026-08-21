import Foundation

/// A single person to notify when a check-in times out or an alert is sent
/// manually. Replaces the earlier single-contact design — CheckInManager now
/// holds an array of these.
struct EmergencyContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phoneNumber: String

    /// Normalized for MessageUI and `tel:` URLs. Pasted phone numbers often
    /// contain spaces, hyphens, or parentheses; preserve only their digits and
    /// a single leading `+`. Invalid text must not become a broken emergency
    /// action or a Shortcuts recipient.
    var dialablePhoneNumber: String? {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLeadingPlus = trimmed.first == "+"
        let digits = trimmed.compactMap(\.wholeNumberValue).map(String.init).joined()
        guard (3...15).contains(digits.count) else { return nil }
        return hasLeadingPlus ? "+\(digits)" : digits
    }
}
