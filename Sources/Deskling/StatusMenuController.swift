import AppKit
import DesklingCore

final class StatusMenuController: NSObject, NSMenuDelegate {
    struct SkinItem {
        let path: String?
        let name: String
    }

    struct State {
        var connected: Bool
        var skins: [SkinItem]
        var selectedSkinPath: String?
        var scale: Double
        var bubblesEnabled: Bool
        var petHidden: Bool
        /// `nil` hides the menu item (the app is not running from an app bundle).
        var launchAtLogin: Bool?
    }

    struct Actions {
        var toggleConnection: () -> Void
        var selectSkin: (String?) -> Void
        var openSkinsFolder: () -> Void
        var setScale: (Double) -> Void
        var toggleBubbles: () -> Void
        var togglePet: () -> Void
        var toggleLaunchAtLogin: () -> Void
    }

    static let scales: [(Text, Double)] = [(.sizeSmall, 0.75), (.sizeMedium, 1.0), (.sizeLarge, 1.5)]

    private final class Handler {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let language: Language
    private let state: () -> State
    private let actions: Actions

    init(language: Language, state: @escaping () -> State, actions: Actions) {
        self.language = language
        self.state = state
        self.actions = actions
        super.init()
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Deskling")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let current = state()
        let actions = self.actions
        menu.removeAllItems()

        let status = NSMenuItem(title: text(current.connected ? .statusConnected : .statusNotConnected), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        add(to: menu, text(current.connected ? .disconnect : .connect), actions.toggleConnection)
        menu.addItem(.separator())

        let skinMenu = NSMenu()
        for skin in current.skins {
            add(to: skinMenu, skin.name, checked: skin.path == current.selectedSkinPath) { actions.selectSkin(skin.path) }
        }
        skinMenu.addItem(.separator())
        add(to: skinMenu, text(.openSkinsFolder), actions.openSkinsFolder)
        addSubmenu(to: menu, text(.skin), skinMenu)

        let sizeMenu = NSMenu()
        for (label, scale) in Self.scales {
            add(to: sizeMenu, text(label), checked: abs(scale - current.scale) < 0.01) { actions.setScale(scale) }
        }
        addSubmenu(to: menu, text(.size), sizeMenu)

        add(to: menu, text(.showBubbles), checked: current.bubblesEnabled, actions.toggleBubbles)
        add(to: menu, text(current.petHidden ? .showPet : .hidePet), actions.togglePet)
        if let launchAtLogin = current.launchAtLogin {
            add(to: menu, text(.launchAtLogin), checked: launchAtLogin, actions.toggleLaunchAtLogin)
        }
        menu.addItem(.separator())
        add(to: menu, text(.quit)) { NSApp.terminate(nil) }
    }

    private func text(_ text: Text) -> String { text.string(language) }

    private func add(to menu: NSMenu, _ title: String, checked: Bool = false, _ handler: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = Handler(handler)
        item.state = checked ? .on : .off
        menu.addItem(item)
    }

    private func addSubmenu(to menu: NSMenu, _ title: String, _ submenu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }

    @objc private func run(_ sender: NSMenuItem) {
        (sender.representedObject as? Handler)?.run()
    }
}
