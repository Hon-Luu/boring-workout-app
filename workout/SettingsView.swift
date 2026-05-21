import SwiftUI
import UniformTypeIdentifiers

private struct WorkoutExport: Codable {
    let workoutLog: [WorkoutLogEntry]
    let routines: [WorkoutTemplate]
    let exportedAt: Date
}

struct SettingsView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @AppStorage("userName") private var userName: String = "Alex"

    @State private var exportItem: ExportFile? = nil
    @State private var showImporter = false
    @State private var importAlert: ImportAlert? = nil
    @State private var isSyncingHealth = false
    @State private var healthSyncMessage: String? = nil
    #if DEBUG
    @State private var debugCelebration: CelebrationKind? = nil
    #endif
    @AppStorage("restTimerSeconds") private var restTimerSeconds: Int = 90
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg: Bool = true
    @AppStorage("prefersDarkMode") private var prefersDarkMode: Bool = true

    private let restTimerOptions: [(label: String, value: Int)] = [
        ("Off", 0), ("60s", 60), ("90s", 90), ("2 min", 120), ("3 min", 180), ("5 min", 300)
    ]

    // Local bindings into the store's userProfile
    private var profile: Binding<UserProfile> {
        Binding(
            get: { store.userProfile },
            set: { store.userProfile = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    optionalDoubleRow("Body Weight (kg)", value: profile.bodyWeightKg,
                                      placeholder: "e.g. 80", range: 30...250)
                    optionalIntRow("Age", value: profile.age,
                                   placeholder: "e.g. 28", range: 13...100)
                    optionalDoubleRow("Height (cm)", value: profile.heightCm,
                                      placeholder: "e.g. 178", range: 120...230)
                } header: {
                    Text("Strength Profile")
                } footer: {
                    Text("Body weight and age determine your strength tier standards. Higher body weight raises the bar; age 40+ lowers the tier ceilings so performance is judged relative to your age group.")
                        .font(.caption2)
                }

                Section {
                    optionalDoubleRow("Body Fat %", value: profile.bodyFatPercent,
                                      placeholder: "e.g. 18", range: 3...60)
                    optionalDoubleRow("Muscle Mass %", value: profile.muscleMassPercent,
                                      placeholder: "e.g. 40", range: 10...65)
                    optionalDoubleRow("Body Water %", value: profile.waterPercent,
                                      placeholder: "e.g. 55", range: 20...80)
                    optionalDoubleRow("Bone Mass (kg)", value: profile.boneMassKg,
                                      placeholder: "e.g. 3.2", range: 1...8)

                    if health.isAuthorized {
                        Button {
                            syncBodyCompositionFromHealth()
                        } label: {
                            HStack {
                                Label("Sync from Apple Health", systemImage: "heart.circle")
                                if isSyncingHealth { Spacer(); ProgressView().scaleEffect(0.8) }
                            }
                        }
                        .disabled(isSyncingHealth)

                        if let msg = healthSyncMessage {
                            Text(msg).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Body Composition (Smart Scale)")
                } footer: {
                    Text("Enter values from a smart scale or DEXA scan, or sync from Apple Health if you have a connected scale.")
                        .font(.caption2)
                }

                Section("Workout") {
                    Picker("Rest Timer", selection: $restTimerSeconds) {
                        ForEach(restTimerOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    Picker("Weight Unit", selection: $weightUnitIsKg) {
                        Text("kg").tag(true)
                        Text("lbs").tag(false)
                    }
                }

                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $prefersDarkMode)
                }

                Section {
                    NavigationLink {
                        HealthMetricsSettingsView()
                    } label: {
                        HStack {
                            Label("Health Metrics", systemImage: "heart.text.clipboard")
                            Spacer()
                            Text(enabledMetricsSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Health")
                } footer: {
                    Text("Garmin, Whoop, Oura, and other wearables can share data with Apple Health. Enable your device's Apple Health sync in its companion app and this app will automatically read it.")
                        .font(.caption2)
                }

                Section("History") {
                    NavigationLink {
                        WorkoutHistorySettingsView()
                    } label: {
                        Label("Workout History", systemImage: "clock.arrow.counterclockwise")
                    }
                }

                Section {
                    NavigationLink {
                        StrengthLabView()
                    } label: {
                        HStack {
                            Label("Lab", systemImage: "flask.fill")
                            Spacer()
                            Text("Advanced analytics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Analytics")
                } footer: {
                    Text("Composite strength score, PCSA-weighted pattern scores, fatigue-adjusted e1RM, and body composition benchmarks.")
                        .font(.caption2)
                }

                Section("Data") {
                    Button {
                        exportData()
                    } label: {
                        Label("Export Workouts", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Workouts", systemImage: "square.and.arrow.down")
                    }
                }

                Section("About") {
                    HelpNavigationLink()
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }

                #if DEBUG
                Section("Debug") {
                    NavigationLink {
                        HONDebugView()
                    } label: {
                        Label("HON Engine", systemImage: "brain.head.profile")
                    }
                    NavigationLink {
                        UATScenarioView()
                    } label: {
                        Label("UAT Scenarios", systemImage: "testtube.2")
                    }
                }

                Section("Debug — Celebrations") {
                    Button("Session — comeback (Sunday)") {
                        debugCelebration = .sessionComplete(
                            duration: "38m", sets: 12, volume: 2100,
                            sessionDays: [6], isComeback: true, completedDayIndex: 6
                        )
                    }
                    Button("Session — 4 this week (Sunday)") {
                        debugCelebration = .sessionComplete(
                            duration: "52m", sets: 21, volume: 5840,
                            sessionDays: [0, 2, 4, 6], isComeback: false, completedDayIndex: 6
                        )
                    }
                    Button("Session — first of week (Wednesday)") {
                        debugCelebration = .sessionComplete(
                            duration: "38m", sets: 12, volume: 2100,
                            sessionDays: [2], isComeback: false, completedDayIndex: 2
                        )
                    }
                    Button("Personal Record — Bench Press") {
                        debugCelebration = .personalRecord(
                            exerciseName: "Bench Press", weight: 102.5, reps: 3
                        )
                    }
                    Button("Streak — 7 days") {
                        debugCelebration = .streakMilestone(days: 7)
                    }
                    Button("Streak — 30 days") {
                        debugCelebration = .streakMilestone(days: 30)
                    }
                }
                .foregroundStyle(HONTheme.accent)
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            #if DEBUG
            .fullScreenCover(item: $debugCelebration) { kind in
                CelebrationOverlay(kind: kind) { debugCelebration = nil }
            }
            #endif
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(item: $importAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Body Measurement Row Helpers

    @ViewBuilder
    private func optionalDoubleRow(
        _ label: String,
        value: Binding<Double?>,
        placeholder: String,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .keyboardType(.decimalPad)
                .frame(width: 90)
        }
    }

    @ViewBuilder
    private func optionalIntRow(
        _ label: String,
        value: Binding<Int?>,
        placeholder: String,
        range: ClosedRange<Int>
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .keyboardType(.numberPad)
                .frame(width: 90)
        }
    }

    // MARK: - Health Sync

    private func syncBodyCompositionFromHealth() {
        isSyncingHealth = true
        healthSyncMessage = nil
        Task {
            let snapshot = await health.fetchBodyCompositionSnapshot()
            await MainActor.run {
                var updated = false
                if let fat = snapshot.bodyFatPct, fat > 0 {
                    store.userProfile.bodyFatPercent = fat
                    updated = true
                }
                if let weight = snapshot.bodyWeightKg, weight > 0 {
                    store.userProfile.bodyWeightKg = weight
                    updated = true
                }
                if let lean = snapshot.leanMassKg, lean > 0 {
                    // Derive muscle mass % from lean mass and body weight
                    if let bw = store.userProfile.bodyWeightKg, bw > 0 {
                        store.userProfile.muscleMassPercent = (lean / bw) * 100
                    }
                    updated = true
                }
                isSyncingHealth = false
                healthSyncMessage = updated
                    ? "Synced successfully from Apple Health."
                    : "No body composition data found in Health."
            }
        }
    }

    // MARK: - Export

    private func exportData() {
        let payload = WorkoutExport(
            workoutLog: store.workoutLog,
            routines: store.routines,
            exportedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hon_export_\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        exportItem = ExportFile(url: url)
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            importAlert = ImportAlert(title: "Import Failed", message: err.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importAlert = ImportAlert(title: "Import Failed", message: "Could not access the selected file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder().decode(WorkoutExport.self, from: data)
                mergeImport(payload)
                importAlert = ImportAlert(
                    title: "Import Complete",
                    message: "Added \(payload.workoutLog.count) workouts and \(payload.routines.count) routines."
                )
            } catch {
                importAlert = ImportAlert(title: "Import Failed", message: "File format not recognized.")
            }
        }
    }

    private func mergeImport(_ payload: WorkoutExport) {
        let existingIds = Set(store.workoutLog.map(\.id))
        let newEntries = payload.workoutLog.filter { !existingIds.contains($0.id) }
        store.workoutLog.append(contentsOf: newEntries)
        store.workoutLog.sort { $0.startedAt > $1.startedAt }

        let existingRoutineIds = Set(store.routines.map(\.id))
        let newRoutines = payload.routines.filter { !existingRoutineIds.contains($0.id) }
        newRoutines.forEach { store.addOrUpdateRoutine($0) }

        store.persistImport()
    }

    // Summary label for the Health Metrics row
    @AppStorage("enabledHealthMetricIds") private var enabledMetricIdsForSummary: String = HealthMetric.defaultEnabledString
    private var enabledMetricsSummary: String {
        let count = enabledMetricIdsForSummary.split(separator: ",").count
        return "\(count) of \(HealthMetric.all.count)"
    }
}

// MARK: - Health Metrics picker

struct HealthMetricsSettingsView: View {
    @AppStorage("enabledHealthMetricIds") private var enabledIdsRaw: String = HealthMetric.defaultEnabledString

    private var enabledIds: Set<String> {
        Set(enabledIdsRaw.split(separator: ",").map(String.init))
    }

    private func toggle(_ metric: HealthMetric) {
        var ids = enabledIds
        if ids.contains(metric.id) {
            guard ids.count > 1 else { return }  // keep at least one enabled
            ids.remove(metric.id)
        } else {
            ids.insert(metric.id)
        }
        enabledIdsRaw = ids.sorted().joined(separator: ",")
    }

    var body: some View {
        List {
            ForEach(HealthMetric.Category.allCases, id: \.self) { cat in
                let metrics = HealthMetric.all.filter { $0.category == cat }
                Section(cat.rawValue) {
                    ForEach(metrics) { metric in
                        Button {
                            toggle(metric)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: metric.icon)
                                    .foregroundStyle(metric.color)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.label)
                                        .foregroundStyle(.primary)
                                    Text(metric.sourceHint)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: enabledIds.contains(metric.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(enabledIds.contains(metric.id)
                                                     ? metric.color : Color.secondary.opacity(0.4))
                                    .font(.system(size: 20))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Health Metrics")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Helpers

private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
