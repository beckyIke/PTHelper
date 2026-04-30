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
                        ForEach(routines) { routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine)) {
                                RoutineRowView(routine: routine)
                            }
                            .listRowBackground(Color.white)
                        }
                        .onDelete(perform: deleteRoutines)
                    }
                    .ptBackground()
                }
            }
            .background(Color.ptBackground.ignoresSafeArea())
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
                        .foregroundColor(.ptTerracotta)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
