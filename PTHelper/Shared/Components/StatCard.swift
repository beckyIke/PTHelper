import SwiftUI

struct StatCard: View {
    let value: String
    let label: String
    var background: Color = Color(.systemGray6)
    var foreground: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(foreground)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(foreground.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(background)
        .cornerRadius(14)
    }
}
