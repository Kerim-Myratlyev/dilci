import SwiftUI
import AVFoundation

// MARK: - Model

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    let mine: Bool
    let result: TranslationResult
}

enum Speaker: String, CaseIterable, Identifiable {
    case me, them
    var id: String { rawValue }
    var title: String { self == .me ? "Me" : "Them" }
}

@MainActor
final class ConversationModel: ObservableObject {
    @Published var lines: [ChatLine] = []
    @Published var input = ""
    @Published var speaker: Speaker = .me
    @Published var tone: Tone = DilciSettings.shared.defaultTone
    @Published var loading = false
    @Published var error: String?

    private let speech = AVSpeechSynthesizer()

    var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading }

    /// Their latest message, used as context for your reply.
    private var lastTheirs: String? { lines.last(where: { !$0.mine })?.result.original }

    func send(store: PhraseStore) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let native = DilciSettings.shared.nativeLanguage
        let source = Lang.detect(text)
        let mine = speaker == .me
        let target: Lang = source == .chinese ? native : .chinese
        let request = TranslationRequest(text: text, source: source, target: target, tone: tone,
                                         replyingTo: mine ? lastTheirs : nil)
        loading = true
        error = nil
        Task {
            defer { loading = false }
            do {
                let result = try await DilciTranslator.shared.translate(request)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    lines.append(ChatLine(mine: mine, result: result))
                }
                input = ""
                if mine { store.add(result) }
                // After their message, you're probably replying.
                if !mine { speaker = .me }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func speak(_ text: String, lang: Lang) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang.speechCode)
        utterance.rate = lang == .chinese ? 0.42 : 0.48
        speech.speak(utterance)
    }

    func clear() {
        withAnimation(.easeOut(duration: 0.2)) { lines.removeAll() }
        error = nil
    }
}

// MARK: - View

