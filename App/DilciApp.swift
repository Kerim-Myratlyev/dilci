import SwiftUI
import Translation

@main
struct DilciApp: App {
    @AppStorage(SettingsKey.onboarded, store: DilciSettings.shared.defaults) private var onboarded = false
    @StateObject private var phrases = PhraseStore()
    @StateObject private var packs = LanguagePacks()

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    RootView()
                } else {
                    OnboardingView { withAnimation(.easeInOut(duration: 0.3)) { onboarded = true } }
                }
            }
            .environmentObject(phrases)
            .environmentObject(packs)
            .tint(Palette.accent)
            .translationHost()
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var phrases: PhraseStore
    @EnvironmentObject private var packs: LanguagePacks
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            ConversationView()
                .tabItem { Label("Translate", systemImage: "bubble.left.and.text.bubble.right") }
            PhrasesView()
                .tabItem { Label("Phrasebook", systemImage: "bookmark") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                phrases.reload()
                Task { await packs.refresh() }
            }
        }
    }
}

// MARK: - Offline language packs

@MainActor
final class LanguagePacks: ObservableObject {
    struct Pair: Hashable, Identifiable {
        let from: Lang
        let to: Lang
        var id: String { from.rawValue + to.rawValue }
        var title: String { "\(from.englishName) and Chinese" }
    }

    enum State: Equatable { case unknown, ready, needsDownload, unsupported, downloading, failed(String) }

    @Published private(set) var states: [Pair: State] = [:]

    static let pairs = [Pair(from: .english, to: .chinese), Pair(from: .russian, to: .chinese)]

    init() { Task { await refresh() } }

    func state(_ pair: Pair) -> State { states[pair] ?? .unknown }

    var nativeReady: Bool {
        let native = DilciSettings.shared.nativeLanguage
        return state(Pair(from: native, to: .chinese)) == .ready
    }

    func refresh() async {
        for pair in Self.pairs where states[pair] != .downloading {
            let forward = await TranslationEngine.status(pair.from, pair.to)
            let back = await TranslationEngine.status(pair.to, pair.from)
            states[pair] = Self.combine(forward, back)
        }
    }

    func download(_ pair: Pair) {
        states[pair] = .downloading
        Task {
            do {
                try await TranslationEngine.shared.prepare(pair.from, pair.to)
                try await TranslationEngine.shared.prepare(pair.to, pair.from)
                states[pair] = nil
                await refresh()
            } catch {
                states[pair] = .failed(error.localizedDescription)
            }
        }
    }

    private static func combine(_ a: LanguageAvailability.Status, _ b: LanguageAvailability.Status) -> State {
        switch (a, b) {
        case (.installed, .installed): return .ready
        case (.unsupported, _), (_, .unsupported): return .unsupported
        default: return .needsDownload
        }
    }
}
