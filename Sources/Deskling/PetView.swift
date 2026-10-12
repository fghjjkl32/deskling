import AppKit
import DesklingCore

final class PetView: NSView {
    var onDragBegan: (() -> Void)?
    var onDragMoved: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private let spriteLayer = CALayer()
    private var currentURL: URL?
    private var facingLeft = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        spriteLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(spriteLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        withoutAnimation {
            spriteLayer.bounds = bounds
            spriteLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    func show(url: URL, facingLeft: Bool) {
        if url != currentURL {
            currentURL = url
            spriteLayer.removeAnimation(forKey: "frames")
            let frames = SpriteFrames.load(url: url)
            withoutAnimation { spriteLayer.contents = frames?.images.first }
            if let frames, frames.images.count > 1 {
                spriteLayer.add(Self.animation(for: frames), forKey: "frames")
            }
        }
        if facingLeft != self.facingLeft {
            self.facingLeft = facingLeft
            withoutAnimation {
                spriteLayer.setAffineTransform(facingLeft ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
            }
        }
    }

    private static func animation(for frames: SpriteFrames) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames.images
        var elapsed = 0.0
        var keyTimes: [NSNumber] = [0]
        for duration in frames.durations {
            elapsed += duration
            keyTimes.append(NSNumber(value: elapsed / frames.totalDuration))
        }
        animation.keyTimes = keyTimes
        animation.calculationMode = .discrete
        animation.duration = frames.totalDuration
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        var origin = window.frame.origin
        origin.x += event.deltaX
        origin.y -= event.deltaY
        window.setFrameOrigin(origin)
        onDragMoved?()
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded?()
    }
}
