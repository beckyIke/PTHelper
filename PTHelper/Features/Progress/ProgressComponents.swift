import Charts
import SwiftUI

// MARK: - Appear Animation

/// Animates changes to `appeared` with a spring, or instantly when Reduce Motion is on.
private struct AppearAnimation: ViewModifier {
    let appeared: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.25).delay(delay), value: appeared)
    }
}

extension View {
    func appearAnimation(_ appeared: Bool, delay: Double = 0) -> some View {
        modifier(AppearAnimation(appeared: appeared, delay: delay))
    }
}

extension DayStatus {
    var color: Color {
        switch self {
        case .complete: return .ptSage
        case .partial:  return .ptSage.opacity(0.45)
        case .missed:   return .ptTerracotta.opacity(0.45)
        case .rest:     return Color(.systemGray5)
        case .upcoming: return Color(.systemGray6)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .complete: return "complete"
        case .partial:  return "partly complete"
        case .missed:   return "missed"
        case .rest:     return "rest day"
        case .upcoming: return "upcoming"
        }
    }
}

// MARK: - Week Ring

/// Ring showing perfect days out of scheduled days this week.
struct WeekRingView: View {
    let perfectDays: Int
    let scheduledDays: Int
    let appeared: Bool

    private var fraction: Double {
        scheduledDays > 0 ? Double(perfectDays) / Double(scheduledDays) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ptSage.opacity(0.18), lineWidth: 14)
            Circle()
                .trim(from: 0, to: appeared ? fraction : 0)
                .stroke(Color.ptSage, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .appearAnimation(appeared)
            VStack(spacing: 0) {
                Text("\(appeared ? perfectDays : 0)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(appeared ? perfectDays : 0)))
                    .appearAnimation(appeared)
                Text(scheduledDays > 0 ? "of \(scheduledDays) days" : "no sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 130, height: 130)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(perfectDays) of \(scheduledDays) scheduled days completed this week")
    }
}

// MARK: - Weeks Streak

struct WeeksStreakView: View {
    let streak: Int
    let totalPerfectWeeks: Int
    let usedGrace: Bool
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundColor(.ptTerracotta)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .appearAnimation(appeared, delay: 0.2)
                Text("\(appeared ? streak : 0)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.ptTerracotta)
                    .contentTransition(.numericText(value: Double(appeared ? streak : 0)))
                    .appearAnimation(appeared, delay: 0.2)
            }
            Text(streak == 1 ? "Week Streak" : "Weeks Streak")
                .font(.subheadline.weight(.semibold))
            Text("\(totalPerfectWeeks) perfect \(totalPerfectWeeks == 1 ? "week" : "weeks") total")
                .font(.caption)
                .foregroundColor(.secondary)
            if usedGrace {
                Label("Streak saved by a grace day", systemImage: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.ptTerracotta)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Day Strip

/// One circle per day of the current week, filled according to its status.
struct WeekDayStrip: View {
    let days: [DaySummary]
    let appeared: Bool

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 6) {
                    DayDot(day: day)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .opacity(appeared ? 1 : 0)
                        .appearAnimation(appeared, delay: 0.3 + Double(index) * 0.06)
                    Text(Self.weekdayFormatter.string(from: day.date))
                        .font(.caption2.weight(Calendar.current.isDateInToday(day.date) ? .bold : .regular))
                        .foregroundColor(Calendar.current.isDateInToday(day.date) ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(day.date.formatted(.dateTime.weekday(.wide))), \(day.status.accessibilityLabel)"
                )
            }
        }
    }
}

private struct DayDot: View {
    let day: DaySummary

    var body: some View {
        ZStack {
            switch day.status {
            case .complete:
                Circle().fill(Color.ptSage)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            case .partial:
                Circle().stroke(Color.ptSage.opacity(0.25), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: Double(day.completed) / Double(max(day.scheduled, 1)))
                    .stroke(Color.ptSage, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .missed:
                Circle().stroke(Color.ptTerracotta.opacity(0.55), lineWidth: 2.5)
            case .upcoming:
                Circle().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            case .rest:
                Circle().fill(Color(.systemGray5))
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Weekly History Chart

/// Completion % per week, with perfect weeks highlighted.
struct WeeklyHistoryChart: View {
    let weeks: [WeekSummary]
    let appeared: Bool

    var body: some View {
        Chart(weeks) { week in
            let percent = (week.completionRate ?? 0) * 100
            BarMark(
                x: .value("Week", week.start, unit: .weekOfYear),
                y: .value("Completion", appeared ? percent : 0)
            )
            .foregroundStyle(week.isPerfect ? Color.ptTerracotta : Color.ptSage)
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 160)
        .appearAnimation(appeared, delay: 0.4)
        .accessibilityLabel("Weekly completion for the last \(weeks.count) weeks")
    }
}

// MARK: - Heatmap

/// Grid of days (rows = weekdays, columns = weeks), shaded by completion.
struct ActivityHeatmap: View {
    let weeks: [WeekSummary]
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                    VStack(spacing: 4) {
                        ForEach(week.days) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.date > Date() ? Color.clear : day.status.color)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: 22)
                    .opacity(appeared ? 1 : 0)
                    .appearAnimation(appeared, delay: 0.5 + Double(index) * 0.03)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                legendItem(.complete, "Done")
                legendItem(.partial, "Partial")
                legendItem(.missed, "Missed")
                legendItem(.rest, "Rest")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity calendar for the last \(weeks.count) weeks")
    }

    private func legendItem(_ status: DayStatus, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(status.color).frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    var background: Color = Color(.systemGray6)
    var foreground: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(foreground.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(background)
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
    }
}
