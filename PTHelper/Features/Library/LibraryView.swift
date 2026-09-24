import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var showingAddExercise = false

    var filtered: [Exercise] {
        exercises.filter { ex in
            let matchesSearch = searchText.isEmpty
                || ex.name.localizedCaseInsensitiveContains(searchText)
                || ex.bodyPart.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || ex.category == selectedCategory?.rawValue
            return matchesSearch && matchesCategory
        }
    }

    var grouped: [(String, [Exercise])] {
        Dictionary(grouping: filtered, by: \.category).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(ExerciseCategory.allCases) { cat in
                            FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.vertical, 6)

                ForEach(grouped, id: \.0) { category, items in
                    Section {
                        ForEach(items) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                ExerciseRowView(exercise: exercise)
                            }
                            .ptGlassRow()
                        }
                    } header: {
                        PTSectionHeader(category)
                    }
                }
            }
            .listRowSpacing(8)
            .animation(PTMotion.snappy, value: selectedCategory)
            .ptBackground()
            .searchable(text: $searchText, prompt: "Search exercises or body part")
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddExercise = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PTChip(title: title, isSelected: isSelected) {
            withAnimation(PTMotion.snappy) { action() }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    private var category: ExerciseCategory? { ExerciseCategory(rawValue: exercise.category) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category?.systemImage ?? "figure.walk")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ptAccent)
                .frame(width: 40, height: 40)
                .background(Color.ptAccent.opacity(0.15), in: .circle)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.ptSerif(.body))
                if exercise.isCustom {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.ptAccent)
                }
            }
            HStack(spacing: 4) {
                Text(exercise.bodyPart)
                    .font(.caption).foregroundColor(.secondary)
                Text("·")
                    .font(.caption).foregroundColor(.secondary)
                Text(exercise.displayTarget)
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        }
        .padding(.vertical, 4)
    }
}
