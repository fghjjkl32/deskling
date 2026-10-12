import XCTest
@testable import DesklingCore

final class AppPathsTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/me")

    func testDirectories() {
        XCTAssertEqual(AppPaths.supportDirectory(home: home).path, "/Users/me/Library/Application Support/Deskling")
        XCTAssertEqual(AppPaths.skinsDirectory(home: home).path, "/Users/me/Library/Application Support/Deskling/skins")
    }

    func testClaudeSettingsHonorsConfigDirectory() {
        XCTAssertEqual(AppPaths.claudeSettings(home: home, environment: [:]).path, "/Users/me/.claude/settings.json")
        XCTAssertEqual(AppPaths.claudeSettings(home: home, environment: ["CLAUDE_CONFIG_DIR": "/cfg"]).path, "/cfg/settings.json")
        XCTAssertEqual(AppPaths.claudeSettings(home: home, environment: ["CLAUDE_CONFIG_DIR": ""]).path, "/Users/me/.claude/settings.json")
    }

    func testSocketPathPrefersSupportDirectory() {
        XCTAssertEqual(AppPaths.socketPath(home: home, uid: 501), "/Users/me/Library/Application Support/Deskling/deskling.sock")
    }

    func testSocketPathFallsBackWhenTooLong() {
        let longHome = URL(fileURLWithPath: "/Users/" + String(repeating: "a", count: 80))
        XCTAssertEqual(AppPaths.socketPath(home: longHome, uid: 501), "/tmp/deskling-501.sock")
    }
}
