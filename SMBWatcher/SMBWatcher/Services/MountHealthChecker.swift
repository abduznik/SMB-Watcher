import Foundation

/// Performs two-stage health checks on a watched SMB mount.
final class MountHealthChecker {
    private let portChecker: PortReachability
    private let fileManager: FileManager

    /// Creates a mount health checker.
    /// - Parameters:
    ///   - portChecker: TCP port reachability checker.
    ///   - fileManager: File manager for filesystem checks.
    init(portChecker: PortReachability = PortReachability(), fileManager: FileManager = .default) {
        self.portChecker = portChecker
        self.fileManager = fileManager
    }

    /// Performs a full two-stage health check on an instance.
    /// - Returns: The determined `InstanceStatus`.
    func check(instance: WatchedInstance) async -> InstanceStatus {
        // Stage 1: Port reachability
        let reachable = await portChecker.check(host: instance.host, port: instance.port)
        guard reachable else {
            return .unreachable
        }

        // Stage 2: Mount liveness
        return await checkMountLiveness(mountPoint: instance.mountPoint)
    }

    /// Checks if the mount point is actually mounted and responsive.
    private func checkMountLiveness(mountPoint: String) async -> InstanceStatus {
        // Check if mount point exists as a directory
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: mountPoint, isDirectory: &isDir), isDir.boolValue else {
            return .unreachable // Mount point missing — needs remount
        }

        // Attempt directory listing with timeout
        let responsive = await withTimeout(seconds: 5) {
            do {
                let contents = try self.fileManager.contentsOfDirectory(atPath: mountPoint)
                // If we get a result (even empty), the mount is responding
                _ = contents
                return true
            } catch {
                // CEF errors or hung mount
                return false
            }
        } ?? false

        return responsive ? .healthy : .unreachable
    }
}

// MARK: - Timeout Utility

/// Runs an async operation with a timeout.
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
