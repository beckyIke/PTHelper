import SwiftUI
import SwiftData

struct AddSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.name) private var routines: [Routine]

    let preselectedRoutine: Routine?

    @State private var selectedRoutine: Routine?
    @State private var scheduledDate = Date()

    init(preselectedRoutine: Routine?) {
        self.preselectedRoutine = preselectedRoutine
        _selectedRoutine = State(initialValue: preselectedRoutine)
    }

    var canSchedule: Bool { selectedRoutine != nil }

    var body: some View {
        NavigationStack {
            List {
                // Routine picker
                Section {
                    if routines.isEmpty {
                        Text("No routines yet. Create one in the Routines tab first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Routine", selection: $selectedRoutine) {
                            Text("None").tag(Optional<Routine>.none)
                            ForEach(routines) { routine in
                                Text(routine.name)
                                    .font(.ptSerif(.body))
                                    .tag(Optional(routine))
                            }
                        }
                    }
                } header: {
                    Text("Routine")
                        .font(.ptSerif(.subheadline, weight: .semibold))
                }
                .listRowBackground(Color.white)

                // Date picker
                Section {
                    DatePicker(
                        "Scheduled For",
                        selection: $scheduledDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .tint(.ptAccent)
                } header: {
                    Text("Date & Time")
                        .font(.ptSerif(.subheadline, weight: .semibold))
                }
                .listRowBackground(Color.white)

                // Preview
                if let routine = selectedRoutine, !routine.exercises.isEmpty {
                    Section {
                        ForEach(routine.exercises.sorted { $0.order < $1.order }) { re in
                            HStack {
                                Text(re.exercise?.name ?? "Unknown")
                                    .font(.ptSerif(.subheadline))
                                Spacer()
                                Text(re.displayTarget)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Preview (\(routine.exercises.count) exercises)")
                            .font(.ptSerif(.subheadline, weight: .semibold))
                    }
                    .listRowBackground(Color.white)
                }
            }
            .ptBackground()
            .navigationTitle("Schedule Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.ptAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") { schedule() }
                        .font(.ptSerif(.body, weight: .semibold))
                        .foregroundColor(canSchedule ? .ptAccent : .secondary)
                        .disabled(!canSchedule)
                }
            }
        }
    }

    private func schedule() {
        guard let routine = selectedRoutine else { return }
        modelContext.insert(ScheduledSession(routine: routine, scheduledDate: scheduledDate))
        // Save now so the session's ID is permanent before it appears in the schedule list — an ID change on a
        // later autosave would rebuild its row and pop an open session (and its workout) off the stack.
        try? modelContext.save()
        dismiss()
    }
}
