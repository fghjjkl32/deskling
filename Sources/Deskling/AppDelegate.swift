import AppKit
import DesklingCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let language = Language.current()
    private let bubble = BubbleController()
    private var tracker = SessionTracker()
    private var pet: PetWindowController?
    private var server: EventServer?
    private var stateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let skin = SkinLoader.load(directory: Resources.defaultSkinDirectory) else {
            NSLog("Deskling: default skin missing at %@", Resources.defaultSkinDirectory.path)
            NSApp.terminate(nil)
            return
        }
        let pet = PetWindowController(skin: skin, scale: preferences.sizeScale, startX: preferences.petX, screenID: preferences.screenID)
        pet.onDropped = { [weak self] x, screenID in
            self?.preferences.petX = x
            self?.preferences.screenID = screenID
        }
        pet.onFrameChanged = { [weak self] in self?.render() }
        pet.setHidden(false)
        pet.start()
        self.pet = pet

        try? FileManager.default.createDirectory(at: AppPaths.supportDirectory(), withIntermediateDirectories: true)
        let server = EventServer { [weak self] event in
            if event.kind == .notification || event.kind == .stop { self?.bubble.clearDismissal() }
            self?.tracker.apply(event, at: Date())
            self?.render()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    private func render() {
        guard let pet else { return }
        let display = tracker.display
        if display != pet.display { pet.display = display }
        let visible = preferences.bubblesEnabled && !preferences.petHidden
        bubble.update(text: visible ? PetPresentation.bubble(for: display, language: language) : nil, anchor: pet.panel.frame)
    }
}
