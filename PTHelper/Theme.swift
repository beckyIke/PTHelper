import SwiftUI

// MARK: - Colors
// Defined as inline sRGB values so they are compile-time constants the linter cannot strip.

extension Color {
    /// Warm terracotta — primary accent throughout the app
    static let ptTerracotta = Color("AccentColor")
    /// Warm cream — app-wide background (#F5EDE0)
}

// MARK: - Typography

extension Font {
    /// Serif variant of a standard SwiftUI text style — used for hero headings.
    static func ptSerif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - View Modifiers

/// Floating card — white background, rounded corners, soft shadow.
struct PTCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(.white)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func ptCardStyle(cornerRadius: CGFloat = 14) -> some View {
        modifier(PTCardStyle(cornerRadius: cornerRadius))
    }

    /// Cream background + hidden default list background.
    func ptBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.ptBackground.ignoresSafeArea())
    }

    /// Keeps the tab bar cream-coloured and opaque on this view.
    func ptTabBarBackground() -> some View {
        self
            .toolbarBackground(Color.ptBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
