import Foundation

public struct HookEvent: Equatable {
    public enum Kind: String, CaseIterable {
        case sessionStart = "SessionStart"
        case userPromptSubmit = "UserPromptSubmit"
        case preToolUse = "PreToolUse"
        case postToolUse = "PostToolUse"
        case notification = "Notification"
        case stop = "Stop"
        case sessionEnd = "SessionEnd"
    }

    public static let maxMessageLength = 300
    private static let forwardedKeys = ["hook_event_name", "session_id", "cwd", "message", "notification_type"]

    public let kind: Kind
    public let sessionID: String
    public let cwd: String?
    public let message: String?
    public let notificationType: String?

    public init(kind: Kind, sessionID: String, cwd: String? = nil, message: String? = nil, notificationType: String? = nil) {
        self.kind = kind
        self.sessionID = sessionID
        self.cwd = cwd
        self.message = message
        self.notificationType = notificationType
    }

    public var projectName: String? {
        guard let cwd else { return nil }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty || name == "/" ? nil : name
    }

    /// Claude Code sends this notification about a minute after it finishes. The pet already showed "done".
    public var isIdlePrompt: Bool {
        guard kind == .notification else { return false }
        if notificationType == "idle_prompt" { return true }
        return message?.localizedCaseInsensitiveContains("waiting for your input") ?? false
    }

    /// Only permission and input requests need the user. Other notifications (idle, auth success, unknown types) do not.
    public var requestsAttention: Bool {
        guard kind == .notification else { return false }
        switch notificationType {
        case "permission_prompt", "elicitation_dialog": return true
        case nil: return !isIdlePrompt
        default: return false
        }
    }

    public static func parse(line: Data) -> HookEvent? {
        guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let name = object["hook_event_name"] as? String,
              let kind = Kind(rawValue: name),
              let sessionID = object["session_id"] as? String, !sessionID.isEmpty
        else { return nil }
        return HookEvent(
            kind: kind,
            sessionID: sessionID,
            cwd: object["cwd"] as? String,
            message: object["message"] as? String,
            notificationType: object["notification_type"] as? String
        )
    }

    /// Reduces a hook payload to the fields the app reads, as one newline-terminated line.
    public static func compactLine(from input: Data, eventOverride: String?) -> Data? {
        guard var object = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] else { return nil }
        if let eventOverride { object["hook_event_name"] = eventOverride }
        var output: [String: Any] = [:]
        for key in forwardedKeys {
            if let value = object[key] as? String { output[key] = value }
        }
        if let message = output["message"] as? String, message.count > maxMessageLength {
            output["message"] = String(message.prefix(maxMessageLength))
        }
        guard output["hook_event_name"] != nil, output["session_id"] != nil,
              var line = try? JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        else { return nil }
        line.append(0x0A)
        return line
    }
}

public struct LineSplitter {
    public static let maxPending = 1_048_576
    private var buffer = Data()

    public init() {}

    public mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var lines: [Data] = []
        while let index = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<index)
            buffer.removeSubrange(buffer.startIndex...index)
            if !line.isEmpty { lines.append(line) }
        }
        if buffer.count > Self.maxPending { buffer.removeAll() }
        return lines
    }

    public mutating func finish() -> Data? {
        defer { buffer.removeAll() }
        return buffer.isEmpty ? nil : buffer
    }
}
