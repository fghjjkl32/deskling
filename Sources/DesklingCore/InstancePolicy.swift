import Foundation

/// Decides which of several simultaneously started copies of the app survives.
public enum InstancePolicy {
    /// An instance quits only when another one is older than itself
    /// (earlier launch date, or the same or unknown date and a lower pid).
    /// Exactly one instance of any group therefore stays.
    public static func shouldQuit(
        selfPID: Int32,
        selfLaunch: Date?,
        others: [(pid: Int32, launch: Date?)]
    ) -> Bool {
        others.contains { other in
            if let a = other.launch, let b = selfLaunch, a != b { return a < b }
            return other.pid < selfPID
        }
    }
}
