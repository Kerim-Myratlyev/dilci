import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var packs: LanguagePacks
    @AppStorage(SettingsKey.nativeLanguage, store: DilciSettings.shared.defaults) private var native: Lang = .english
    @AppStorage(SettingsKey.defaultTone, store: DilciSettings.shared.defaults) private var defaultTone: Tone = .casual
    @AppStorage(SettingsKey.showPinyin, store: DilciSettings.shared.defaults) private var showPinyin = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(LanguagePacks.pairs) { pair in
                        LanguagePackRow(pair: pair)
                    }
                } header: {
                    Text("Offline languages")
                } footer: {
                    Text("Translation runs on your iPhone with Apple's translator. No account, no internet once downloaded, nothing to pay.")
                }

                Section("Keyboard") {
                    SetupStep(icon: "keyboard", title: "Add Dilçi",
                              detail: "Settings, General, Keyboard, Keyboards, Add New Keyboard.")
                    SetupStep(icon: "lock.open", title: "Allow Full Access",
                              detail: "Needed to read a copied message and keep your Phrasebook in sync. Dilçi never sends what you type anywhere.")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "arrow.up.forward.app")
                    }
                }

                Section {
                    Picker("Explain Chinese in", selection: $native) {
                        Text(Lang.english.nativeName).tag(Lang.english)
                        Text(Lang.russian.nativeName).tag(Lang.russian)
                    }
                    Picker("Default tone", selection: $defaultTone) {
                        ForEach(Tone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    Toggle("Show pinyin", isOn: $showPinyin)
                } header: {
                    Text("Preferences")
                } footer: {
                    Text(defaultTone.help)
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0")
                } footer: {
                    Text("Dilçi means \"linguist\". Your messages never leave your phone.")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Palette.canvas)
            .task { await packs.refresh() }
        }
    }
}

struct LanguagePackRow: View {
    @EnvironmentObject private var packs: LanguagePacks
    let pair: LanguagePacks.Pair

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.title)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.text)
                Text(subtitle)
                    .font(Typeface.footnote)
                    .foregroundStyle(subtitleColor)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }

    private var state: LanguagePacks.State { packs.state(pair) }

    private var subtitle: String {
        switch state {
        case .unknown: return "Checking"
        case .ready: return "Ready offline"
        case .needsDownload: return "Not downloaded"
        case .unsupported: return "Not available on this iPhone"
        case .downloading: return "Downloading"
        case .failed(let message): return message
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .ready: return Palette.accent
        case .failed, .unsupported: return Palette.warning
        default: return Palette.textSecondary
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)
                .accessibilityLabel("Downloaded")
        case .downloading, .unknown:
            ProgressView()
        case .needsDownload, .failed:
            Button("Get") { packs.download(pair) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.accent)
        case .unsupported:
            EmptyView()
        }
    }
}

struct SetupStep: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typeface.body)
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(Typeface.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
