import SwiftUI

// MARK: - Log General Activity Sheet

struct LogGeneralActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SeedStore.self) private var store

    @State private var selectedType: GeneralActivityEntry.GeneralActivityType = .yoga
    @State private var durationMinutes: Int = 30
    @State private var intensity: GeneralActivityEntry.IntensityLevel = .moderate
    @State private var notes: String = ""
    @State private var feelRating: FeelRating? = nil

    // Grid layout for activity type picker
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Activity Type
                Section("Activity Type") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(GeneralActivityEntry.GeneralActivityType.allCases, id: \.self) { type in
                            ActivityTypeCell(
                                type: type,
                                isSelected: selectedType == type
                            )
                            .onTapGesture { selectedType = type }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: Duration
                Section("Duration") {
                    Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 5...180, step: 5)
                }

                // MARK: Intensity
                Section("Intensity") {
                    Picker("Intensity", selection: $intensity) {
                        ForEach(GeneralActivityEntry.IntensityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // MARK: Feel
                Section("How did it feel? (optional)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FeelRating.allCases, id: \.self) { rating in
                                Button(action: {
                                    feelRating = feelRating == rating ? nil : rating
                                }) {
                                    Text(rating.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            feelRating == rating
                                                ? HONTheme.accent.opacity(0.9)
                                                : Color.secondary.opacity(0.1),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(feelRating == rating ? HONTheme.textPrimary : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Notes
                Section("Notes (optional)") {
                    TextField("How did it go?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save Activity") {
                        let entry = GeneralActivityEntry(
                            activityType: selectedType,
                            durationMinutes: durationMinutes,
                            intensityLevel: intensity,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            startedAt: Date(),
                            feelRating: feelRating
                        )
                        store.saveGeneralActivity(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Activity Type Cell

private struct ActivityTypeCell: View {
    let type: GeneralActivityEntry.GeneralActivityType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(isSelected ? Color.black : HONTheme.accent)
            Text(type.rawValue)
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? Color.black : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            isSelected ? HONTheme.accent : Color.secondary.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}
