import Foundation

/// Chat shorthand → plain language, so the on-device translator understands
/// "see u tmrw" the way a person would. Matching is whole-word and
/// case-insensitive. Longer phrases are tried first.
enum Slang {
    static func expand(_ text: String, language: Lang) -> String {
        let table: [(String, String)]
        switch language {
        case .english: table = english
        case .russian: table = russian
        case .chinese: return text
        }
        var out = text
        // "5min", "10 mins", "2hrs" → "5 minutes", before word replacements
        out = regexReplace(#"(\d+)\s?(mins?|минут|мин)\b"#, in: out, template: language == .russian ? "$1 минут" : "$1 minutes")
        out = regexReplace(#"(\d+)\s?(hrs?|h)\b"#, in: out, template: "$1 hours")
        for (short, full) in table {
            out = replaceWord(short, with: full, in: out)
        }
        return out
    }

    private static func replaceWord(_ word: String, with replacement: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "(?<![\\p{L}\\p{N}'’])" + escaped + "(?![\\p{L}\\p{N}'’])"
        return regexReplace(pattern, in: text, template: NSRegularExpression.escapedTemplate(for: replacement))
    }

    private static func regexReplace(_ pattern: String, in text: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    // Sorted longest-first at load so multi-word phrases win.
    static let english: [(String, String)] = [
        ("see u", "see you"), ("c u", "see you"), ("cya", "see you"), ("c ya", "see you"),
        ("u", "you"), ("ya", "you"), ("yu", "you"), ("ur", "your"), ("urs", "yours"), ("r", "are"),
        ("y", "why"), ("n", "and"), ("k", "okay"), ("kk", "okay"), ("ok", "okay"), ("okey", "okay"),
        ("tmrw", "tomorrow"), ("tmr", "tomorrow"), ("tmrrw", "tomorrow"), ("tomoz", "tomorrow"), ("2moro", "tomorrow"), ("2mrw", "tomorrow"), ("tmw", "tomorrow"),
        ("tn", "tonight"), ("tonite", "tonight"), ("2nite", "tonight"), ("2day", "today"), ("tdy", "today"),
        ("pls", "please"), ("plz", "please"),
        ("thx", "thanks"), ("thnx", "thanks"), ("tnx", "thanks"), ("ty", "thank you"), ("tysm", "thank you so much"),
        ("np", "no problem"), ("nw", "no worries"),
        ("idk", "I don't know"), ("dunno", "I don't know"), ("idc", "I don't care"),
        ("imo", "in my opinion"), ("tbh", "to be honest"), ("btw", "by the way"), ("fyi", "for your information"),
        ("brb", "be right back"), ("omw", "on my way"), ("otw", "on the way"), ("asap", "as soon as possible"),
        ("wru", "where are you"), ("hru", "how are you"), ("wyd", "what are you doing"), ("wbu", "what about you"), ("hbu", "how about you"),
        ("rn", "right now"), ("atm", "at the moment"), ("nvm", "never mind"), ("ttyl", "talk to you later"), ("l8r", "later"),
        ("gonna", "going to"), ("wanna", "want to"), ("gotta", "have to"), ("lemme", "let me"), ("gimme", "give me"),
        ("cuz", "because"), ("coz", "because"), ("cos", "because"), ("bc", "because"), ("b4", "before"),
        ("gr8", "great"), ("abt", "about"), ("w/", "with"), ("w/o", "without"), ("smth", "something"), ("sth", "something"), ("sb", "somebody"),
        ("msg", "message"), ("ppl", "people"), ("pic", "photo"), ("pics", "photos"), ("bday", "birthday"), ("convo", "conversation"),
        ("sry", "sorry"), ("srry", "sorry"), ("luv", "love"), ("ily", "I love you"),
        ("yea", "yes"), ("yeah", "yes"), ("ye", "yes"), ("yep", "yes"), ("yup", "yes"), ("nah", "no"), ("nope", "no"),
        ("gn", "good night"), ("gm", "good morning"), ("lol", "haha"), ("lmao", "hahaha"), ("jk", "just kidding"),
        ("sec", "second"), ("min", "minute"), ("mins", "minutes"), ("hr", "hour"), ("hrs", "hours"),
        ("approx", "approximately"), ("info", "information"), ("dm", "message"), ("ez", "easy"),
    ].sorted { $0.0.count > $1.0.count }

    static let russian: [(String, String)] = [
        ("спс", "спасибо"), ("спасибки", "спасибо"), ("пасиб", "спасибо"), ("пасибо", "спасибо"), ("сенкс", "спасибо"),
        ("пжлст", "пожалуйста"), ("пжл", "пожалуйста"), ("пж", "пожалуйста"), ("плиз", "пожалуйста"), ("плз", "пожалуйста"),
        ("щас", "сейчас"), ("ща", "сейчас"), ("щя", "сейчас"), ("счас", "сейчас"),
        ("норм", "нормально"), ("нормас", "нормально"), ("ок", "хорошо"), ("окей", "хорошо"), ("оке", "хорошо"), ("лан", "ладно"), ("ладн", "ладно"),
        ("прив", "привет"), ("привки", "привет"), ("хай", "привет"), ("здрасте", "здравствуйте"), ("здрасьте", "здравствуйте"), ("дарова", "привет"),
        ("чё", "что"), ("че", "что"), ("чо", "что"), ("шо", "что"), ("ничё", "ничего"), ("ничо", "ничего"),
        ("тока", "только"), ("мб", "может быть"), ("хз", "не знаю"), ("незнаю", "не знаю"), ("кста", "кстати"), ("всм", "в смысле"),
        ("оч", "очень"), ("седня", "сегодня"), ("сёдня", "сегодня"), ("завтро", "завтра"),
        ("сек", "секунду"), ("щас буду", "сейчас буду"), ("др", "день рождения"),
        ("споки", "спокойной ночи"), ("спок", "спокойной ночи"), ("ваще", "вообще"), ("вобще", "вообще"),
        ("када", "когда"), ("кода", "когда"), ("скока", "сколько"), ("скок", "сколько"), ("тож", "тоже"),
        ("го", "давай"), ("канеш", "конечно"), ("конеш", "конечно"), ("кароч", "короче"), ("грю", "говорю"),
        ("тя", "тебя"), ("мя", "меня"), ("чел", "человек"), ("инфа", "информация"), ("пол часа", "полчаса"),
    ].sorted { $0.0.count > $1.0.count }
}
