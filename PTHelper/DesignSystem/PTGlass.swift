import SwiftUI

// MARK: - Glass Surfaces
//
// Usage guide:
// - `ptGlass`            Cards and panels that float over the ambient background.
// - `ptGlassRow`         Rows inside a `List` — each row becomes its own glass tile (pair with `.listRowSpacing`).
// - `ptPrimaryButton`    The one main action on a screen (tinted, prominent glass).
// - `ptSecondaryButton`  Supporting actions next to a primary button.
// - `PTGlassIconButton`  Round icon controls (timer controls, toolbar-style actions in content).
// - `PTChip`             Filter / selection chips; wrap a row of them in `GlassEffectContainer` so they blend.

extension View {
    /// Liquid Glass panel in a rounded rectangle, optionally tinted with a brand color.
    func ptGlass(cornerRadius: CGFloat = PTRadius.lg, tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(
            .regular.tint(tint?.opacity(0.35)).interactive(interactive),
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    /// Makes a `List` row a standalone glass tile.
    func ptGlassRow(tint: Color? = nil) -> some View {
        listRowBackground(
            Color.clear.ptGlass(cornerRadius: PTRadius.md, tint: tint)
        )
        .listRowSeparator(.hidden)
    }

    /// Full-width prominent glass button tinted with the brand accent.
    func ptPrimaryButton(tint: Color = .ptAccent) -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(tint)
    }

    /// Clear glass button for supporting actions.
    func ptSecondaryButton() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
    }
}

// MARK: - Icon Button

/// Circular glass control. `prominent` fills it with the tint for the main control in a group.
struct PTGlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 48
    var prominent = false
    var tint: Color = .ptAccent
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .frame(width: size, height: size)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonBorderShape(.circle)
        .modifier(IconButtonStyle(prominent: prominent))
        .tint(prominent ? tint : .primary)
        .accessibilityLabel(accessibilityLabel)
    }

    private struct IconButtonStyle: ViewModifier {
        let prominent: Bool

        func body(content: Content) -> some View {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        }
    }
}

// MARK: - Chip

/// Selectable glass capsule. Selected chips fill with the tint and bounce.
struct PTChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color = .ptAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(isSelected ? tint : nil).interactive(), in: .capsule)
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(PTMotion.bouncy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Section Header

/// Serif section header used above glass groups.
struct PTSectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.ptSerif(.subheadline, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.7))
            .textCase(nil)
    }
}

// MARK: - Glass Section

/// Titled glass card — replaces `GroupBox` on custom (non-List) screens.
struct PTGlassSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PTSpacing.md) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(PTSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ptGlass()
    }
}

// MARK: - Progress Bar

/// Rounded progress bar filled with the brand (icon) gradient that springs to new values.
struct PTProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.ptBrandGradient)
                        .frame(width: max(8, geometry.size.width * min(max(value, 0), 1)))
                }
        }
        .frame(height: 8)
        .animation(PTMotion.bouncy, value: value)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}
