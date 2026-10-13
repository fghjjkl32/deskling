import Foundation

public struct WalkModel {
    /// Points per second.
    public static let speed = 40.0
    public static let restRange = 3.0...8.0
    private static let initialRest = 1.0

    public private(set) var x: Double
    public private(set) var facingLeft = false
    public private(set) var isWalking = false
    private var target: Double?
    private var restRemaining = WalkModel.initialRest

    public init(x: Double) {
        self.x = x
    }

    public mutating func place(x: Double) {
        self.x = x
        stop()
    }

    public mutating func face(left: Bool) {
        facingLeft = left
    }

    public mutating func stop() {
        target = nil
        isWalking = false
        restRemaining = Self.initialRest
    }

    public mutating func clamp(to bounds: ClosedRange<Double>) {
        x = min(max(x, bounds.lowerBound), bounds.upperBound)
    }

    public mutating func step(
        dt: Double,
        bounds: ClosedRange<Double>,
        random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        clamp(to: bounds)
        guard let target else {
            restRemaining -= dt
            if restRemaining <= 0, bounds.upperBound > bounds.lowerBound {
                let next = random(bounds)
                self.target = next
                facingLeft = next < x
                isWalking = true
            }
            return
        }
        let goal = min(max(target, bounds.lowerBound), bounds.upperBound)
        let distance = goal - x
        let move = Self.speed * dt
        if abs(distance) <= move {
            x = goal
            self.target = nil
            isWalking = false
            restRemaining = random(Self.restRange)
        } else {
            facingLeft = distance < 0
            x += distance < 0 ? -move : move
        }
    }
}
