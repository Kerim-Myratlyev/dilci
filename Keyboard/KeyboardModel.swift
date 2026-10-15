import UIKit
import SwiftUI

enum StripState: Equatable {
    case idle
    case loading(previous: TranslationResult?)
    case ready(TranslationResult)
    case inserted(TranslationResult, original: String)
    case understood(TranslationResult)
    case needsDownload(String)
    case failed(String)
}

/// State for the translation strip only. Typing never touches SwiftUI: keys
/// live in `KeyGridView`, and this model only hears about text changes after
/// a short pause.
@MainActor
final class KeyboardModel: ObservableObject {
    @Published var state: StripState = .idle
    @Published var tone: Tone {
        didSet {
            settings.keyboardTone = tone
            if oldValue != tone { lastRequest = nil; refresh() }
        }
    }
    @Published var replyContext: String?
    @Published var showMeaning = false
    @Published private(set) var swipeAlternatives: [String] = []

    let settings = DilciSettings.shared
    private weak var controller: UIInputViewController?
    private var work: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private var lastRequest: TranslationRequest?
    private var lastInserted: String?
    private var lastSwiped: String?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(controller: UIInputViewController) {
        self.controller = controller
        self.tone = DilciSettings.shared.keyboardTone
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }

    // MARK: - Text changes

    /// Called on every keystroke. Cheap: it only restarts a timer.
    func textChanged(delay: Double = 0.55) {
        if !swipeAlternatives.isEmpty { swipeAlternatives = [] }
        lastSwiped = nil
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    func didSwipe(word: String, alternatives: [String]) {
        textChanged()
        swipeAlternatives = alternatives
        lastSwiped = word
    }

    func pickAlternative(_ word: String) {
        guard let proxy, let current = lastSwiped else { return }
        tap()
        for _ in 0..<current.count { proxy.deleteBackward() }
        proxy.insertText(word)
        swipeAlternatives = swipeAlternatives.filter { $0 != word } + [current]
        lastSwiped = word
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    // MARK: - Reading the field

    private func fieldText() -> (text: String, isSelection: Bool) {
        guard let proxy else { return ("", false) }
        if let selected = proxy.selectedText, !selected.isEmpty { return (selected, true) }
        return ((proxy.documentContextBeforeInput ?? "") + (proxy.documentContextAfterInput ?? ""), false)
    }

    // MARK: - Translating

    func refresh() {
        let text = fieldText().text.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            work?.cancel()
            lastRequest = nil
            if case .understood = state { return }
            if state != .idle { state = .idle }
            return
        }
        if let lastInserted, text == lastInserted.trimmingCharacters(in: .whitespacesAndNewlines) { return }

        let source = Lang.detect(text)
        let target: Lang = source == .chinese ? settings.nativeLanguage : .chinese
        let request = TranslationRequest(text: text, source: source, target: target,
                                         tone: tone, replyingTo: replyContext)
        if request == lastRequest, !isFailed { return }
        run(request, understood: false)
    }

    private var isFailed: Bool {
        switch state {
        case .failed, .needsDownload: return true
        default: return false
        }
    }

    private func run(_ request: TranslationRequest, understood: Bool) {
        work?.cancel()
        if !understood { lastRequest = request }
        let previous = currentResult
        work = Task { [weak self] in
            guard let self else { return }
            self.state = .loading(previous: previous)
            do {
                let result = try await DilciTranslator.shared.translate(request)
                guard !Task.isCancelled else { return }
                self.showMeaning = false
                self.state = understood ? .understood(result) : .ready(result)
            } catch {
                guard !Task.isCancelled else { return }
                self.lastRequest = nil
                if let engineError = error as? EngineError, case .notDownloaded = engineError {
                    self.state = .needsDownload(error.localizedDescription)
                } else {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    var currentResult: TranslationResult? {
        switch state {
        case .ready(let r), .understood(let r), .inserted(let r, _): return r
        case .loading(let p): return p
        default: return nil
        }
    }

    func retry() {
        tap()
        lastRequest = nil
        refresh()
    }

    // MARK: - Actions

    /// Replace what you wrote with the Chinese.
    func insertTranslation() {
        guard case .ready(let result) = state, let proxy else { return }
        let (raw, isSelection) = fieldText()
        tap()
        if isSelection {
            proxy.insertText(result.translation)
        } else {
            let after = proxy.documentContextAfterInput ?? ""
            if !after.isEmpty { proxy.adjustTextPosition(byCharacterOffset: after.count) }
            for _ in 0..<raw.count { proxy.deleteBackward() }
            proxy.insertText(result.translation)
        }
        lastInserted = result.translation
        lastRequest = nil
        swipeAlternatives = []
        state = .inserted(result, original: raw)
        if hasFullAccess {
            DispatchQueue.global(qos: .utility).async { PhraseStore().add(result) }
        }
    }

    func undoInsert() {
        guard case .inserted(let result, let original) = state, let proxy else { return }
        tap()
        for _ in 0..<result.translation.count { proxy.deleteBackward() }
        proxy.insertText(original)
        lastInserted = nil
        lastRequest = TranslationRequest(text: original.trimmingCharacters(in: .whitespacesAndNewlines),
                                         source: result.source, target: result.target,
                                         tone: result.tone, replyingTo: replyContext)
        state = .ready(result)
    }

    func understandClipboard() {
        tap()
        guard hasFullAccess else {
            state = .failed("Turn on Allow Full Access to read copied messages.")
            return
        }
        guard let copied = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copied.isEmpty else {
            state = .failed("Copy their message first. Press and hold it, then Copy.")
            return
        }
        replyContext = copied
        let source = Lang.detect(copied)
        let target: Lang = source == .chinese ? settings.nativeLanguage : .chinese
        run(TranslationRequest(text: copied, source: source, target: target, tone: tone, replyingTo: nil),
            understood: true)
    }

    func clearReplyContext() {
        tap()
        replyContext = nil
        if case .understood = state { state = .idle }
        lastRequest = nil
        refresh()
    }

    func dismissUnderstood() {
        tap()
        state = .idle
        lastRequest = nil
        refresh()
    }

    func tap() {
        guard hasFullAccess else { return }
        haptic.impactOccurred(intensity: 0.6)
    }
}
