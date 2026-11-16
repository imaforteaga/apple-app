import SwiftUI
import UIKit

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A colour that adapts to light / dark mode.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

// MARK: - Design tokens

enum Theme {
    // Palette: "paper & ink" with a single calm sage accent.
    // To re-tint the whole app, change `orange` / `deepOrange` / `yellow`
    // (names kept from the first version so every screen picks it up).
    static let orange = Color(hex: 0x4F7D5E)       // primary accent (sage)
    static let deepOrange = Color(hex: 0x3F6B4E)   // pressed / deeper accent
    static let yellow = Color(hex: 0x9DBFA8)       // light tint of the accent
    static let paleYellow = Color(hex: 0xE4EEE6)
    static let cream = Color(hex: 0xF7F5F0)
    static let beige = Color(hex: 0xEFECE5)
    static let ink = Color(hex: 0x1C1C1A)

    // Adaptive surfaces
    static let background = Color.adaptive(light: 0xF7F5F0, dark: 0x111211)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x1A1B19)
    static let cardAlt = Color.adaptive(light: 0xEFECE5, dark: 0x262826)
    static let text = Color.adaptive(light: 0x1C1C1A, dark: 0xF2F1EC)
    static let textSecondary = Color.adaptive(light: 0x8A8780, dark: 0x9A9890)
    static let hairline = Color.adaptive(light: 0xE6E2DA, dark: 0x2F312E)
    static let accentText = Color.adaptive(light: 0x3F6B4E, dark: 0xA6CDB1)
    static let softAccent = Color.adaptive(light: 0xE4EEE6, dark: 0x203026)

    // Gradients (kept very quiet: tonal, never loud)
    static let brandGradient = LinearGradient(
        colors: [yellow, orange],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let buttonGradient = LinearGradient(
        colors: [orange, deepOrange],
        startPoint: .top, endPoint: .bottom)
    static let ringGradient = AngularGradient(
        colors: [yellow, orange, yellow],
        center: .center)
    static let warmWash = LinearGradient(
        colors: [paleYellow.opacity(0.7), cream.opacity(0)],
        startPoint: .top, endPoint: .bottom)

    // Layout
    static let corner: CGFloat = 20
    static let pad: CGFloat = 20
    static let gap: CGFloat = 14

    // Typography: SF Pro throughout. Light, airy numbers; medium titles.
    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func number(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}

// MARK: - Motion

enum Motion {
    static let soft = Animation.smooth(duration: 0.45)
    static let quick = Animation.snappy(duration: 0.28)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let ring = Animation.smooth(duration: 1.1)
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}
