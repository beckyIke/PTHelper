import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduledSession.scheduledDate) private var sessions: [ScheduledSession]

    @State private var showingAddSession = false

    private var todaysSessions: [ScheduledSession] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return sessions.filter { !$0.isCompleted && $0.scheduledDate >= today && $0.scheduledDate < tomorrow }
    }
    private var upcoming: [ScheduledSession] { sessions.filter { !$0.isCompleted } }
    private var completed: [ScheduledSession] { sessions.filter { $0.isCompleted }.reversed() }

    var body: some View {
        NavigationStack {
            List {
                // Hero header card
                Section {
                    ScheduleHeroCard(todayCount: todaysSessions.count)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                if sessions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Sessions Scheduled",
                            systemImage: "calendar",
                            description: Text("Tap + to schedule your first workout.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    if !upcoming.isEmpty {
                        Section {
                            ForEach(upcoming) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                }
                                .listRowBackground(Color.white)
                            }
                            .onDelete { offsets in deleteSessions(from: upcoming, offsets: offsets) }
                        } header: {
                            Text("Upcoming")
                                .font(.ptSerif(.subheadline, weight: .semibold))
                        }
                    }

                    if !completed.isEmpty {
                        Section {
                            ForEach(completed.prefix(15), id: \.persistentModelID) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                }
                                .listRowBackground(Color.white)
                            }
                        } header: {
                            Text("Completed")
                                .font(.ptSerif(.subheadline, weight: .semibold))
                        }
                    }
                }
            }
            .ptBackground()
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddSession = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView(preselectedRoutine: nil)
            }
        }
    }

    private func deleteSessions(from list: [ScheduledSession], offsets: IndexSet) {
        for index in offsets { modelContext.delete(list[index]) }
    }
}

// MARK: - Hero card

struct ScheduleHeroCard: View {
    let todayCount: Int

    private var dayString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.ptTerracotta)

            VStack(alignment: .leading, spacing: 6) {
                Text(dayString)
                    .font(.ptSerif(.subheadline))
                    .foregroundColor(.white.opacity(0.85))
                Text(todayCount == 0 ? "Rest day" : todayCount == 1 ? "1 session today" : "\(todayCount) sessions today")
                    .font(.ptSerif(.title, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
    }
}

// MARK: - Session row

struct SessionRowView: View {
    let session: ScheduledSession

    private var isOverdue: Bool {
        !session.isCompleted && session.scheduledDate < Date()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.routine?.name ?? "Unknown Routine")
                    .font(.ptSerif(.subheadline, weight: .semibold))
                Text(session.scheduledDate, format: .dateTime.weekday().month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let routine = session.routine {
                    Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.ptSage)
            } else if isOverdue {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
            } else {
                Image(systemName: "circle").foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
