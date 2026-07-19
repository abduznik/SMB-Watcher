import Foundation
import os.log

private let log = OSLog(subsystem: "com.smbwatcher.SMBWatcher", category: "mount")

/// Performs mount and unmount operations for SMB shares.
final class MountManager {
    private let keychain: KeychainService
    private let fileManager: FileManager

    /// Creates a mount manager.
    /// - Parameters:
    ///   - keychain: Keychain service for retrieving credentials.
    ///   - fileManager: File manager for filesystem checks.
    init(keychain: KeychainService = KeychainService(), fileManager: FileManager = .default) {
        self.keychain = keychain
        self.fileManager = fileManager
    }

    /// Mounts the given SMB instance.
    /// - Returns: `true` if the mount succeeded.
    @discardableResult
    func mount(instance: WatchedInstance) async -> Bool {
        // Retrieve credentials from keychain
        guard let credentials = keychain.load(for: instance.id) else {
            os_log("No credentials found for %{public}@", log: log, type: .error, instance.name)
            return false
        }

        // First, clean up any stale mount at the target
        await cleanupStaleMount(mountPoint: instance.mountPoint)

        // Ensure mount point directory exists
        if !fileManager.fileExists(atPath: instance.mountPoint) {
            do {
                try fileManager.createDirectory(atPath: instance.mountPoint, withIntermediateDirectories: true)
            } catch {
                os_log("Failed to create mount point %{public}@: %{public}@", log: log, type: .error, instance.mountPoint, error.localizedDescription)
                return false
            }
        }

        // Build mount command — mount_smbfs expects //user:pass@host/share (NOT smb://)
        let smbURL = "//\(credentials.username):\(credentials.password)@\(instance.host)\(instance.sharePath)"
        let command = "/sbin/mount_smbfs"
        let args = [smbURL, instance.mountPoint]

        os_log("Mounting %{public}@ -> %{public}@", log: log, type: .info, instance.name, instance.mountPoint)

        // Execute mount with timeout, capturing stderr
        let result = await executeWithOutput(command: command, arguments: args, timeout: 15)
        if result.status == 0 {
            os_log("Successfully mounted %{public}@", log: log, type: .info, instance.name)
        } else {
            os_log("Failed to mount %{public}@ (exit %d): %{public}@", log: log, type: .error, instance.name, result.status, result.stderr)
        }
        return result.status == 0
    }

    /// Unmounts the given mount point.
    func unmount(mountPoint: String) async -> Bool {
        let result = await executeWithOutput(command: "/sbin/umount", arguments: [mountPoint], timeout: 10)
        if result.status != 0 {
            // Try force unmount
            let forceResult = await executeWithOutput(command: "/sbin/diskutil", arguments: ["unmount", "force", mountPoint], timeout: 10)
            return forceResult.status == 0
        }
        return true
    }

    /// Cleans up stale or zombie mounts at the given mount point.
    private func cleanupStaleMount(mountPoint: String) async {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: mountPoint, isDirectory: &isDir), isDir.boolValue else {
            return
        }

        // Test if existing mount is responsive
        let isResponsive = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try self.fileManager.contentsOfDirectory(atPath: mountPoint)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }

        if !isResponsive {
            os_log("Stale mount detected at %{public}@, unmounting...", log: log, type: .info, mountPoint)
            _ = await unmount(mountPoint: mountPoint)
        }
    }

    /// Result of a command execution with captured output.
    private struct CommandResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    /// Executes a shell command, capturing stdout and stderr.
    private func executeWithOutput(command: String, arguments: [String], timeout: TimeInterval) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var hasResumed = false
            let lock = NSLock()

            process.terminationHandler = { _ in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""

                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: CommandResult(status: process.terminationStatus, stdout: outStr, stderr: errStr))
            }

            do {
                try process.run()
            } catch {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: CommandResult(status: -1, stdout: "", stderr: error.localizedDescription))
                return
            }

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                if process.isRunning {
                    process.terminate()
                }
                continuation.resume(returning: CommandResult(status: -1, stdout: "", stderr: "Timed out after \(Int(timeout))s"))
            }
        }
    }
}
