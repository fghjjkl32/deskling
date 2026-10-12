import Foundation

final class Preferences {
    private let defaults = UserDefaults.standard

    /// Directory of the chosen user skin. `nil` means the bundled default pet.
    var skinPath: String? {
        get { defaults.string(forKey: "skinPath") }
        set { defaults.set(newValue, forKey: "skinPath") }
    }

    var sizeScale: Double {
        get {
            let value = defaults.double(forKey: "sizeScale")
            return value > 0 ? value : 1.0
        }
        set { defaults.set(newValue, forKey: "sizeScale") }
    }

    var bubblesEnabled: Bool {
        get { defaults.object(forKey: "bubblesEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "bubblesEnabled") }
    }

    var petHidden: Bool {
        get { defaults.bool(forKey: "petHidden") }
        set { defaults.set(newValue, forKey: "petHidden") }
    }

    var petX: Double? {
        get { defaults.object(forKey: "petX") as? Double }
        set { defaults.set(newValue, forKey: "petX") }
    }

    var screenID: Int? {
        get { defaults.object(forKey: "screenID") as? Int }
        set { defaults.set(newValue, forKey: "screenID") }
    }
}
