import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The Dilçi pipeline. Everything runs on the iPhone, for free:
///
/// 1. Understand chat shorthand ("see u tmrw", "щас буду") with a built-in
///    slang dictionary, or with Apple Intelligence when the phone has it.
/// 2. Translate with Apple's on-device translator.
/// 3. Shape the Chinese for the chosen tone (你 vs 您, chat punctuation).
/// 4. Translate it back so you can check the meaning, and add a usage note
///    when a phrase is easy to misread.
@MainActor
final class DilciTranslator {
    static let shared = DilciTranslator()

    private var cache: [TranslationRequest: TranslationResult] = [:]
    private let engine = TranslationEngine.shared

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        if let hit = cache[request] { return hit }

        let native = DilciSettings.shared.nativeLanguage
        let result: TranslationResult

        if request.target == .chinese {
            let prepared = await Rewriter.prepare(request.text, language: request.source, context: request.replyingTo)
            var chinese = try await engine.translate(prepared, from: request.source, to: .chinese)
            chinese = ToneStyler.apply(chinese, tone: request.tone)
            let back = (try? await engine.translate(chinese, from: .chinese, to: request.source)) ?? ""
            result = TranslationResult(
                original: request.text,
                translation: chinese,
                pinyin: Pinyin.of(chinese),
                back: back,
                note: CultureNotes.note(for: chinese, in: request.source == .russian ? .russian : native),
                source: request.source,
                target: .chinese,
                tone: request.tone
            )
        } else {
            let meaning = try await engine.translate(request.text, from: request.source, to: request.target)
            result = TranslationResult(
                original: request.text,
                translation: meaning,
                pinyin: request.source == .chinese ? Pinyin.of(request.text) : "",
                back: "",
                note: request.source == .chinese ? CultureNotes.note(for: request.text, in: request.target) : "",
                source: request.source,
                target: request.target,
                tone: request.tone
            )
        }

        if cache.count > 150 { cache.removeAll() }
        cache[request] = result
        return result
    }
}

// MARK: - Step 1: understanding the input

enum Rewriter {
    /// Expand shorthand. With Apple Intelligence available, also resolve what
    /// the message means given the other person's last message.
    static func prepare(_ text: String, language: Lang, context: String?) async -> String {
        let expanded = Slang.expand(text, language: language)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let smarter = await rewriteWithAppleIntelligence(text, language: language, context: context) {
                return smarter
            }
        }
        #endif
        return expanded
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func rewriteWithAppleIntelligence(_ text: String, language: Lang, context: String?) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let instructions = """
        You rewrite short chat messages so a translator can understand them. \
        Expand abbreviations, slang and typos into plain, complete \(language.englishName). \
        Keep the meaning, tone, names, numbers and emoji exactly. Do not add anything. \
        Reply with the rewritten message only.
        """
        var prompt = ""
        if let context, !context.isEmpty {
            prompt += "The other person said: \"\(context.prefix(300))\"\n"
        }
        prompt += "Message: \(text.prefix(600))"
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let out = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            guard !out.isEmpty, out.count < text.count * 4 + 60 else { return nil }
            return out
        } catch {
            return nil
        }
    }
    #endif
}

// MARK: - Step 3: tone

enum ToneStyler {
    static func apply(_ chinese: String, tone: Tone) -> String {
        var s = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tone {
        case .casual:
            s = replaceRespectful(s, polite: false)
            // People rarely end a chat message with a full stop.
            if s.hasSuffix("。") && s.filter({ $0 == "。" }).count == 1 { s.removeLast() }
        case .polite, .business:
            s = replaceRespectful(s, polite: true)
        }
        return s
    }

    /// 你 ↔ 您, leaving the plural 你们 alone (您们 sounds wrong).
    private static func replaceRespectful(_ text: String, polite: Bool) -> String {
        var out = ""
        let chars = Array(text)
        for (i, c) in chars.enumerated() {
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if polite, c == "你", next != "们" { out.append("您") }
            else if !polite, c == "您" { out.append("你") }
            else { out.append(c) }
        }
        return out
    }
}

// MARK: - Pinyin (on-device)

enum Pinyin {
    static func of(_ text: String) -> String {
        let mutable = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        let latin = (mutable as String)
        // Turn Chinese punctuation into spaced Latin punctuation for readability.
        let map: [Character: String] = ["，": ",", "。": ".", "？": "?", "！": "!", "：": ":", "；": ";"]
        var out = ""
        for ch in latin { out += map[ch] ?? String(ch) }
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}
