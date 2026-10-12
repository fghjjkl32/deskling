import XCTest
@testable import DesklingCore

final class InstancePolicyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)
    private let t1 = Date(timeIntervalSince1970: 2000)

    func testNoOthersKeepsRunning() {
        XCTAssertFalse(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t1, others: []))
    }

    func testOlderOtherMeansQuit() {
        XCTAssertTrue(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t1, others: [(pid: 99, launch: t0)]))
    }

    func testNewerOtherMeansStay() {
        XCTAssertFalse(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t0, others: [(pid: 5, launch: t1)]))
    }

    func testSameDateLowerPidQuits() {
        XCTAssertTrue(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t0, others: [(pid: 5, launch: t0)]))
    }

    func testSameDateHigherPidStays() {
        XCTAssertFalse(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t0, others: [(pid: 20, launch: t0)]))
    }

    func testNilDatesFallBackToPid() {
        XCTAssertTrue(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: nil, others: [(pid: 5, launch: nil)]))
        XCTAssertFalse(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: nil, others: [(pid: 20, launch: nil)]))
        XCTAssertTrue(InstancePolicy.shouldQuit(selfPID: 10, selfLaunch: t0, others: [(pid: 5, launch: nil)]))
    }

    func testTwoInstancesNeverBothQuit() {
        let a = (pid: Int32(10), launch: Optional(t0))
        let b = (pid: Int32(20), launch: Optional(t0))
        XCTAssertNotEqual(
            InstancePolicy.shouldQuit(selfPID: a.pid, selfLaunch: a.launch, others: [b]),
            InstancePolicy.shouldQuit(selfPID: b.pid, selfLaunch: b.launch, others: [a])
        )
    }
}
