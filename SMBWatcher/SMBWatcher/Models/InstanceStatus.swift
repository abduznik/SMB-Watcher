import Foundation

/// Represents the current health state of a watched SMB mount.
enum InstanceStatus: String, Codable, CaseIterable {
    /// The mount is present and responsive.
    case healthy

    /// The SMB server port is unreachable.
    case unreachable

    /// A remount attempt is in progress.
    case remounting

    /// Remount attempts have been exhausted.
    case mountFailed

    /// Status has not yet been determined.
    case unknown

    /// SF Symbol name for display in the menu bar and menus.
    var symbolName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .unreachable: return "wifi.slash"
        case .remounting: return "arrow.triangle.2.circlepath"
        case .mountFailed: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// User-facing status description.
    var description: String {
        switch self {
        case .healthy: return "Healthy"
        case .unreachable: return "Unreachable"
        case .remounting: return "Remounting…"
        case .mountFailed: return "Mount Failed"
        case .unknown: return "Unknown"
        }
    }
}
