import Foundation

/// A single person to notify when a check-in times out or an alert is sent
/// manually. Replaces the earlier single-contact design — CheckInManager now
/// holds an array of these.
struct EmergencyContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phoneNumber: String
}
