import Foundation

enum Resources {
    /// `DESKLING_RESOURCES` points at the repository's Resources folder when running with `swift run`.
    static var root: URL {
        if let override = ProcessInfo.processInfo.environment["DESKLING_RESOURCES"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return Bundle.main.resourceURL ?? Bundle.main.bundleURL
    }

    static var defaultSkinDirectory: URL {
        root.appendingPathComponent("skins/default", isDirectory: true)
    }

    static var bundledHookURL: URL {
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        return executable.deletingLastPathComponent().appendingPathComponent("deskling-hook")
    }
}
