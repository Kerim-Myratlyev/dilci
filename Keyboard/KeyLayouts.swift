import UIKit

enum KeyLayout: String {
    case latin, cyrillic, numbers, symbols

    var isLetters: Bool { self == .latin || self == .cyrillic }
}

enum ShiftState { case off, on, locked }

enum KeyKind: Equatable {
    case char(String)
    case shift
    case delete
    case space
    case ret
    case modeSwitch      // 123 / ABC
    case symbolSwitch    // #+= / 123
    case language        // EN / RU
    case globe

    var isChar: Bool { if case .char = self { return true } else { return false } }
}

enum KeyboardMetrics {
    static let stripHeight: CGFloat = 102
    static let keyHeight: CGFloat = 43
    static let rowSpacing: CGFloat = 11
    static let keySpacing: CGFloat = 6
    static let sideInset: CGFloat = 3
    static let keysTop: CGFloat = 6
    static let keysBottom: CGFloat = 4
    static var keysHeight: CGFloat { keysTop + keyHeight * 4 + rowSpacing * 3 + keysBottom }
    static var totalHeight: CGFloat { stripHeight + keysHeight }
}

enum Rows {
    static let latin = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    static let cyrillic = [
        ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х"],
        ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
        ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
    ]
    static let numbers = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "¥", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]
    static let symbols = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "$", "£", "•"],
        [".", ",", "?", "!", "'"],
    ]

    static func rows(for layout: KeyLayout) -> [[String]] {
        switch layout {
        case .latin: return latin
        case .cyrillic: return cyrillic
        case .numbers: return numbers
        case .symbols: return symbols
        }
    }

    /// Press and hold for these, like the system keyboard.
    static let alternates: [String: String] = ["е": "ё", "ь": "ъ", "e": "é", "a": "à", "u": "ü", "o": "ö", "n": "ñ", "c": "ç"]
}

/// A placed key: what it is and where it sits.
struct PlacedKey {
    let kind: KeyKind
    let frame: CGRect
    let row: Int
}

enum KeyPlacer {
    static func place(layout: KeyLayout, width: CGFloat, needsGlobe: Bool) -> [PlacedKey] {
        let m = KeyboardMetrics.self
        let s = m.keySpacing
        let available = width - m.sideInset * 2
        let rows = Rows.rows(for: layout)
        let columns = CGFloat(max(rows[0].count, rows[1].count))
        let unit = (available - s * (columns - 1)) / columns
        let baseUnit = (available - s * 9) / 10
        var keys: [PlacedKey] = []

        func y(_ row: Int) -> CGFloat { m.keysTop + CGFloat(row) * (m.keyHeight + m.rowSpacing) }

        // Rows 0 and 1: centered letters
        for r in 0..<2 {
            let count = CGFloat(rows[r].count)
            let rowWidth = count * unit + (count - 1) * s
            var x = m.sideInset + (available - rowWidth) / 2
            for k in rows[r] {
                keys.append(PlacedKey(kind: .char(k), frame: CGRect(x: x, y: y(r), width: unit, height: m.keyHeight), row: r))
                x += unit + s
            }
        }

        // Row 2: function key, letters, delete
        let third = rows[2]
        let count = CGFloat(third.count)
        let letterWidth = layout.isLetters ? unit : unit * 1.38
        let fn = max(unit, (available - count * letterWidth - (count + 1) * s) / 2)
        keys.append(PlacedKey(kind: layout.isLetters ? .shift : .symbolSwitch,
                              frame: CGRect(x: m.sideInset, y: y(2), width: fn, height: m.keyHeight), row: 2))
        let lettersWidth = count * letterWidth + (count - 1) * s
        var x = m.sideInset + (available - lettersWidth) / 2
        for k in third {
            keys.append(PlacedKey(kind: .char(k), frame: CGRect(x: x, y: y(2), width: letterWidth, height: m.keyHeight), row: 2))
            x += letterWidth + s
        }
        keys.append(PlacedKey(kind: .delete,
                              frame: CGRect(x: width - m.sideInset - fn, y: y(2), width: fn, height: m.keyHeight), row: 2))

        // Row 3: 123, globe, language, space, return
        let small = baseUnit * 1.25
        let ret = baseUnit * 2.1
        var left: [KeyKind] = [.modeSwitch]
        if needsGlobe { left.append(.globe) }
        left.append(.language)
        x = m.sideInset
        for kind in left {
            keys.append(PlacedKey(kind: kind, frame: CGRect(x: x, y: y(3), width: small, height: m.keyHeight), row: 3))
            x += small + s
        }
        let retX = width - m.sideInset - ret
        keys.append(PlacedKey(kind: .space, frame: CGRect(x: x, y: y(3), width: retX - s - x, height: m.keyHeight), row: 3))
        keys.append(PlacedKey(kind: .ret, frame: CGRect(x: retX, y: y(3), width: ret, height: m.keyHeight), row: 3))
        return keys
    }
}
