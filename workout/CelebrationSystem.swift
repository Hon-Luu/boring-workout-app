import SwiftUI

// MARK: - Celebration Kind

enum CelebrationKind {
    case sessionComplete(duration: String, sets: Int, volume: Int, sessionDays: [Int], isComeback: Bool, completedDayIndex: Int)
    case personalRecord(exerciseName: String, weight: Double, reps: Int)
    case streakMilestone(days: Int)
}

extension CelebrationKind: Identifiable {
    var id: String {
        switch self {
        case .sessionComplete:               return "session"
        case .personalRecord(let name, _, _): return "pr-\(name)"
        case .streakMilestone(let d):        return "streak-\(d)"
        }
    }
}

// MARK: - Today Dot Anchor Preference

struct TodayDotAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

// MARK: - Particle Burst

private let _particles: [(angle: Double, speed: Double, size: Double, isAmber: Bool)] = (0..<20).map { i in
    func h(_ seed: Int) -> Double {
        let x = (seed &* 1664525 &+ i &* 1013904223) & 0x7FFFFFFF
        return Double(x) / Double(0x7FFFFFFF)
    }
    return (
        angle: Double(i) / 20.0 * .pi * 2 + (h(3) - 0.5) * 0.8,
        speed: 38 + h(7) * 52,
        size:  1.5 + h(11) * 2.8,
        isAmber: i % 3 != 0
    )
}

struct ParticleBurst: View {
    @State private var startTime: Date? = nil
    let trigger: Bool
    var origin: CGPoint? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: startTime == nil)) { tl in
            Canvas { ctx, size in
                guard let start = startTime else { return }
                let t = tl.date.timeIntervalSince(start)
                guard t > 0 && t < 2.6 else { return }
                let cx = origin?.x ?? size.width / 2
                let cy = origin?.y ?? size.height / 2

                for p in _particles {
                    let x = cx + cos(p.angle) * p.speed * t
                    let y = cy + sin(p.angle) * p.speed * t + 0.5 * 28 * t * t
                    let alpha = min(t / 0.28, 1.0) * max(0, 1.0 - max(0, t - 0.3) / 2.1) * 0.85
                    let hs = p.size / 2
                    let color: Color = p.isAmber
                        ? HONTheme.accent.opacity(alpha)
                        : Color(red: 0.94, green: 0.93, blue: 0.91).opacity(alpha * 0.7)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - hs, y: y - hs, width: p.size, height: p.size)),
                        with: .color(color)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, new in if new { startTime = Date() } }
    }
}

// MARK: - Amber Rule

private struct AmberRule: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, HONTheme.accent.opacity(0.8), HONTheme.accent.opacity(0.8), .clear],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(width: 200, height: 1)
    }
}

// MARK: - Animated Week Dots

private struct AnimatedWeekDots: View {
    let sessionDays: [Int]   // Mon=0..Sun=6
    let todayIndex: Int
    let litDays: Set<Int>    // past days driven by parent
    let todayLit: Bool

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring1Opacity: CGFloat = 0.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring2Opacity: CGFloat = 0.0

    var body: some View {
        VStack(spacing: 6) {
            Text("This Week")
                .font(.custom("DMSans-Medium", size: 7))
                .kerning(0.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.3))
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let isToday = i == todayIndex
                    let isLit   = isToday ? todayLit : litDays.contains(i)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isLit ? HONTheme.accent : Color.white.opacity(0.1))
                            .frame(width: 8, height: 8)
                            .shadow(
                                color: isToday && todayLit ? HONTheme.accent.opacity(0.7) : .clear,
                                radius: isToday && todayLit ? 8 : 0
                            )
                            .overlay {
                                if isToday {
                                    ZStack {
                                        Circle()
                                            .stroke(HONTheme.accent, lineWidth: 1.5)
                                            .scaleEffect(ring1Scale)
                                            .opacity(ring1Opacity)
                                        Circle()
                                            .stroke(HONTheme.accent.opacity(0.6), lineWidth: 1)
                                            .scaleEffect(ring2Scale)
                                            .opacity(ring2Opacity)
                                        // Anchor for the particle burst — only the today dot reports this
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: TodayDotAnchorKey.self,
                                                value: geo.frame(in: .named("celebration"))
                                            )
                                        }
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.4), value: isLit)
                        Text(labels[i])
                            .font(.system(size: 6))
                            .foregroundStyle(isToday ? Color.white.opacity(0.5) : Color.white.opacity(0.25))
                    }
                }
            }
        }
        .onChange(of: todayLit) { _, new in
            guard new else { return }
            ring1Scale = 1.0; ring1Opacity = 0.65
            withAnimation(.easeOut(duration: 1.8)) {
                ring1Scale = 4.0; ring1Opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ring2Scale = 1.0; ring2Opacity = 0.45
                withAnimation(.easeOut(duration: 1.6)) {
                    ring2Scale = 6.0; ring2Opacity = 0.0
                }
            }
        }
    }
}

