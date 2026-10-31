import SwiftUI

// MARK: - 颜色

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum Palette {
    static let purple = Color.adaptive(light: 0x7C5CFF, dark: 0x9B82FF)
    static let purpleDeep = Color.adaptive(light: 0x6A48F5, dark: 0x8B70FF)
    static let purpleSoft = Color.adaptive(light: 0xEFEAFF, dark: 0x2B2440)
    static let purpleTint = Color.adaptive(light: 0xF7F4FF, dark: 0x221D31)

    static let background = Color.adaptive(light: 0xF5F3FB, dark: 0x14121C)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x1E1B29)
    static let ink = Color.adaptive(light: 0x1C1A2B, dark: 0xF2F0FA)
    static let ink2 = Color.adaptive(light: 0x4A4560, dark: 0xCDC7E0)
    static let subtle = Color.adaptive(light: 0x8B86A4, dark: 0x918BA8)
    static let hairline = Color.adaptive(light: 0xECE8F5, dark: 0x2E2940)
    static let hairlineSoft = Color.adaptive(light: 0xF4F1FB, dark: 0x262231)

    static let ok = Color.adaptive(light: 0x1F9D6B, dark: 0x3EC48D)
    static let okBg = Color.adaptive(light: 0xE7F7EF, dark: 0x16342A)
    static let warn = Color.adaptive(light: 0xD97706, dark: 0xE9A23B)
    static let warnBg = Color.adaptive(light: 0xFFF7ED, dark: 0x33260F)
    static let bad = Color.adaptive(light: 0xE0513A, dark: 0xF2715C)
    static let badBg = Color.adaptive(light: 0xFDEEEB, dark: 0x38201C)
    static let pinkBg = Color.adaptive(light: 0xFFF0F5, dark: 0x35222C)
    static let blueBg = Color.adaptive(light: 0xEAF4FF, dark: 0x17263C)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x7C5CFF), Color(hex: 0x9F82FF), Color(hex: 0xC3A8FF)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let warmGradient = LinearGradient(
        colors: [Color(hex: 0xFF7A59), Color(hex: 0xFF9F45), Color(hex: 0xFFC06B)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}

// MARK: - 卡片

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - 标题

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.subtle)
            Spacer()
            if let trailing = trailing {
                Button(action: { action?() }) {
                    Text(trailing)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.purple)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

// MARK: - 标签

struct TagView: View {
    enum Tone { case ok, warn, bad, gray, purple }
    let text: String
    var tone: Tone = .gray

    private var fg: Color {
        switch tone {
        case .ok: return Palette.ok
        case .warn: return Palette.warn
        case .bad: return Palette.bad
        case .gray: return Palette.subtle
        case .purple: return Palette.purple
        }
    }

    private var bg: Color {
        switch tone {
        case .ok: return Palette.okBg
        case .warn: return Palette.warnBg
        case .bad: return Palette.badBg
        case .gray: return Palette.purpleTint
        case .purple: return Palette.purpleSoft
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}

// MARK: - 胶囊按钮

struct ChipLabel: View {
    let text: String
    var selected: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon { Text(icon) }
            Text(text)
        }
        .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
        .foregroundColor(selected ? .white : Palette.ink2)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(selected ? Palette.purple : Palette.purpleTint)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Palette.purple : Palette.hairline, lineWidth: 1))
    }
}

// MARK: - 主按钮

struct PrimaryButtonStyle: ButtonStyle {
    var filled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15.5, weight: .semibold))
            .foregroundColor(filled ? .white : Palette.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(filled ? Palette.purple : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(filled ? Color.clear : Palette.purple, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

// MARK: - 键值行

struct KVRow: View {
    let key: String
    let value: String
    var valueColor: Color = Palette.ink
    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 13.5))
                .foregroundColor(Palette.subtle)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 提示块

struct HintBlock: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundColor(Palette.warn)
            .lineSpacing(3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.warnBg)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - 进度条

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.purpleTint)
                Capsule()
                    .fill(LinearGradient(colors: [Palette.ok, Color(hex: 0x4DBE91)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 空状态

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundColor(Palette.subtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }
}
