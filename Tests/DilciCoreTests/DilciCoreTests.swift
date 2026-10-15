import XCTest
@testable import DilciCore

final class LanguageDetectionTests: XCTestCase {
    func testDetectsScripts() {
        XCTAssertEqual(Lang.detect("see u tmrw"), .english)
        XCTAssertEqual(Lang.detect("привет, как дела"), .russian)
        XCTAssertEqual(Lang.detect("明天见"), .chinese)
    }

    func testHanziWinsInMixedText() {
        XCTAssertEqual(Lang.detect("ok 好的"), .chinese)
    }

    func testEmptyFallsBackToEnglish() {
        XCTAssertEqual(Lang.detect(""), .english)
        XCTAssertEqual(Lang.detect("123 !!"), .english)
    }

    func testChineseLocaleIsSimplified() {
        XCTAssertEqual(Lang.chinese.locale.script?.identifier, "Hans")
    }
}

final class SlangTests: XCTestCase {
    func testEnglishShorthand() {
        XCTAssertEqual(Slang.expand("see u tmrw", language: .english), "see you tomorrow")
        XCTAssertEqual(Slang.expand("Thx", language: .english), "thanks")
    }

    func testNumbersWithUnits() {
        XCTAssertEqual(Slang.expand("thx, see u at 5min", language: .english),
                       "thanks, see you at 5 minutes")
        XCTAssertEqual(Slang.expand("2hrs", language: .english), "2 hours")
    }

    func testWholeWordsOnly() {
        XCTAssertEqual(Slang.expand("unique you", language: .english), "unique you")
    }

    func testRussianShorthand() {
        XCTAssertEqual(Slang.expand("щас буду, 5 мин", language: .russian), "сейчас буду, 5 минут")
        XCTAssertEqual(Slang.expand("спс норм", language: .russian), "спасибо нормально")
    }

    func testChineseIsUntouched() {
        XCTAssertEqual(Slang.expand("明天见 u", language: .chinese), "明天见 u")
    }
}

final class CultureNotesTests: XCTestCase {
    func testKnownPhraseGetsNote() {
        XCTAssertFalse(CultureNotes.note(for: "改天吧", in: .english).isEmpty)
        XCTAssertFalse(CultureNotes.note(for: "麻烦您了", in: .english).isEmpty)
    }

    func testNoteFollowsLanguage() {
        let en = CultureNotes.note(for: "呵呵", in: .english)
        let ru = CultureNotes.note(for: "呵呵", in: .russian)
        XCTAssertNotEqual(en, ru)
        XCTAssertTrue(ru.contains("сарказм"))
    }

    func testNoFalsePositives() {
        // 亲 inside 父亲 (father) is not the shop-assistant "dear".
        XCTAssertEqual(CultureNotes.note(for: "我父亲", in: .english), "")
        // A lone 哦 is curt; 哦哦好的 is friendly.
        XCTAssertFalse(CultureNotes.note(for: "哦。", in: .english).isEmpty)
        XCTAssertEqual(CultureNotes.note(for: "哦哦好的", in: .english), "")
    }
}
