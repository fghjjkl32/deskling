import XCTest
@testable import DesklingCore

final class HookEventTests: XCTestCase {
    private func data(_ string: String) -> Data { Data(string.utf8) }

    func testParsesNotification() {
        let line = data(#"{"hook_event_name":"Notification","session_id":"s1","cwd":"/Users/me/work/app","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}"#)
        let event = HookEvent.parse(line: line)
        XCTAssertEqual(event?.kind, .notification)
        XCTAssertEqual(event?.sessionID, "s1")
        XCTAssertEqual(event?.projectName, "app")
        XCTAssertEqual(event?.message, "Claude needs your permission to use Bash")
        XCTAssertEqual(event?.isIdlePrompt, false)
    }

    func testRejectsUnusableLines() {
        XCTAssertNil(HookEvent.parse(line: data("not json")))
        XCTAssertNil(HookEvent.parse(line: data(#"{"hook_event_name":"Unknown","session_id":"s1"}"#)))
        XCTAssertNil(HookEvent.parse(line: data(#"{"hook_event_name":"Stop"}"#)))
        XCTAssertNil(HookEvent.parse(line: data(#"{"hook_event_name":"Stop","session_id":""}"#)))
        XCTAssertNil(HookEvent.parse(line: data("[1,2,3]")))
    }

    func testMissingOptionalFieldsAreNil() {
        let event = HookEvent.parse(line: data(#"{"hook_event_name":"Stop","session_id":"s1"}"#))
        XCTAssertEqual(event?.kind, .stop)
        XCTAssertNil(event?.cwd)
        XCTAssertNil(event?.projectName)
        XCTAssertNil(event?.message)
    }

    func testIdlePromptIsDetectedByTypeOrMessage() {
        let byType = HookEvent.parse(line: data(#"{"hook_event_name":"Notification","session_id":"s1","notification_type":"idle_prompt"}"#))
        let byMessage = HookEvent.parse(line: data(#"{"hook_event_name":"Notification","session_id":"s1","message":"Claude is waiting for your input"}"#))
        XCTAssertEqual(byType?.isIdlePrompt, true)
        XCTAssertEqual(byMessage?.isIdlePrompt, true)
    }

    func testCompactLineDropsLargeFields() throws {
        let big = String(repeating: "x", count: 2_000_000)
        let input = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": "PreToolUse", "session_id": "s1", "cwd": "/a/b",
            "tool_input": ["content": big],
        ])
        let line = try XCTUnwrap(HookEvent.compactLine(from: input, eventOverride: nil))
        XCTAssertLessThan(line.count, 300)
        XCTAssertEqual(line.last, 0x0A)
        XCTAssertEqual(line.filter { $0 == 0x0A }.count, 1)
        XCTAssertEqual(HookEvent.parse(line: line.dropLast())?.kind, .preToolUse)
    }

    func testCompactLineUsesEventOverride() throws {
        let input = data(#"{"session_id":"s1"}"#)
        let line = try XCTUnwrap(HookEvent.compactLine(from: input, eventOverride: "Stop"))
        XCTAssertEqual(HookEvent.parse(line: line.dropLast())?.kind, .stop)
    }

    func testCompactLineForwardsAndTruncatesThePrompt() throws {
        let input = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": "UserPromptSubmit", "session_id": "s1",
            "prompt": String(repeating: "가", count: 5000),
        ])
        let line = try XCTUnwrap(HookEvent.compactLine(from: input, eventOverride: nil))
        XCTAssertEqual(HookEvent.parse(line: line.dropLast())?.prompt?.count, 300)
    }

    func testCompactLineTruncatesLongMessage() throws {
        let input = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": "Notification", "session_id": "s1",
            "message": String(repeating: "가", count: 5000),
        ])
        let line = try XCTUnwrap(HookEvent.compactLine(from: input, eventOverride: nil))
        XCTAssertEqual(HookEvent.parse(line: line.dropLast())?.message?.count, 300)
    }

    func testCompactLineReturnsNilWhenUnusable() {
        XCTAssertNil(HookEvent.compactLine(from: data("garbage"), eventOverride: "Stop"))
        XCTAssertNil(HookEvent.compactLine(from: data(#"{"hook_event_name":"Stop"}"#), eventOverride: nil))
        XCTAssertNil(HookEvent.compactLine(from: Data(), eventOverride: "Stop"))
    }

    func testLineSplitterHandlesPartialAndMultipleLines() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.append(data("ab")), [])
        XCTAssertEqual(splitter.append(data("c\nde\n\nf")), [data("abc"), data("de")])
        XCTAssertEqual(splitter.finish(), data("f"))
        XCTAssertNil(splitter.finish())
    }

    func testLineSplitterDropsOversizedPendingData() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.append(Data(repeating: 0x41, count: LineSplitter.maxPending + 1)), [])
        XCTAssertNil(splitter.finish())
    }
}
