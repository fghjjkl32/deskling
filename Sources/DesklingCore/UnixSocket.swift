import Darwin
import Foundation

public enum UnixSocket {
    private static func address(path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    private static func withAddress(_ address: sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> Int32) -> Int32 {
        var address = address
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    /// Opens a listening socket, replacing any stale socket file at the path.
    public static func listen(path: String) -> Int32? {
        guard let address = address(path: path) else { return nil }
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        guard withAddress(address, { Darwin.bind(fd, $0, $1) }) == 0, Darwin.listen(fd, 16) == 0 else {
            close(fd)
            return nil
        }
        chmod(path, 0o600)
        return fd
    }

    public static func send(_ data: Data, to path: String) -> Bool {
        guard let address = address(path: path) else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard withAddress(address, { Darwin.connect(fd, $0, $1) }) == 0 else { return false }
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return true }
            var offset = 0
            while offset < raw.count {
                let written = write(fd, base + offset, raw.count - offset)
                if written <= 0 { return false }
                offset += written
            }
            return true
        }
    }

    public static func readAll(from fd: Int32, limit: Int = 1_048_576) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < limit {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    /// Reads until EOF, `limit` bytes, or `timeout` seconds in total, whichever comes first.
    /// Any error (including an invalid descriptor) ends the read and returns what was collected.
    public static func readUntilEOF(from fd: Int32, limit: Int, timeout: TimeInterval) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(max(0, timeout) * 1_000_000_000)
        while data.count < limit {
            let now = DispatchTime.now().uptimeNanoseconds
            if now >= deadline { break }
            let remainingMs = Int32(min((deadline - now) / 1_000_000 + 1, 60_000))
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, remainingMs)
            if ready < 0 {
                if errno == EINTR { continue }
                break
            }
            if ready == 0 { break }
            if descriptor.revents & Int16(POLLNVAL) != 0 { break }
            let count = read(fd, &buffer, min(buffer.count, limit - data.count))
            if count < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                break
            }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
