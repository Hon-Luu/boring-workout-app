import SwiftUI
import AVFoundation

// MARK: - CountdownRing

struct CountdownRing: View {
    let remaining: Int
    let total: Int
    let color: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    private var timeText: String {
        if total <= 60 {
            return "\(remaining)"
        } else {
            let m = remaining / 60
            let s = remaining % 60
            return String(format: "%d:%02d", m, s)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            Text(timeText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(HONTheme.textPrimary)
        }
    }
}

// MARK: - AMRAPSessionView

struct AMRAPSessionView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health

    let circuit: CardioCircuit
    let onDone: () -> Void

    @State private var timeRemaining: Int
    @State private var timer: Timer? = nil
    @State private var currentRound: Int = 0
    @State private var currentExerciseIndex: Int = 0
    @State private var currentReps: Int
    @State private var results: [CircuitRoundResult] = []
    @State private var sessionStartTime = Date()
    @State private var completedEntry: CardioLogEntry? = nil
    @State private var showCountdown = true
    @State private var countdownValue = 3

    init(circuit: CardioCircuit, onDone: @escaping () -> Void) {
        self.circuit = circuit
        self.onDone = onDone
        _timeRemaining = State(initialValue: circuit.durationMinutes * 60)
        _currentReps = State(initialValue: circuit.exercises.first?.targetReps ?? 10)
    }

    private var currentExercise: CircuitExercise? {
        circuit.exercises[safe: currentExerciseIndex]
    }

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            if let entry = completedEntry {
                CardioSessionSummaryView(entry: entry, onDone: onDone)
            } else {
                mainSessionContent
            }

