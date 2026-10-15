import SwiftUI

struct PhrasesView: View {
    @EnvironmentObject private var phrases: PhraseStore
    @State private var filter: Filter = .saved
    @State private var query = ""
    @State private var copied: UUID?
    @AppStorage(SettingsKey.showPinyin, store: DilciSettings.shared.defaults) private var showPinyin = true

    enum Filter: String, CaseIterable, Identifiable {
        case saved = "Saved", recent = "Recent"
        var id: String { rawValue }
    }

    private var items: [TranslationResult] {
        let base = filter == .saved ? phrases.items.filter(\.starred) : phrases.items
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.original.lowercased().contains(q) || $0.translation.contains(q)
                || $0.pinyin.lowercased().contains(q) || $0.back.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            row(item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { phrases.delete(item.id) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { phrases.toggleStar(item.id) } label: {
                                        Label(item.starred ? "Unsave" : "Save",
                                              systemImage: item.starred ? "bookmark.slash" : "bookmark")
                                    }
                                    .tint(Palette.accent)
                                }
                        }
                    } footer: {
                        Text("Tap a phrase to copy it. Swipe right to save, left to delete.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.canvas)
            .overlay {
                if items.isEmpty { emptyState }
            }
            .searchable(text: $query, prompt: "Search phrases")
            .navigationTitle("Phrasebook")
            .toolbar {
                if filter == .recent && phrases.items.contains(where: { !$0.starred }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Recent", role: .destructive) { phrases.clearRecent() }
                    }
                }
            }
            .onAppear { phrases.reload() }
        }
    }

    private func row(_ item: TranslationResult) -> some View {
        Button {
            UIPasteboard.general.string = item.translation
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { copied = item.id }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.translation)
                        .font(item.target == .chinese ? Typeface.hanzi : Typeface.headline)
                        .foregroundStyle(Palette.text)
                    if showPinyin && !item.pinyin.isEmpty {
                        Text(item.pinyin)
                            .font(Typeface.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Text(item.original)
                        .font(Typeface.footnote)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if copied == item.id {
                    Image(systemName: "checkmark")
                        .font(Typeface.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                } else if item.starred {
                    Image(systemName: "bookmark.fill")
                        .font(Typeface.footnote)
                        .foregroundStyle(Palette.accent)
                        .accessibilityLabel("Saved")
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if filter == .saved {
            ContentUnavailableView {
                Label("No saved phrases", systemImage: "bookmark")
            } description: {
                Text("Save the lines you send every day: your address, your order, how much is this. Tap the bookmark under any translation.")
            }
        } else {
            ContentUnavailableView {
                Label("Nothing translated yet", systemImage: "clock")
            } description: {
                Text("Everything you insert with the keyboard or translate in the app shows up here.")
            }
        }
    }
}
