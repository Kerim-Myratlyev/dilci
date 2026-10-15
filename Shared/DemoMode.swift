#if DEBUG
import Foundation

/// Sample data for README / App Store screenshots.
///
/// Only compiled into Debug builds and only active when the app is launched
/// with `-demo` (see .github/workflows/screenshots.yml). Real users never see it.
enum DemoMode {
    static var isOn: Bool { CommandLine.arguments.contains("-demo") }

    /// `-tab 0|1|2` opens Translate, Phrasebook or Settings.
    static var tab: Int {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-tab"), i + 1 < args.count else { return 0 }
        return Int(args[i + 1]) ?? 0
    }

    private static func sample(_ original: String, _ translation: String, _ pinyin: String,
                               back: String = "", note: String = "", from: Lang, to: Lang,
                               tone: Tone = .casual, starred: Bool = false,
                               minutesAgo: Double = 0) -> TranslationResult {
        TranslationResult(original: original, translation: translation, pinyin: pinyin,
                          back: back, note: note, source: from, target: to, tone: tone,
                          date: Date().addingTimeInterval(-minutesAgo * 60), starred: starred)
    }

    /// A short WeChat-style exchange. `mine` is true for what you wrote.
    static let conversation: [(mine: Bool, result: TranslationResult)] = [
        (false, sample("这周末一起吃饭吗？", "Want to have dinner together this weekend?",
                       "zhè zhōu mò yì qǐ chī fàn ma?", from: .chinese, to: .english)),
        (true, sample("sry cant this wknd, maybe next week?", "抱歉这周末不行，下周可以吗？",
                      "bào qiàn zhè zhōu mò bù xíng, xià zhōu kě yǐ ma?",
                      back: "Sorry, not this weekend. Is next week okay?",
                      from: .english, to: .chinese)),
        (false, sample("好的，改天吧！", "Okay, another day then!", "hǎo de, gǎi tiān ba!",
                       note: "改天 (another day) is often a polite way to say no.",
                       from: .chinese, to: .english)),
        (true, sample("no no i really want to! fri 7pm?", "不不，我真的很想去！周五晚上七点？",
                      "bù bù, wǒ zhēn de hěn xiǎng qù! zhōu wǔ wǎn shang qī diǎn?",
                      back: "No, no, I really want to go! Friday at 7 pm?",
                      from: .english, to: .chinese)),
    ]

    static let phrases: [TranslationResult] = [
        sample("where is the restroom?", "请问洗手间在哪里？", "qǐng wèn xǐ shǒu jiān zài nǎ lǐ?",
               from: .english, to: .chinese, tone: .polite, starred: true, minutesAgo: 30),
        sample("I'm allergic to peanuts", "我对花生过敏。", "wǒ duì huā shēng guò mǐn.",
               from: .english, to: .chinese, tone: .polite, starred: true, minutesAgo: 90),
        sample("can I get a fapiao pls", "麻烦开一下发票。", "má fan kāi yí xià fā piào.",
               from: .english, to: .chinese, tone: .polite, starred: true, minutesAgo: 600),
        sample("сколько стоит?", "这个多少钱？", "zhè ge duō shao qián?",
               from: .russian, to: .chinese, starred: true, minutesAgo: 1400),
        sample("im at the door", "我在门口等你。", "wǒ zài mén kǒu děng nǐ.",
               from: .english, to: .chinese, starred: true, minutesAgo: 3000),
        sample("thx for today, it was great", "谢谢你今天的招待，太开心了！",
               "xiè xie nǐ jīn tiān de zhāo dài, tài kāi xīn le!",
               from: .english, to: .chinese, minutesAgo: 5000),
    ]
}
#endif
