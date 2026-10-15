import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @EnvironmentObject private var packs: LanguagePacks
    @State private var step = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if step == 0 { welcome.transition(.opacity) } else { setup.transition(.opacity) }
            Spacer(minLength: 16)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background(Palette.canvas.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85).delay(0.15)) { appeared = true }
        }
        .task { await packs.refresh() }
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppMark(size: 56)
                .padding(.top, 48)
            Text("Chinese, from\nyour own words.")
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.text)
                .padding(.top, 28)
            Text("Type in English or Russian, in any chat. Dilçi turns it into natural Chinese on your keyboard.")
                .font(Typeface.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            KeyboardPreview()
                .padding(.top, 36)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
        }
    }

    // MARK: Setup

    private var setup: some View {
        let pair = LanguagePacks.Pair(from: DilciSettings.shared.nativeLanguage, to: .chinese)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Two things,\nthen you're set.")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Palette.text)
                .padding(.top, 64)

            VStack(spacing: 12) {
                checklistRow(
                    icon: "arrow.down.circle",
                    title: "Download Chinese",
                    detail: "One download. After that it works offline.",
                    done: packs.state(pair) == .ready
                ) {
                    switch packs.state(pair) {
                    case .downloading, .unknown:
                        ProgressView()
                    case .ready:
                        EmptyView()
                    default:
                        Button("Get") { packs.download(pair) }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(Palette.accent)
                    }
                }

                checklistRow(
                    icon: "keyboard",
                    title: "Add the keyboard",
                    detail: "Keyboards, Add New Keyboard, Dilçi. Then turn on Allow Full Access.",
                    done: false
                ) {
                    Button("Open") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Palette.text)
                }
            }
            .padding(.top, 32)

            Text("Full Access lets the keyboard read a message you copy. Nothing you type leaves your iPhone.")
                .font(Typeface.footnote)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
        }
    }

    private func checklistRow<Trailing: View>(icon: String, title: String, detail: String, done: Bool,
                                              @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.title2)
                .foregroundStyle(done ? Palette.accent : Palette.textSecondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typeface.headline)
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(Typeface.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<2) { i in
                    Capsule()
                        .fill(i == step ? Palette.text : Palette.hairline)
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            if step == 1 {
                Button("Skip") { onFinish() }
                    .font(Typeface.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.trailing, 6)
            }
            Button {
                if step == 0 { step = 1 } else { onFinish() }
            } label: {
                Text(step == 0 ? "Continue" : "Start")
                    .font(Typeface.headline)
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 26)
                    .frame(height: 50)
                    .background(Capsule().fill(Palette.accent))
            }
            .buttonStyle(PressScale())
        }
    }
}

/// A real, static rendering of the keyboard strip so people see what they get.
private struct KeyboardPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("see u tmrw at the gate, ok?")
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
                Spacer(minLength: 0)
            }
            .padding(14)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("English to 中文")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    ToneSwitch(tone: .constant(.casual), compact: true)
                        .allowsHitTesting(false)
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("明天门口见，好吗？")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Text("míng tiān mén kǒu jiàn, hǎo ma?")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Text("Insert")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(Palette.accent))
                }
            }
            .padding(12)
            .background(Palette.keyBed)
        }
        .background(Palette.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example: see you tomorrow at the gate becomes 明天门口见，好吗")
    }
}
