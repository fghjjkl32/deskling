import DesklingCore
import Foundation

// Claude Code reads a hook's exit code and stdout, so this always exits 0 and prints nothing.
let input = UnixSocket.readUntilEOF(from: STDIN_FILENO, limit: 16 * 1024 * 1024, timeout: 1.0)
let eventOverride = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
if let line = HookEvent.compactLine(from: input, eventOverride: eventOverride) {
    _ = UnixSocket.send(line, to: AppPaths.socketPath())
}
exit(0)
