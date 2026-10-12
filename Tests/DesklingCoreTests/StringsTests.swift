import XCTest
@testable import DesklingCore

final class StringsTests: XCTestCase {
    func testLanguageFollowsFirstPreferredLanguage() {
        XCTAssertEqual(Language.current(preferred: ["ko-KR", "en-US"]), .korean)
        XCTAssertEqual(Language.current(preferred: ["en-US", "ko-KR"]), .english)
        XCTAssertEqual(Language.current(preferred: ["ja-JP"]), .english)
        XCTAssertEqual(Language.current(preferred: []), .english)
    }

    func testEveryTextHasBothLanguages() {
        for text in Text.allCases {
            XCTAssertFalse(text.string(.korean).isEmpty, "\(text)")
            XCTAssertFalse(text.string(.english).isEmpty, "\(text)")
        }
    }

    func testKoreanSentencesUseFormalPolite() {
        for text in Text.allCases {
            let korean = text.string(.korean)
            guard korean.hasSuffix(".") else { continue }
            XCTAssertTrue(korean.hasSuffix("니다."), "\(text): \(korean)")
        }
    }

    func testPoseForState() {
        XCTAssertEqual(PetPresentation.pose(for: .idle, isWalking: false), .idle)
        XCTAssertEqual(PetPresentation.pose(for: .idle, isWalking: true), .walk)
        XCTAssertEqual(PetPresentation.pose(for: .working, isWalking: true), .working)
        XCTAssertEqual(PetPresentation.pose(for: .waiting, isWalking: false), .waiting)
        XCTAssertEqual(PetPresentation.pose(for: .done, isWalking: false), .done)
    }

    func testBubbleOnlyForWaitingAndDone() {
        XCTAssertNil(PetPresentation.bubble(for: PetDisplay(state: .idle, projectName: "app", message: nil), language: .korean))
        XCTAssertNil(PetPresentation.bubble(for: PetDisplay(state: .working, projectName: "app", message: nil), language: .korean))
    }

    func testBubbleText() {
        XCTAssertEqual(
            PetPresentation.bubble(for: PetDisplay(state: .waiting, projectName: "app", message: "Need permission"), language: .korean),
            "app\nNeed permission"
        )
        XCTAssertEqual(
            PetPresentation.bubble(for: PetDisplay(state: .waiting, projectName: nil, message: nil), language: .korean),
            "입력을 기다리고 있습니다."
        )
        XCTAssertEqual(
            PetPresentation.bubble(for: PetDisplay(state: .waiting, projectName: "app", message: "  "), language: .english),
            "app\nWaiting for your input."
        )
        XCTAssertEqual(
            PetPresentation.bubble(for: PetDisplay(state: .done, projectName: "app", message: nil), language: .korean),
            "app\n작업을 마쳤습니다."
        )
    }

    func testBubbleTruncatesLongMessage() {
        let long = String(repeating: "a", count: 500)
        let bubble = PetPresentation.bubble(for: PetDisplay(state: .waiting, projectName: nil, message: long), language: .english)
        XCTAssertEqual(bubble?.count, PetPresentation.maxMessageLength + 1)
        XCTAssertEqual(bubble?.last, "…")
    }

    func testBubbleCollapsesWhitespaceBeforeTruncating() {
        let display = PetDisplay(state: .waiting, projectName: nil, message: "Run\n\n  this   command\t now")
        XCTAssertEqual(PetPresentation.bubble(for: display, language: .english), "Run this command now")
    }

    func testBubbleTruncatesLongProjectName() {
        let name = String(repeating: "p", count: 60)
        let bubble = PetPresentation.bubble(for: PetDisplay(state: .done, projectName: name, message: nil), language: .english)
        XCTAssertEqual(bubble?.components(separatedBy: "\n").first, String(repeating: "p", count: 40) + "…")
    }
}
