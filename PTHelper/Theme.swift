import SwiftUI

// MARK: - Colors
//
// Palette derived from the app icon's sky-blue → sage-green gradient. Every color has a light and dark
// variant in the asset catalog, and names describe the role, not the hue.
//
// | Token            | Role                                               | Light     | Dark      |
// |------------------|----------------------------------------------------|-----------|-----------|
// | ptAccent         | Tint, links, primary buttons, key numbers          | #2870B2   | #4A9ADF   |
// | ptSecondary      | Completion, success, rest/break states             | #327A59   | #4FA07C   |
// | ptAccentSoft     | Soft tinted surfaces (banners, secondary tiles)    | #D5E9F7   | #1C3A52   |
// | ptBackground     | Base of the ambient background                     | #EEF6F9   | #0E171D   |
// | ptBrandSky/Mint  | The icon's exact gradient — decoration only        | #75B7EF / #8CBA9C     |
//
// ptAccent and ptSecondary meet WCAG AA (4.5:1) as text on ptBackground in both modes, and carry white
// text on filled controls. The brand colors are only ~2:1 on the background, so never use them for text.
// Status colors that aren't brand colors (pain severity, overdue) stay on system red/orange/yellow.
// Color.ptBackground, .ptSecondary, .ptAccentSoft, .ptBrandSky and .ptBrandMint are generated from the asset catalog.

extension Color {
    /// Primary brand accent (the asset catalog's AccentColor, so system controls pick it up too).
    static let ptAccent = Color("AccentColor")
}

extension ShapeStyle where Self == LinearGradient {
    /// The app icon's sky → mint gradient, for decorative fills like progress bars.
    static var ptBrandGradient: LinearGradient {
        LinearGradient(colors: [.ptBrandSky, .ptBrandMint], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Typography

extension Font {
    /// Serif variant of a standard SwiftUI text style — used for hero headings.
    static func ptSerif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }

    /// Large rounded numerals for stats and timers.
    static func ptNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Spacing & Radius

enum PTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Corner radii. Glass surfaces read best with generous, concentric corners.
enum PTRadius {
    /// Chips, small tiles
    static let sm: CGFloat = 12
    /// List rows, stat tiles
    static let md: CGFloat = 20
    /// Cards, hero panels
    static let lg: CGFloat = 28
}

// MARK: - Motion

enum PTMotion {
    /// Quick, crisp response to taps and selection.
    static let snappy: Animation = .snappy(duration: 0.3)
    /// Playful overshoot for things arriving on screen.
    static let bouncy: Animation = .bouncy(duration: 0.55, extraBounce: 0.12)
    /// Slow, soft transitions between states.
    static let gentle: Animation = .smooth(duration: 0.6)
    /// Delay between items in a staggered entrance.
    static let stagger: Double = 0.05
}

// MARK: - View Modifiers

extension View {
    /// Glass card. Kept under its original name so existing call sites pick up the new look.
    func ptCardStyle(cornerRadius: CGFloat = PTRadius.lg) -> some View {
        ptGlass(cornerRadius: cornerRadius)
    }

    /// Animated ambient background + hidden default list background.
    func ptBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { PTAmbientBackground().ignoresSafeArea() }
    }
}
