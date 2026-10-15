import UIKit

@MainActor
protocol KeyGridDelegate: AnyObject {
    var textProxy: UITextDocumentProxy { get }
    var hasFullAccess: Bool { get }
    func gridDidEditText()
    func gridDidSwipe(word: String, alternatives: [String])
    func gridHandleGlobe(from view: UIView, with event: UIEvent)
}

private enum KeyColors {
    static let cap      = UIColor.dynamic(light: 0xFDFDFE, dark: 0x5A5A5F)
    static let capFn    = UIColor.dynamic(light: 0xA9AEB8, dark: 0x3A3A3E)
    static let shadow   = UIColor.dynamic(light: 0x898A8E, dark: 0x0A0A0B)
    static let text     = UIColor.dynamic(light: 0x18181B, dark: 0xF4F4F5)
    static let faint    = UIColor.dynamic(light: 0x71717A, dark: 0xA1A1AA)
    static let accent   = UIColor.dynamic(light: 0x07875C, dark: 0x34D399)
}

// MARK: - A single key (pure drawing, no gestures)

private final class KeyCellView: UIView {
    let kind: KeyKind
    let label = UILabel()
    let icon = UIImageView()
    var isLit = false { didSet { refreshBackground() } }
    var isPressed = false { didSet { if oldValue != isPressed { refreshBackground() } } }

    init(kind: KeyKind) {
        self.kind = kind
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = 5.5
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = 1
        label.textAlignment = .center
        label.textColor = KeyColors.text
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        icon.contentMode = .center
        icon.tintColor = KeyColors.text
        addSubview(label)
        addSubview(icon)
        refreshBackground()
        updateShadowColor()
    }

    required init?(coder: NSCoder) { fatalError() }

    var isFunction: Bool {
        switch kind {
        case .char, .space: return false
        default: return true
        }
    }

    func refreshBackground() {
        if isPressed {
            backgroundColor = isFunction ? KeyColors.cap : KeyColors.capFn
        } else {
            backgroundColor = (isFunction && !isLit) ? KeyColors.capFn : KeyColors.cap
        }
    }

    func updateShadowColor() {
        layer.shadowColor = KeyColors.shadow.resolvedColor(with: traitCollection).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let lowercaseNudge: CGFloat = (kind.isChar && label.text == label.text?.lowercased() && label.text?.uppercased() != label.text) ? -1.5 : 0
        label.frame = bounds.insetBy(dx: 2, dy: 0).offsetBy(dx: 0, dy: lowercaseNudge)
        icon.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 5.5).cgPath
    }
}

// MARK: - The press preview balloon

private final class KeyPopupView: UIView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = KeyColors.cap
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        label.textAlignment = .center
        label.textColor = KeyColors.text
        label.font = .systemFont(ofSize: 32, weight: .regular)
        addSubview(label)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.offsetBy(dx: 0, dy: -2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 9).cgPath
    }
}

// MARK: - The grid

/// All keys in one UIKit view. Touches are tracked by hand, which keeps typing
/// light and makes multi-finger rollover, swipe typing and the space-bar
/// trackpad possible.
final class KeyGridView: UIView {
    weak var delegate: KeyGridDelegate?

    private(set) var layout: KeyLayout = .latin
    private(set) var letterLayout: KeyLayout = .latin
    private(set) var shift: ShiftState = .on { didSet { if oldValue != shift { updateLabels() } } }
    var needsGlobe = true { didSet { if oldValue != needsGlobe { rebuild() } } }
    private var returnTitle = "return"

    private var placed: [PlacedKey] = []
    private var cells: [KeyCellView] = []
    private var builtWidth: CGFloat = 0
    private var letterUnit: CGFloat = 32

    private let popup = KeyPopupView()
    private let trail = CAShapeLayer()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    private final class Tracked {
        var key: Int?
        let start: CGPoint
        var points: [CGPoint]
        var isSwipe = false
        var isTrackpad = false
        var trackAnchor = CGPoint.zero
        var alternate = false
        var timer: Timer?
        var repeats = 0

        init(key: Int?, start: CGPoint) {
            self.key = key
            self.start = start
            self.points = [start]
        }
    }

    private var active: [ObjectIdentifier: Tracked] = [:]
    private var lastShiftTap: CFTimeInterval = 0
    private var lastSpaceTap: CFTimeInterval = 0

    // MARK: Setup

