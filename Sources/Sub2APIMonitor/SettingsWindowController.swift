import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let serverField = NSTextField()
    private let keyField = NSSecureTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private var onSave: ((String, String?) throws -> Void)?

    init(server: String?, hasStoredKey: Bool, onSave: @escaping (String, String?) throws -> Void) {
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent(server: server, hasStoredKey: hasStoredKey)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func buildContent(server: String?, hasStoredKey: Bool) {
        guard let contentView = window?.contentView else { return }

        serverField.stringValue = server ?? ""
        serverField.placeholderString = "https://sub2api.example.com"
        serverField.delegate = self
        keyField.placeholderString = hasStoredKey ? "Stored securely in Keychain" : "admin-..."
        keyField.delegate = self

        let serverLabel = formLabel("Server URL")
        let keyLabel = formLabel("Admin API Key")

        statusLabel.textColor = .systemRed
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY

        let separator = NSBox()
        separator.boxType = .separator

        [serverLabel, serverField, keyLabel, keyField, statusLabel, separator, buttons]
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }

        NSLayoutConstraint.activate([
            serverLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            serverLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            serverLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),

            serverField.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor),
            serverField.trailingAnchor.constraint(equalTo: serverLabel.trailingAnchor),
            serverField.topAnchor.constraint(equalTo: serverLabel.bottomAnchor, constant: 6),

            keyLabel.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor),
            keyLabel.trailingAnchor.constraint(equalTo: serverLabel.trailingAnchor),
            keyLabel.topAnchor.constraint(equalTo: serverField.bottomAnchor, constant: 16),

            keyField.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor),
            keyField.trailingAnchor.constraint(equalTo: serverLabel.trailingAnchor),
            keyField.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 6),

            statusLabel.leadingAnchor.constraint(equalTo: serverField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: serverField.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: keyField.bottomAnchor, constant: 8),

            separator.leadingAnchor.constraint(equalTo: serverLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: serverLabel.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -58),

            buttons.trailingAnchor.constraint(equalTo: serverLabel.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 82),
            saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 82),
        ])
        window?.center()
    }

    private func formLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.lineBreakMode = .byClipping
        return label
    }

    func controlTextDidChange(_ notification: Notification) {
        statusLabel.stringValue = ""
    }

    @objc private func save() {
        do {
            let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            try onSave?(serverField.stringValue, key.isEmpty ? nil : key)
            close()
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func cancel() {
        close()
    }
}
