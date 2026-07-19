import AppKit
import SwiftUI
import os.log

private let log = OSLog(subsystem: "com.smbwatcher.SMBWatcher", category: "statusbar")

/// Manages the menu bar status item and its menu.
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private let configStore: ConfigStore
    private let watcherEngine: WatcherEngine
    private var addWindow: NSWindow?

    /// Creates a status bar controller.
    init(configStore: ConfigStore, watcherEngine: WatcherEngine) {
        self.configStore = configStore
        self.watcherEngine = watcherEngine
        setupStatusItem()
    }

    /// Sets up the status bar item with default icon.
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            if let baseImage = NSImage(systemSymbolName: "folder", accessibilityDescription: "SMBWatcher") {
                button.image = baseImage.withSymbolConfiguration(config)
            }
            button.image?.isTemplate = true
        }

        rebuildMenu()
        installEditMenuOnApp()
        os_log("Status bar item created", log: log, type: .info)
    }

    /// Rebuilds the entire menu.
    func rebuildMenu() {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "SMBWatcher", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // Instance list
        for instance in configStore.instances {
            let status = watcherEngine.statuses[instance.id] ?? .unknown

            let item = NSMenuItem()
            item.title = "\(instance.name)"
            item.submenu = buildInstanceSubmenu(instance: instance, status: status)
            menu.addItem(item)
        }

        if configStore.instances.isEmpty {
            let emptyItem = NSMenuItem(title: "No instances configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        menu.addItem(.separator())

        // Add Instance
        let addItem = NSMenuItem(title: "Add Instance…", action: #selector(showAddInstance), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Builds a submenu for an individual instance.
    private func buildInstanceSubmenu(instance: WatchedInstance, status: InstanceStatus) -> NSMenu {
        let submenu = NSMenu()

        // Status display
        let statusItem = NSMenuItem(title: status.description, action: nil, keyEquivalent: "")
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        if let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: status.description) {
            statusItem.image = image.withSymbolConfiguration(config)
        }
        statusItem.isEnabled = false
        submenu.addItem(statusItem)

        submenu.addItem(.separator())

        // Toggle enabled
        let toggleItem = NSMenuItem(
            title: instance.isEnabled ? "Disable" : "Enable",
            action: #selector(toggleInstance(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.representedObject = instance.id
        submenu.addItem(toggleItem)

        // Remount Now
        let remountItem = NSMenuItem(title: "Remount Now", action: #selector(remountNow(_:)), keyEquivalent: "")
        remountItem.target = self
        remountItem.representedObject = instance
        submenu.addItem(remountItem)

        submenu.addItem(.separator())

        // Edit
        let editItem = NSMenuItem(title: "Edit…", action: #selector(editInstance(_:)), keyEquivalent: "")
        editItem.target = self
        editItem.representedObject = instance
        submenu.addItem(editItem)

        // Delete
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteInstance(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = instance.id
        submenu.addItem(deleteItem)

        return submenu
    }

    /// Updates the menu bar icon based on aggregate status.
    func updateIcon() {
        let statuses = watcherEngine.statuses.values

        let iconName: String
        if statuses.contains(.mountFailed) {
            iconName = "exclamationmark.triangle"
        } else if statuses.contains(.unreachable) || statuses.contains(.remounting) {
            iconName = "arrow.clockwise"
        } else {
            iconName = "folder"
        }

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SMBWatcher")?
                .withSymbolConfiguration(config)
            button.image?.isTemplate = true
        }
    }

    // MARK: - Actions

    @objc private func showAddInstance() {
        let addView = AddInstanceView { [weak self] instance in
            self?.configStore.add(instance)
            self?.watcherEngine.startWatching(instance)
            self?.rebuildMenu()
        }

        let hostingView = NSHostingController(rootView: addView)
        let window = NSWindow(contentViewController: hostingView)
        window.title = "Add SMB Instance"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        addWindow = window
    }

    @objc private func toggleInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              var instance = configStore.instance(withID: id) else { return }
        instance.isEnabled.toggle()
        configStore.update(instance)

        if instance.isEnabled {
            watcherEngine.startWatching(instance)
        } else {
            watcherEngine.stopWatching(instance)
        }
        rebuildMenu()
    }

    @objc private func remountNow(_ sender: NSMenuItem) {
        guard let instance = sender.representedObject as? WatchedInstance else { return }
        Task {
            await watcherEngine.remountNow(instance)
            rebuildMenu()
            updateIcon()
        }
    }

    @objc private func editInstance(_ sender: NSMenuItem) {
        guard let instance = sender.representedObject as? WatchedInstance else { return }

        let editView = AddInstanceView(editing: instance) { [weak self] updated in
            self?.configStore.update(updated)
            self?.watcherEngine.stopWatching(instance)
            if updated.isEnabled {
                self?.watcherEngine.startWatching(updated)
            }
            self?.rebuildMenu()
        }

        let hostingView = NSHostingController(rootView: editView)
        let window = NSWindow(contentViewController: hostingView)
        window.title = "Edit \(instance.name)"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        addWindow = window
    }

    @objc private func deleteInstance(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Instance"
        alert.informativeText = "Are you sure you want to delete this watched instance? Credentials will also be removed from Keychain."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        watcherEngine.stopWatching(WatchedInstance(id: id))
        try? keychain.delete(for: id)
        configStore.remove(id: id)
        rebuildMenu()
        updateIcon()
    }

    @objc private func quit() {
        watcherEngine.stop()
        NSApp.terminate(nil)
    }

    /// Installs a global Edit menu on NSApp so Cmd+C/V/X/A work in all text fields.
    private func installEditMenuOnApp() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private let keychain = KeychainService()
}
