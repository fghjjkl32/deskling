import ImageIO
import XCTest
@testable import DesklingCore

final class SkinTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("deskling-skins-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeImage(width: Int = 4, height: Int = 4) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func writeImage(_ url: URL, frames: Int = 1, gif: Bool = false, delay: Double = 0.25, width: Int = 4, height: Int = 4) {
        let type = (gif ? "com.compuserve.gif" : "public.png") as CFString
        let destination = CGImageDestinationCreateWithURL(url as CFURL, type, frames, nil)!
        let properties: [CFString: Any] = gif
            ? [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]]
            : [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay]]
        for _ in 0..<frames {
            CGImageDestinationAddImage(destination, makeImage(width: width, height: height), properties as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func skinDirectory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testStaticPNGHasOneFrame() throws {
        let url = root.appendingPathComponent("a.png")
        writeImage(url)
        XCTAssertEqual(SpriteFrames.load(url: url)?.images.count, 1)
    }

    func testAnimatedGIFAndPNGKeepFramesAndDelays() throws {
        for (name, gif) in [("a.gif", true), ("b.png", false)] {
            let url = root.appendingPathComponent(name)
            writeImage(url, frames: 3, gif: gif, delay: 0.25)
            let frames = try XCTUnwrap(SpriteFrames.load(url: url), name)
            XCTAssertEqual(frames.images.count, 3, name)
            XCTAssertEqual(frames.totalDuration, 0.75, accuracy: 0.01, name)
        }
    }

    func testBrokenAndOversizedImagesAreRejected() throws {
        let broken = root.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: broken)
        XCTAssertNil(SpriteFrames.load(url: broken))
        let empty = root.appendingPathComponent("empty.png")
        try Data().write(to: empty)
        XCTAssertNil(SpriteFrames.load(url: empty))
        let huge = root.appendingPathComponent("huge.png")
        writeImage(huge, width: SpriteFrames.maxDimension + 1, height: 2)
        XCTAssertNil(SpriteFrames.load(url: huge))
        XCTAssertNil(SpriteFrames.load(url: root.appendingPathComponent("missing.png")))
    }

    func testFullSkinLoadsEveryPose() throws {
        let directory = try skinDirectory("full")
        for pose in PetPose.allCases { writeImage(directory.appendingPathComponent("\(pose.rawValue).png")) }
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.id, "full")
        XCTAssertEqual(skin.name, "full")
        XCTAssertEqual(skin.height, 96)
        for pose in PetPose.allCases {
            XCTAssertEqual(skin.url(for: pose).lastPathComponent, "\(pose.rawValue).png")
        }
    }

    func testMissingPosesFallBackToIdle() throws {
        let directory = try skinDirectory("partial")
        writeImage(directory.appendingPathComponent("idle.gif"), gif: true)
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .walk).lastPathComponent, "idle.gif")
        XCTAssertEqual(skin.url(for: .done).lastPathComponent, "idle.gif")
    }

    func testHeldAndFallingPosesBorrowTheWalkCycleAtRunningSpeed() throws {
        let directory = try skinDirectory("walker")
        writeImage(directory.appendingPathComponent("idle.png"))
        writeImage(directory.appendingPathComponent("walk.png"))
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .drag).lastPathComponent, "walk.png")
        XCTAssertEqual(skin.url(for: .fall).lastPathComponent, "walk.png")
        XCTAssertEqual(skin.playbackSpeed(for: .drag), Skin.borrowedWalkSpeed)
        XCTAssertEqual(skin.playbackSpeed(for: .fall), Skin.borrowedWalkSpeed)
        XCTAssertEqual(skin.playbackSpeed(for: .walk), 1)
    }

    func testFallingBorrowsTheDragImageAtNormalSpeed() throws {
        let directory = try skinDirectory("runner")
        for name in ["idle", "walk", "drag"] { writeImage(directory.appendingPathComponent("\(name).png")) }
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .drag).lastPathComponent, "drag.png")
        XCTAssertEqual(skin.url(for: .fall).lastPathComponent, "drag.png")
        XCTAssertEqual(skin.playbackSpeed(for: .drag), 1)
        XCTAssertEqual(skin.playbackSpeed(for: .fall), 1)
    }

    func testHeldPoseFallsBackToIdleWithoutAWalkCycle() throws {
        let directory = try skinDirectory("still")
        writeImage(directory.appendingPathComponent("idle.png"))
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .drag).lastPathComponent, "idle.png")
        XCTAssertEqual(skin.playbackSpeed(for: .drag), 1)
    }

    func testSkinWithoutUsableIdleIsRejected() throws {
        let noIdle = try skinDirectory("no-idle")
        writeImage(noIdle.appendingPathComponent("walk.png"))
        XCTAssertNil(SkinLoader.load(directory: noIdle))

        let brokenIdle = try skinDirectory("broken-idle")
        try Data("x".utf8).write(to: brokenIdle.appendingPathComponent("idle.png"))
        XCTAssertNil(SkinLoader.load(directory: brokenIdle))
    }

    func testBrokenNonIdlePoseFallsBackToIdle() throws {
        let directory = try skinDirectory("broken-walk")
        writeImage(directory.appendingPathComponent("idle.png"))
        try Data("x".utf8).write(to: directory.appendingPathComponent("walk.png"))
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .walk).lastPathComponent, "idle.png")
    }

    func testUppercaseFileNamesAreAccepted() throws {
        let directory = try skinDirectory("upper")
        writeImage(directory.appendingPathComponent("IDLE.PNG"))
        writeImage(directory.appendingPathComponent("Walk.GIF"), gif: true)
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.url(for: .idle).lastPathComponent, "IDLE.PNG")
        XCTAssertEqual(skin.url(for: .walk).lastPathComponent, "Walk.GIF")
    }

    func testSkinJSONOverridesNameAndHeight() throws {
        let directory = try skinDirectory("named")
        writeImage(directory.appendingPathComponent("idle.png"))
        try Data(#"{"name":"내 펫","height":140}"#.utf8).write(to: directory.appendingPathComponent("skin.json"))
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.name, "내 펫")
        XCTAssertEqual(skin.height, 140)
    }

    func testSkinJSONProblemsFallBackToDefaults() throws {
        let cases: [(String, Double)] = [("{ broken", 96), (#"{"name":"","height":"big"}"#, 96), (#"{"height":5}"#, 16), (#"{"height":9999}"#, 512)]
        for (index, item) in cases.enumerated() {
            let directory = try skinDirectory("case\(index)")
            writeImage(directory.appendingPathComponent("idle.png"))
            try Data(item.0.utf8).write(to: directory.appendingPathComponent("skin.json"))
            let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
            XCTAssertEqual(skin.name, "case\(index)")
            XCTAssertEqual(skin.height, item.1)
        }
    }

    func testListReturnsOnlyValidSkinsSortedByName() throws {
        writeImage(try skinDirectory("b").appendingPathComponent("idle.png"))
        writeImage(try skinDirectory("a").appendingPathComponent("idle.png"))
        _ = try skinDirectory("empty")
        try Data("x".utf8).write(to: root.appendingPathComponent("stray-file.txt"))
        XCTAssertEqual(SkinLoader.list(in: root).map(\.id), ["a", "b"])
        XCTAssertEqual(SkinLoader.list(in: root.appendingPathComponent("missing")), [])
    }

    /// The default skin ships no `drag` or `fall` image; both borrow its walk cycle.
    private static let bundledPoses: [PetPose] = [.idle, .walk, .working, .waiting, .done]

    func testBundledDefaultSkinLoadsWithAnimations() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = repository.appendingPathComponent("Resources/skins/default")
        let skin = try XCTUnwrap(SkinLoader.load(directory: directory))
        XCTAssertEqual(skin.name, "Deskling")
        for pose in Self.bundledPoses {
            XCTAssertEqual(skin.url(for: pose).lastPathComponent, "\(pose.rawValue).png")
        }
        XCTAssertEqual(skin.url(for: .drag).lastPathComponent, "walk.png")
        XCTAssertEqual(SpriteFrames.load(url: skin.url(for: .idle))?.images.count, 2)
        XCTAssertEqual(SpriteFrames.load(url: skin.url(for: .walk))?.images.count, 19)
        XCTAssertEqual(SpriteFrames.load(url: skin.url(for: .done))?.images.count, 10)
    }

    func testTotalPixelBudgetRejectsAnimationsThatAreTooLargeInSum() throws {
        let url = root.appendingPathComponent("budget.png")
        writeImage(url, frames: 3)
        XCTAssertNil(SpriteFrames.load(url: url, maxTotalPixels: 40))
        XCTAssertEqual(SpriteFrames.load(url: url, maxTotalPixels: 48)?.images.count, 3)
        XCTAssertEqual(SpriteFrames.maxTotalPixels, 64_000_000)
    }

    func testBundledDefaultSkinImagesAllLoadWithinBudget() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for pose in Self.bundledPoses {
            let url = repository.appendingPathComponent("Resources/skins/default/\(pose.rawValue).png")
            XCTAssertNotNil(SpriteFrames.load(url: url), pose.rawValue)
        }
    }
}
