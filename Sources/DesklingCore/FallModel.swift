import Foundation

/// A slow, floaty descent to the floor after the pet is let go in mid-air.
public struct FallModel {
    /// Points per second squared.
    public static let acceleration = 300.0
    /// Points per second.
    public static let maxSpeed = 140.0

    public private(set) var y: Double
    public private(set) var hasLanded = false
    private var speed = 0.0

    public init(y: Double) {
        self.y = y
    }

    public mutating func step(dt: Double, floor: Double) {
        speed = min(speed + Self.acceleration * dt, Self.maxSpeed)
        y -= speed * dt
        if y <= floor {
            y = floor
            hasLanded = true
        }
    }
}
