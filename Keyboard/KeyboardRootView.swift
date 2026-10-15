import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        TranslationStrip(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .translationHost()
    }
}

// MARK: - Strip

struct TranslationStrip: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .center, spacing: 10) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.state)
                action
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if !model.swipeAlternatives.isEmpty {
                HStack(spacing: 6) {
                    ForEach(model.swipeAlternatives, id: \.self) { word in
                        Button { model.pickAlternative(word) } label: {
                            Text(word)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                                .padding(.horizontal, 11)
                                .frame(height: 30)
                                .background(Capsule().fill(Palette.stripSurface))
                        }
                        .buttonStyle(PressScale())
                        .accessibilityLabel("Use \(word)")
                    }
                }
            } else if let context = model.replyContext {
                Button(action: model.clearReplyContext) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text(context)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Capsule().fill(Palette.stripSurface))
                    .frame(maxWidth: 160, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Replying to copied message. Double tap to clear.")
            } else {
                Text(directionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.swipeAlternatives.isEmpty {
                ToneSwitch(tone: $model.tone, compact: true)
            }
        }
        .frame(height: 30)
    }

    private var directionLabel: String {
        if case .understood(let r) = model.state { return "They said, in \(r.target.nativeName)" }
        if let r = model.currentResult { return "\(r.source.nativeName) to \(r.target.nativeName)" }
        return "Dilçi"
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            Text("Type in English or Russian.\nThe Chinese appears here.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
        case .loading(let previous):
            HStack(spacing: 10) {
                if let previous {
                    Text(previous.translation)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
                TypingDots()
            }
        case .ready(let r):
            resultView(r)
        case .inserted(let r, _):
            VStack(alignment: .leading, spacing: 2) {
                Label("Inserted", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                if !r.back.isEmpty {
                    Text("Reads as: \(r.back)")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
            }
        case .understood(let r):
            VStack(alignment: .leading, spacing: 2) {
                Text(r.translation)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(r.note.isEmpty ? "Now type your reply." : r.note)
                    .font(.system(size: 12))
                    .foregroundStyle(r.note.isEmpty ? Palette.textTertiary : Palette.accent)
                    .lineLimit(1)
            }
        case .needsDownload(let message):
            message2(title: "Languages not downloaded", detail: message)
        case .failed(let message):
            message2(title: message, detail: nil)
        }
    }

    private func resultView(_ r: TranslationResult) -> some View {
        Button {
            model.tap()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { model.showMeaning.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.translation)
                    .font(.system(size: r.target == .chinese ? 21 : 18, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                Group {
                    if model.showMeaning || r.pinyin.isEmpty || !model.settings.showPinyin {
                        if !r.note.isEmpty && model.showMeaning {
                            Text(r.note).foregroundStyle(Palette.accent)
                        } else if !r.back.isEmpty {
                            Text("Reads as: \(r.back)").foregroundStyle(Palette.textSecondary)
                        }
                    } else {
                        Text(r.pinyin).foregroundStyle(Palette.textSecondary)
                    }
                }
                .font(.system(size: 13))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows what it means in your language")
    }

    private func message2(title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: Action

    @ViewBuilder
    private var action: some View {
        switch model.state {
        case .ready(let r) where r.target == .chinese:
            PrimaryKeyButton(title: "Insert") { model.insertTranslation() }
        case .ready:
            EmptyView()
        case .loading:
            PrimaryKeyButton(title: "Insert") {}
                .opacity(0.35)
                .allowsHitTesting(false)
        case .inserted:
            SecondaryKeyButton(icon: "arrow.uturn.backward", title: "Undo", action: model.undoInsert)
        case .understood:
            SecondaryKeyButton(icon: "xmark", title: "Close", action: model.dismissUnderstood)
        case .failed, .needsDownload:
            SecondaryKeyButton(icon: "arrow.clockwise", title: "Retry", action: model.retry)
        case .idle:
            SecondaryKeyButton(icon: "doc.on.clipboard", title: "Their message", action: model.understandClipboard)
        }
    }
}

/// The one accent-colored control on the keyboard.
struct PrimaryKeyButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(Capsule().fill(Palette.accent))
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Insert Chinese")
    }
}

struct SecondaryKeyButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Capsule().fill(Palette.stripSurface))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale())
    }
}
