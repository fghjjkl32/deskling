import XCTest
@testable import DesklingCore

final class FallModelTests: XCTestCase {
    func testDescendsWithoutExceedingMaxSpeed() {
        var model = FallModel(y: 1000)
        var previous = model.y
        for _ in 0..<60 {
            model.step(dt: 0.1, floor: 0)
            XCTAssertLessThan(model.y, previous)
            XCTAssertLessThanOrEqual(previous - model.y, FallModel.maxSpeed * 0.1 + 0.001)
            previous = model.y
            if model.hasLanded { break }
        }
    }

    func testStartsSlowerThanMaxSpeed() {
        var model = FallModel(y: 1000)
        model.step(dt: 0.1, floor: 0)
        XCTAssertEqual(model.y, 1000 - FallModel.acceleration * 0.1 * 0.1, accuracy: 0.001)
        XCTAssertFalse(model.hasLanded)
    }

    func testLandsExactlyOnTheFloor() {
        var model = FallModel(y: 105)
        for _ in 0..<100 where !model.hasLanded { model.step(dt: 0.1, floor: 100) }
        XCTAssertTrue(model.hasLanded)
        XCTAssertEqual(model.y, 100)
    }

    func testLandsAtOnceWhenAlreadyOnOrBelowTheFloor() {
        var model = FallModel(y: 40)
        model.step(dt: 0, floor: 100)
        XCTAssertTrue(model.hasLanded)
        XCTAssertEqual(model.y, 100)
    }
}
