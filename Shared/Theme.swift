import SwiftUI
import UIKit

// MARK: - Design tokens
//
// Monochrome zinc neutrals with one saturated jade accent. The accent is only
// ever used for the action you are meant to take next (Insert, Send, Download)
// and for your own messages. Everything else is ink on neutral.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

enum Palette {
    // Surfaces
    static let canvasUI      = UIColor.dynamic(light: 0xF4F4F5, dark: 0x0B0B0D)
    static let canvas        = Color(canvasUI)
    static let surface       = Color(UIColor.dynamic(light: 0xFCFCFD, dark: 0x17171A))
    static let surfaceMuted  = Color(UIColor.dynamic(light: 0xE9E9EC, dark: 0x222226))

    // Text
    static let text          = Color(UIColor.dynamic(light: 0x18181B, dark: 0xF4F4F5))
    static let textSecondary = Color(UIColor.dynamic(light: 0x52525B, dark: 0xA1A1AA))
    static let textTertiary  = Color(UIColor.dynamic(light: 0x71717A, dark: 0x8A8A93))
    static let hairline      = Color(UIColor.dynamic(light: 0xDCDCE0, dark: 0x2C2C31))

    // The one accent: jade
    static let accent        = Color(UIColor.dynamic(light: 0x07875C, dark: 0x34D399))
    static let onAccent      = Color(UIColor.dynamic(light: 0xF6FFFA, dark: 0x03251A))
    static let accentSoft    = Color(UIColor.dynamic(light: 0xDDF3EA, dark: 0x0F2A21))
    static let warning       = Color(UIColor.dynamic(light: 0xB42318, dark: 0xF97066))

    // Keyboard, tuned to sit next to the system keyboard without looking foreign
    static let keyBedUI      = UIColor.dynamic(light: 0xD3D5DB, dark: 0x1C1C1F)
    static let keyBed        = Color(keyBedUI)
    static let keyCap        = Color(UIColor.dynamic(light: 0xFDFDFE, dark: 0x5A5A5F))
    static let keyCapFn      = Color(UIColor.dynamic(light: 0xA9AEB8, dark: 0x3A3A3E))
    static let keyShadow     = Color(UIColor.dynamic(light: 0x898A8E, dark: 0x0A0A0B))
    static let stripSurface  = Color(UIColor.dynamic(light: 0xF2F2F4, dark: 0x2A2A2E))
}

// MARK: - Type
//
// SF Pro everywhere, built on Dynamic Type styles so the app respects the
// reader's text size. Hanzi render in PingFang automatically.

enum Typeface {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title      = Font.system(.title2, design: .default).weight(.semibold)
    static let headline   = Font.system(.headline)
    static let body       = Font.system(.body)
    static let callout    = Font.system(.callout)
    static let subhead    = Font.system(.subheadline)
    static let footnote   = Font.system(.footnote)
    static let caption    = Font.system(.caption)

    /// Translated Chinese, the hero of every screen.
    static let hanziLarge = Font.system(.title, design: .default).weight(.medium)
    static let hanzi      = Font.system(.title3, design: .default).weight(.medium)
    static let pinyin     = Font.system(.subheadline, design: .default)
}

// MARK: - Shared components

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Palette.hairline).frame(height: 0.5)
    }
}

/// Compact segmented control for tone, shared by app and keyboard.
struct ToneSwitch: View {
    @Binding var tone: Tone
    var compact = false
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tone.allCases) { t in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) { tone = t }
                } label: {
                    Text(compact ? t.shortTitle : t.title)
                        .font(compact ? .system(size: 12, weight: .semibold) : .system(.footnote).weight(.semibold))
                        .foregroundStyle(t == tone ? Palette.text : Palette.textTertiary)
                        .padding(.horizontal, compact ? 9 : 12)
                        .frame(minHeight: compact ? 26 : 32)
                        .background {
                            if t == tone {
                                Capsule()
                                    .fill(Palette.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "tone", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t.title) tone")
                .accessibilityAddTraits(t == tone ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Palette.surfaceMuted))
    }
}

/// Three dots, used while the on-device model works.
struct TypingDots: View {
    var color: Color = Palette.textTertiary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    let phase = reduceMotion ? 0.6 : (sin(t * 5 - Double(i) * 0.8) + 1) / 2
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + 0.7 * phase)
                }
            }
        }
        .accessibilityLabel("Translating")
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// The app mark: 译 set in a jade squircle. Same drawing as the app icon.
struct AppMark: View {
    var size: CGFloat = 44
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Palette.accent)
            .frame(width: size, height: size)
            .overlay(
                Text("译")
                    .font(.system(size: size * 0.56, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
            )
            .accessibilityHidden(true)
    }
}
