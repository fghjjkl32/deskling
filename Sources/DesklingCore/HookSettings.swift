import Foundation

public enum HookSettings {
    public enum SettingsError: Error, Equatable {
        case invalidJSON
    }

    public static let marker = "deskling-hook"
    private typealias Group = [String: Any]

    public static func command(hookPath: String, event: HookEvent.Kind) -> String {
        "\"\(hookPath)\" \(event.rawValue)"
    }

    public static func install(into data: Data?, hookPath: String) throws -> Data {
        var root = try decode(data)
        var section = try hooksSection(of: root)
        for kind in HookEvent.Kind.allCases {
            var groups = strip(section[kind.rawValue] ?? [])
            let entry: [String: Any] = ["type": "command", "command": command(hookPath: hookPath, event: kind), "timeout": 5]
            groups.append(["hooks": [entry]])
            section[kind.rawValue] = groups
        }
        root["hooks"] = section
        return try encode(root)
    }

    public static func uninstall(from data: Data) throws -> Data {
        var root = try decode(data)
        var section = try hooksSection(of: root)
        for (event, groups) in section {
            let remaining = strip(groups)
            section[event] = remaining.isEmpty ? nil : remaining
        }
        root["hooks"] = section.isEmpty ? nil : section
        return try encode(root)
    }

    public static func isInstalled(in data: Data?) -> Bool {
        guard let root = try? decode(data), let section = try? hooksSection(of: root) else { return false }
        return section.values.contains { groups in groups.contains { group in hooks(of: group).contains(where: isOurs) } }
    }

    public static func manualSnippet(hookPath: String) -> String {
        guard let data = try? install(into: nil, hookPath: hookPath) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode(_ data: Data?) throws -> [String: Any] {
        guard let data else { return [:] }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return [:] }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw SettingsError.invalidJSON
        }
        return root
    }

    private static func encode(_ root: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(0x0A)
        return data
    }

    private static func hooksSection(of root: [String: Any]) throws -> [String: [Group]] {
        guard let raw = root["hooks"] else { return [:] }
        guard let section = raw as? [String: Any] else { throw SettingsError.invalidJSON }
        var result: [String: [Group]] = [:]
        for (event, value) in section {
            guard let groups = value as? [Group] else { throw SettingsError.invalidJSON }
            result[event] = groups
        }
        return result
    }

    private static func hooks(of group: Group) -> [[String: Any]] {
        group["hooks"] as? [[String: Any]] ?? []
    }

    private static func isOurs(_ hook: [String: Any]) -> Bool {
        (hook["command"] as? String)?.contains(marker) ?? false
    }

    /// Removes our hook entries, dropping groups that held nothing else.
    private static func strip(_ groups: [Group]) -> [Group] {
        groups.compactMap { group in
            let all = hooks(of: group)
            let kept = all.filter { !isOurs($0) }
            if kept.count == all.count { return group }
            if kept.isEmpty { return nil }
            var copy = group
            copy["hooks"] = kept
            return copy
        }
    }
}
