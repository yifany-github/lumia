import SwiftUI
import UIKit

extension Color {
    // ---- Organic Palette (matches index.css :root) ----
    static var organicBackground:  Color { dynamic(light: 0xFDFCF8, dark: 0x0B0F0A) }
    static var organicForeground:  Color { dynamic(light: 0x2C2C24, dark: 0xFAF7EF) }
    static var organicPrimary:     Color { dynamic(light: 0x5D7052, dark: 0xB9D39E) }
    static var organicPrimaryFg:   Color { dynamic(light: 0xF3F4F1, dark: 0x0B0F0A) }
    static var organicSecondary:   Color { dynamic(light: 0xC18C5D, dark: 0xF0C27A) }
    static var organicAccent:      Color { dynamic(light: 0xE6DCCD, dark: 0x3C3528) }
    static var organicMuted:       Color { dynamic(light: 0xF0EBE5, dark: 0x1D231A) }
    static var organicMutedFg:     Color { dynamic(light: 0x78786C, dark: 0xD5CEC1) }
    static var organicCard:        Color { dynamic(light: 0xFFFFFF, dark: 0x151A13) }
    static var organicBorder:      Color { dynamic(light: 0xDED8CF, dark: 0x505A48) }
    static var organicElevated:    Color { dynamic(light: 0xFFFFFF, dark: 0x1C2319) }
    static var organicBackdrop:    Color { dynamic(light: 0xF8F3EA, dark: 0x10160F) }

    static func dynamic(light: UInt, dark: UInt, alpha: Double = 1) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor.luminaHex(hex, alpha: CGFloat(alpha))
        })
    }
    
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue:  Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    static var luminaBackground: UIColor { luminaDynamic(light: 0xFDFCF8, dark: 0x0B0F0A) }
    static var luminaForeground: UIColor { luminaDynamic(light: 0x2C2C24, dark: 0xFAF7EF) }
    static var luminaPrimary: UIColor { luminaDynamic(light: 0x5D7052, dark: 0xB9D39E) }
    static var luminaCard: UIColor { luminaDynamic(light: 0xFFFFFF, dark: 0x151A13) }
    static var luminaMutedForeground: UIColor { luminaDynamic(light: 0x78786C, dark: 0xD5CEC1) }
    static var luminaBorder: UIColor { luminaDynamic(light: 0xDED8CF, dark: 0x505A48) }
    static var luminaTabBackground: UIColor { luminaDynamic(light: 0xFDFCF8, dark: 0x10160F, alpha: 0.98) }

    static func luminaHex(_ hex: UInt, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }

    static func luminaDynamic(light: UInt, dark: UInt, alpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return luminaHex(hex, alpha: alpha)
        }
    }
}

// MARK: - Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct LuminaTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var luminaTextScale: CGFloat {
        get { self[LuminaTextScaleKey.self] }
        set { self[LuminaTextScaleKey.self] = newValue }
    }
}

private struct LuminaFontModifier: ViewModifier {
    @Environment(\.luminaTextScale) private var textScale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * textScale, weight: weight, design: design))
    }
}

extension View {
    func luminaFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(LuminaFontModifier(size: size, weight: weight, design: design))
    }

    @ViewBuilder
    func luminaLargeText(_ enabled: Bool) -> some View {
        if enabled {
            self
                .dynamicTypeSize(.accessibility2)
                .environment(\.luminaTextScale, 1.18)
        } else {
            self
                .dynamicTypeSize(.xSmall ... .xxLarge)
                .environment(\.luminaTextScale, 1)
        }
    }
}
