import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Provides pastel-colour pairs and adapts them for the current UI style.
final class ColorManager {
    /// Returns a random (pastel, darker) colour pair.
    @MainActor
    func randomColorPair() -> (pastel: Color, darker: Color) {
        let pair = colorPairs.randomElement() ?? (
            Color(red: 0.7, green: 0.8, blue: 1.0),
            Color(red: 0.5, green: 0.6, blue: 0.8)
        )
        let darkerDynamic = adjustForCurrentInterface(pair.darker)
        return (pastel: pair.pastel, darker: darkerDynamic)
    }

    // MARK: - Private helpers
    private let colorPairs: [(pastel: Color, darker: Color)] = [
        (Color(red: 1.0, green: 0.7, blue: 0.7), Color(red: 0.8, green: 0.5, blue: 0.5)),
        (Color(red: 1.0, green: 0.8, blue: 0.6), Color(red: 0.8, green: 0.6, blue: 0.4)),
        (Color(red: 0.7, green: 1.0, blue: 0.7), Color(red: 0.5, green: 0.8, blue: 0.5)),
        (Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)),
        (Color(red: 0.9, green: 0.7, blue: 1.0), Color(red: 0.7, green: 0.5, blue: 0.8)),
        (Color(red: 1.0, green: 0.7, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 0.7)),
        (Color(red: 0.7, green: 1.0, blue: 0.9), Color(red: 0.5, green: 0.8, blue: 0.7)),
        (Color(red: 0.7, green: 0.9, blue: 0.9), Color(red: 0.5, green: 0.7, blue: 0.7)),
        (Color(red: 0.7, green: 0.9, blue: 1.0), Color(red: 0.5, green: 0.7, blue: 0.8)),
        (Color(red: 0.8, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.6, blue: 0.8)),
        (Color(red: 0.9, green: 0.8, blue: 0.7), Color(red: 0.7, green: 0.6, blue: 0.5)),
        (Color(red: 0.9, green: 0.9, blue: 0.9), Color(red: 0.7, green: 0.7, blue: 0.7)),
        (Color(red: 0.8, green: 0.7, blue: 0.9), Color(red: 0.6, green: 0.5, blue: 0.7)),
        (Color(red: 0.9, green: 0.6, blue: 0.8), Color(red: 0.7, green: 0.4, blue: 0.6)),
        (Color(red: 0.6, green: 0.9, blue: 0.8), Color(red: 0.4, green: 0.7, blue: 0.6)),
        (Color(red: 0.8, green: 0.9, blue: 0.6), Color(red: 0.6, green: 0.7, blue: 0.4)),
        (Color(red: 0.9, green: 0.6, blue: 0.6), Color(red: 0.7, green: 0.4, blue: 0.4)),
        (Color(red: 0.6, green: 0.8, blue: 0.9), Color(red: 0.4, green: 0.6, blue: 0.7))
    ]

    /// Creates a dynamic colour that darkens in dark-mode for a pleasant contrast.
    private func adjustForCurrentInterface(_ color: Color, darkenFactor: CGFloat = 0.6) -> Color {
        #if canImport(UIKit)
        let light = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard light.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }
        let dark = UIColor(red: r * darkenFactor, green: g * darkenFactor, blue: b * darkenFactor, alpha: a)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        #else
        return color
        #endif
    }
} 