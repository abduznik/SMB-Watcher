import Foundation
import UserNotifications

/// Orchestrates background monitoring and remounting for all enabled instances.
final class WatcherEngine {
    private let configStore: ConfigStore
    private let healthChecker: MountHealthChecker
    private let mountManager: MountManager
    private let keychain: KeychainService

    /// Current status of each instance, keyed by instance id.
    private(set) var statuses: [UUID: InstanceStatus] = [:]

    /// Retry counts per instance for backoff calculation.
    private var retryCounts: [UUID: Int] = [:]

    /// Active timers per instance.
    private var timers: [UUID: DispatchSourceTimer] = [:]

    /// Whether the engine is running.
    private(set) var isRunning = false

    /// Callback invoked when any instance status changes.
    var onStatusChange: ((UUID, InstanceStatus) -> Void)?

    /// Maximum retries before marking as failed.
    private let maxRetries = 5

    /// Maximum backoff interval (10 minutes).
    private let maxBackoff: TimeInterval = 600

    init(
        configStore: ConfigStore,
        healthChecker: MountHealthChecker = MountHealthChecker(),
        mountManager: MountManager = MountManager(),
        keychain: KeychainService = KeychainService()
    ) {
        self.configStore = configStore
        self.healthChecker = healthChecker
        self.mountManager = mountManager
        self.keychain = keychain
    }

    /// Starts monitoring all enabled instances.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        for instance in configStore.instances where instance.isEnabled {
            startWatching(instance)
        }
    }

    /// Stops all monitoring.
    func stop() {
        isRunning = false
        for (_, timer) in timers {
            timer.cancel()
        }
        timers.removeAll()
    }

    /// Starts watching a specific instance.
    func startWatching(_ instance: WatchedInstance) {
        // Cancel any existing timer
        timers[instance.id]?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        let interval = backoffInterval(for: instance.id)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.performHealthCheck(instance)
            }
        }
        timer.resume()
        timers[instance.id] = timer
    }

    /// Stops watching a specific instance.
    func stopWatching(_ instance: WatchedInstance) {
        timers[instance.id]?.cancel()
        timers.removeValue(forKey: instance.id)
    }

    /// Manually triggers a remount for an instance, ignoring backoff.
    func remountNow(_ instance: WatchedInstance) async {
        updateStatus(for: instance.id, status: .remounting)
        let success = await mountManager.mount(instance: instance)
        let newStatus: InstanceStatus = success ? .healthy : .mountFailed
        updateStatus(for: instance.id, status: newStatus)

        if success {
            retryCounts[instance.id] = 0
            // Restart with normal interval
            startWatching(instance)
        }
    }

    /// Performs a full health check and acts on the result.
    private func performHealthCheck(_ instance: WatchedInstance) async {
        let status = await healthChecker.check(instance: instance)

        switch status {
        case .healthy:
            retryCounts[instance.id] = 0
            updateStatus(for: instance.id, status: .healthy)
            // Reset timer to normal interval
            startWatching(instance)

        case .unreachable:
            let retries = retryCounts[instance.id, default: 0]
            if retries >= maxRetries {
                updateStatus(for: instance.id, status: .mountFailed)
                sendNotification(for: instance, message: "Mount failed after \(maxRetries) attempts")
            } else {
                retryCounts[instance.id] = retries + 1
                updateStatus(for: instance.id, status: .remounting)
                let success = await mountManager.mount(instance: instance)
                if success {
                    retryCounts[instance.id] = 0
                    updateStatus(for: instance.id, status: .healthy)
                    startWatching(instance)
                } else {
                    updateStatus(for: instance.id, status: .unreachable)
                    // Reschedule with backoff
                    startWatching(instance)
                }
            }

        default:
            updateStatus(for: instance.id, status: status)
        }
    }

    /// Calculates the current backoff interval for an instance.
    private func backoffInterval(for instanceID: UUID) -> TimeInterval {
        guard let instance = configStore.instance(withID: instanceID) else {
            return 30 // Default fallback
        }
        let retries = retryCounts[instanceID, default: 0]
        let base = TimeInterval(instance.pollIntervalSeconds)
        let exponential = base * pow(2.0, Double(retries))
        return min(exponential, maxBackoff)
    }

    /// Updates the status and notifies observers.
    private func updateStatus(for instanceID: UUID, status: InstanceStatus) {
        statuses[instanceID] = status
        onStatusChange?(instanceID, status)
    }

    /// Sends a macOS user notification.
    private func sendNotification(for instance: WatchedInstance, message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "SMBWatcher"
            content.body = "\(instance.name): \(message)"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: instance.id.uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    /// Calculates the backoff interval for a given retry count (exposed for testing).
    static func calculateBackoff(
        baseInterval: Int,
        retryCount: Int,
        maxInterval: TimeInterval = 600
    ) -> TimeInterval {
        let base = TimeInterval(baseInterval)
        let exponential = base * pow(2.0, Double(retryCount))
        return min(exponential, maxInterval)
    }
}