struct ConversationView: View {
    @StateObject private var model = ConversationModel()
    @EnvironmentObject private var phrases: PhraseStore
    @EnvironmentObject private var packs: LanguagePacks
    @FocusState private var focused: Bool
    @State private var copied: UUID?
    @AppStorage(SettingsKey.showPinyin, store: DilciSettings.shared.defaults) private var showPinyin = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if !packs.nativeReady { downloadBanner }
                        if model.lines.isEmpty {
                            emptyState
                        } else {
                            ForEach(model.lines) { line in
                                bubble(line, isLast: line.id == model.lines.last?.id)
                                    .id(line.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                        }
                        if let error = model.error {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(Typeface.footnote)
                                .foregroundStyle(Palette.warning)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Palette.canvas)
                .onChange(of: model.lines.count) { _, _ in
                    if let last = model.lines.last {
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle("Dilçi")
            .toolbar {
                if !model.lines.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", action: model.clear)
                    }
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Write the way you text.")
                .font(Typeface.title)
                .foregroundStyle(Palette.text)
            Text("Shorthand is fine. Dilçi works out what you mean and writes natural Chinese, on your iPhone, for free.")
                .font(Typeface.callout)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(["see u tmrw at the gate, ok?", "can u send me the address pls", "щас буду, 5 мин"], id: \.self) { sample in
                    Button {
                        model.speaker = .me
                        model.input = sample
                        focused = true
                    } label: {
                        HStack(spacing: 10) {
                            Text(sample)
                                .font(Typeface.callout)
                                .foregroundStyle(Palette.text)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.left")
                                .font(.system(.caption).weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
                    }
                    .buttonStyle(PressScale())
                }
            }
            Text("Got a message in Chinese? Switch to Them and paste it.")
                .font(Typeface.footnote)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.top, 24)
    }

    private var downloadBanner: some View {
        let pair = LanguagePacks.Pair(from: DilciSettings.shared.nativeLanguage, to: .chinese)
        let state = packs.state(pair)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Download Chinese once")
                    .font(Typeface.subhead.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text("Then translation works offline, in the app and on the keyboard.")
                    .font(Typeface.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if state == .downloading {
                ProgressView()
            } else {
                Button("Get") { packs.download(pair) }
                    .font(Typeface.subhead.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Palette.accent)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
    }

    // MARK: Bubbles

    @ViewBuilder
    private func bubble(_ line: ChatLine, isLast: Bool) -> some View {
        let r = line.result
        HStack {
            if line.mine { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 8) {
                if line.mine {
                    // You: the Chinese you will send is the headline.
                    Text(r.translation)
                        .font(r.target == .chinese ? Typeface.hanziLarge : Typeface.title)
                        .foregroundStyle(Palette.text)
                        .textSelection(.enabled)
                    if showPinyin && !r.pinyin.isEmpty {
                        Text(r.pinyin)
                            .font(Typeface.pinyin)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Hairline()
                    Text(r.original)
                        .font(Typeface.footnote)
                        .foregroundStyle(Palette.textTertiary)
                    if !r.back.isEmpty && r.back.lowercased() != r.original.lowercased() {
                        Text("Reads as: \(r.back)")
                            .font(Typeface.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                } else {
                    // Them: their words, then what they mean.
                    Text(r.original)
                        .font(r.source == .chinese ? Typeface.hanzi : Typeface.body)
                        .foregroundStyle(Palette.text)
                        .textSelection(.enabled)
                    if showPinyin && !r.pinyin.isEmpty {
                        Text(r.pinyin)
                            .font(Typeface.pinyin)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Hairline()
                    Text(r.translation)
                        .font(Typeface.body.weight(.medium))
                        .foregroundStyle(Palette.text)
                }
                if !r.note.isEmpty {
                    Label(r.note, systemImage: "info.circle")
                        .font(Typeface.footnote)
                        .foregroundStyle(Palette.accent)
                }
                if isLast { actions(for: line) }
            }
            .padding(14)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(line.mine ? Palette.surface : Palette.surfaceMuted)
            )
            .contextMenu { menu(for: line) }
            if !line.mine { Spacer(minLength: 36) }
        }
    }

    private func actions(for line: ChatLine) -> some View {
        let r = line.result
        let spoken = line.mine ? r.translation : r.original
        let spokenLang = line.mine ? r.target : r.source
        let starred = phrases.isStarred(r.id)
        return HStack(spacing: 4) {
            iconButton(copied == line.id ? "checkmark" : "doc.on.doc", label: "Copy") {
                UIPasteboard.general.string = r.translation
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { copied = line.id }
            }
            iconButton("speaker.wave.2", label: "Listen") {
                model.speak(spoken, lang: spokenLang)
            }
            if line.mine {
                iconButton(starred ? "bookmark.fill" : "bookmark", label: starred ? "Remove from Phrasebook" : "Save to Phrasebook") {
                    phrases.toggleStar(r.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(.top, 2)
        .padding(.leading, -10)
    }

    private func iconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(.callout).weight(.medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func menu(for line: ChatLine) -> some View {
        let r = line.result
        Button { UIPasteboard.general.string = r.translation } label: {
            Label("Copy translation", systemImage: "doc.on.doc")
        }
        Button { UIPasteboard.general.string = r.original } label: {
            Label("Copy original", systemImage: "text.quote")
        }
        Button { model.speak(line.mine ? r.translation : r.original, lang: line.mine ? r.target : r.source) } label: {
            Label("Listen", systemImage: "speaker.wave.2")
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Picker("Who is writing", selection: $model.speaker) {
                    ForEach(Speaker.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 128)
                Spacer(minLength: 0)
                if model.speaker == .me {
                    ToneSwitch(tone: $model.tone)
                        .transition(.opacity)
                } else if model.input.isEmpty {
                    Button {
                        model.input = UIPasteboard.general.string ?? ""
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(Typeface.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Palette.text)
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.speaker)

            HStack(alignment: .bottom, spacing: 8) {
                TextField(model.speaker == .me ? "Message in English or Russian" : "Their message",
                          text: $model.input, axis: .vertical)
                    .font(Typeface.body)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                    .submitLabel(.send)
                    .onSubmit { model.send(store: phrases) }

                Button {
                    model.send(store: phrases)
                } label: {
                    ZStack {
                        Circle().fill(model.canSend ? Palette.accent : Palette.surfaceMuted)
                        if model.loading {
                            ProgressView().tint(Palette.onAccent)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(.body).weight(.bold))
                                .foregroundStyle(model.canSend ? Palette.onAccent : Palette.textTertiary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(PressScale())
                .disabled(!model.canSend)
                .accessibilityLabel("Translate")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Palette.canvas)
    }
}
