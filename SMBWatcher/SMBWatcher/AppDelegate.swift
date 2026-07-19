import Cocoa
import UserNotifications
import os.log

private let log = OSLog(subsystem: "com.smbwatcher.SMBWatcher", category: "app")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let configStore = ConfigStore()
    private var watcherEngine: WatcherEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("SMBWatcher launched", log: log, type: .info)

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Load saved instances
        try? configStore.load()

        // Create watcher engine with loaded config store
        watcherEngine = WatcherEngine(configStore: configStore)
        setupWatcherEngine(watcherEngine)

        // Set up status bar
        statusBarController = StatusBarController(configStore: configStore, watcherEngine: watcherEngine)

        // Start monitoring
        watcherEngine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcherEngine.stop()
    }

    private func setupWatcherEngine(_ engine: WatcherEngine) {
        engine.onStatusChange = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.statusBarController?.updateIcon()
                self?.statusBarController?.rebuildMenu()
            }
        }
    }
}
