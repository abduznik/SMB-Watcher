import Foundation

/// Represents a single SMB share to monitor and auto-remount.
struct WatchedInstance: Codable, Identifiable, Hashable {
    /// Unique identifier for this watched instance.
    let id: UUID

    /// User-facing label, e.g. "Homelab NAS".
    var name: String

    /// Hostname or IP address of the SMB server.
    var host: String

    /// SMB port (default 445).
    var port: UInt16

    /// Share path on the server, e.g. /volume1/media.
    var sharePath: String

    /// Local mount point, e.g. /Volumes/media.
    var mountPoint: String

    /// Whether this instance is actively being watched.
    var isEnabled: Bool

    /// How often (in seconds) to check health. Default 30.
    var pollIntervalSeconds: Int

    /// Creates a new watched instance with sensible defaults.
    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: UInt16 = 445,
        sharePath: String = "",
        mountPoint: String = "",
        isEnabled: Bool = true,
        pollIntervalSeconds: Int = 30
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.sharePath = sharePath
        self.mountPoint = mountPoint
        self.isEnabled = isEnabled
        self.pollIntervalSeconds = pollIntervalSeconds
    }
}
