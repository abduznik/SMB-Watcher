import Foundation
import Network

/// Checks whether an SMB server is reachable via raw TCP connection on its port.
class PortReachability {
    private let timeout: TimeInterval

    /// Creates a port reachability checker.
    /// - Parameter timeout: Connection timeout in seconds. Default 3.
    init(timeout: TimeInterval = 3) {
        self.timeout = timeout
    }

    /// Tests TCP connectivity to the given host and port.
    /// - Returns: `true` if the connection succeeds within the timeout.
    func check(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            var hasResumed = false
            let queue = DispatchQueue(label: "com.smbwatcher.reachability")

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: true)
                    }
                case .failed:
                    connection.cancel()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                case .cancelled:
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Enforce timeout
            queue.asyncAfter(deadline: .now() + timeout) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
