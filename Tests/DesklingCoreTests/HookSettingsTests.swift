import XCTest
@testable import DesklingCore

final class HookSettingsTests: XCTestCase {
    private let hookPath = "/Users/me/Library/Application Support/Deskling/deskling-hook"

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func commands(_ root: [String: Any], _ event: String) -> [String] {
        let groups = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    func testInstallIntoMissingOrEmptyFile() throws {
        for input in [nil, Data(), Data("  \n".utf8)] as [Data?] {
            let root = try object(HookSettings.install(into: input, hookPath: hookPath))
            for kind in HookEvent.Kind.allCases {
                XCTAssertEqual(commands(root, kind.rawValue), ["\"\(hookPath)\" \(kind.rawValue)"])
            }
        }
    }

    func testInstallKeepsExistingSettingsAndHooks() throws {
        let input = Data(#"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}],"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"fmt"}]}]}}"#.utf8)
        let root = try object(HookSettings.install(into: input, hookPath: hookPath))
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual(commands(root, "Stop"), ["say done", "\"\(hookPath)\" Stop"])
        XCTAssertEqual(commands(root, "PostToolUse"), ["fmt", "\"\(hookPath)\" PostToolUse"])
    }

    func testInstallTwiceDoesNotDuplicate() throws {
        let once = try HookSettings.install(into: nil, hookPath: hookPath)
        let twice = try HookSettings.install(into: once, hookPath: hookPath)
        XCTAssertEqual(commands(try object(twice), "Stop").count, 1)
    }

    func testInstallReplacesOldHookPath() throws {
        let old = try HookSettings.install(into: nil, hookPath: "/old/deskling-hook")
        let root = try object(HookSettings.install(into: old, hookPath: hookPath))
        XCTAssertEqual(commands(root, "Stop"), ["\"\(hookPath)\" Stop"])
    }

    func testUninstallRemovesOnlyOurEntries() throws {
        let input = Data(#"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#.utf8)
        let installed = try HookSettings.install(into: input, hookPath: hookPath)
        let root = try object(HookSettings.uninstall(from: installed))
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual(commands(root, "Stop"), ["say done"])
        XCTAssertNil((root["hooks"] as? [String: Any])?["Notification"])
    }

    func testUninstallRemovesEmptyHooksSection() throws {
        let installed = try HookSettings.install(into: Data(#"{"model":"opus"}"#.utf8), hookPath: hookPath)
        let root = try object(HookSettings.uninstall(from: installed))
        XCTAssertNil(root["hooks"])
        XCTAssertEqual(root["model"] as? String, "opus")
    }

    func testUninstallKeepsUserHookSharingOurGroup() throws {
        let input = Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"},{"type":"command","command":"\"/x/deskling-hook\" Stop"}]}]}}"#.utf8)
        let root = try object(HookSettings.uninstall(from: input))
        XCTAssertEqual(commands(root, "Stop"), ["say done"])
    }

    func testInvalidShapesThrowAndAreNotInstalled() {
        let inputs = ["{ broken", "[1,2]", #"{"hooks":[]}"#, #"{"hooks":{"Stop":"oops"}}"#, #"{"hooks":{"Stop":["oops"]}}"#]
        for text in inputs {
            let data = Data(text.utf8)
            XCTAssertThrowsError(try HookSettings.install(into: data, hookPath: hookPath), text) {
                XCTAssertEqual($0 as? HookSettings.SettingsError, .invalidJSON)
            }
            XCTAssertThrowsError(try HookSettings.uninstall(from: data), text)
            XCTAssertFalse(HookSettings.isInstalled(in: data), text)
        }
    }

    func testIsInstalled() throws {
        XCTAssertFalse(HookSettings.isInstalled(in: nil))
        XCTAssertFalse(HookSettings.isInstalled(in: Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#.utf8)))
        XCTAssertTrue(HookSettings.isInstalled(in: try HookSettings.install(into: nil, hookPath: hookPath)))
    }

    func testManualSnippetIsValidJSONWithAllEvents() throws {
        let root = try object(Data(HookSettings.manualSnippet(hookPath: hookPath).utf8))
        XCTAssertEqual((root["hooks"] as? [String: Any])?.count, HookEvent.Kind.allCases.count)
    }

    func testInstallsSevenEventsAndUninstallRemovesAll() throws {
        XCTAssertEqual(HookEvent.Kind.allCases.count, 7)
        let installed = try HookSettings.install(into: nil, hookPath: hookPath)
        XCTAssertEqual((try object(installed)["hooks"] as? [String: Any])?.count, 7)
        XCTAssertNotNil((try object(installed)["hooks"] as? [String: Any])?["PostToolUse"])
        let removed = try HookSettings.uninstall(from: installed)
        XCTAssertNil(try object(removed)["hooks"])
    }
}
