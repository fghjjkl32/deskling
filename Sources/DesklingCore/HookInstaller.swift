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

    /// Writing replaces the file, so follow a symlinked settings.json to the file it points at.
    private var writeURL: URL { settingsURL.resolvingSymlinksInPath() }

    public var isConnected: Bool {
        HookSettings.isInstalled(in: try? Data(contentsOf: settingsURL))
    }

    public func copyHelper() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        if manager.fileExists(atPath: installedHookURL.path) {
            try manager.removeItem(at: installedHookURL)
        }
        try manager.copyItem(at: bundledHookURL, to: installedHookURL)
    }

    public func connect() throws {
        let manager = FileManager.default
        let existing: Data? = manager.fileExists(atPath: settingsURL.path) ? try Data(contentsOf: settingsURL) : nil
        let merged = try HookSettings.install(into: existing, hookPath: installedHookURL.path)
        try copyHelper()
        if let existing, !HookSettings.isInstalled(in: existing) {
            try existing.write(to: backupURL, options: .atomic)
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
