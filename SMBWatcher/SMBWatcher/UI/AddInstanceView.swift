import SwiftUI

/// SwiftUI form for adding or editing an SMB watched instance.
struct AddInstanceView: View {
    @Environment(\.dismiss) private var dismiss

    /// Whether we're editing an existing instance.
    private let editingInstance: WatchedInstance?

    /// Callback when the instance is saved.
    private let onSave: (WatchedInstance) -> Void

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var sharePath: String
    @State private var mountPoint: String
    @State private var username: String
    @State private var password: String
    @State private var pollInterval: Double
    @State private var isEnabled: Bool

    @State private var errorMessage: String?

    /// Creates an add/edit instance view.
    /// - Parameters:
    ///   - editing: The instance to edit, or `nil` for adding a new one.
    ///   - onSave: Callback invoked with the saved instance.
    init(editing: WatchedInstance? = nil, onSave: @escaping (WatchedInstance) -> Void) {
        self.editingInstance = editing
        self.onSave = onSave

        _name = State(initialValue: editing?.name ?? "")
        _host = State(initialValue: editing?.host ?? "")
        _port = State(initialValue: String(editing?.port ?? 445))
        _sharePath = State(initialValue: editing?.sharePath ?? "")
        _mountPoint = State(initialValue: editing?.mountPoint ?? "\(NSHomeDirectory())/mnt/")
        _username = State(initialValue: "")
        _password = State(initialValue: "")
        _pollInterval = State(initialValue: Double(editing?.pollIntervalSeconds ?? 30))
        _isEnabled = State(initialValue: editing?.isEnabled ?? true)

        // Load existing credentials if editing
        if let editing {
            let keychain = KeychainService()
            if let creds = keychain.load(for: editing.id) {
                _username = State(initialValue: creds.username)
                _password = State(initialValue: creds.password)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingInstance == nil ? "Add SMB Instance" : "Edit SMB Instance")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Host (IP or hostname)", text: $host)
                    .textFieldStyle(.roundedBorder)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Share Path", text: $sharePath)
                        .textFieldStyle(.roundedBorder)
                    Text("Path on the server, e.g. /volume1/media or /share")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Mount Point", text: $mountPoint)
                        .textFieldStyle(.roundedBorder)
                    Text("Where it appears on your Mac, e.g. \(NSHomeDirectory())/mnt/storage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Divider()

                HStack {
                    Text("Poll Interval")
                    Slider(value: $pollInterval, in: 10...300, step: 5)
                    Text("\(Int(pollInterval))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }

                Toggle("Enabled", isOn: $isEnabled)
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var isValid: Bool {
        !name.isEmpty && !host.isEmpty && !sharePath.isEmpty && !mountPoint.isEmpty
    }

    private func save() {
        guard let portValue = UInt16(port) else {
            errorMessage = "Invalid port number"
            return
        }

        let instance = WatchedInstance(
            id: editingInstance?.id ?? UUID(),
            name: name,
            host: host,
            port: portValue,
            sharePath: sharePath,
            mountPoint: mountPoint,
            isEnabled: isEnabled,
            pollIntervalSeconds: Int(pollInterval)
        )

        // Save credentials to keychain
        if !username.isEmpty && !password.isEmpty {
            let keychain = KeychainService()
            try? keychain.save(username: username, password: password, for: instance.id)
        }

        onSave(instance)
        dismiss()
    }
}

#Preview {
    AddInstanceView { _ in }
}
