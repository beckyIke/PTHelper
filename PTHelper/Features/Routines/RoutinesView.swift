import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]

    @State private var showingAddRoutine = false
    @State private var newRoutineName = ""

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap + to create your first routine.")
                    )
                } else {
                    List {
                        ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                RoutineRowView(routine: routine)
                            }
                            .ptGlassRow()
                            .ptEntrance(index: index)
                        }
                        .onDelete(perform: deleteRoutines)
                    }
                    .listRowSpacing(10)
                }
            }
            .ptBackground()
            .animation(PTMotion.bouncy, value: routines.count)
            .navigationTitle("My Routines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddRoutine = true } label: {
                        Image(systemName: "plus")
                    }
                }
                if !routines.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .alert("New Routine", isPresented: $showingAddRoutine) {
                TextField("Routine name", text: $newRoutineName)
                Button("Cancel", role: .cancel) { newRoutineName = "" }
                Button("Create") { createRoutine() }
            } message: {
                Text("Enter a name for your new routine.")
            }
        }
    }

    private func createRoutine() {
        let trimmed = newRoutineName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Routine(name: trimmed))
        newRoutineName = ""
    }

    private func deleteRoutines(offsets: IndexSet) {
        for index in offsets { modelContext.delete(routines[index]) }
    }
}

struct RoutineRowView: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 14) {
            Text("\(routine.exercises.count)")
                .font(.ptNumber(20))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.ptAccent.gradient, in: .rect(cornerRadius: PTRadius.sm))
                .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
            Text(routine.name)
                .font(.ptSerif(.headline, weight: .semibold))
            HStack(spacing: 6) {
                Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
                if routine.recurrence != .none {
                    Text("·").font(.caption).foregroundColor(.secondary)
                    Label(routine.recurrence.displayName, systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.ptAccent)
                }
            }
        }
        }
        .padding(.vertical, 6)
    }
}
