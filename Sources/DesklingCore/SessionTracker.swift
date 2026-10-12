import Foundation

public enum PetState: Int, Comparable {
    case idle, done, working, waiting

    public static func < (lhs: PetState, rhs: PetState) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct PetDisplay: Equatable {
    public let state: PetState
    public let projectName: String?
    public let message: String?

    public init(state: PetState, projectName: String?, message: String?) {
        self.state = state
        self.projectName = projectName
        self.message = message
    }
}

public struct SessionSummary: Equatable {
    public let projectName: String?
    public let state: PetState

    public init(projectName: String?, state: PetState) {
        self.projectName = projectName
        self.state = state
    }
}

public struct SessionTracker {
    public static let doneDuration: TimeInterval = 5
    public static let workingTimeout: TimeInterval = 600
    public static let sessionTimeout: TimeInterval = 1800

    private struct Session {
        var state: PetState = .idle
        var lastEvent: Date
        var projectName: String?
        var message: String?
    }

    private var sessions: [String: Session] = [:]

    public init() {}

    public var sessionCount: Int { sessions.count }

    public mutating func apply(_ event: HookEvent, at now: Date) {
        if event.kind == .sessionEnd {
            sessions[event.sessionID] = nil
            return
        }
        var session = sessions[event.sessionID] ?? Session(lastEvent: now)
        session.lastEvent = now
        if let name = event.projectName { session.projectName = name }
        switch event.kind {
        case .sessionStart:
            session.state = .idle
            session.message = nil
        case .userPromptSubmit, .preToolUse, .postToolUse:
            session.state = .working
            session.message = nil
        case .notification:
            if event.requestsAttention {
                session.state = .waiting
                session.message = event.message
            }
        case .stop:
            session.state = .done
            session.message = nil
        case .sessionEnd:
            break
        }
        sessions[event.sessionID] = session
    }

    public mutating func tick(at now: Date) {
        for (id, session) in sessions {
            let elapsed = now.timeIntervalSince(session.lastEvent)
            if elapsed >= Self.sessionTimeout {
                sessions[id] = nil
            } else if session.state == .done, elapsed >= Self.doneDuration {
                sessions[id]?.state = .idle
            } else if session.state == .working, elapsed >= Self.workingTimeout {
                sessions[id]?.state = .idle
            }
        }
    }

    public var display: PetDisplay {
        let top = sessions.values.max { ($0.state, $0.lastEvent) < ($1.state, $1.lastEvent) }
        guard let top else { return PetDisplay(state: .idle, projectName: nil, message: nil) }
        return PetDisplay(state: top.state, projectName: top.projectName, message: top.message)
    }

    /// The session that finished most recently and is still "done", whatever the other sessions are doing.
    public var justFinished: PetDisplay? {
        let finished = sessions.values.filter { $0.state == .done }.max { $0.lastEvent < $1.lastEvent }
        return finished.map { PetDisplay(state: .done, projectName: $0.projectName, message: nil) }
    }

    /// Every tracked session, most urgent state first and most recent first within a state.
    public var summaries: [SessionSummary] {
        sessions.values
            .sorted { ($0.state, $0.lastEvent) > ($1.state, $1.lastEvent) }
            .map { SessionSummary(projectName: $0.projectName, state: $0.state) }
    }
}
