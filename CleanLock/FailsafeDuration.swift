import Foundation

/// How long cleaning mode may run before auto-unlocking.
enum FailsafeDuration: Int, CaseIterable, Identifiable, Codable {
    case oneMinute = 60
    case threeMinutes = 180
    case fiveMinutes = 300
    case tenMinutes = 600

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .threeMinutes: return "3 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        }
    }

    /// Short form for overlay copy ("1 minute", "3 minutes", …).
    var overlayLabel: String { label }

    static let `default`: FailsafeDuration = .threeMinutes
}
