import Foundation

/// Short notes for Chinese chat phrases that a translation alone won't explain.
/// Shown under a translation when one of these appears.
enum CultureNotes {
    private struct Entry {
        let phrase: String
        let en: String
        let ru: String
    }

    private static let entries: [Entry] = [
        Entry(phrase: "呵呵", en: "呵呵 often reads as cold or sarcastic. Use 哈哈 to sound friendly.", ru: "呵呵 часто звучит холодно или с сарказмом. Дружелюбнее 哈哈."),
        Entry(phrase: "改天", en: "改天 (another day) is often a polite way to say no.", ru: "改天 («в другой раз») часто вежливый отказ."),
        Entry(phrase: "再说吧", en: "再说吧 usually means a soft no: let's not decide now.", ru: "再说吧 обычно мягкий отказ: «потом посмотрим»."),
        Entry(phrase: "随便", en: "随便 means whatever or up to you. It can sound careless.", ru: "随便 значит «как хочешь». Может звучать небрежно."),
        Entry(phrase: "辛苦了", en: "辛苦了 thanks someone for their effort. Common at work.", ru: "辛苦了 благодарит за труд. Часто на работе."),
        Entry(phrase: "在吗", en: "在吗 just checks you're there. Reply when you're free.", ru: "在吗 значит «ты тут?». Можно ответить, когда удобно."),
        Entry(phrase: "不好意思", en: "不好意思 is a light sorry or excuse me, very common.", ru: "不好意思 лёгкое «извините», очень частое."),
        Entry(phrase: "没事", en: "没事 means it's fine or no problem.", ru: "没事 значит «ничего страшного»."),
        Entry(phrase: "还行", en: "还行 is lukewarm: it's okay, not great.", ru: "还行 сдержанно: «нормально, не более»."),
        Entry(phrase: "麻烦你", en: "麻烦你 is a polite way to ask a favor.", ru: "麻烦你 вежливая просьба об одолжении."),
        Entry(phrase: "亲", en: "亲 (dear) is how shop staff address customers online.", ru: "亲 («дорогой») так обращаются продавцы в онлайн-магазинах."),
        Entry(phrase: "666", en: "666 means awesome or well done.", ru: "666 значит «круто», «молодец»."),
        Entry(phrase: "吃了吗", en: "吃了吗 (have you eaten?) is a greeting, not an invitation.", ru: "吃了吗 («ты поел?») приветствие, а не приглашение."),
        Entry(phrase: "不用了", en: "不用了 is a polite no thanks.", ru: "不用了 вежливое «не нужно, спасибо»."),
        Entry(phrase: "收到", en: "收到 means got it. Standard reply at work.", ru: "收到 значит «принято». Стандартный ответ на работе."),
        Entry(phrase: "嗯嗯", en: "嗯嗯 is a friendly yes. A single 嗯 can feel curt.", ru: "嗯嗯 дружелюбное «ага». Одно 嗯 может звучать сухо."),
        Entry(phrase: "哦", en: "A lone 哦 can feel cold. 哦哦 or 好的 sounds warmer.", ru: "Одно 哦 может звучать холодно. Теплее 哦哦 или 好的."),
        Entry(phrase: "加油", en: "加油 means you can do it, good luck.", ru: "加油 значит «давай, удачи»."),
        Entry(phrase: "拜拜", en: "拜拜 is a casual bye.", ru: "拜拜 неформальное «пока»."),
    ]

    static func note(for chinese: String, in language: Lang) -> String {
        guard let entry = entries.first(where: { matches($0.phrase, in: chinese) }) else { return "" }
        return language == .russian ? entry.ru : entry.en
    }

    private static func matches(_ phrase: String, in text: String) -> Bool {
        if phrase == "哦" {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return trimmed == "哦"
        }
        if phrase == "麻烦你" { return text.contains("麻烦你") || text.contains("麻烦您") }
        if phrase == "亲" {
            guard text.hasPrefix("亲"), text.count > 1 else { return text == "亲" }
            let second = text[text.index(after: text.startIndex)]
            return second.isPunctuation || second.isWhitespace || second == "~"
        }
        return text.contains(phrase)
    }
}
