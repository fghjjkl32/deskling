import XCTest
@testable import DesklingCore

final class WalkModelTests: XCTestCase {
    private let bounds = 0.0...1000.0

    func testRestsThenWalksTowardTarget() {
        var model = WalkModel(x: 100)
        model.step(dt: 0.5, bounds: bounds, random: { _ in 500 })
        XCTAssertFalse(model.isWalking)
        model.step(dt: 0.6, bounds: bounds, random: { _ in 500 })
        XCTAssertTrue(model.isWalking)
        XCTAssertFalse(model.facingLeft)
        model.step(dt: 1, bounds: bounds, random: { _ in 500 })
        XCTAssertEqual(model.x, 100 + WalkModel.speed, accuracy: 0.001)
    }

    func testFaceTurnsThePet() {
        var model = WalkModel(x: 100)
        model.face(left: true)
        XCTAssertTrue(model.facingLeft)
        model.face(left: false)
        XCTAssertFalse(model.facingLeft)
    }

    func testFacesLeftWhenTargetIsBehind() {
        var model = WalkModel(x: 800)
        model.step(dt: 2, bounds: bounds, random: { _ in 200 })
        model.step(dt: 1, bounds: bounds, random: { _ in 200 })
        XCTAssertTrue(model.facingLeft)
        XCTAssertEqual(model.x, 800 - WalkModel.speed, accuracy: 0.001)
    }

    func testArrivesExactlyAndRests() {
        var model = WalkModel(x: 100)
        model.step(dt: 2, bounds: bounds, random: { _ in 110 })
        model.step(dt: 1, bounds: bounds, random: { _ in 4 })
        XCTAssertEqual(model.x, 110)
        XCTAssertFalse(model.isWalking)
        model.step(dt: 3.9, bounds: bounds, random: { _ in 900 })
        XCTAssertFalse(model.isWalking)
        model.step(dt: 0.2, bounds: bounds, random: { _ in 900 })
        XCTAssertTrue(model.isWalking)
    }

    func testNeverLeavesBounds() {
        var model = WalkModel(x: 500)
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<5000 {
            model.step(dt: 1.0 / 30, bounds: bounds, random: { Double.random(in: $0, using: &generator) })
            XCTAssertTrue(bounds.contains(model.x))
        }
    }

    func testPositionOutsideBoundsIsPulledBack() {
        var model = WalkModel(x: 5000)
        model.step(dt: 0, bounds: bounds, random: { _ in 0 })
        XCTAssertEqual(model.x, 1000)
        model.clamp(to: 0.0...300.0)
        XCTAssertEqual(model.x, 300)
    }

    func testTargetOutsideShrunkBoundsIsPulledBack() {
        var model = WalkModel(x: 100)
        model.step(dt: 2, bounds: bounds, random: { _ in 900 })
        for _ in 0..<600 { model.step(dt: 0.1, bounds: 0.0...300.0, random: { _ in 5 }) }
        XCTAssertLessThanOrEqual(model.x, 300)
    }

    func testZeroWidthBoundsStayStill() {
        var model = WalkModel(x: 50)
        for _ in 0..<100 { model.step(dt: 1, bounds: 50.0...50.0, random: { _ in 50 }) }
        XCTAssertEqual(model.x, 50)
        XCTAssertFalse(model.isWalking)
    }

    func testPlaceAndStopCancelWalking() {
        var model = WalkModel(x: 100)
        model.step(dt: 2, bounds: bounds, random: { _ in 900 })
        XCTAssertTrue(model.isWalking)
        model.stop()
        XCTAssertFalse(model.isWalking)
        model.step(dt: 2, bounds: bounds, random: { _ in 900 })
        model.place(x: 400)
        XCTAssertEqual(model.x, 400)
        XCTAssertFalse(model.isWalking)
    }
}
