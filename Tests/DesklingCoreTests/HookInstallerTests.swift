import XCTest
@testable import DesklingCore

final class HookInstallerTests: XCTestCase {
    private var root: URL!
    private var installer: HookInstaller!
    private var settingsURL: URL { root.appendingPathComponent("claude/settings.json") }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("deskling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bundle"), withIntermediateDirectories: true)
        let bundled = root.appendingPathComponent("bundle/deskling-hook")
        try Data("v1".utf8).write(to: bundled)
        installer = HookInstaller(settingsURL: settingsURL, supportDirectory: root.appendingPathComponent("support"), bundledHookURL: bundled)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func writeSettings(_ text: String) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: settingsURL)
    }

    func testConnectCreatesSettingsAndCopiesHelper() throws {
        XCTAssertFalse(installer.isConnected)
        try installer.connect()
        XCTAssertTrue(installer.isConnected)
        XCTAssertEqual(try Data(contentsOf: installer.installedHookURL), Data("v1".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.backupURL.path))
    }

    func testConnectBacksUpOriginal() throws {
        try writeSettings(#"{"model":"opus"}"#)
        try installer.connect()
        XCTAssertEqual(try String(contentsOf: installer.backupURL, encoding: .utf8), #"{"model":"opus"}"#)
        XCTAssertTrue(try String(contentsOf: settingsURL, encoding: .utf8).contains("\"model\" : \"opus\""))
    }

    func testConnectLeavesInvalidFileUntouched() throws {
        try writeSettings("{ broken")
        XCTAssertThrowsError(try installer.connect()) {
            XCTAssertEqual($0 as? HookSettings.SettingsError, .invalidJSON)
        }
        XCTAssertEqual(try String(contentsOf: settingsURL, encoding: .utf8), "{ broken")
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.installedHookURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.backupURL.path))
    }

    func testDisconnectRemovesHooksAndKeepsOtherSettings() throws {
        try writeSettings(#"{"model":"opus"}"#)
        try installer.connect()
        try installer.disconnect()
        XCTAssertFalse(installer.isConnected)
        XCTAssertTrue(try String(contentsOf: settingsURL, encoding: .utf8).contains("opus"))
    }

    func testDisconnectWithoutFileDoesNothing() throws {
        XCTAssertNoThrow(try installer.disconnect())
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
    }

    func testCopyHelperReplacesOlderCopy() throws {
        try installer.copyHelper()
        try Data("v2".utf8).write(to: installer.bundledHookURL)
        try installer.copyHelper()
        XCTAssertEqual(try Data(contentsOf: installer.installedHookURL), Data("v2".utf8))
    }

    func testConnectWritesThroughSymlink() throws {
        let realURL = root.appendingPathComponent("dotfiles/settings.json")
        try FileManager.default.createDirectory(at: realURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"model":"opus"}"#.utf8).write(to: realURL)
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: settingsURL, withDestinationURL: realURL)

        try installer.connect()

        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        XCTAssertTrue(HookSettings.isInstalled(in: try Data(contentsOf: realURL)))
    }

    func testSecondConnectKeepsOriginalBackup() throws {
        try writeSettings(#"{"model":"opus"}"#)
        try installer.connect()
        try installer.connect()
        XCTAssertEqual(try String(contentsOf: installer.backupURL, encoding: .utf8), #"{"model":"opus"}"#)
    }

    func testSecondConnectDoesNotTouchExistingBackup() throws {
        try writeSettings(#"{"model":"opus"}"#)
        try installer.connect()
        try Data("marker".utf8).write(to: installer.backupURL)
        try installer.connect()
        XCTAssertEqual(try String(contentsOf: installer.backupURL, encoding: .utf8), "marker")
    }

    func testDisconnectWithoutOurHooksLeavesFileByteIdentical() throws {
        let text = #"{"z":1,   "a":2}"#
        try writeSettings(text)
        try installer.disconnect()
        XCTAssertEqual(try String(contentsOf: settingsURL, encoding: .utf8), text)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.backupURL.path))
    }

    func testDisconnectInvalidFileThrowsAndLeavesItUntouched() throws {
        try writeSettings("{ broken")
        XCTAssertThrowsError(try installer.disconnect()) {
            XCTAssertEqual($0 as? HookSettings.SettingsError, .invalidJSON)
        }
        XCTAssertEqual(try String(contentsOf: settingsURL, encoding: .utf8), "{ broken")
    }

    private func hasQuarantine(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.quarantine", nil, 0, 0, 0) >= 0
    }

    func testCopyHelperStripsQuarantineAndIsExecutable() throws {
        XCTAssertEqual(setxattr(installer.bundledHookURL.path, "com.apple.quarantine", "0081;00000000;Safari;", 21, 0, 0), 0)
        XCTAssertTrue(hasQuarantine(installer.bundledHookURL))
        try installer.copyHelper()
        XCTAssertFalse(hasQuarantine(installer.installedHookURL))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: installer.installedHookURL.path))
        let mode = try FileManager.default.attributesOfItem(atPath: installer.installedHookURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o755)
    }

    func testCopyHelperLeavesNoTemporaryFiles() throws {
        try installer.copyHelper()
        try installer.copyHelper()
        let names = try FileManager.default.contentsOfDirectory(atPath: installer.supportDirectory.path)
        XCTAssertEqual(names, ["deskling-hook"])
    }

    func testCopyHelperFailureKeepsPreviousHelper() throws {
        try installer.copyHelper()
        try FileManager.default.removeItem(at: installer.bundledHookURL)
        XCTAssertThrowsError(try installer.copyHelper())
        XCTAssertEqual(try Data(contentsOf: installer.installedHookURL), Data("v1".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: installer.supportDirectory.path), ["deskling-hook"])
    }

    func testBackupKeepsOriginalPermissions() throws {
        try writeSettings(#"{"model":"opus"}"#)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
        try installer.connect()
        let mode = try FileManager.default.attributesOfItem(atPath: installer.backupURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o600)
    }

    func testConnectWritesThroughDanglingSymlink() throws {
        let realURL = root.appendingPathComponent("dotfiles/sub/settings.json")
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: settingsURL, withDestinationURL: realURL)

        try installer.connect()

        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        XCTAssertTrue(HookSettings.isInstalled(in: try Data(contentsOf: realURL)))
    }

    func testConnectWritesThroughRelativeDanglingSymlink() throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: settingsURL.path, withDestinationPath: "../elsewhere/settings.json")

        try installer.connect()

        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        let realURL = root.appendingPathComponent("elsewhere/settings.json")
        XCTAssertTrue(HookSettings.isInstalled(in: try Data(contentsOf: realURL)))
    }
}
