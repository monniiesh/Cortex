import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum Theme {
    // backgrounds
    static let bg = Color(hex: "0A0E1A")
    static let card = Color(hex: "111827")
    static let elevated = Color(hex: "1A2235")

    // accent
    static let accent = Color(hex: "3B82F6")
    static let accentGlow = Color(hex: "60A5FA")
    static let success = Color(hex: "0EA5E9")
    static let warning = Color(hex: "F59E0B")

    // text
    static let textPrimary = Color(hex: "F1F5F9")
    static let textSecondary = Color(hex: "94A3B8")

    // borders
    static let divider = Color(hex: "1E293B")
    static let searchField = Color(hex: "1E293B")

    // glass
    static let glassBackground = Color(hex: "111827").opacity(0.85)
    static let glassBorder = Color.white.opacity(0.08)

    // shadows
    static let cardShadow = Color.black.opacity(0.25)
    static let glowShadow = Color(hex: "3B82F6").opacity(0.3)

    // radii
    static let folderRadius: CGFloat = 16
    static let cardRadius: CGFloat = 12

    // animation
    static let spring = Animation.spring(response: 0.35)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.85)
    static let fadeIn = Animation.easeOut(duration: 0.25)

    enum Haptic {
        static func light() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        static func medium() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        static func heavy() {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