    init(letters: KeyLayout) {
        super.init(frame: .zero)
        letterLayout = letters
        layout = letters
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        clipsToBounds = false
        backgroundColor = .clear

        trail.fillColor = UIColor.clear.cgColor
        trail.lineWidth = 7
        trail.lineCap = .round
        trail.lineJoin = .round
        trail.opacity = 0
        trail.zPosition = 10
        layer.addSublayer(trail)
        popup.layer.zPosition = 20
        addSubview(popup)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: KeyGridView, _: UITraitCollection) in
            view.cells.forEach { $0.updateShadowColor() }
            view.trail.strokeColor = KeyColors.accent.withAlphaComponent(0.55).resolvedColor(with: view.traitCollection).cgColor
        }
        trail.strokeColor = KeyColors.accent.withAlphaComponent(0.55).resolvedColor(with: traitCollection).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != builtWidth { rebuild() }
    }

    private func rebuild() {
        guard bounds.width > 0 else { return }
        builtWidth = bounds.width
        placed = KeyPlacer.place(layout: layout, width: bounds.width, needsGlobe: needsGlobe)
        if let first = placed.first { letterUnit = first.frame.width }
        cells.forEach { $0.removeFromSuperview() }
        cells = placed.map { p in
            let cell = KeyCellView(kind: p.kind)
            cell.frame = p.frame
            insertSubview(cell, belowSubview: popup)
            return cell
        }
        updateLabels()
    }

    private func setLayout(_ newLayout: KeyLayout) {
        guard newLayout != layout else { return }
        layout = newLayout
        rebuild()
    }

    private func updateLabels() {
        let caps = shift != .off && layout.isLetters
        for cell in cells {
            cell.label.text = nil
            cell.icon.image = nil
            cell.label.textColor = KeyColors.text
            cell.isLit = false
            switch cell.kind {
            case .char(let k):
                cell.label.text = caps ? k.uppercased() : k
                cell.label.font = .systemFont(ofSize: layout.isLetters ? 22.5 : 21, weight: .regular)
            case .shift:
                let name: String
                switch shift {
                case .off: name = "shift"
                case .on: name = "shift.fill"
                case .locked: name = "capslock.fill"
                }
                cell.icon.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
                cell.isLit = shift != .off
            case .delete:
                cell.icon.image = UIImage(systemName: "delete.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
            case .globe:
                cell.icon.image = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
            case .space:
                cell.label.text = letterLayout == .cyrillic ? "Русский" : "English"
                cell.label.font = .systemFont(ofSize: 15)
                cell.label.textColor = KeyColors.faint
            case .ret:
                cell.label.text = returnTitle
                cell.label.font = .systemFont(ofSize: 16)
            case .modeSwitch:
                cell.label.text = layout.isLetters ? "123" : (letterLayout == .cyrillic ? "АБВ" : "ABC")
                cell.label.font = .systemFont(ofSize: 16)
            case .symbolSwitch:
                cell.label.text = layout == .symbols ? "123" : "#+="
                cell.label.font = .systemFont(ofSize: 16)
            case .language:
                cell.label.text = letterLayout == .cyrillic ? "EN" : "RU"
                cell.label.font = .systemFont(ofSize: 15, weight: .semibold)
            }
            cell.setNeedsLayout()
        }
    }

    // MARK: Host environment

    func syncWithHost() {
        guard let proxy = delegate?.textProxy else { return }
        let title: String
        switch proxy.returnKeyType ?? .default {
        case .send: title = "send"
        case .search, .google, .yahoo: title = "search"
        case .go: title = "go"
        case .done: title = "done"
        case .next: title = "next"
        default: title = "return"
        }
        if title != returnTitle {
            returnTitle = title
            updateLabels()
        }
        updateAutoShift()
    }

    // MARK: Hit testing

    private func keyIndex(at p: CGPoint) -> Int? {
        guard !placed.isEmpty else { return nil }
        let m = KeyboardMetrics.self
        let row = min(3, max(0, Int(((p.y - m.keysTop + m.rowSpacing / 2) / (m.keyHeight + m.rowSpacing)).rounded(.down))))
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (i, key) in placed.enumerated() where key.row == row {
            let d: CGFloat = p.x < key.frame.minX ? key.frame.minX - p.x : (p.x > key.frame.maxX ? p.x - key.frame.maxX : 0)
            if d < bestDistance { bestDistance = d; best = i }
        }
        return best
    }

    private func kind(_ index: Int?) -> KeyKind? {
        guard let index, index < placed.count else { return nil }
        return placed[index].kind
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)

            // Rollover: a new finger commits any letter still held down.
            for (id, other) in active where !other.isSwipe && !other.isTrackpad {
                if let k = kind(other.key), k.isChar {
                    commitTap(other)
                    endVisuals(other)
                    active[id] = nil
                }
            }

            let index = keyIndex(at: p)
            let tracked = Tracked(key: index, start: p)
            active[ObjectIdentifier(touch)] = tracked
            guard let index, let k = kind(index) else { continue }
            feedback(click: true)

            switch k {
            case .char(let value):
                cells[index].isPressed = true
                showPopup(for: index, text: displayed(value))
                if Rows.alternates[value] != nil {
                    tracked.timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self, weak tracked] _ in
                        MainActor.assumeIsolated {
                            guard let self, let tracked, !tracked.isSwipe, let alt = Rows.alternates[value] else { return }
                            tracked.alternate = true
                            self.showPopup(for: index, text: self.displayed(alt))
                            self.feedback(click: false)
                        }
                    }
                }
            case .delete:
                cells[index].isPressed = true
                deleteOnce(tracked)
                tracked.timer = Timer.scheduledTimer(withTimeInterval: 0.42, repeats: false) { [weak self, weak tracked] _ in
                    MainActor.assumeIsolated {
                        guard let self, let tracked else { return }
                        tracked.timer = Timer.scheduledTimer(withTimeInterval: 0.085, repeats: true) { [weak self, weak tracked] _ in
                            MainActor.assumeIsolated {
                                guard let self, let tracked else { return }
                                self.deleteOnce(tracked)
                            }
                        }
                    }
                }
            case .shift:
                handleShift()
            case .space:
                cells[index].isPressed = true
                tracked.timer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self, weak tracked] _ in
                    MainActor.assumeIsolated {
                        guard let self, let tracked else { return }
                        self.enterTrackpad(tracked, at: tracked.points.last ?? tracked.start)
                    }
                }
            case .globe:
                cells[index].isPressed = true
                if let event { delegate?.gridHandleGlobe(from: self, with: event) }
            default:
                cells[index].isPressed = true
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let tracked = active[ObjectIdentifier(touch)] else { continue }
            let p = touch.location(in: self)
            tracked.points.append(p)

            if tracked.isTrackpad {
                moveCursor(tracked, to: p)
                continue
            }

            switch kind(tracked.key) {
            case .space?:
                if abs(p.x - tracked.start.x) > 14 { enterTrackpad(tracked, at: p) }
            case .globe?:
                if let event { delegate?.gridHandleGlobe(from: self, with: event) }
            case .char?:
                if layout.isLetters {
                    if !tracked.isSwipe && hypot(p.x - tracked.start.x, p.y - tracked.start.y) > letterUnit * 0.9 {
                        beginSwipe(tracked)
                    }
                    if tracked.isSwipe { drawTrail(tracked.points) }
                } else if let index = keyIndex(at: p), index != tracked.key, kind(index)?.isChar == true {
                    // Slide to correct a key on the number pages.
                    if let old = tracked.key { cells[old].isPressed = false }
                    tracked.key = index
                    cells[index].isPressed = true
                    if case .char(let v)? = kind(index) { showPopup(for: index, text: v) }
                }
            default:
                break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let tracked = active[id] else { continue }
            active[id] = nil
            endVisuals(tracked)

            if tracked.isTrackpad {
                exitTrackpad()
                continue
            }
            switch kind(tracked.key) {
            case .char?:
                if tracked.isSwipe { finishSwipe(tracked) } else { commitTap(tracked) }
            case .space?:
                insertSpace()
            case .ret?:
                delegate?.textProxy.insertText("\n")
                didEdit()
            case .modeSwitch?:
                setLayout(layout.isLetters ? .numbers : letterLayout)
            case .symbolSwitch?:
                setLayout(layout == .symbols ? .numbers : .symbols)
            case .language?:
                letterLayout = letterLayout == .latin ? .cyrillic : .latin
                DilciSettings.shared.defaults.set(letterLayout.rawValue, forKey: SettingsKey.keyboardLetters)
                if layout.isLetters { setLayout(letterLayout) } else { updateLabels() }
                updateAutoShift()
            case .globe?:
                if let event { delegate?.gridHandleGlobe(from: self, with: event) }
            default:
                break
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let tracked = active[id] else { continue }
            active[id] = nil
            endVisuals(tracked)
            if tracked.isTrackpad { exitTrackpad() }
        }
    }

    private func endVisuals(_ tracked: Tracked) {
        tracked.timer?.invalidate()
        tracked.timer = nil
        if let k = tracked.key, k < cells.count { cells[k].isPressed = false }
        popup.isHidden = true
        if tracked.isSwipe { fadeTrail() }
    }

    // MARK: Typing

    private func displayed(_ value: String) -> String {
        (shift != .off && layout.isLetters) ? value.uppercased() : value
    }

    private func commitTap(_ tracked: Tracked) {
        guard case .char(let value)? = kind(tracked.key), let proxy = delegate?.textProxy else { return }
        let char = tracked.alternate ? (Rows.alternates[value] ?? value) : value
        proxy.insertText(displayed(char))
        if shift == .on { shift = .off }
        if !layout.isLetters && char == "'" { setLayout(letterLayout) }
        didEdit()
    }

    private func insertSpace() {
        guard let proxy = delegate?.textProxy else { return }
        let now = CACurrentMediaTime()
        let before = proxy.documentContextBeforeInput ?? ""
        if now - lastSpaceTap < 0.35, before.hasSuffix(" "),
           let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
            proxy.deleteBackward()
            proxy.insertText(". ")
            lastSpaceTap = 0
        } else {
            proxy.insertText(" ")
            lastSpaceTap = now
        }
        if !layout.isLetters { setLayout(letterLayout) }
        didEdit()
    }

    private func deleteOnce(_ tracked: Tracked) {
        guard let proxy = delegate?.textProxy else { return }
        tracked.repeats += 1
        if tracked.repeats > 14 {
            // Held long enough: delete whole words, like the system keyboard.
            let before = proxy.documentContextBeforeInput ?? ""
            var count = 0
            var sawWord = false
            for ch in before.reversed() {
                if ch.isWhitespace || ch.isPunctuation {
                    if sawWord { break }
                } else {
                    sawWord = true
                }
                count += 1
            }
            for _ in 0..<max(1, count) { proxy.deleteBackward() }
        } else {
            proxy.deleteBackward()
        }
        if tracked.repeats > 1 { feedback(click: true) }
        didEdit()
    }

    private func handleShift() {
        let now = CACurrentMediaTime()
        if now - lastShiftTap < 0.3 {
            shift = .locked
        } else {
            shift = shift == .off ? .on : .off
        }
        lastShiftTap = now
    }

    private func didEdit() {
        updateAutoShift()
        delegate?.gridDidEditText()
    }

    private func updateAutoShift() {
        guard shift != .locked, let proxy = delegate?.textProxy, layout.isLetters else { return }
        if proxy.autocapitalizationType == UITextAutocapitalizationType.none {
            shift = .off
            return
        }
        let before = proxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let sentenceStart = trimmed.isEmpty
            || before.hasSuffix("\n")
            || (before.hasSuffix(" ") && [".", "!", "?"].contains(trimmed.last.map(String.init) ?? ""))
        shift = sentenceStart ? .on : .off
    }

    private func feedback(click: Bool) {
        if click { UIDevice.current.playInputClick() }
        if delegate?.hasFullAccess == true { impact.impactOccurred(intensity: 0.55) }
    }

    // MARK: Popup

    private func showPopup(for index: Int, text: String) {
        let key = placed[index].frame
        let width = max(key.width + 18, 46)
        var x = key.midX - width / 2
        x = min(max(2, x), bounds.width - width - 2)
        popup.frame = CGRect(x: x, y: key.minY - 58, width: width, height: 54)
        popup.label.text = text
        popup.isHidden = false
        bringSubviewToFront(popup)
    }

    // MARK: Space-bar trackpad

    private func enterTrackpad(_ tracked: Tracked, at p: CGPoint) {
        guard !tracked.isTrackpad else { return }
        tracked.timer?.invalidate()
        tracked.isTrackpad = true
        tracked.trackAnchor = p
        if let k = tracked.key { cells[k].isPressed = false }
        impact.impactOccurred(intensity: 0.8)
        UIView.animate(withDuration: 0.15) {
            self.cells.forEach { $0.label.alpha = 0; $0.icon.alpha = 0 }
        }
    }

    private func moveCursor(_ tracked: Tracked, to p: CGPoint) {
        guard let proxy = delegate?.textProxy else { return }
        let step: CGFloat = 8
        let dx = p.x - tracked.trackAnchor.x
        let n = Int(dx / step)
        if n != 0 {
            proxy.adjustTextPosition(byCharacterOffset: n)
            tracked.trackAnchor.x += CGFloat(n) * step
        }
        // Vertical moves jump a line at a time.
        let dy = p.y - tracked.trackAnchor.y
        if abs(dy) > 30 {
            moveLine(up: dy < 0, proxy: proxy)
            tracked.trackAnchor.y = p.y
        }
    }

    private func moveLine(up: Bool, proxy: UITextDocumentProxy) {
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let column = before.distance(from: before.lastIndex(of: "\n").map { before.index(after: $0) } ?? before.startIndex,
                                     to: before.endIndex)
        if up {
            guard let lineStart = before.lastIndex(of: "\n") else {
                proxy.adjustTextPosition(byCharacterOffset: -before.count)
                return
            }
            let previous = before[..<lineStart]
            let prevStart = previous.lastIndex(of: "\n").map { previous.index(after: $0) } ?? previous.startIndex
            let prevLength = previous.distance(from: prevStart, to: previous.endIndex)
            let target = min(column, prevLength)
            proxy.adjustTextPosition(byCharacterOffset: -(column + 1 + (prevLength - target)))
        } else {
            guard let newline = after.firstIndex(of: "\n") else {
                proxy.adjustTextPosition(byCharacterOffset: after.count)
                return
            }
            let toEndOfLine = after.distance(from: after.startIndex, to: newline)
            let rest = after[after.index(after: newline)...]
            let nextLength = rest.firstIndex(of: "\n").map { rest.distance(from: rest.startIndex, to: $0) } ?? rest.count
            proxy.adjustTextPosition(byCharacterOffset: toEndOfLine + 1 + min(column, nextLength))
        }
    }

    private func exitTrackpad() {
        UIView.animate(withDuration: 0.15) {
            self.cells.forEach { $0.label.alpha = 1; $0.icon.alpha = 1 }
        }
        didEdit()
    }

    // MARK: Swipe typing

    private func beginSwipe(_ tracked: Tracked) {
        tracked.isSwipe = true
        tracked.timer?.invalidate()
        if let k = tracked.key { cells[k].isPressed = false }
        popup.isHidden = true
        trail.removeAllAnimations()
        trail.opacity = 1
    }

    private func drawTrail(_ points: [CGPoint]) {
        let recent = points.suffix(60)
        guard let first = recent.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for p in recent.dropFirst() { path.addLine(to: p) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trail.path = path.cgPath
        CATransaction.commit()
    }

    private func fadeTrail() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = trail.opacity
        fade.toValue = 0
        fade.duration = 0.25
        trail.opacity = 0
        trail.add(fade, forKey: "fade")
    }

    private func finishSwipe(_ tracked: Tracked) {
        guard let proxy = delegate?.textProxy else { return }
        var keys: [Character: CGPoint] = [:]
        for key in placed {
            if case .char(let v) = key.kind, let c = v.first {
                keys[c] = CGPoint(x: key.frame.midX, y: key.frame.midY)
            }
        }
        let language: Lang = layout == .cyrillic ? .russian : .english
        let candidates = SwipeDecoder.shared.decode(path: tracked.points, keys: keys,
                                                     keyWidth: letterUnit, language: language)
        guard var word = candidates.first else { return }

        let alternatives = Array(candidates.dropFirst().prefix(3)).map { cased($0) }
        word = cased(word)

        let before = proxy.documentContextBeforeInput ?? ""
        let needsSpace = before.last.map { !$0.isWhitespace && !"([\"'“«".contains($0) } ?? false
        proxy.insertText((needsSpace ? " " : "") + word)
        if shift == .on { shift = .off }
        updateAutoShift()
        delegate?.gridDidSwipe(word: word, alternatives: alternatives)
    }

    private func cased(_ word: String) -> String {
        switch shift {
        case .off: return word
        case .on: return word.prefix(1).uppercased() + word.dropFirst()
        case .locked: return word.uppercased()
        }
    }

    /// Prepare the swipe dictionary in the background so the first swipe is instant.
    func warmUp() {
        SwipeDecoder.shared.preload(letterLayout == .cyrillic ? .russian : .english)
    }
}

/// The keyboard's root input view. Adopting UIInputViewAudioFeedback turns on
/// the system key click sound.
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
