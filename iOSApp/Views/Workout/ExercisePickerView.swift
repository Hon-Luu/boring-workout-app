import SwiftUI

// MARK: - Root Picker

struct ExercisePickerView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialRegion: BodyRegion?
    let showTemplateToggle: Bool
    let onSelect: (Exercise, Bool) -> Void

    @State private var path: [BodyRegion] = []
    @State private var swapForTemplate = false
    @State private var showAllSearch = false

    init(
        title: String = "Add Exercise",
        initialRegion: BodyRegion? = nil,
        showTemplateToggle: Bool = false,
        onSelect: @escaping (Exercise, Bool) -> Void
    ) {
        self.title = title
        self.initialRegion = initialRegion
        self.showTemplateToggle = showTemplateToggle
        self.onSelect = onSelect
        if let region = initialRegion {
            _path = State(initialValue: [region])
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            BodyRegionGrid(
                onSelect: { path.append($0) },
                onSearchAll: { showAllSearch = true }
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: BodyRegion.self) { region in
                ExerciseListByEquipment(
                    region: region,
                    showTemplateToggle: showTemplateToggle,
                    swapForTemplate: $swapForTemplate
                ) { exercise in
                    onSelect(exercise, swapForTemplate)
                    dismiss()
                }
            }
            .sheet(isPresented: $showAllSearch) {
                AllExerciseSearchView { exercise in
                    onSelect(exercise, swapForTemplate)
                    showAllSearch = false
                    dismiss()
                }
                .environment(store)
            }
        }
    }
}

// MARK: - Step 1: Body Region Grid

struct BodyRegionGrid: View {
    @Environment(SeedStore.self) private var store
    let onSelect: (BodyRegion) -> Void
    let onSearchAll: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(BodyRegion.allCases, id: \.self) { region in
                    RegionCard(
                        region: region,
                        count: store.exercises.filter { $0.bodyRegion == region }.count
                    )
                    .onTapGesture { onSelect(region) }
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onSearchAll) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.bold())
                        .foregroundStyle(HONTheme.accent)
                    Text("Search all exercises")
                        .font(.subheadline.bold())
                        .foregroundStyle(HONTheme.accent)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RegionCard: View {
    let region: BodyRegion
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: region.icon)
                .font(.system(size: 36))
                .foregroundStyle(HONTheme.accent)
            Text(region.rawValue)
                .font(.headline)
            Text("\(count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(HONTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Step 2: Exercise List for Body Region

struct ExerciseListByEquipment: View {
    @Environment(SeedStore.self) private var store
    let region: BodyRegion
    let showTemplateToggle: Bool
    @Binding var swapForTemplate: Bool
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedEquipment: Equipment? = nil

    private var availableEquipment: [Equipment] {
        let used = Set(store.exercises.filter { $0.bodyRegion == region }.map(\.equipment))
        return Equipment.allCases.filter { used.contains($0) }
    }

    private var exercises: [Exercise] {
        store.exercises
            .filter { ex in
                ex.bodyRegion == region &&
                (selectedEquipment == nil || ex.equipment == selectedEquipment) &&
                (searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText))
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Swap for template toggle (only shown in swap mode when a template is active)
            if showTemplateToggle {
                Toggle(isOn: $swapForTemplate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also update template")
                            .font(.subheadline.bold())
                        Text("Permanently replaces this exercise in your routine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                Divider()
            }

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    EquipmentPill(label: "All", isSelected: selectedEquipment == nil) {
                        selectedEquipment = nil
                    }
                    ForEach(availableEquipment, id: \.self) { equip in
                        EquipmentPill(label: equip.rawValue, isSelected: selectedEquipment == equip) {
                            selectedEquipment = selectedEquipment == equip ? nil : equip
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            Divider()

            List(exercises) { exercise in
                ExercisePickerRow(
                    exercise: exercise,
                    pr: store.personalRecord(for: exercise),
                    onSelect: { onSelect(exercise) }
                )
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search \(region.rawValue) exercises")
        .navigationTitle(region.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EquipmentPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? HONTheme.accent : Color.secondary.opacity(0.12),
                            in: Capsule())
                .foregroundStyle(isSelected ? HONTheme.textPrimary : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct ExercisePickerRow: View {
    let exercise: Exercise
    let pr: PersonalRecord?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if exercise.equipment == .dumbbell {
                        Text("Weight logged per hand")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        EquipmentTag(equipment: exercise.equipment)
                        if let pr {
                            Text("PR \(pr.weight.weightFormatted) kg × \(pr.reps)")
                                .font(.caption)
                                .foregroundStyle(HONTheme.accent)
                        }
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HONTheme.accent)
            }
            .padding(.vertical, 2)
        }
    }
}

private struct EquipmentTag: View {
    let equipment: Equipment

    var color: Color {
        switch equipment {
        case .barbell:     return HONTheme.warning
        case .dumbbell:    return HONTheme.chartLavender
        case .ezBar:       return HONTheme.chartAmber
        case .straightBar: return HONTheme.chartClay
        case .cable:       return HONTheme.chartSage
        case .machine:     return HONTheme.chartLavender
        case .bodyweight:  return HONTheme.positive
        case .kettlebell:  return .brown
        }
    }

    var body: some View {
        Text(equipment.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - All-Exercise Global Search

struct AllExerciseSearchView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedEquipment: Equipment? = nil

    private let pillEquipment: [Equipment] = [.machine, .dumbbell, .barbell, .ezBar, .straightBar, .bodyweight]

    private var filteredExercises: [Exercise] {
        store.exercises
            .filter { ex in
                (selectedEquipment == nil || ex.equipment == selectedEquipment) &&
                (searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText))
            }
            .sorted { $0.name < $1.name }
    }

    private var recentExercises: [Exercise] {
        store.recentExerciseIds.compactMap { id in
            store.exercises.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        EquipmentPill(label: "All", isSelected: selectedEquipment == nil) {
                            selectedEquipment = nil
                        }
                        ForEach(pillEquipment, id: \.self) { equip in
                            EquipmentPill(label: equip.rawValue, isSelected: selectedEquipment == equip) {
                                selectedEquipment = selectedEquipment == equip ? nil : equip
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Divider()

                if filteredExercises.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        if searchText.isEmpty && !recentExercises.isEmpty {
                            Section("Recents") {
                                ForEach(recentExercises) { exercise in
                                    ExercisePickerRow(
                                        exercise: exercise,
                                        pr: store.personalRecord(for: exercise),
                                        onSelect: { onSelect(exercise) }
                                    )
                                }
                            }
                        }
                        Section(searchText.isEmpty ? "All Exercises" : "Results") {
                            ForEach(filteredExercises) { exercise in
                                ExercisePickerRow(
                                    exercise: exercise,
                                    pr: store.personalRecord(for: exercise),
                                    onSelect: { onSelect(exercise) }
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle("All Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
