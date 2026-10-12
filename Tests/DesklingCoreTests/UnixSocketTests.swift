import XCTest
@testable import DesklingCore

final class UnixSocketTests: XCTestCase {
    private var path: String!

    override func setUp() {
        path = "/tmp/deskling-test-\(UUID().uuidString.prefix(8)).sock"
    }

    override func tearDown() {
        unlink(path)
    }

    func testSendDeliversDataToListener() throws {
        let server = try XCTUnwrap(UnixSocket.listen(path: path))
        defer { close(server) }
        XCTAssertTrue(UnixSocket.send(Data("hello\n".utf8), to: path))
        let client = accept(server, nil, nil)
        XCTAssertGreaterThanOrEqual(client, 0)
        defer { close(client) }
        XCTAssertEqual(UnixSocket.readAll(from: client), Data("hello\n".utf8))
    }

    func testSendFailsQuietlyWithoutListener() {
        XCTAssertFalse(UnixSocket.send(Data("x".utf8), to: path))
    }

    func testListenReplacesStaleSocketFile() throws {
        let first = try XCTUnwrap(UnixSocket.listen(path: path))
        close(first)
        let second = try XCTUnwrap(UnixSocket.listen(path: path))
        close(second)
    }

    func testOverlongPathIsRejected() {
        let long = "/tmp/" + String(repeating: "a", count: 200)
        XCTAssertNil(UnixSocket.listen(path: long))
        XCTAssertFalse(UnixSocket.send(Data("x".utf8), to: long))
    }

    func testReadAllStopsAtLimit() throws {
        let server = try XCTUnwrap(UnixSocket.listen(path: path))
        defer { close(server) }
        // Stays under the default 8 KB socket buffer, so the send finishes before anyone reads.
        XCTAssertTrue(UnixSocket.send(Data(repeating: 0x41, count: 6000), to: path))
        let client = accept(server, nil, nil)
        defer { close(client) }
        let received = UnixSocket.readAll(from: client, limit: 1000)
        XCTAssertGreaterThanOrEqual(received.count, 1000)
        XCTAssertLessThan(received.count, 6000)
    }

    private func makePipe() -> (read: Int32, write: Int32) {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&fds), 0)
        return (fds[0], fds[1])
    }

    func testReadUntilEOFReturnsAllDataAfterClose() {
        let p = makePipe()
        defer { close(p.read) }
        _ = write(p.write, "hello", 5)
        close(p.write)
        XCTAssertEqual(UnixSocket.readUntilEOF(from: p.read, limit: 1024, timeout: 1), Data("hello".utf8))
    }

    func testReadUntilEOFStopsAtTimeoutWhenWriterStaysOpen() {
        let p = makePipe()
        defer { close(p.read); close(p.write) }
        _ = write(p.write, "abc", 3)
        let start = Date()
        let data = UnixSocket.readUntilEOF(from: p.read, limit: 1024, timeout: 0.2)
        XCTAssertEqual(data, Data("abc".utf8))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)
    }

    func testReadUntilEOFNeverReturnsMoreThanLimit() {
        let p = makePipe()
        defer { close(p.read) }
        _ = write(p.write, [UInt8](repeating: 0x41, count: 5000), 5000)
        close(p.write)
        XCTAssertEqual(UnixSocket.readUntilEOF(from: p.read, limit: 1000, timeout: 1).count, 1000)
    }

    func testReadUntilEOFReturnsEmptyForInvalidDescriptor() {
        XCTAssertEqual(UnixSocket.readUntilEOF(from: -1, limit: 1024, timeout: 0.2), Data())
        let p = makePipe()
        close(p.read)
        close(p.write)
        XCTAssertEqual(UnixSocket.readUntilEOF(from: p.read, limit: 1024, timeout: 0.2), Data())
    }
}
