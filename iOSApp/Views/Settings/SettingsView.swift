import Charts
import SwiftUI
import UniformTypeIdentifiers

private struct WorkoutExport: Codable {
    let workoutLog: [WorkoutLogEntry]
    let cardioLog: [CardioLogEntry]
    let generalLog: [GeneralActivityEntry]
    let routines: [WorkoutTemplate]
    let userProfile: UserProfile
    let exportedAt: Date
    let appVersion: String

    // Backward-compatible decode: older backups may lack generalLog
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workoutLog  = try c.decodeIfPresent([WorkoutLogEntry].self,      forKey: .workoutLog)  ?? []
        cardioLog   = try c.decodeIfPresent([CardioLogEntry].self,       forKey: .cardioLog)   ?? []
        generalLog  = try c.decodeIfPresent([GeneralActivityEntry].self, forKey: .generalLog)  ?? []
        routines    = try c.decodeIfPresent([WorkoutTemplate].self,      forKey: .routines)    ?? []
        userProfile = try c.decode(UserProfile.self,                     forKey: .userProfile)
        exportedAt  = try c.decodeIfPresent(Date.self,                   forKey: .exportedAt)  ?? Date()
        appVersion  = try c.decodeIfPresent(String.self,                 forKey: .appVersion)  ?? "1.0"
    }

    init(workoutLog: [WorkoutLogEntry], cardioLog: [CardioLogEntry], generalLog: [GeneralActivityEntry],
         routines: [WorkoutTemplate], userProfile: UserProfile, exportedAt: Date, appVersion: String) {
        self.workoutLog  = workoutLog
        self.cardioLog   = cardioLog
        self.generalLog  = generalLog
        self.routines    = routines
        self.userProfile = userProfile
        self.exportedAt  = exportedAt
        self.appVersion  = appVersion
    }
}

