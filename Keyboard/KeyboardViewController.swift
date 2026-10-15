import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController, KeyGridDelegate {
    private lazy var model = KeyboardModel(controller: self)
    private var grid: KeyGridView!
    private var host: UIHostingController<KeyboardRootView>?

    override func loadView() {
        // A UIInputView that adopts UIInputViewAudioFeedback gives us the
        // system key click.
        let root = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
        root.allowsSelfSizing = true
        inputView = root
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.keyBedUI

        // Translation strip (SwiftUI, updates only when the translation changes)
        let host = UIHostingController(rootView: KeyboardRootView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        self.host = host

        // Keys (UIKit, handles every touch itself)
        let letters = KeyLayout(rawValue: DilciSettings.shared.defaults.string(forKey: SettingsKey.keyboardLetters) ?? "") ?? .latin
        let grid = KeyGridView(letters: letters)
        grid.delegate = self
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)   // above the strip, so key previews can overlap it
        self.grid = grid

        let height = view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.totalHeight)
        height.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.stripHeight),

            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            grid.topAnchor.constraint(equalTo: host.view.bottomAnchor),
            grid.heightAnchor.constraint(equalToConstant: KeyboardMetrics.keysHeight),
            height,
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        grid.syncWithHost()
        grid.warmUp()
        model.refresh()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        grid.needsGlobe = needsInputModeSwitchKey
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        grid.syncWithHost()
        model.textChanged(delay: 0.3)
    }

    // MARK: KeyGridDelegate

    var textProxy: UITextDocumentProxy { textDocumentProxy }

    func gridDidEditText() {
        model.textChanged()
    }

    func gridDidSwipe(word: String, alternatives: [String]) {
        model.didSwipe(word: word, alternatives: alternatives)
    }

    func gridHandleGlobe(from view: UIView, with event: UIEvent) {
        handleInputModeList(from: view, with: event)
    }
}