            // 3-2-1 countdown overlay
            if showCountdown {
                countdownOverlay
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: Countdown Overlay

    @ViewBuilder
    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Get Ready")
                    .font(.title.bold())
                    .foregroundStyle(HONTheme.textPrimary)
                Text("\(countdownValue)")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(HONTheme.accent)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: countdownValue)
            }
        }
        .onAppear { startCountdown() }
    }

    private var mainSessionContent: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button { finishSession() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HONTheme.textPrimary.opacity(0.7))
                }
                Spacer()
                Text("Round \(currentRound + 1)")
                    .font(.headline)
                    .foregroundStyle(HONTheme.textPrimary)
                Spacer()
                // Exercise progress dots
                HStack(spacing: 5) {
                    ForEach(circuit.exercises.indices, id: \.self) { i in
                        Circle()
                            .fill(i == currentExerciseIndex ? HONTheme.accent : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Countdown ring
            CountdownRing(
                remaining: timeRemaining,
                total: circuit.durationMinutes * 60,
                color: HONTheme.accent
            )
            .frame(width: 200, height: 200)

            Spacer().frame(height: 28)

            // Current exercise name
            Text(currentExercise?.exercise.name ?? "")
                .font(.title.bold())
                .foregroundStyle(HONTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("Target: \(currentExercise?.targetReps ?? 0) reps")
                .font(.subheadline)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.6))
                .padding(.top, 4)

            Spacer().frame(height: 24)

            // Rep counter
            HStack(spacing: 32) {
                Button {
                    if currentReps > 0 { currentReps -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .foregroundStyle(HONTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(HONTheme.textPrimary.opacity(0.15), in: Circle())
                }

                Text("\(currentReps)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(HONTheme.textPrimary)
                    .frame(minWidth: 100)

                Button {
                    currentReps += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(HONTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(HONTheme.textPrimary.opacity(0.15), in: Circle())
                }
            }

            Spacer().frame(height: 32)

            // Done button
            Button(action: advanceExercise) {
                HStack {
                    Text("Done")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(HONTheme.textPrimary)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            Button("End Session") { finishSession() }
                .font(.subheadline)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.5))
                .padding(.bottom, 24)
        }
    }

    // MARK: Logic

    private func startCountdown() {
        // If there's a saved session for this circuit, skip the countdown and resume
        if UserDefaults.standard.string(forKey: "honcardio_circuit_id") == circuit.id.uuidString {
            showCountdown = false
            startSession()
            return
        }
        var count = 3
        countdownValue = count
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            count -= 1
            if count <= 0 {
                t.invalidate()
                showCountdown = false
                startSession()
            } else {
                countdownValue = count
            }
        }
    }

    private func startSession() {
        let total = circuit.durationMinutes * 60
        // Restore wall-clock start time if this session was previously saved
        let savedId   = UserDefaults.standard.string(forKey: "honcardio_circuit_id")
        let savedTime = UserDefaults.standard.double(forKey: "honcardio_start_time")
        if savedId == circuit.id.uuidString, savedTime > 0 {
            sessionStartTime = Date(timeIntervalSince1970: savedTime)
        } else {
            sessionStartTime = Date()
            UserDefaults.standard.set(circuit.id.uuidString, forKey: "honcardio_circuit_id")
            UserDefaults.standard.set(sessionStartTime.timeIntervalSince1970, forKey: "honcardio_start_time")
        }
        // Sync immediately so the UI shows correct remaining time on restore
        let elapsed = Int(Date().timeIntervalSince(sessionStartTime))
        timeRemaining = max(0, total - elapsed)
        if timeRemaining <= 0 { finishSession(); return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Derive remaining from wall clock — survives app backgrounding
            let el = Int(Date().timeIntervalSince(sessionStartTime))
            let rem = max(0, total - el)
            timeRemaining = rem
            if rem <= 0 { finishSession() }
        }
    }

    private func advanceExercise() {
        guard let ce = currentExercise else { return }
        let result = CircuitRoundResult(
            round: currentRound,
            exerciseId: ce.id,
            exerciseName: ce.exercise.name,
            repsCompleted: currentReps
        )
        results.append(result)

        if currentExerciseIndex + 1 >= circuit.exercises.count {
            currentRound += 1
            currentExerciseIndex = 0
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            currentExerciseIndex += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        currentReps = circuit.exercises[safe: currentExerciseIndex]?.targetReps ?? 10
    }

    private func finishSession() {
        guard completedEntry == nil else { return }
        timer?.invalidate()
        timer = nil
        UserDefaults.standard.removeObject(forKey: "honcardio_circuit_id")
        UserDefaults.standard.removeObject(forKey: "honcardio_start_time")

        let entry = CardioLogEntry(
            circuitId: circuit.id,
            circuitName: circuit.displayName,
            format: circuit.format,
            durationMinutes: circuit.durationMinutes,
            exercises: circuit.exercises,
            results: results,
            startedAt: sessionStartTime,
            finishedAt: Date()
        )
        store.saveCardioSession(entry)
        health.saveCardioSession(entry)
        completedEntry = entry
    }
}

// MARK: - EMOMSessionView

struct EMOMSessionView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health

    let circuit: CardioCircuit
    let onDone: () -> Void

    @State private var currentMinute: Int = 0
    @State private var secondsThisMinute: Int = 60
    @State private var timer: Timer? = nil
    @State private var currentReps: Int
    @State private var results: [CircuitRoundResult] = []
    @State private var sessionStartTime = Date()
    @State private var completedEntry: CardioLogEntry? = nil
    @State private var isWarning: Bool = false
    @State private var showCountdown = true
    @State private var countdownValue = 3
    @State private var lastAnnouncedMinute: Int = -1
    private let synth = AVSpeechSynthesizer()

    init(circuit: CardioCircuit, onDone: @escaping () -> Void) {
        self.circuit = circuit
        self.onDone = onDone
        _currentReps = State(initialValue: circuit.exercises.first?.targetReps ?? 10)
    }

    private var currentExerciseIndex: Int {
        guard !circuit.exercises.isEmpty else { return 0 }
        return currentMinute % circuit.exercises.count
    }

    private var currentExercise: CircuitExercise? {
        circuit.exercises[safe: currentExerciseIndex]
    }

    private var upcomingExercises: [CircuitExercise] {
        guard !circuit.exercises.isEmpty else { return [] }
        let next1 = (currentMinute + 1) % circuit.exercises.count
        let next2 = (currentMinute + 2) % circuit.exercises.count
        if next1 == next2 {
            return [circuit.exercises[next1]]
        }
        return [circuit.exercises[next1], circuit.exercises[next2]]
    }

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            if let entry = completedEntry {
                CardioSessionSummaryView(entry: entry, onDone: onDone)
            } else {
                mainSessionContent
            }

            if showCountdown {
                emomCountdownOverlay
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    @ViewBuilder
    private var emomCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Get Ready")
                    .font(.title.bold())
                    .foregroundStyle(HONTheme.textPrimary)
                Text("\(countdownValue)")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(HONTheme.warning)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: countdownValue)
            }
        }
        .onAppear { startCountdown() }
    }

    private var ringColor: Color {
        isWarning ? HONTheme.negative : HONTheme.warning
    }

    private var mainSessionContent: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button { finishSession() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HONTheme.textPrimary.opacity(0.7))
                }
                Spacer()
                Text("Minute \(currentMinute + 1) / \(circuit.durationMinutes)")
                    .font(.headline)
                    .foregroundStyle(HONTheme.textPrimary)
                Spacer()
                // Placeholder for alignment
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Exercise cycle strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(circuit.exercises.indices, id: \.self) { i in
                        Text(circuit.exercises[i].exercise.name)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                i == currentExerciseIndex
                                    ? ringColor
                                    : Color.white.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                i == currentExerciseIndex ? HONTheme.textPrimary : .white.opacity(0.6)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            Spacer()

            // Per-minute countdown ring
            ZStack {
                CountdownRing(
                    remaining: secondsThisMinute,
                    total: 60,
                    color: ringColor
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isWarning ? 1.04 : 1.0)
                .animation(
                    isWarning
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: isWarning
                )
            }

            Spacer().frame(height: 24)

            // Current exercise name
            Text(currentExercise?.exercise.name ?? "")
                .font(.title.bold())
                .foregroundStyle(HONTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("Target: \(currentExercise?.targetReps ?? 0) reps/min")
                .font(.subheadline)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.6))
                .padding(.top, 4)

            Spacer().frame(height: 20)

            // Rep counter
            HStack(spacing: 32) {
                Button {
                    if currentReps > 0 { currentReps -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .foregroundStyle(HONTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(HONTheme.textPrimary.opacity(0.15), in: Circle())
                }

                Text("\(currentReps)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(HONTheme.textPrimary)
                    .frame(minWidth: 100)

                Button {
                    currentReps += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(HONTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(HONTheme.textPrimary.opacity(0.15), in: Circle())
                }
            }

            Text(isWarning ? "Time almost up!" : "Adjust reps — auto-saves at 0")
                .font(.caption)
                .foregroundStyle(isWarning ? HONTheme.negative : .white.opacity(0.4))
                .padding(.top, 8)

            Spacer().frame(height: 16)

            // Upcoming exercises strip
            if !upcomingExercises.isEmpty {
                HStack(spacing: 6) {
                    Text("Next:")
                        .font(.caption)
                        .foregroundStyle(HONTheme.textPrimary.opacity(0.5))
                    ForEach(upcomingExercises.indices, id: \.self) { i in
                        Text(upcomingExercises[i].exercise.name)
                            .font(.caption.bold())
                            .foregroundStyle(HONTheme.textPrimary.opacity(0.7))
                        if i < upcomingExercises.count - 1 {
                            Text("·").foregroundStyle(HONTheme.textPrimary.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer().frame(height: 16)

            Button("End Session") { finishSession() }
                .font(.subheadline)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.5))
                .padding(.bottom, 24)
        }
    }

    // MARK: Logic

    private func startCountdown() {
        // If there's a saved session for this circuit, skip the countdown and resume
        if UserDefaults.standard.string(forKey: "honcardio_circuit_id") == circuit.id.uuidString {
            showCountdown = false
            startSession()
            return
        }
        var count = 3
        countdownValue = count
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            count -= 1
            if count <= 0 {
                t.invalidate()
                showCountdown = false
                startSession()
            } else {
                countdownValue = count
            }
        }
    }

    private func startSession() {
        // Restore wall-clock start time if this session was previously saved
        let savedId   = UserDefaults.standard.string(forKey: "honcardio_circuit_id")
        let savedTime = UserDefaults.standard.double(forKey: "honcardio_start_time")
        if savedId == circuit.id.uuidString, savedTime > 0 {
            sessionStartTime = Date(timeIntervalSince1970: savedTime)
            // Fast-forward state to where we actually are
            let elapsed = Date().timeIntervalSince(sessionStartTime)
            let restoredMinute = min(Int(elapsed / 60.0), circuit.durationMinutes - 1)
            currentMinute = restoredMinute
            lastAnnouncedMinute = restoredMinute
            let exIdx = restoredMinute % max(circuit.exercises.count, 1)
            currentReps = circuit.exercises[safe: exIdx]?.targetReps ?? 10
        } else {
            sessionStartTime = Date()
            UserDefaults.standard.set(circuit.id.uuidString, forKey: "honcardio_circuit_id")
            UserDefaults.standard.set(sessionStartTime.timeIntervalSince1970, forKey: "honcardio_start_time")
            lastAnnouncedMinute = 0
            announceExercise(forMinute: 0)
        }

        let total = Double(circuit.durationMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard completedEntry == nil else { return }
            let elapsed = Date().timeIntervalSince(sessionStartTime)

            // Compute current position from wall clock
            let newMinute = Int(elapsed / 60.0)
            let secsIntoMinute = Int(elapsed.truncatingRemainder(dividingBy: 60.0))
            let newSecsRemaining = max(0, 60 - secsIntoMinute)

            // Handle any minute transitions (including minutes skipped while in background)
            if newMinute > currentMinute {
                for m in currentMinute..<newMinute {
                    autoSaveResult(forMinute: m)
                }
                currentMinute = min(newMinute, circuit.durationMinutes - 1)
                if newMinute < circuit.durationMinutes {
                    let exIdx = newMinute % max(circuit.exercises.count, 1)
                    currentReps = circuit.exercises[safe: exIdx]?.targetReps ?? 10
                    isWarning = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if newMinute != lastAnnouncedMinute {
                        lastAnnouncedMinute = newMinute
                        announceExercise(forMinute: newMinute)
                    }
                }
            }

            // Session complete
            if elapsed >= total {
                finishSession()
                return
            }

            // 3-2-1 voice countdown (fires once per second transition)
            if newSecsRemaining != secondsThisMinute,
               newSecsRemaining >= 1, newSecsRemaining <= 3 {
                speak("\(newSecsRemaining)")
            }

            secondsThisMinute = newSecsRemaining
            isWarning = newSecsRemaining <= 10
        }
    }

    private func autoSaveResult(forMinute m: Int) {
        let exIdx = m % max(circuit.exercises.count, 1)
        guard let ce = circuit.exercises[safe: exIdx] else { return }
        results.append(CircuitRoundResult(
            round: m,
            exerciseId: ce.id,
            exerciseName: ce.exercise.name,
            repsCompleted: currentReps
        ))
    }

    // advanceMinute is now handled inline by the wall-clock timer above.
    // Kept as a no-op stub so external call sites compile if any remain.
    private func advanceMinute_unused() {
        currentMinute += 1
        if currentMinute >= circuit.durationMinutes {
            finishSession()
            return
        }

        // Reset for new minute
        secondsThisMinute = 60
        isWarning = false
        let newExIdx = currentMinute % max(circuit.exercises.count, 1)
        currentReps = circuit.exercises[safe: newExIdx]?.targetReps ?? 10
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        announceExercise(forMinute: currentMinute)
    }

    private func announceExercise(forMinute minute: Int) {
        let exIdx = minute % max(circuit.exercises.count, 1)
        let name = circuit.exercises[safe: exIdx]?.exercise.name ?? "Go"
        speak(name)
    }

    private func speak(_ text: String) {
        // Keep Spotify/Apple Music playing during workout speech
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.volume = 1.0
        synth.speak(u)
    }

    private func finishSession() {
        guard completedEntry == nil else { return }
        timer?.invalidate()
        timer = nil
        UserDefaults.standard.removeObject(forKey: "honcardio_circuit_id")
        UserDefaults.standard.removeObject(forKey: "honcardio_start_time")
        // Save result for the final minute
        autoSaveResult(forMinute: currentMinute)

        let entry = CardioLogEntry(
            circuitId: circuit.id,
            circuitName: circuit.displayName,
            format: circuit.format,
            durationMinutes: circuit.durationMinutes,
            exercises: circuit.exercises,
            results: results,
            startedAt: sessionStartTime,
            finishedAt: Date()
        )
        store.saveCardioSession(entry)
        health.saveCardioSession(entry)
        completedEntry = entry
    }
}

// MARK: - CardioSessionSummaryView

struct CardioSessionSummaryView: View {
    let entry: CardioLogEntry
    let onDone: () -> Void

    private var roundsLabel: String {
        entry.format == .amrap ? "rounds" : "minutes"
    }

    private var totalRepsPerExercise: [(exercise: CircuitExercise, total: Int, avg: Double)] {
        entry.exercises.map { ce in
            let relevant = entry.results.filter { $0.exerciseId == ce.id }
            let total = relevant.reduce(0) { $0 + $1.repsCompleted }
            let avg = relevant.isEmpty ? 0.0 : Double(total) / Double(relevant.count)
            return (ce, total, avg)
        }
    }

    private var roundBreakdown: [(round: Int, total: Int)] {
        guard entry.format == .amrap else { return [] }
        let maxRound = entry.results.map(\.round).max() ?? -1
        return (0...maxRound).map { r in
            let total = entry.results.filter { $0.round == r }.reduce(0) { $0 + $1.repsCompleted }
            return (r, total)
        }
    }

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Trophy icon
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(HONTheme.positive)

                        Text("Workout Complete!")
                            .font(.title.bold())
                            .foregroundStyle(HONTheme.textPrimary)
                    }

                    // Circuit name + format badge
                    VStack(spacing: 6) {
                        Text(entry.circuitName)
                            .font(.title3.bold())
                            .foregroundStyle(HONTheme.textPrimary)
                        HStack(spacing: 6) {
                            Image(systemName: entry.format.icon)
                            Text(entry.format.rawValue)
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(entry.format.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(entry.format.color.opacity(0.15), in: Capsule())
                    }

                    // Stats row
                    HStack(spacing: 0) {
                        statCell(value: "\(entry.completedRounds)", label: roundsLabel)
                        Divider().frame(height: 40).background(HONTheme.textPrimary.opacity(0.2))
                        statCell(value: "\(entry.totalReps)", label: "total reps")
                        Divider().frame(height: 40).background(HONTheme.textPrimary.opacity(0.2))
                        statCell(value: entry.formattedDuration, label: "duration")
                    }
                    .padding()
                    .background(HONTheme.textPrimary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // Per-exercise breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercise Breakdown")
                            .font(.headline)
                            .foregroundStyle(HONTheme.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(totalRepsPerExercise, id: \.exercise.id) { row in
                            HStack {
                                Text(row.exercise.exercise.name)
                                    .font(.subheadline)
                                    .foregroundStyle(HONTheme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(row.total) reps total")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(HONTheme.textPrimary)
                                    Text(String(format: "%.1f avg/\(entry.format == .amrap ? "round" : "min")", row.avg))
                                        .font(.caption)
                                        .foregroundStyle(HONTheme.textPrimary.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(HONTheme.textPrimary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                        }
                    }

                    // AMRAP rounds breakdown (only if ≤ 10 rounds)
                    if entry.format == .amrap && roundBreakdown.count <= 10 && !roundBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rounds Breakdown")
                                .font(.headline)
                                .foregroundStyle(HONTheme.textPrimary)
                                .padding(.horizontal, 20)

                            ForEach(roundBreakdown, id: \.round) { row in
                                HStack {
                                    Text("Round \(row.round + 1)")
                                        .font(.subheadline)
                                        .foregroundStyle(HONTheme.textPrimary.opacity(0.8))
                                    Spacer()
                                    Text("\(row.total) reps")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(HONTheme.textPrimary)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Done button
                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HONTheme.positive, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(HONTheme.textPrimary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(HONTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(HONTheme.textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
