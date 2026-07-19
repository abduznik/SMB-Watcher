import Foundation

/// Handles loading and saving watched instances to disk.
final class ConfigStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let _fileURL: URL

    /// The current list of watched instances.
    private(set) var instances: [WatchedInstance] = [] {
        didSet { save() }
    }

    /// Path to the instances file.
    var instancesFileURL: URL { _fileURL }

    /// Creates a config store using the Application Support directory.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = appSupport.appendingPathComponent("SMBWatcher", isDirectory: true)
        _fileURL = directoryURL.appendingPathComponent("instances.json")
    }

    /// Loads instances from disk. If the file doesn't exist, starts with an empty list.
    func load() throws {
        guard fileManager.fileExists(atPath: _fileURL.path) else {
            instances = []
            return
        }
        let data = try Data(contentsOf: _fileURL)
        guard !data.isEmpty else {
            instances = []
            return
        }
        instances = try JSONDecoder().decode([WatchedInstance].self, from: data)
    }

    /// Saves the current instances to disk.
    func save() {
        do {
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(instances)
            try data.write(to: _fileURL, options: .atomic)
        } catch {
            print("[ConfigStore] Failed to save: \(error)")
        }
    }

    /// Adds a new instance.
    func add(_ instance: WatchedInstance) {
        instances.append(instance)
    }

    /// Updates an existing instance by id.
    func update(_ instance: WatchedInstance) {
        guard let index = instances.firstIndex(where: { $0.id == instance.id }) else { return }
        instances[index] = instance
    }

    /// Removes an instance by id.
    func remove(id: UUID) {
        instances.removeAll { $0.id == id }
    }

    /// Returns a specific instance by id.
    func instance(withID id: UUID) -> WatchedInstance? {
        instances.first { $0.id == id }
    }
}