// MARK: - Session Complete Celebration

struct SessionCelebrationView: View {
    let duration: String
    let sets: Int
    let volume: Int
    let sessionDays: [Int]       // Mon=0..Sun=6 indices of this week's session days
    let isComeback: Bool
    let completedDayIndex: Int   // Mon=0..Sun=6 of the workout just finished — drives the sparking dot
    let onDismiss: () -> Void

    @State private var vignetteOn    = false
    @State private var ruleScale     = 0.0
    @State private var titleOn       = false
    @State private var headlineOn    = false
    @State private var weekLabelOn   = false
    @State private var litDays: Set<Int> = []
    @State private var todayLit      = false
    @State private var glowOn        = false
    @State private var dividerOn     = false
    @State private var receiptOn     = false
    @State private var feedbackOn    = false
    @State private var buttonOn      = false
    @State private var particleFired = false
    @State private var particleOrigin: CGPoint = .zero

    private var pastDays: [Int] { sessionDays.filter { $0 != completedDayIndex }.sorted() }

    private var feedbackText: String {
        if isComeback {
            return "You came back. Most people don't."
        }
        let n = min(max(sessionDays.count, 1), 7)
        let pool = [
            "First one in. Come back and the habit begins.",
            "Two sessions this week. The pattern is forming.",
            "Three sessions in. The habit is forming.",
            "Four sessions. Well ahead of the curve.",
            "Five sessions. This is consistency.",
            "Six sessions. Remarkable week.",
            "Seven for seven. A perfect week."
        ]
        return pool[n - 1]
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(vignetteOn ? 0.92 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.5), value: vignetteOn)

            RadialGradient(
                colors: [HONTheme.accent.opacity(glowOn ? 0.13 : 0), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: glowOn)

            ParticleBurst(trigger: particleFired, origin: particleOrigin)

            VStack(spacing: 0) {
                Spacer()

                // Rules + title
                VStack(spacing: 0) {
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.bottom, 10)
                    Text("Session Complete")
                        .font(.custom("DMSans-Medium", size: 9))
                        .kerning(0.26)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .opacity(titleOn ? 1 : 0)
                        .animation(.easeInOut(duration: 2), value: titleOn)
                        .padding(.vertical, 8)
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.top, 10)
                }

