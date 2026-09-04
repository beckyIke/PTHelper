import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>

    // Calendar.weekday: 1=Sun, 2=Mon … 7=Sat
    private let days: [(Int, String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { number, label in
                let isOn = selectedDays.contains(number)
                Button {
                    if isOn {
                        selectedDays.remove(number)
                    } else {
                        selectedDays.insert(number)
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(isOn ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(isOn ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
