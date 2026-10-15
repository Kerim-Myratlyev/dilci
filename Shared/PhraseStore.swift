import Foundation
import Combine

/// Recent and starred translations, stored as JSON in the shared App Group
/// container so both the keyboard and the app see the same list.
final class PhraseStore: ObservableObject {
    @Published private(set) var items: [TranslationResult] = []

    private let limit = 300
    private let fileURL: URL?

    init(settings: DilciSettings = .shared) {
        fileURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: settings.appGroup)?
            .appendingPathComponent("phrases.json")
        reload()
    }

    func reload() {
        items = Self.read(fileURL)
    }

    func add(_ result: TranslationResult) {
        var current = Self.read(fileURL)
        if let i = current.firstIndex(where: { $0.id == result.id }) {
            var existing = current.remove(at: i)
            existing.date = Date()
            current.insert(existing, at: 0)
        } else {
            // Keep one entry per (original, translation) pair; newest wins.
            current.removeAll { $0.original == result.original && $0.translation == result.translation && !$0.starred }
            current.insert(result, at: 0)
        }
        if current.count > limit {
            let starred = current.filter(\.starred)
            let recent = current.filter { !$0.starred }.prefix(limit - min(starred.count, limit))
            current = (starred + recent).sorted { $0.date > $1.date }
        }
        write(current)
    }

    func toggleStar(_ id: UUID) {
        var current = Self.read(fileURL)
        guard let i = current.firstIndex(where: { $0.id == id }) else { return }
        current[i].starred.toggle()
        write(current)
    }

    func isStarred(_ id: UUID) -> Bool {
        items.first(where: { $0.id == id })?.starred ?? false
    }

    func delete(_ id: UUID) {
        var current = Self.read(fileURL)
        current.removeAll { $0.id == id }
        write(current)
    }

    func clearRecent() {
        write(Self.read(fileURL).filter(\.starred))
    }

    private func write(_ list: [TranslationResult]) {
        if Thread.isMainThread { items = list } else { DispatchQueue.main.async { self.items = list } }
        guard let url = fileURL, let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func read(_ url: URL?) -> [TranslationResult] {
        guard let url, let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([TranslationResult].self, from: data) else { return [] }
        return list
    }
}
