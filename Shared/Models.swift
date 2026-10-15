import Foundation

// MARK: - Languages

enum Lang: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case chinese = "zh"

    var id: String { rawValue }

    var englishName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        case .chinese: return "中文"
        }
    }

    var short: String {
        switch self {
        case .english: return "EN"
        case .russian: return "RU"
        case .chinese: return "中文"
        }
    }

    /// The language identifier Apple's on-device translator uses.
    var locale: Locale.Language {
        switch self {
        case .english: return Locale.Language(identifier: "en")
        case .russian: return Locale.Language(identifier: "ru")
        case .chinese: return Locale.Language(identifier: "zh-Hans")
        }
    }

    var speechCode: String {
        switch self {
        case .english: return "en-US"
        case .russian: return "ru-RU"
        case .chinese: return "zh-CN"
        }
    }

    /// Script-based detection. Han wins quickly because each character carries
    /// a word's worth of meaning.
    static func detect(_ text: String) -> Lang {
        var han = 0, cyrillic = 0, latin = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF: han += 1
            case 0x0400...0x04FF: cyrillic += 1
            case 0x41...0x5A, 0x61...0x7A: latin += 1
            default: break
            }
        }
        if han > 0 && han * 3 >= max(cyrillic, latin) { return .chinese }
        if cyrillic > latin { return .russian }
        return .english
    }
}

// MARK: - Tone

enum Tone: String, Codable, CaseIterable, Identifiable {
    case casual, polite, business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .casual: return "Casual"
        case .polite: return "Polite"
        case .business: return "Work"
        }
    }

    var shortTitle: String { title }

    var hanzi: String {
        switch self {
        case .casual: return "随意"
        case .polite: return "礼貌"
        case .business: return "正式"
        }
    }

    var help: String {
        switch self {
        case .casual: return "Friends and classmates"
        case .polite: return "Landlord, shops, teachers, older people"
        case .business: return "Colleagues and clients"
        }
    }
}

// MARK: - Translation

struct TranslationRequest: Hashable {
    var text: String
    var source: Lang
    var target: Lang
    var tone: Tone
    /// The other person's last message, if known. Used only as context.
    var replyingTo: String?
}

struct TranslationResult: Codable, Hashable, Identifiable {
    var id = UUID()
    var original: String
    var translation: String
    var pinyin: String
    /// Back-translation into the source language, so you can check the meaning.
    var back: String
    /// A short cultural or usage note, usually empty.
    var note: String
    var source: Lang
    var target: Lang
    var tone: Tone
    var date = Date()
    var starred = false
}
