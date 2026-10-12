import AppKit
import DesklingCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var pet: PetWindowController?

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
        pet.setHidden(false)
        pet.start()
        self.pet = pet
    }
}
