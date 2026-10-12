import Foundation

public struct HookInstaller {
    public let settingsURL: URL
    public let supportDirectory: URL
    public let bundledHookURL: URL

    public init(settingsURL: URL, supportDirectory: URL, bundledHookURL: URL) {
        self.settingsURL = settingsURL
        self.supportDirectory = supportDirectory
        self.bundledHookURL = bundledHookURL
    }

    public var installedHookURL: URL { supportDirectory.appendingPathComponent("deskling-hook") }

    public var backupURL: URL {
        settingsURL.deletingLastPathComponent().appendingPathComponent("settings.json.deskling-backup")
    }

    /// Writing replaces the file, so follow a symlinked settings.json (even a dangling one) to the file it points at.
    private var writeURL: URL {
        let manager = FileManager.default
        var url = settingsURL
        for _ in 0..<16 {
            guard let destination = try? manager.destinationOfSymbolicLink(atPath: url.path) else { break }
            url = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : url.deletingLastPathComponent().appendingPathComponent(destination).standardized
        }
        return url
    }

    public var isConnected: Bool {
        HookSettings.isInstalled(in: try? Data(contentsOf: settingsURL))
    }

    /// Installs the helper through a temporary copy so a failure keeps the previous helper, and drops the
    /// quarantine flag so Gatekeeper does not block hooks started from a downloaded app.
    public func copyHelper() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let temporary = supportDirectory.appendingPathComponent(".deskling-hook.\(UUID().uuidString).tmp")
        defer { try? manager.removeItem(at: temporary) }
        try manager.copyItem(at: bundledHookURL, to: temporary)
        if removexattr(temporary.path, "com.apple.quarantine", 0) != 0, errno != ENOATTR {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: temporary.path])
        }
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        if manager.fileExists(atPath: installedHookURL.path) {
            _ = try manager.replaceItemAt(installedHookURL, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: installedHookURL)
        }
    }

    /// The backup holds the same secrets as the original, so it never gets broader permissions.
    private func writeBackup(_ data: Data) throws {
        let manager = FileManager.default
        let original = try? manager.attributesOfItem(atPath: writeURL.path)[.posixPermissions] as? Int
        let mode = (original ?? 0o600) & 0o777
        guard manager.createFile(atPath: backupURL.path, contents: data, attributes: [.posixPermissions: mode]) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: backupURL.path])
        }
        try manager.setAttributes([.posixPermissions: mode], ofItemAtPath: backupURL.path)
    }

    public func connect() throws {
        let manager = FileManager.default
        let existing: Data? = manager.fileExists(atPath: settingsURL.path) ? try Data(contentsOf: settingsURL) : nil
        let merged = try HookSettings.install(into: existing, hookPath: installedHookURL.path)
        try copyHelper()
        if let existing, !HookSettings.isInstalled(in: existing) {
            try writeBackup(existing)
        }
        try manager.createDirectory(at: writeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try merged.write(to: writeURL, options: .atomic)
    }

    public func disconnect() throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        let existing = try Data(contentsOf: settingsURL)
        let stripped = try HookSettings.uninstall(from: existing)
        guard HookSettings.isInstalled(in: existing) else { return }
        try stripped.write(to: writeURL, options: .atomic)
    }
}