                // Hero: habit headline — session count or comeback message
                Group {
                    if isComeback {
                        Text("You came back.")
                            .font(.custom("CormorantGaramond-LightItalic", size: 30))
                            .foregroundStyle(Color.white.opacity(0.88))
                    } else {
                        VStack(spacing: 4) {
                            Text("\(sessionDays.count)")
                                .font(.custom("CormorantGaramond-Light", size: 64))
                                .foregroundStyle(Color.white.opacity(0.95))
                            Text("this week")
                                .font(.custom("DMSans-Medium", size: 9))
                                .kerning(0.16)
                                .textCase(.uppercase)
                                .foregroundStyle(HONTheme.accent)
                        }
                    }
                }
                .opacity(headlineOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.4), value: headlineOn)
                .padding(.top, 28)

                // Week dots (always shown — they are the visual proof of the habit)
                AnimatedWeekDots(
                    sessionDays: sessionDays,
                    todayIndex: completedDayIndex,
                    litDays: litDays,
                    todayLit: todayLit
                )
                .opacity(weekLabelOn ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: weekLabelOn)
                .padding(.top, 18)

                // Receipt divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 48)
                    .opacity(dividerOn ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8), value: dividerOn)
                    .padding(.top, 22)

                // Receipt stats — subordinate to the habit headline above
                HStack(spacing: 14) {
                    receiptStat(value: duration, unit: "Time")
                    receiptDot()
                    receiptStat(value: "\(sets)", unit: "Sets")
                    receiptDot()
                    receiptStat(value: volumeStr(volume), unit: "kg")
                }
                .opacity(receiptOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.0), value: receiptOn)
                .padding(.top, 14)

                // Feedback
                Text(feedbackText)
                    .font(.custom("CormorantGaramond-LightItalic", size: 14))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 48)
                    .padding(.top, 26)
                    .opacity(feedbackOn ? 1 : 0)
                    .animation(.easeInOut(duration: 2.5), value: feedbackOn)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.custom("DMSans-SemiBold", size: 10))
                        .kerning(0.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 11)
                        .background(HONTheme.accent, in: Capsule())
                }
                .opacity(buttonOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.5), value: buttonOn)
                .padding(.bottom, 60)
            }
        }
        .coordinateSpace(name: "celebration")
        .onPreferenceChange(TodayDotAnchorKey.self) { rect in
            guard rect != .zero else { return }
            particleOrigin = CGPoint(x: rect.midX, y: rect.midY)
        }
        .onAppear(perform: runSequence)
    }

    private func runSequence() {
        schedule(0.1)  { vignetteOn   = true }
        schedule(0.6)  { ruleScale    = 1 }
        schedule(1.0)  { titleOn      = true }
        schedule(1.6)  { headlineOn   = true }
        schedule(2.0)  { weekLabelOn  = true }
        schedule(3.4)  { glowOn       = true }

        // Past session dots light up one by one
        for (i, day) in pastDays.enumerated() {
            schedule(2.4 + Double(i) * 0.26) { litDays.insert(day) }
        }

        // Today's dot — the climax of the dot sequence
        let todayDelay = 2.4 + Double(pastDays.count) * 0.26 + 0.2
        schedule(todayDelay)       { todayLit      = true }
        schedule(todayDelay + 0.8) { particleFired = true }
        schedule(todayDelay + 1.2) { dividerOn     = true }
        schedule(todayDelay + 1.6) { receiptOn     = true }

        // Feedback and button — never before ~5.6 / 6.6s
        schedule(max(5.6, todayDelay + 2.4)) { feedbackOn = true }
        schedule(max(6.6, todayDelay + 3.4)) { buttonOn   = true }
    }

    private func schedule(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    private func receiptStat(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.custom("DMSans-SemiBold", size: 14))
                .foregroundStyle(Color.white.opacity(0.65))
            Text(unit)
                .font(.custom("DMSans-Regular", size: 9))
                .foregroundStyle(Color.white.opacity(0.28))
                .textCase(.uppercase)
        }
    }

    private func receiptDot() -> some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 3, height: 3)
    }

    private func volumeStr(_ vol: Int) -> String {
        vol >= 10_000 ? String(format: "%.1fk", Double(vol) / 1000.0) : "\(vol)"
    }
}

// MARK: - PR Celebration

private struct PRCelebrationView: View {
    let exerciseName: String
    let weight: Double
    let reps: Int
    let onDismiss: () -> Void

