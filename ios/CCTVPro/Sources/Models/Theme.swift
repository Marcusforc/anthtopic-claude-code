import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0B0D12)
    static let card = Color(hex: 0x14171E)
    static let stroke = Color.white.opacity(0.06)
    static let accent = Color(hex: 0x2F6BFF)
    static let green = Color(hex: 0x22B573)
    static let orange = Color(hex: 0xF5A524)
    static let purple = Color(hex: 0x8B5CF6)
    static let secondary = Color.white.opacity(0.55)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    func card() -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke))
    }

    func screenBackground() -> some View {
        background(Theme.bg.ignoresSafeArea())
    }
}

private let rubleFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f
}()

func rubles(_ value: Double) -> String {
    (rubleFormatter.string(from: NSNumber(value: value)) ?? "0") + " ₽"
}

struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.3))
    }
}
