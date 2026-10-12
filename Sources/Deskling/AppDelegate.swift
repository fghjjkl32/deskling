import AppKit
import DesklingCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let language = Language.current()
    private let bubble = BubbleController()
    private let installer = HookInstaller(
        settingsURL: AppPaths.claudeSettings(),
        supportDirectory: AppPaths.supportDirectory(),
        bundledHookURL: Resources.bundledHookURL
    )
    private var tracker = SessionTracker()
    private var pet: PetWindowController?
    private var server: EventServer?
    private var menu: StatusMenuController?
    private var stateTimer: Timer?

    private var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier {
            let me = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .filter { $0.processIdentifier != me }
                .map { (pid: $0.processIdentifier, launch: $0.launchDate) }
            let myLaunch = NSRunningApplication(processIdentifier: me)?.launchDate
            if InstancePolicy.shouldQuit(selfPID: me, selfLaunch: myLaunch, others: others) {
                NSApp.terminate(nil)
                return
            }
        }
        guard let skin = currentSkin() else {
            showAlert(title: text(.missingResources), body: Resources.defaultSkinDirectory.path)
            NSApp.terminate(nil)
            return
        }
        try? FileManager.default.createDirectory(at: AppPaths.skinsDirectory(), withIntermediateDirectories: true)
        // Keep the installed helper in step with this version of the app.
        if installer.isConnected { try? installer.copyHelper() }

        let pet = PetWindowController(skin: skin, scale: preferences.sizeScale, startX: preferences.petX, screenID: preferences.screenID)
        pet.onDropped = { [weak self] x, screenID in
            self?.preferences.petX = x
            self?.preferences.screenID = screenID
        }
        pet.onFrameChanged = { [weak self] in self?.render() }
        pet.setHidden(preferences.petHidden)
        pet.start()
        self.pet = pet

        let server = EventServer { [weak self] event in
            guard let self else { return }
            self.tracker.apply(event, at: Date())
            if event.kind == .notification || event.kind == .stop { self.bubble.clearDismissal() }
            self.render()
        }
        if !server.start(path: AppPaths.socketPath()) {
            NSLog("Deskling: could not open socket at %@", AppPaths.socketPath())
        }
        self.server = server

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tracker.tick(at: Date())
            self?.render()
        }
        RunLoop.main.add(timer, forMode: .common)
        stateTimer = timer

        menu = StatusMenuController(language: language, state: { [unowned self] in self.menuState() }, actions: menuActions())
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    // MARK: - Rendering

    private func render() {
        guard let pet else { return }
        let display = tracker.display
        if display != pet.display { pet.display = display }
        let visible = preferences.bubblesEnabled && !preferences.petHidden
        bubble.update(text: visible ? PetPresentation.bubble(for: display, language: language) : nil, anchor: pet.panel.frame)
    }

    private func text(_ text: Text) -> String { text.string(language) }

    // MARK: - Skins

    private func currentSkin() -> Skin? {
        if let path = preferences.skinPath, let skin = SkinLoader.load(directory: URL(fileURLWithPath: path)) {
            return skin
        }
        return SkinLoader.load(directory: Resources.defaultSkinDirectory)
    }

    private func applyCurrentSkin() {
        guard let skin = currentSkin() else { return }
        pet?.apply(skin: skin, scale: preferences.sizeScale)
    }

    // MARK: - Menu

    private func menuState() -> StatusMenuController.State {
        let userSkins = SkinLoader.list(in: AppPaths.skinsDirectory()).map {
            StatusMenuController.SkinItem(path: $0.directory.path, name: $0.name)
        }
        let selected = userSkins.contains { $0.path == preferences.skinPath } ? preferences.skinPath : nil
        return StatusMenuController.State(
            connected: installer.isConnected,
            skins: [StatusMenuController.SkinItem(path: nil, name: text(.defaultSkin))] + userSkins,
            selectedSkinPath: selected,
            scale: preferences.sizeScale,
            bubblesEnabled: preferences.bubblesEnabled,
            petHidden: preferences.petHidden,
            launchAtLogin: isBundled ? SMAppService.mainApp.status == .enabled : nil
        )
    }

    private func menuActions() -> StatusMenuController.Actions {
        StatusMenuController.Actions(
            toggleConnection: { [unowned self] in self.toggleConnection() },
            selectSkin: { [unowned self] path in
                self.preferences.skinPath = path
                self.applyCurrentSkin()
            },
            openSkinsFolder: {
                try? FileManager.default.createDirectory(at: AppPaths.skinsDirectory(), withIntermediateDirectories: true)
                NSWorkspace.shared.open(AppPaths.skinsDirectory())
            },
            setScale: { [unowned self] scale in
                self.preferences.sizeScale = scale
                self.applyCurrentSkin()
            },
            toggleBubbles: { [unowned self] in
                self.preferences.bubblesEnabled.toggle()
                self.render()
            },
            togglePet: { [unowned self] in
                self.preferences.petHidden.toggle()
                self.pet?.setHidden(self.preferences.petHidden)
                self.render()
            },
            toggleLaunchAtLogin: { [unowned self] in self.toggleLaunchAtLogin() }
        )
    }

    // MARK: - Claude Code connection

    private func toggleConnection() {
        do {
            if installer.isConnected {
                try installer.disconnect()
            } else {
                try installer.connect()
            }
        } catch HookSettings.SettingsError.invalidJSON {
            showManualSetup()
        } catch {
            showAlert(title: text(.connectFailed), body: error.localizedDescription)
        }
    }

    private func showManualSetup() {
        let snippet = HookSettings.manualSnippet(hookPath: installer.installedHookURL.path)
        try? installer.copyHelper()

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
        let textView = NSTextView(frame: scroll.bounds)
        textView.string = snippet
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let alert = NSAlert()
        alert.messageText = text(.invalidSettingsTitle)
        alert.informativeText = text(.invalidSettingsBody) + "\n" + installer.settingsURL.path
        alert.accessoryView = scroll
        alert.addButton(withTitle: text(.copy))
        alert.addButton(withTitle: text(.close))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet, forType: .string)
        }
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(title: text(.loginItemFailed), body: error.localizedDescription)
        }
    }

    private func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: text(.close))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
