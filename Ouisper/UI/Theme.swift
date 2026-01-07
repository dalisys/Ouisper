import SwiftUI

enum OuisperTheme {
    static let ink = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let slate = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let mist = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let neon = Color(red: 0.78, green: 0.95, blue: 0.30)
    static let ember = Color(red: 0.98, green: 0.45, blue: 0.25)
    static let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)
    static let violet = Color(red: 0.65, green: 0.45, blue: 0.95)

    static let cardGradient = LinearGradient(
        colors: [slate.opacity(0.95), ink.opacity(0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = RadialGradient(
        colors: [slate.opacity(0.9), ink],
        center: .topLeading,
        startRadius: 20,
        endRadius: 680
    )
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(OuisperTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }

    func pointerOnHover() -> some View {
        modifier(PointerOnHover())
    }
}

private struct PointerOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