struct SettingsView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @AppStorage("userName") private var userName: String = "Alex"

    @State private var exportItem: ExportFile? = nil
    @State private var showImporter = false
    @State private var importAlert: ImportAlert? = nil
    @State private var importConfirmPayload: WorkoutExport? = nil
    @State private var isSyncingHealth = false
    @State private var healthSyncMessage: String? = nil
    @State private var showSavedToast = false
    @State private var showImportError = false       // F-07
    @State private var importError = ""              // F-07
    #if DEBUG
    @State private var debugCelebration: CelebrationKind? = nil
    #endif
    @AppStorage("restTimerSeconds") private var restTimerSeconds: Int = 90
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg: Bool = true
    @AppStorage("prefersDarkMode") private var prefersDarkMode: Bool = true
    @AppStorage("insightLevel") private var insightLevel: String = "standard"
    @AppStorage("emomHapticsEnabled") private var emomHapticsEnabled: Bool = true
    @AppStorage("coachingNudgeFrequency") private var coachingNudgeFrequency: String = "every2days"
    @AppStorage("trainingReminders") private var trainingReminders: Bool = true
    @AppStorage("reminderTimeInterval") private var reminderTimeHour: Int = 18
    @AppStorage("customFatigueDecayEnabled") private var customFatigueDecayEnabled: Bool = false
    @AppStorage("customAlpha") private var customAlpha: Double = 0.08

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = reminderTimeHour
                comps.minute = 0
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                reminderTimeHour = Calendar.current.component(.hour, from: date)
            }
        )
    }

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
                    HStack {
                        Text(weightUnitIsKg ? "Body Weight (kg)" : "Body Weight (lbs)")
                        Spacer()
                        TextField(weightUnitIsKg ? "e.g. 80" : "e.g. 175", value: profile.bodyWeightKg, format: .number)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .onChange(of: store.userProfile.bodyWeightKg) { _, newValue in
                                if let kg = newValue, kg > 0 {
                                    store.logBodyWeight(kg)
                                }
                            }
                    }
                    if store.userProfile.weightHistory.count >= 2 {
                        Chart(store.userProfile.weightHistory) { entry in
                            LineMark(x: .value("Date", entry.date), y: .value("kg", entry.kg))
                                .foregroundStyle(HONTheme.positive)
                            AreaMark(x: .value("Date", entry.date), y: .value("kg", entry.kg))
                                .foregroundStyle(HONTheme.positive.opacity(0.08))
                        }
                        .chartXAxis(.hidden)
                        .frame(height: 72)
                        .padding(.vertical, 4)
                    }
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

                Section {
                    Picker("Rest Timer", selection: $restTimerSeconds) {
                        ForEach(restTimerOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    Picker("Weight Unit", selection: $weightUnitIsKg) {
                        Text("kg").tag(true)
                        Text("lbs").tag(false)
                    }
                    Picker("Insight Level", selection: $insightLevel) {
                        Text("Essential").tag("beginner")
                        Text("Standard").tag("standard")
                        Text("Expert").tag("expert")
                    }
                    Toggle("EMOM Haptic Feedback", isOn: $emomHapticsEnabled)

                    #if DEBUG
                    if insightLevel == "expert" {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Fatigue Decay (\u{03B1})")
                                Spacer()
                                Text(customFatigueDecayEnabled ? String(format: "%.2f", customAlpha) : "Auto")
                                    .foregroundStyle(.secondary)
                            }
                            if customFatigueDecayEnabled {
                                Slider(value: $customAlpha, in: 0.03...0.10, step: 0.01)
                                    .onChange(of: customAlpha) { _, new in
                                        store.userProfile.customFatigueDecay = new
                                    }
                                Text("Lower = slower fatigue (Elite). Higher = faster (Beginner). Auto = based on your tier.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Toggle("Override Auto-Detection", isOn: $customFatigueDecayEnabled)
                                .onChange(of: customFatigueDecayEnabled) { _, enabled in
                                    store.userProfile.customFatigueDecay = enabled ? customAlpha : nil
                                }
                        }
                    }
                    #endif
                } header: {
                    Text("Workout")
                } footer: {
                    Text("Essential shows only key trends. Standard adds INOL and efficiency. Expert shows all derived metrics including PSI and fiber load.")
                        .font(.caption2)
                }

                Section {
                    Picker("Coaching Nudges", selection: $coachingNudgeFrequency) {
                        Text("Off").tag("off")
                        Text("Daily").tag("daily")
                        Text("Every 2 days").tag("every2days")
                        Text("Weekly").tag("weekly")
                    }
                    Toggle("Training Reminders", isOn: $trainingReminders)
                    if trainingReminders {
                        DatePicker("Reminder Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Coaching nudges are motivational messages based on your training history and readiness. Training reminders fire when you haven't logged a session in your set interval.")
                        .font(.caption2)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Composite strength score, PCSA-weighted pattern scores, fatigue-adjusted e1RM, and body composition benchmarks.")
                            .font(.caption2)
                        Text("Strength tiers (BEG/INT/ADV/ELITE) are based on population-relative standards and may not reflect every body type, age group, or training background.")
                            .font(.caption2)
                    }
                }

                Section("Data") {
                    Button {
                        exportData()
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }

                    Button("Export as CSV") {
                        exportCSV()
                    }
                    Text("Includes all sessions, sets, weight history, and today's health snapshot")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import / Restore", systemImage: "square.and.arrow.down")
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
            .alert("Invalid File", isPresented: $showImportError) {
                Button("OK") {}
            } message: {
                Text(importError)
            }
            .confirmationDialog(
                store.workoutLog.isEmpty
                    ? "This will replace your current data. Continue?"
                    : "You already have workout data. Importing will merge — duplicate sessions may appear. Continue?",
                isPresented: Binding(
                    get: { importConfirmPayload != nil },
                    set: { if !$0 { importConfirmPayload = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(store.workoutLog.isEmpty ? "Replace Data" : "Import Anyway", role: .destructive) {
                    if let payload = importConfirmPayload {
                        applyFullImport(payload)
                        importAlert = ImportAlert(
                            title: "Import Complete",
                            message: "Restored \(payload.workoutLog.count) workouts, \(payload.cardioLog.count) cardio sessions, and \(payload.routines.count) routines."
                        )
                    }
                    importConfirmPayload = nil
                }
                Button("Cancel", role: .cancel) {
                    importConfirmPayload = nil
                }
            }
            .onChange(of: store.userProfile) {
                showSavedToast = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { showSavedToast = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showSavedToast {
                    Text("Profile saved")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSavedToast)
                }
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
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = formatter.string(from: now)
        let payload = WorkoutExport(
            workoutLog: store.workoutLog,
            cardioLog: store.cardioLog,
            generalLog: store.generalLog,
            routines: store.routines,
            userProfile: store.userProfile,
            exportedAt: now,
            appVersion: "1.0"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hon_backup_\(dateString).json")
        try? data.write(to: url)
        exportItem = ExportFile(url: url)
    }

    // MARK: - CSV Export (F-29 / V4)

    private func exportCSV() {
        // Build day-keyed lookup from 90-day HealthKit histories
        let cal = Calendar.current
        func dayKey(_ date: Date) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        var sleepByDay:  [String: Double] = [:]
        var hrvByDay:    [String: Double] = [:]
        var rhrByDay:    [String: Double] = [:]
        for pt in health.sleepHistory   { sleepByDay[dayKey(pt.date)]  = pt.value }
        for pt in health.hrvHistory     { hrvByDay[dayKey(pt.date)]    = pt.value }
        for pt in health.restingHRHistory { rhrByDay[dayKey(pt.date)] = pt.value }

        var rows: [String] = []
        rows.append("Date,Type,Exercise,Set,Weight_kg,Reps,e1RM_kg,RPE,Completed,Feel,ReadinessBefore,Duration_min,Notes,Sleep_hrs,HRV_ms,RestingHR_bpm")
        let fmt = ISO8601DateFormatter()

        // Strength sessions
        for entry in store.workoutLog.sorted(by: { $0.startedAt < $1.startedAt }) {
            let d   = fmt.string(from: entry.startedAt)
            let key = dayKey(entry.startedAt)
            let feel      = entry.feelRating?.rawValue ?? ""
            let readiness = entry.readinessBefore.map { String($0) } ?? ""
            let sleep = sleepByDay[key].map { String(format: "%.1f", $0) } ?? ""
            let hrv   = hrvByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            let rhr   = rhrByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            for we in entry.exercises {
                for (i, s) in we.sets.enumerated() {
                    let e1rm = (s.weight > 0 && s.reps > 0) ? String(format: "%.0f", SetRecord.e1RM(weight: s.weight, reps: s.reps)) : ""
                    let rpe  = s.rpe.map { String(format: "%.1f", $0) } ?? ""
                    let name = we.exercise.name.replacingOccurrences(of: ",", with: ";")
                    rows.append("\(d),Strength,\"\(name)\",\(i+1),\(String(format:"%.2f",s.weight)),\(s.reps),\(e1rm),\(rpe),\(s.isCompleted ? 1 : 0),\(feel),\(readiness),,,\(sleep),\(hrv),\(rhr)")
                }
            }
        }

        // Cardio sessions
        for entry in store.cardioLog.sorted(by: { $0.startedAt < $1.startedAt }) {
            let d   = fmt.string(from: entry.startedAt)
            let key = dayKey(entry.startedAt)
            let name  = entry.circuitName.replacingOccurrences(of: ",", with: ";")
            let feel  = entry.feelRating?.rawValue ?? ""
            let sleep = sleepByDay[key].map { String(format: "%.1f", $0) } ?? ""
            let hrv   = hrvByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            let rhr   = rhrByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            rows.append("\(d),Cardio,\"\(name)\",,,,,,,\(feel),,\(entry.durationMinutes),,\(sleep),\(hrv),\(rhr)")
        }

        // General activity sessions
        for entry in store.generalLog.sorted(by: { $0.startedAt < $1.startedAt }) {
            let d   = fmt.string(from: entry.startedAt)
            let key = dayKey(entry.startedAt)
            let name  = entry.activityType.rawValue.replacingOccurrences(of: ",", with: ";")
            let notes = entry.notes.replacingOccurrences(of: ",", with: ";")
            let feel  = entry.feelRating?.rawValue ?? ""
            let sleep = sleepByDay[key].map { String(format: "%.1f", $0) } ?? ""
            let hrv   = hrvByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            let rhr   = rhrByDay[key].map   { String(format: "%.0f", $0) } ?? ""
            rows.append("\(d),General,\"\(name)\",,,,,,,\(feel),,\(entry.durationMinutes),\"\(notes)\",\(sleep),\(hrv),\(rhr)")
        }

        let csv = rows.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd_HH-mm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hon_workouts_\(df.string(from: Date())).csv")
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
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(WorkoutExport.self, from: data)
                // F-07: Reject backups containing future-dated workouts
                let futureEntries = payload.workoutLog.filter { $0.startedAt > Date() }
                if !futureEntries.isEmpty {
                    importError = "File contains \(futureEntries.count) future-dated workout(s). Please verify the backup file."
                    showImportError = true
                    return
                }
                // Show confirmation before overwriting data
                importConfirmPayload = payload
            } catch {
                importAlert = ImportAlert(title: "Import Failed", message: "File format not recognized.")
            }
        }
    }

    private func applyFullImport(_ payload: WorkoutExport) {
        store.workoutLog  = payload.workoutLog.sorted { $0.startedAt > $1.startedAt }
        store.cardioLog   = payload.cardioLog.sorted { $0.startedAt > $1.startedAt }
        store.generalLog  = payload.generalLog.sorted { $0.startedAt > $1.startedAt }
        store.routines    = payload.routines
        store.userProfile = payload.userProfile
        store.persistImport()
        store.refreshAnalytics()
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
