import Foundation

public enum AppPaths {
    /// sockaddr_un.sun_path holds 104 bytes including the terminating zero.
    public static let maxSocketPathBytes = 103

    public static func supportDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Deskling", isDirectory: true)
    }

    public static func skinsDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        supportDirectory(home: home).appendingPathComponent("skins", isDirectory: true)
    }

    public static func claudeSettings(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let custom = environment["CLAUDE_CONFIG_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true).appendingPathComponent("settings.json")
        }
        return home.appendingPathComponent(".claude/settings.json")
    }

    public static func socketPath(home: URL = FileManager.default.homeDirectoryForCurrentUser, uid: uid_t = getuid()) -> String {
        let preferred = supportDirectory(home: home).appendingPathComponent("deskling.sock").path
        return preferred.utf8.count <= maxSocketPathBytes ? preferred : "/tmp/deskling-\(uid).sock"
    }
}
