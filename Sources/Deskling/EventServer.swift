import DesklingCore
import Foundation

final class EventServer {
    private static let maxPayload = 65_536

    private let queue = DispatchQueue(label: "io.github.fghjjkl32.deskling.events")
    private let onEvent: (HookEvent) -> Void
    private var source: DispatchSourceRead?

    /// `onEvent` is called on the main queue.
    init(onEvent: @escaping (HookEvent) -> Void) {
        self.onEvent = onEvent
    }

    func start(path: String) -> Bool {
        guard let fd = UnixSocket.listen(path: path) else { return false }
        let onEvent = self.onEvent
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            defer { close(client) }
            var timeout = timeval(tv_sec: 1, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var splitter = LineSplitter()
            var lines = splitter.append(UnixSocket.readAll(from: client, limit: Self.maxPayload))
            if let rest = splitter.finish() { lines.append(rest) }
            let events = lines.compactMap(HookEvent.parse(line:))
            guard !events.isEmpty else { return }
            DispatchQueue.main.async { events.forEach(onEvent) }
        }
        source.setCancelHandler {
            close(fd)
            unlink(path)
        }
        source.resume()
        self.source = source
        return true
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
