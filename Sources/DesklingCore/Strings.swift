import Foundation

public enum Language: Equatable {
    case korean, english

    public static func current(preferred: [String] = Locale.preferredLanguages) -> Language {
        preferred.first?.hasPrefix("ko") == true ? .korean : .english
    }
}

public enum Text: CaseIterable {
    case statusConnected, statusNotConnected, connect, disconnect
    case skin, defaultSkin, openSkinsFolder
    case size, sizeSmall, sizeMedium, sizeLarge
    case showBubbles, hidePet, showPet, launchAtLogin, quit
    case waitingFallback, doneMessage
    case sessions, noSessions, unnamedProject, stateIdle, stateWorking, stateWaiting, stateDone
    case invalidSettingsTitle, invalidSettingsBody, copy, close
    case connectFailed, loginItemFailed, missingResources

    public func string(_ language: Language) -> String {
        let pair = Self.table[self]!
        return language == .korean ? pair.0 : pair.1
    }

    private static let table: [Text: (String, String)] = [
        .statusConnected: ("Claude Code: 연결됨", "Claude Code: Connected"),
        .statusNotConnected: ("Claude Code: 연결 안 됨", "Claude Code: Not connected"),
        .connect: ("Claude Code 연결하기", "Connect to Claude Code"),
        .disconnect: ("연결 해제하기", "Disconnect"),
        .skin: ("스킨", "Skin"),
        .defaultSkin: ("기본 펫", "Default pet"),
        .openSkinsFolder: ("스킨 폴더 열기", "Open Skins Folder"),
        .size: ("크기", "Size"),
        .sizeSmall: ("작게", "Small"),
        .sizeMedium: ("보통", "Medium"),
        .sizeLarge: ("크게", "Large"),
        .showBubbles: ("말풍선 보이기", "Show Speech Bubbles"),
        .hidePet: ("펫 숨기기", "Hide Pet"),
        .showPet: ("펫 보이기", "Show Pet"),
        .launchAtLogin: ("로그인할 때 실행하기", "Launch at Login"),
        .quit: ("종료하기", "Quit Deskling"),
        .waitingFallback: ("입력을 기다리고 있습니다.", "Waiting for your input."),
        .doneMessage: ("작업을 마쳤습니다.", "Finished working."),
        .sessions: ("세션", "Sessions"),
        .noSessions: ("세션 없음", "No sessions"),
        .unnamedProject: ("이름 없음", "Unnamed"),
        .stateIdle: ("쉬는 중", "Idle"),
        .stateWorking: ("작업 중", "Working"),
        .stateWaiting: ("입력 대기", "Waiting for input"),
        .stateDone: ("작업 완료", "Finished"),
        .invalidSettingsTitle: ("settings.json을 읽을 수 없습니다.", "Could not read settings.json."),
        .invalidSettingsBody: (
            "파일을 수정하지 않았습니다. 아래 설정을 settings.json에 직접 추가해야 합니다.",
            "The file was not changed. Add the settings below to settings.json yourself."
        ),
        .copy: ("복사하기", "Copy"),
        .close: ("닫기", "Close"),
        .connectFailed: ("Claude Code와 연결하지 못했습니다.", "Could not connect to Claude Code."),
        .loginItemFailed: ("로그인 항목을 바꾸지 못했습니다.", "Could not change the login item."),
        .missingResources: ("기본 펫 그림을 찾을 수 없습니다.", "The default pet images are missing."),
    ]
}

public enum PetPresentation {
    public static let maxMessageLength = 120
    public static let maxProjectLength = 40
    public static let maxTitleLength = 60

    public static func pose(for state: PetState, isWalking: Bool, isHeld: Bool = false, isFalling: Bool = false) -> PetPose {
        if isHeld { return .drag }
        if isFalling { return .fall }
        switch state {
        case .idle: return isWalking ? .walk : .idle
        case .working: return .working
        case .waiting: return .waiting
        case .done: return .done
        }
    }

    /// The bubble text: an optional project line, an optional title line, then the message, one per line.
    public static func bubble(for display: PetDisplay, language: Language) -> String? {
        let body: String
        switch display.state {
        case .idle, .working:
            return nil
        case .waiting:
            let message = collapseWhitespace(display.message ?? "")
            body = message.isEmpty ? Text.waitingFallback.string(language) : truncate(message)
        case .done:
            body = Text.doneMessage.string(language)
        }
        var lines: [String] = []
        if let project = display.projectName, !project.isEmpty {
            lines.append(truncate(project, limit: maxProjectLength))
        }
        if let title = title(display.title) { lines.append(title) }
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    /// A prompt shortened to one line, or `nil` when there is nothing to show.
    public static func title(_ prompt: String?) -> String? {
        let text = collapseWhitespace(prompt ?? "")
        return text.isEmpty ? nil : truncate(text, limit: maxTitleLength)
    }

    public static func sessionLine(for summary: SessionSummary, language: Language) -> String {
        let state: Text
        switch summary.state {
        case .idle: state = .stateIdle
        case .working: state = .stateWorking
        case .waiting: state = .stateWaiting
        case .done: state = .stateDone
        }
        let project = summary.projectName.flatMap { $0.isEmpty ? nil : $0 } ?? Text.unnamedProject.string(language)
        return "\(truncate(project, limit: maxProjectLength)) — \(state.string(language))"
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func truncate(_ message: String, limit: Int = maxMessageLength) -> String {
        message.count > limit ? String(message.prefix(limit)) + "…" : message
    }
}
