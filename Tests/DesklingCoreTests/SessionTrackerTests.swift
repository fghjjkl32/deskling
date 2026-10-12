import XCTest
@testable import DesklingCore

final class SessionTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ kind: HookEvent.Kind, _ session: String = "s1", cwd: String? = "/work/app", message: String? = nil, type: String? = nil) -> HookEvent {
        HookEvent(kind: kind, sessionID: session, cwd: cwd, message: message, notificationType: type)
    }

    func testEmptyTrackerIsIdle() {
        XCTAssertEqual(SessionTracker().display, PetDisplay(state: .idle, projectName: nil, message: nil))
    }

    func testEventSequenceDrivesState() {
        var tracker = SessionTracker()
        tracker.apply(event(.sessionStart), at: start)
        XCTAssertEqual(tracker.display.state, .idle)
        tracker.apply(event(.userPromptSubmit), at: start)
        XCTAssertEqual(tracker.display.state, .working)
        tracker.apply(event(.notification, message: "Need permission"), at: start)
        XCTAssertEqual(tracker.display, PetDisplay(state: .waiting, projectName: "app", message: "Need permission"))
        tracker.apply(event(.preToolUse), at: start)
        XCTAssertEqual(tracker.display, PetDisplay(state: .working, projectName: "app", message: nil))
        tracker.apply(event(.stop), at: start)
        XCTAssertEqual(tracker.display.state, .done)
    }

    func testDoneBecomesIdleAfterFiveSeconds() {
        var tracker = SessionTracker()
        tracker.apply(event(.stop), at: start)
        tracker.tick(at: start.addingTimeInterval(4.9))
        XCTAssertEqual(tracker.display.state, .done)
        tracker.tick(at: start.addingTimeInterval(5))
        XCTAssertEqual(tracker.display.state, .idle)
    }

    func testWorkingTimesOutAfterTenMinutes() {
        var tracker = SessionTracker()
        tracker.apply(event(.preToolUse), at: start)
        tracker.tick(at: start.addingTimeInterval(599))
        XCTAssertEqual(tracker.display.state, .working)
        tracker.tick(at: start.addingTimeInterval(600))
        XCTAssertEqual(tracker.display.state, .idle)
    }

    func testStaleSessionIsRemovedAfterThirtyMinutes() {
        var tracker = SessionTracker()
        tracker.apply(event(.notification, message: "m"), at: start)
        tracker.tick(at: start.addingTimeInterval(1799))
        XCTAssertEqual(tracker.display.state, .waiting)
        tracker.tick(at: start.addingTimeInterval(1800))
        XCTAssertEqual(tracker.sessionCount, 0)
        XCTAssertEqual(tracker.display.state, .idle)
    }

    func testSessionEndRemovesSession() {
        var tracker = SessionTracker()
        tracker.apply(event(.preToolUse), at: start)
        tracker.apply(event(.sessionEnd), at: start)
        XCTAssertEqual(tracker.sessionCount, 0)
    }

    func testHighestPriorityStateWins() {
        var tracker = SessionTracker()
        tracker.apply(event(.stop, "a", cwd: "/w/a"), at: start)
        tracker.apply(event(.preToolUse, "b", cwd: "/w/b"), at: start)
        XCTAssertEqual(tracker.display.projectName, "b")
        tracker.apply(event(.notification, "c", cwd: "/w/c", message: "m"), at: start)
        XCTAssertEqual(tracker.display, PetDisplay(state: .waiting, projectName: "c", message: "m"))
    }

    func testMostRecentSessionWinsWithinSameState() {
        var tracker = SessionTracker()
        tracker.apply(event(.preToolUse, "a", cwd: "/w/a"), at: start)
        tracker.apply(event(.preToolUse, "b", cwd: "/w/b"), at: start.addingTimeInterval(1))
        XCTAssertEqual(tracker.display.projectName, "b")
    }

    func testIdlePromptDoesNotChangeState() {
        var tracker = SessionTracker()
        tracker.apply(event(.stop), at: start)
        tracker.tick(at: start.addingTimeInterval(10))
        tracker.apply(event(.notification, message: "Claude is waiting for your input", type: "idle_prompt"), at: start.addingTimeInterval(60))
        XCTAssertEqual(tracker.display.state, .idle)
    }

    func testProjectNameIsKeptWhenLaterEventHasNoCwd() {
        var tracker = SessionTracker()
        tracker.apply(event(.userPromptSubmit), at: start)
        tracker.apply(event(.stop, cwd: nil), at: start)
        XCTAssertEqual(tracker.display.projectName, "app")
    }

    func testPostToolUseReturnsWaitingSessionToWorking() {
        var tracker = SessionTracker()
        tracker.apply(event(.notification, message: "Need permission", type: "permission_prompt"), at: start)
        XCTAssertEqual(tracker.display.state, .waiting)
        tracker.apply(event(.postToolUse), at: start)
        XCTAssertEqual(tracker.display, PetDisplay(state: .working, projectName: "app", message: nil))
    }

    func testOtherNotificationTypesLeaveStateUnchanged() {
        var tracker = SessionTracker()
        tracker.apply(event(.userPromptSubmit), at: start)
        tracker.apply(event(.notification, message: "signed in", type: "auth_success"), at: start)
        XCTAssertEqual(tracker.display.state, .working)
        tracker.apply(event(.notification, message: "?", type: "something_new"), at: start)
        XCTAssertEqual(tracker.display.state, .working)
    }

    func testAttentionNotificationTypesSetWaiting() {
        for type in ["permission_prompt", "elicitation_dialog", nil] {
            var tracker = SessionTracker()
            tracker.apply(event(.userPromptSubmit), at: start)
            tracker.apply(event(.notification, message: "Question", type: type), at: start)
            XCTAssertEqual(tracker.display, PetDisplay(state: .waiting, projectName: "app", message: "Question"), String(describing: type))
        }
    }

    func testIdlePromptKeepsWaitingState() {
        var tracker = SessionTracker()
        tracker.apply(event(.notification, message: "Need permission", type: "permission_prompt"), at: start)
        tracker.apply(event(.notification, message: "Claude is waiting for your input", type: "idle_prompt"), at: start.addingTimeInterval(60))
        XCTAssertEqual(tracker.display, PetDisplay(state: .waiting, projectName: "app", message: "Need permission"))
    }

    func testIdleTextWithoutTypeDoesNotRequestAttention() {
        var tracker = SessionTracker()
        tracker.apply(event(.userPromptSubmit), at: start)
        tracker.apply(event(.notification, message: "Claude is waiting for your input"), at: start)
        XCTAssertEqual(tracker.display.state, .working)
    }
}
