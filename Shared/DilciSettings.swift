import Foundation

/// Settings shared between the app and the keyboard through the App Group.
/// The group id comes from Info.plist (`DilciAppGroup`) so it always matches
/// the bundle identifier you sign with. If the group isn't available (some
/// free signing setups), each side falls back to its own defaults.
enum SettingsKey {
    static let nativeLanguage = "nativeLanguage"
    static let defaultTone = "defaultTone"
    static let keyboardTone = "keyboardTone"
    static let showPinyin = "showPinyin"
    static let onboarded = "onboarded.v2"
    static let keyboardLetters = "keyboardLetters"
}

final class DilciSettings {
    static let shared = DilciSettings()

    let appGroup: String
    let defaults: UserDefaults

    private init() {
        appGroup = (Bundle.main.object(forInfoDictionaryKey: "DilciAppGroup") as? String) ?? "group.app.dilci"
        defaults = UserDefaults(suiteName: appGroup) ?? .standard
        defaults.register(defaults: [
            SettingsKey.nativeLanguage: Lang.english.rawValue,
            SettingsKey.defaultTone: Tone.casual.rawValue,
            SettingsKey.keyboardTone: Tone.casual.rawValue,
            SettingsKey.showPinyin: true,
        ])
    }

    var nativeLanguage: Lang {
        get { Lang(rawValue: defaults.string(forKey: SettingsKey.nativeLanguage) ?? "") ?? .english }
        set { defaults.set(newValue.rawValue, forKey: SettingsKey.nativeLanguage) }
    }

    var keyboardTone: Tone {
        get { Tone(rawValue: defaults.string(forKey: SettingsKey.keyboardTone) ?? "") ?? .casual }
        set { defaults.set(newValue.rawValue, forKey: SettingsKey.keyboardTone) }
    }

    var defaultTone: Tone {
        Tone(rawValue: defaults.string(forKey: SettingsKey.defaultTone) ?? "") ?? .casual
    }

    var showPinyin: Bool { defaults.bool(forKey: SettingsKey.showPinyin) }
}