    @State private var vignetteOn    = false
    @State private var ruleScale     = 0.0
    @State private var titleOn       = false
    @State private var glowOn        = false
    @State private var exerciseOn    = false
    @State private var weightOn      = false
    @State private var particleFired = false
    @State private var feedbackOn    = false
    @State private var buttonOn      = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(vignetteOn ? 0.90 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.5), value: vignetteOn)

            RadialGradient(
                colors: [HONTheme.accent.opacity(glowOn ? 0.13 : 0), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: glowOn)

            ParticleBurst(trigger: particleFired)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.bottom, 10)
                    Text("Personal Record")
                        .font(.custom("DMSans-Medium", size: 9))
                        .kerning(0.26)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .opacity(titleOn ? 1 : 0)
                        .animation(.easeInOut(duration: 2), value: titleOn)
                        .padding(.vertical, 8)
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.top, 10)
                }

                // Exercise name — the visual anchor
                Text(exerciseName.uppercased())
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(0.5)
                    .foregroundStyle(HONTheme.accent)
                    .opacity(exerciseOn ? 1 : 0)
                    .animation(.easeInOut(duration: 1.4), value: exerciseOn)
                    .padding(.top, 28)

                // Weight — supporting fact below the exercise anchor
                VStack(spacing: 6) {
                    Text(String(format: weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", weight))
                        .font(.custom("CormorantGaramond-Light", size: 54))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kg × \(reps)")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(HONTheme.accent)
                        .kerning(0.06)
                }
                .opacity(weightOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.2), value: weightOn)
                .padding(.top, 12)

                Text("New peak on \(exerciseName).\nRemember the work that got you here.")
                    .font(.custom("CormorantGaramond-LightItalic", size: 14))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 48)
                    .padding(.top, 26)
                    .opacity(feedbackOn ? 1 : 0)
                    .animation(.easeInOut(duration: 2.5), value: feedbackOn)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.custom("DMSans-SemiBold", size: 10))
                        .kerning(0.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 11)
                        .background(HONTheme.accent, in: Capsule())
                }
                .opacity(buttonOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.5), value: buttonOn)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            schedule(0.0) { vignetteOn  = true }
            schedule(0.4) { ruleScale   = 1 }
            schedule(0.7) { titleOn     = true }
            schedule(1.2) { glowOn      = true; exerciseOn = true }
            schedule(2.0) { weightOn    = true }
            schedule(3.2) { particleFired = true }
            schedule(4.8) { feedbackOn  = true }
            schedule(5.8) { buttonOn    = true }
        }
    }

    private func schedule(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Streak Celebration

private struct StreakCelebrationView: View {
    let days: Int
    let onDismiss: () -> Void

    @State private var vignetteOn    = false
    @State private var ruleScale     = 0.0
    @State private var titleOn       = false
    @State private var glowOn        = false
    @State private var contentOn     = false
    @State private var particleFired = false
    @State private var feedbackOn    = false
    @State private var buttonOn      = false

    private var feedbackText: String {
        switch days {
        case 7:   return "Seven days. The habit is becoming automatic."
        case 30:  return "Thirty days. This is who you are now."
        case 100: return "A hundred days.\nMost people quit before they reach this."
        default:  return "\(days) days. Keep showing up."
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(vignetteOn ? 0.90 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.5), value: vignetteOn)

            RadialGradient(
                colors: [HONTheme.accent.opacity(glowOn ? 0.13 : 0), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: glowOn)

            ParticleBurst(trigger: particleFired)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.bottom, 10)
                    Text("Streak")
                        .font(.custom("DMSans-Medium", size: 9))
                        .kerning(0.26)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .opacity(titleOn ? 1 : 0)
                        .animation(.easeInOut(duration: 2), value: titleOn)
                        .padding(.vertical, 8)
                    AmberRule()
                        .scaleEffect(x: ruleScale, anchor: .center)
                        .animation(.easeInOut(duration: 2), value: ruleScale)
                        .padding(.top, 10)
                }

                VStack(spacing: 8) {
                    Text("\(days)")
                        .font(.custom("CormorantGaramond-Light", size: 76))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text("consecutive days")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(HONTheme.accent)
                        .kerning(0.06)
                }
                .opacity(contentOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.4), value: contentOn)
                .padding(.top, 24)

                Text(feedbackText)
                    .font(.custom("CormorantGaramond-LightItalic", size: 14))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 48)
                    .padding(.top, 26)
                    .opacity(feedbackOn ? 1 : 0)
                    .animation(.easeInOut(duration: 2.5), value: feedbackOn)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.custom("DMSans-SemiBold", size: 10))
                        .kerning(0.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 11)
                        .background(HONTheme.accent, in: Capsule())
                }
                .opacity(buttonOn ? 1 : 0)
                .animation(.easeInOut(duration: 1.5), value: buttonOn)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            schedule(0.0) { vignetteOn = true }
            schedule(0.4) { ruleScale  = 1 }
            schedule(0.7) { titleOn    = true }
            schedule(1.2) { glowOn     = true; contentOn = true }
            schedule(3.6) { particleFired = true }
            schedule(4.8) { feedbackOn = true }
            schedule(5.8) { buttonOn   = true }
        }
    }

    private func schedule(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Celebration Overlay (dispatcher)

struct CelebrationOverlay: View {
    let kind: CelebrationKind
    let onDismiss: () -> Void

    var body: some View {
        switch kind {
        case .sessionComplete(let dur, let sets, let vol, let days, let comeback, let dayIdx):
            SessionCelebrationView(
                duration: dur, sets: sets, volume: vol,
                sessionDays: days, isComeback: comeback,
                completedDayIndex: dayIdx, onDismiss: onDismiss
            )
        case .personalRecord(let name, let weight, let reps):
            PRCelebrationView(exerciseName: name, weight: weight, reps: reps, onDismiss: onDismiss)
        case .streakMilestone(let days):
            StreakCelebrationView(days: days, onDismiss: onDismiss)
        }
    }
}

// MARK: - Tier 2A: Set Completion Amber Flash

struct SetCompletionFlash: ViewModifier {
    let isCompleted: Bool
    @State private var scaleX: Double = 0
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                HONTheme.accent
                    .frame(height: 1)
                    .scaleEffect(x: scaleX, anchor: .leading)
                    .opacity(opacity)
            }
            .onChange(of: isCompleted) { _, new in
                guard new else { return }
                scaleX = 0; opacity = 0
                withAnimation(.easeOut(duration: 0.32)) { scaleX = 1; opacity = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
                    withAnimation(.easeIn(duration: 0.38)) { opacity = 0 }
                }
            }
    }
}

