import SwiftUI

// Exact SwiftUI replication of the H.O.N. HTML splash.
// Timing, easing, and element order match the original JS animation sequence.
//
// Sequence:
//   t=300ms  — both rules expand centre-outward simultaneously (3s ease-in-out)
//   t=1200ms — H.O.N. pure opacity fade (3.5s ease-in-out)
//   t=3200ms — "HABIT OVER NUMBERS" subtitle fades (3s ease-in-out)
//   t=4400ms — dots light up left-to-right, one per 320ms (1.4s each)
//   lastDot+1800ms — tagline fades (3.5s ease-in-out)
//   tagline settled + 1s hold → screen fades out → onComplete()

struct HONSplashScreen: View {
    var onComplete: () -> Void

    private let streak: [Bool] = [true, true, true, false, true, false, true]

    @State private var ruleScale:      CGFloat  = 0
    @State private var ruleOpacity:    Double   = 0
    @State private var honOpacity:     Double   = 0
    @State private var subOpacity:     Double   = 0
    @State private var dotOpacities:   [Double] = Array(repeating: 0, count: 7)
    @State private var taglineOpacity: Double   = 0

    var body: some View {
        ZStack {
            Color(hex: "111111")
            VStack {
                Spacer()
                card
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animate() }
        }
    }

    // MARK: - Card

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(HONTheme.background)           // #1c1c1e Onyx
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

            VStack(spacing: 0) {
                ruleBar

                honLetters
                    .padding(.vertical, 16)
                    .opacity(honOpacity)

                ruleBar

                subtitle
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                    .opacity(subOpacity)

                dotsRow

                tagline
                    .padding(.top, 20)
                    .opacity(taglineOpacity)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 60)
        }
    }

    // MARK: - Sub-views

    // Rule — expands from centre outward via scaleEffect(anchor: .center)
    private var ruleBar: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear,         location: 0),
                        .init(color: HONTheme.accent, location: 0.2),
                        .init(color: HONTheme.accent, location: 0.8),
                        .init(color: .clear,         location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 220, height: 1)
            .scaleEffect(x: ruleScale, y: 1, anchor: .center)
            .opacity(ruleOpacity)
    }

    // H.O.N. — HStack with 0.22em inter-character gap avoids line-break issues
    // that arise when kerning is applied to concatenated Text in a width-constrained frame.
    private var honLetters: some View {
        HStack(spacing: 60 * 0.22) {
            Text("H").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
            Text("O").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
            Text("N").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
        }
        .font(.custom("CormorantGaramond-Light", size: 60))
        .lineLimit(1)
        .fixedSize()
    }

    // "HABIT OVER NUMBERS" — DM Sans 8.5pt, uppercase, wide tracking
    private var subtitle: some View {
        Text("Habit Over Numbers")
            .font(.custom("DMSans-Regular", size: 8.5))
            .kerning(8.5 * 0.28)
            .textCase(.uppercase)
            .foregroundStyle(HONTheme.textSecondary)
    }

    // 7 streak dots: amber = active day, iron = missed
    private var dotsRow: some View {
        HStack(spacing: 9) {
            ForEach(Array(streak.enumerated()), id: \.offset) { i, on in
                Circle()
                    .fill(on ? HONTheme.accent : HONTheme.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(dotOpacities[i])
            }
        }
    }

    // "Show up. That's enough." — Cormorant Garamond LightItalic
    private var tagline: some View {
        Text("Show up. That\u{2019}s enough.")
            .font(.custom("CormorantGaramond-LightItalic", size: 13))
            .kerning(13 * 0.06)
            .foregroundStyle(HONTheme.textSecondary)
    }

    // MARK: - Animation (mirrors JS timing exactly)

    private func animate() {
        // 1. Both rules expand simultaneously (t = 300ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 3.0)) { ruleScale   = 1 }
            withAnimation(.easeInOut(duration: 2.0)) { ruleOpacity = 1 }
        }

        // 2. H.O.N. pure opacity fade (t = 1200ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 3.5)) { honOpacity = 1 }
        }

        // 3. Subtitle (t = 3200ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 3.0)) { subOpacity = 1 }
        }

        // 4. Dots — left to right, one every 320ms starting at t = 4400ms
        for i in 0..<streak.count {
            let delay = 4.4 + Double(i) * 0.32
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 1.4)) { dotOpacities[i] = 1 }
            }
        }

        // 5. Tagline — after last dot + 1800ms
        //    lastDotEnd = 4.4 + 6×0.32 + 1.8 = 8.12s
        let lastDotEnd = 4.4 + Double(streak.count - 1) * 0.32 + 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + lastDotEnd) {
            withAnimation(.easeInOut(duration: 3.5)) { taglineOpacity = 1 }
        }

        // 6. Hold 1s after tagline settles (~11.6s), then complete (HONAppRoot handles fade)
        let completeAt = lastDotEnd + 3.5 + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + completeAt) {
            onComplete()
        }
    }
}

// MARK: - App Entry Wrapper

struct HONAppRoot: View {
    @State private var splashDone = false

    var body: some View {
        ZStack {
            // ContentView initialises while splash plays; hidden until done
            ContentView()
                .opacity(splashDone ? 1 : 0)
                .allowsHitTesting(splashDone)

            if !splashDone {
                HONSplashScreen {
                    withAnimation(.easeOut(duration: 0.8)) { splashDone = true }
                }
                // ignoresSafeArea must be applied to the splash layer itself,
                // not just to its internal Color — ZStack children don't inherit it.
                .ignoresSafeArea()
                .zIndex(1)
            }
        }
    }
}
