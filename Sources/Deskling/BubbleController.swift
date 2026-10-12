import AppKit

private final class BubbleView: NSView {
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override var wantsUpdateLayer: Bool { true }
}

final class BubbleController {
    private static let maxTextWidth: CGFloat = 260
    private static let padding: CGFloat = 12
    private static let gap: CGFloat = 6

    private let panel: NSPanel
    private let container = BubbleView()
    private let label = NSTextField(wrappingLabelWithString: "")
    private var shownText: String?
    private var dismissedText: String?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        label.font = .systemFont(ofSize: 14)
        label.textColor = .labelColor
        label.isSelectable = false
        container.addSubview(label)
        panel.contentView = container
        container.onClick = { [weak self] in
            self?.dismissedText = self?.shownText
            self?.panel.orderOut(nil)
        }
    }

    /// Shows `text` above `anchor`. Passing `nil` hides the bubble and forgets a dismissal.
    func update(text: String?, anchor: NSRect) {
        guard let text else {
            dismissedText = nil
            shownText = nil
            panel.orderOut(nil)
            return
        }
        if text == dismissedText { return }
        dismissedText = nil
        if text != shownText {
            shownText = text
            label.stringValue = text
        }
        let textSize = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: Self.maxTextWidth, height: 10_000))
            ?? NSSize(width: Self.maxTextWidth, height: 20)
        let size = NSSize(width: ceil(textSize.width) + Self.padding * 2, height: ceil(textSize.height) + Self.padding * 2)
        label.frame = NSRect(x: Self.padding, y: Self.padding, width: ceil(textSize.width), height: ceil(textSize.height))

        var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + Self.gap)
        let anchorCenter = NSPoint(x: anchor.midX, y: anchor.midY)
        if let visible = (NSScreen.screens.first { $0.frame.contains(anchorCenter) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 4), max(visible.minX + 4, visible.maxX - size.width - 4))
            origin.y = min(origin.y, visible.maxY - size.height - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }
}
