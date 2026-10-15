import SwiftUI
import Translation

enum EngineError: LocalizedError {
    case notDownloaded(Lang, Lang)
    case unsupported
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notDownloaded(let a, let b):
            return "Download \(a.englishName) and \(b.englishName) once in the Dilçi app."
        case .unsupported:
            return "This language pair isn't available on this iPhone."
        case .timedOut:
            return "Translation took too long. Try again."
        case .failed(let message):
            return message
        }
    }
}

/// Bridge to Apple's on-device Translation framework (iOS 18+).
///
/// Apple hands out a `TranslationSession` only through the `.translationTask`
/// view modifier, so requests are queued here, the configuration is bumped,
/// and the modifier drains the queue with the session it receives.
/// Free, private, and fully offline once the languages are downloaded.
@MainActor
final class TranslationEngine: ObservableObject {
    static let shared = TranslationEngine()

    @Published fileprivate(set) var configuration: TranslationSession.Configuration?
    @Published private(set) var preparing: Set<String> = []

    private struct Job {
        let id = UUID()
        let text: String
        let source: Lang
        let target: Lang
        let prepareOnly: Bool
        let continuation: CheckedContinuation<String, Error>
    }

    private var jobs: [Job] = []
    private var running = false

    // MARK: Public API

    func translate(_ text: String, from source: Lang, to target: Lang) async throws -> String {
        guard !text.isEmpty else { return "" }
        return try await enqueue(text: text, source: source, target: target, prepareOnly: false, timeout: 25)
    }

    /// Ask iOS to download the language pair. In the app this shows the
    /// system download sheet.
    func prepare(_ source: Lang, _ target: Lang) async throws {
        let key = Self.key(source, target)
        preparing.insert(key)
        defer { preparing.remove(key) }
        _ = try await enqueue(text: "", source: source, target: target, prepareOnly: true, timeout: 600)
    }

    func isPreparing(_ source: Lang, _ target: Lang) -> Bool {
        preparing.contains(Self.key(source, target))
    }

    nonisolated static func status(_ source: Lang, _ target: Lang) async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: source.locale, to: target.locale)
    }

    // MARK: Queue

    private static func key(_ a: Lang, _ b: Lang) -> String { a.rawValue + ">" + b.rawValue }

    private func enqueue(text: String, source: Lang, target: Lang,
                         prepareOnly: Bool, timeout: Double) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let job = Job(text: text, source: source, target: target,
                          prepareOnly: prepareOnly, continuation: continuation)
            jobs.append(job)
            if !running { trigger(source: source, target: target) }
            let id = job.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.expire(id)
            }
        }
    }

    private func expire(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        let job = jobs.remove(at: index)
        job.continuation.resume(throwing: EngineError.timedOut)
    }

    private func trigger(source: Lang, target: Lang) {
        if var current = configuration, current.source == source.locale, current.target == target.locale {
            current.invalidate()
            configuration = current
        } else {
            configuration = TranslationSession.Configuration(source: source.locale, target: target.locale)
        }
    }

    /// Called by `.translationTask` with a live session for `configuration`.
    fileprivate func drain(_ session: TranslationSession) async {
        guard let config = configuration else { return }
        running = true
        defer {
            running = false
            if let next = jobs.first { trigger(source: next.source, target: next.target) }
        }

        while let index = jobs.firstIndex(where: { $0.source.locale == config.source && $0.target.locale == config.target }) {
            let job = jobs.remove(at: index)
            do {
                if job.prepareOnly {
                    try await session.prepareTranslation()
                    job.continuation.resume(returning: "")
                } else {
                    let response = try await session.translate(job.text)
                    job.continuation.resume(returning: response.targetText)
                }
            } catch {
                let status = await Self.status(job.source, job.target)
                switch status {
                case .supported: job.continuation.resume(throwing: EngineError.notDownloaded(job.source, job.target))
                case .unsupported: job.continuation.resume(throwing: EngineError.unsupported)
                default: job.continuation.resume(throwing: EngineError.failed(error.localizedDescription))
                }
            }
        }
    }
}

/// Attach once near the root of any view tree that translates.
@MainActor
struct TranslationHost: ViewModifier {
    @ObservedObject var engine = TranslationEngine.shared

    func body(content: Content) -> some View {
        content.translationTask(engine.configuration) { session in
            await engine.drain(session)
        }
    }
}

extension View {
    func translationHost() -> some View { modifier(TranslationHost()) }
}