extension View {
    func setCompletionFlash(isCompleted: Bool) -> some View {
        modifier(SetCompletionFlash(isCompleted: isCompleted))
    }
}

// MARK: - Tier 2B: Volume PR Badge

struct VolumePRBadge: View {
    @State private var visible = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(HONTheme.accent)
                .frame(width: 4, height: 4)
            Text("Biggest day yet")
                .font(.custom("DMSans-Medium", size: 9))
                .kerning(0.12)
                .textCase(.uppercase)
                .foregroundStyle(HONTheme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(HONTheme.accent.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(HONTheme.accent.opacity(0.25), lineWidth: 1))
        .opacity(visible ? 1 : 0)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 1.8)) { visible = true }
            }
        }
    }
}

// MARK: - Tier 2C: Spider Glow Modifier

struct SpiderGlowModifier: ViewModifier {
    let allGroupsCovered: Bool
    @State private var glowOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .background(
                RadialGradient(
                    colors: [HONTheme.accent.opacity(0.15), .clear],
                    center: .center, startRadius: 0, endRadius: 110
                )
                .opacity(glowOpacity)
            )
            .onAppear {
                guard allGroupsCovered else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 1.2)) { glowOpacity = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 1.2)) { glowOpacity = 0 }
                    }
                }
            }
    }
}

extension View {
    func spiderGlow(allGroupsCovered: Bool) -> some View {
        modifier(SpiderGlowModifier(allGroupsCovered: allGroupsCovered))
    }
}

// MARK: - Previews

// completedDayIndex: 6 = Sunday (last dot in M-T-W-T-F-S-S)
#Preview("Session — 4 sessions, comeback") {
    CelebrationOverlay(
        kind: .sessionComplete(duration: "52m", sets: 21, volume: 5840,
                               sessionDays: [0, 2, 4, 6], isComeback: true,
                               completedDayIndex: 6),
        onDismiss: {}
    )
}

#Preview("Session — 4 sessions, regular") {
    CelebrationOverlay(
        kind: .sessionComplete(duration: "52m", sets: 21, volume: 5840,
                               sessionDays: [0, 2, 4, 6], isComeback: false,
                               completedDayIndex: 6),
        onDismiss: {}
    )
}

#Preview("Session — first of week (Wednesday)") {
    CelebrationOverlay(
        kind: .sessionComplete(duration: "38m", sets: 12, volume: 2100,
                               sessionDays: [2], isComeback: false,
                               completedDayIndex: 2),
        onDismiss: {}
    )
}

#Preview("Personal Record") {
    CelebrationOverlay(
        kind: .personalRecord(exerciseName: "Bench Press", weight: 102.5, reps: 3),
        onDismiss: {}
    )
}

#Preview("Streak — 30 days") {
    CelebrationOverlay(
        kind: .streakMilestone(days: 30),
        onDismiss: {}
    )
}
