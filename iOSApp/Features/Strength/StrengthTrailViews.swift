import SwiftUI

// MARK: - Shared private helpers

private struct LiftSesh {
    let date: Date
    let e1rm: Double
}

private struct TrailLiftDef {
    let key: String
    let label: String
    let short: String
    let color: Color
    let match: [String]
    let reject: [String]
}

private let kTrailDefs: [TrailLiftDef] = [
    .init(key: "bench",    label: "Bench Press",    short: "Bench",
          color: HONTheme.chartRose,
          match: ["bench press"],                    reject: ["incline", "decline", "dumbbell", "db"]),
    .init(key: "squat",    label: "Barbell Squat",  short: "Squat",
          color: HONTheme.chartSlate,
          match: ["barbell squat", "back squat"],    reject: ["hack", "goblet", "leg press", "front"]),
    .init(key: "deadlift", label: "Deadlift",       short: "Deadlift",
          color: HONTheme.chartSage,
          match: ["deadlift"],                       reject: ["romanian", "rdl", "sumo", "stiff"]),
    .init(key: "ohp",      label: "Overhead Press", short: "OHP",
          color: HONTheme.chartAmber,
          match: ["overhead press", "ohp", "military press"], reject: ["dumbbell", "db"]),
]

private let kTrailDefsDB: [TrailLiftDef] = [
    .init(key: "db_bench",  label: "DB Bench Press",   short: "DB Bench",
          color: HONTheme.chartRose,
          match: ["dumbbell bench", "db bench"],
          reject: ["incline", "decline", "floor"]),
    .init(key: "db_squat",  label: "Goblet Squat",     short: "Goblet",
          color: HONTheme.chartSlate,
          match: ["goblet squat", "dumbbell squat", "db squat"],
          reject: ["barbell"]),
    .init(key: "db_rdl",    label: "DB Romanian DL",   short: "DB RDL",
          color: HONTheme.chartSage,
          match: ["dumbbell romanian", "db romanian", "dumbbell rdl", "db rdl", "dumbbell stiff"],
          reject: []),
    .init(key: "db_ohp",    label: "DB Shoulder Press", short: "DB OHP",
          color: HONTheme.chartAmber,
          match: ["dumbbell shoulder press", "db shoulder press",
                  "dumbbell overhead press", "db overhead press", "arnold press"],
          reject: []),
]

private enum EquipmentMode: String, CaseIterable {
    case barbell  = "Barbell"
    case dumbbell = "Dumbbell"
}

private func buildSessions(_ def: TrailLiftDef, _ log: [WorkoutLogEntry]) -> [LiftSesh] {
    log.sorted { $0.startedAt < $1.startedAt }.compactMap { entry in
        var best = 0.0
        for we in entry.exercises {
            let n = we.exercise.name.lowercased()
            guard def.match.contains(where: { n.contains($0) }),
                  !def.reject.contains(where: { n.contains($0) }) else { continue }
            let e = we.completedSets.map(\.estimated1RM).max() ?? 0
            best = max(best, e)
        }
        return best > 0 ? LiftSesh(date: entry.startedAt, e1rm: best) : nil
    }
}

// OLS gain rate: kg/week as % of mean e1RM, over last 8 sessions.
private func olsGainRate(_ sessions: [LiftSesh]) -> Double {
    let pts = Array(sessions.suffix(8))
    guard pts.count >= 3 else { return 0 }
    let t0  = pts[0].date.timeIntervalSince1970
    let xs  = pts.map { ($0.date.timeIntervalSince1970 - t0) / 604_800.0 }
    let ys  = pts.map { $0.e1rm }
    let n   = Double(pts.count)
    let sx  = xs.reduce(0, +), sy = ys.reduce(0, +)
    let sxy = zip(xs, ys).map(*).reduce(0, +)
    let sx2 = xs.map { $0 * $0 }.reduce(0, +)
    let d   = n * sx2 - sx * sx
    guard abs(d) > 1e-9 else { return 0 }
    let slope = (n * sxy - sx * sy) / d
    let mean  = sy / n
    return mean > 0 ? slope / mean * 100 : 0
}

// Canvas coordinate helpers
private let cPL: CGFloat = 52, cPT: CGFloat = 28, cPR: CGFloat = 18, cPB: CGFloat = 46

private func cW(_ s: CGSize) -> CGFloat { s.width  - cPL - cPR }
private func cH(_ s: CGSize) -> CGFloat { s.height - cPT - cPB }

private func toX(_ v: CGFloat, lo: CGFloat, hi: CGFloat, sz: CGSize) -> CGFloat {
    cPL + (v - lo) / (hi - lo) * cW(sz)
}
private func toY(_ v: CGFloat, lo: CGFloat, hi: CGFloat, sz: CGSize) -> CGFloat {
    cPT + cH(sz) - (v - lo) / (hi - lo) * cH(sz)
}

private func tlabel(_ s: String, size: CGFloat,
                     weight: Font.Weight = .regular,
                     color: Color = .secondary) -> Text {
    Text(s).font(.system(size: size, weight: weight)).foregroundStyle(color)
}

// MARK: - StrengthPortfolioCard  (Progress tab)

struct StrengthPortfolioCard: View {
    let log: [WorkoutLogEntry]
    let bodyWeightKg: Double?

    @State private var selectedKey:  String?       = nil
    @State private var equipMode:    EquipmentMode = .barbell

    private var activeDefs: [TrailLiftDef] {
        equipMode == .barbell ? kTrailDefs : kTrailDefsDB
    }

    // ── Data ──────────────────────────────────────────────────────────────

    private var liftData: [(def: TrailLiftDef, sessions: [LiftSesh])] {
        activeDefs.compactMap { def in
            let s = buildSessions(def, log)
            return s.count >= 3 ? (def, s) : nil
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        let data = liftData
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Portfolio")
                        .font(.system(size: 14, weight: .bold))
                    Text(selectedKey == nil
                         ? "Current e1RM vs gain rate · tap a bubble"
                         : "Tap again or background to go back")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedKey != nil {
                    Button { withAnimation(.easeInOut(duration: 0.22)) { selectedKey = nil } } label: {
                        Text("← All lifts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("", selection: $equipMode) {
                        ForEach(EquipmentMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 148)
                }
            }

            if data.isEmpty {
                Text("Log at least 3 sessions of \(equipMode == .barbell ? "bench, squat, deadlift, or OHP" : "DB bench, goblet squat, DB RDL, or DB OHP") to unlock the portfolio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            } else {
                GeometryReader { geo in
                    Canvas { ctx, size in
                        let key = selectedKey
                        if let key, let idx = data.firstIndex(where: { $0.def.key == key }) {
                            portfolioTrailMode(ctx, size, data, idx)
                        } else {
                            portfolioNormalMode(ctx, size, data)
                        }
                    }
                    .onTapGesture { loc in
                        portfolioTap(at: loc, size: geo.size, data: data)
                    }
                }
                .frame(height: 260)

                // Legend row
                HStack(spacing: 14) {
                    ForEach(data, id: \.def.key) { item in
                        HStack(spacing: 5) {
                            Circle().fill(item.def.color).frame(width: 7, height: 7)
                            Text(item.def.short)
                                .font(.system(size: 11))
                                .foregroundStyle(
                                    selectedKey == nil || selectedKey == item.def.key
                                    ? Color.secondary : Color.secondary.opacity(0.3)
                                )
                        }
                    }
                    Spacer()
                    if selectedKey == nil {
                        Text("bubble size = sessions")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: equipMode) { selectedKey = nil }
    }

    // ── Tap ───────────────────────────────────────────────────────────────

    private func portfolioTap(at loc: CGPoint, size: CGSize,
                               data: [(def: TrailLiftDef, sessions: [LiftSesh])]) {
        if selectedKey != nil {
            withAnimation(.easeInOut(duration: 0.22)) { selectedKey = nil }
            return
        }
        let (xLo, xHi, yLo, yHi, maxN) = portfolioBounds(data)
        for item in data {
            let cx = toX(CGFloat(item.sessions.last!.e1rm),   lo: xLo, hi: xHi, sz: size)
            let cy = toY(CGFloat(olsGainRate(item.sessions)), lo: yLo, hi: yHi, sz: size)
            let r  = bubbleR(item.sessions.count, maxN)
            if hypot(loc.x - cx, loc.y - cy) <= r + 6 {
                withAnimation(.easeInOut(duration: 0.22)) { selectedKey = item.def.key }
                return
            }
        }
    }

    // ── Bounds ────────────────────────────────────────────────────────────

    private func portfolioBounds(_ data: [(def: TrailLiftDef, sessions: [LiftSesh])])
        -> (xLo: CGFloat, xHi: CGFloat, yLo: CGFloat, yHi: CGFloat, maxN: Int) {
        let e1rms  = data.map { CGFloat($0.sessions.last!.e1rm) }
        let rates  = data.map { CGFloat(olsGainRate($0.sessions)) }
        let yPad   = (rates.map(abs).max() ?? 1) * 1.6
        return (
            xLo:  (e1rms.min() ?? 0) * 0.78,
            xHi:  (e1rms.max() ?? 100) * 1.18,
            yLo:  -yPad,
            yHi:   yPad,
            maxN: data.map(\.sessions.count).max() ?? 1
        )
    }

    private func bubbleR(_ count: Int, _ maxCount: Int) -> CGFloat {
        18 + CGFloat(count) / CGFloat(max(maxCount, 1)) * 16
    }

    // ── Normal mode ───────────────────────────────────────────────────────

    private func portfolioNormalMode(_ ctx: GraphicsContext, _ size: CGSize,
                                      _ data: [(def: TrailLiftDef, sessions: [LiftSesh])]) {
        let (xLo, xHi, yLo, yHi, maxN) = portfolioBounds(data)
        let w = cW(size), h = cH(size)
        let midX = toX((xLo + xHi) / 2, lo: xLo, hi: xHi, sz: size)
        let midY = toY(0,               lo: yLo, hi: yHi, sz: size)

        // Quadrant fills + labels
        let quads: [(CGRect, Color, String, CGPoint)] = [
            (CGRect(x: midX,  y: cPT,  width: cPL+w-midX,  height: midY-cPT),   HONTheme.positive,  "Strong & growing",
             CGPoint(x: midX  + (cPL+w-midX)*0.5,  y: cPT  + (midY-cPT)*0.15)),
            (CGRect(x: cPL,   y: cPT,  width: midX-cPL,    height: midY-cPT),   HONTheme.accent,   "Rising fast",
             CGPoint(x: cPL   + (midX-cPL)*0.5,    y: cPT  + (midY-cPT)*0.15)),
            (CGRect(x: midX,  y: midY, width: cPL+w-midX,  height: cPT+h-midY), HONTheme.chartAmber, "Peaked",
             CGPoint(x: midX  + (cPL+w-midX)*0.5,  y: midY + (cPT+h-midY)*0.8)),
            (CGRect(x: cPL,   y: midY, width: midX-cPL,    height: cPT+h-midY), HONTheme.negative,    "Stagnant",
             CGPoint(x: cPL   + (midX-cPL)*0.5,    y: midY + (cPT+h-midY)*0.8)),
        ]
        for (rect, color, label, lpt) in quads {
            ctx.fill(Path(rect), with: .color(color.opacity(0.06)))
            ctx.draw(tlabel(label, size: 9, color: .white.opacity(0.18)), at: lpt, anchor: .center)
        }

        // Zero line
        var zl = Path()
        zl.move(to: CGPoint(x: cPL, y: midY)); zl.addLine(to: CGPoint(x: cPL+w, y: midY))
        ctx.stroke(zl, with: .color(.white.opacity(0.10)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        // Bubbles
        for item in data {
            let cx = toX(CGFloat(item.sessions.last!.e1rm),   lo: xLo, hi: xHi, sz: size)
            let cy = toY(CGFloat(olsGainRate(item.sessions)), lo: yLo, hi: yHi, sz: size)
            let r  = bubbleR(item.sessions.count, maxN)
            drawBubble(ctx, cx: cx, cy: cy, r: r, color: item.def.color, alpha: 1)

            ctx.draw(tlabel(item.def.short, size: 10, weight: .bold, color: item.def.color),
                     at: CGPoint(x: cx, y: cy - 4), anchor: .center)
            ctx.draw(tlabel(String(format: "%.0f kg", item.sessions.last!.e1rm), size: 9, color: .white.opacity(0.65)),
                     at: CGPoint(x: cx, y: cy + 7), anchor: .center)

            let rate = olsGainRate(item.sessions)
            let sign = rate >= 0 ? "+" : ""
            let rCol: Color = rate >= 0.1 ? HONTheme.positive
                            : rate < -0.1  ? HONTheme.negative
                            : .secondary
            ctx.draw(tlabel(String(format: "%@%.2f%%/wk", sign, rate), size: 9, weight: .semibold, color: rCol),
                     at: CGPoint(x: cx, y: cy + r + 12), anchor: .center)
        }

        portfolioGrid(ctx, size, xLo: xLo, xHi: xHi, yLo: yLo, yHi: yHi,
                      yFmt: { String(format: "%+.1f%%", $0) })
        portfolioAxes(ctx, size, x: "e1RM (kg)", y: "Gain Rate (%/wk)")
    }

    // ── Trail mode ────────────────────────────────────────────────────────

    private func portfolioTrailMode(_ ctx: GraphicsContext, _ size: CGSize,
                                     _ data: [(def: TrailLiftDef, sessions: [LiftSesh])],
                                     _ selectedIdx: Int) {
        let (xLo, xHi, yLo, yHi, maxN) = portfolioBounds(data)
        let w = cW(size)
        let midY = toY(0, lo: yLo, hi: yHi, sz: size)

        // Faint zero line
        var zl = Path()
        zl.move(to: CGPoint(x: cPL, y: midY)); zl.addLine(to: CGPoint(x: cPL+w, y: midY))
        ctx.stroke(zl, with: .color(.white.opacity(0.04)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        // Ghost other bubbles
        for (i, item) in data.enumerated() where i != selectedIdx {
            let cx = toX(CGFloat(item.sessions.last!.e1rm),   lo: xLo, hi: xHi, sz: size)
            let cy = toY(CGFloat(olsGainRate(item.sessions)), lo: yLo, hi: yHi, sz: size)
            let r  = bubbleR(item.sessions.count, maxN)
            let circle = Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
            ctx.stroke(circle, with: .color(item.def.color.opacity(0.10)), lineWidth: 1)
        }

        let selected = data[selectedIdx]
        let sessions = selected.sessions
        let n        = sessions.count
        let currentR = bubbleR(n, maxN)

        // Historical trail: (e1rm_i, gainRate up to session i) on the same axes.
        // Draw oldest → newest so newer bubbles sit on top.
        for i in 0..<(n - 1) {
            let stepsBack = (n - 1) - i
            let scale     = pow(0.9, Double(stepsBack))
            let histRate  = olsGainRate(Array(sessions.prefix(i + 1)))
            let cx = toX(CGFloat(sessions[i].e1rm), lo: xLo, hi: xHi, sz: size)
            let cy = toY(CGFloat(histRate),          lo: yLo, hi: yHi, sz: size)
            let r  = currentR * CGFloat(scale)
            drawBubble(ctx, cx: cx, cy: cy, r: r, color: selected.def.color, alpha: CGFloat(scale))
        }

        // Current bubble (full weight, same position as normal mode)
        let curCX = toX(CGFloat(sessions.last!.e1rm),   lo: xLo, hi: xHi, sz: size)
        let curCY = toY(CGFloat(olsGainRate(sessions)), lo: yLo, hi: yHi, sz: size)
        drawBubble(ctx, cx: curCX, cy: curCY, r: currentR, color: selected.def.color, alpha: 1)
        ctx.draw(tlabel(selected.def.short, size: 10, weight: .bold, color: selected.def.color),
                 at: CGPoint(x: curCX, y: curCY - 4), anchor: .center)
        ctx.draw(tlabel(String(format: "%.0f kg", sessions.last!.e1rm), size: 9, color: .white.opacity(0.65)),
                 at: CGPoint(x: curCX, y: curCY + 7), anchor: .center)

        // Start date label on oldest dot
        let oldRate = olsGainRate(Array(sessions.prefix(1)))
        let oldCX   = toX(CGFloat(sessions[0].e1rm), lo: xLo, hi: xHi, sz: size)
        let oldCY   = toY(CGFloat(oldRate),           lo: yLo, hi: yHi, sz: size)
        let oldR    = currentR * CGFloat(pow(0.9, Double(n - 1)))
        let df      = DateFormatter(); df.dateFormat = "MMM yy"
        ctx.draw(tlabel(df.string(from: sessions[0].date), size: 9, color: .white.opacity(0.22)),
                 at: CGPoint(x: oldCX, y: oldCY - oldR - 5), anchor: .bottom)

        portfolioGrid(ctx, size, xLo: xLo, xHi: xHi, yLo: yLo, yHi: yHi,
                      yFmt: { String(format: "%+.1f%%", $0) })
        portfolioAxes(ctx, size, x: "e1RM (kg)", y: "Gain Rate (%/wk)")
    }

    // ── Drawing primitives ────────────────────────────────────────────────

    private func drawBubble(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                             r: CGFloat, color: Color, alpha: CGFloat) {
        guard r >= 1.5 else { return }
        let rect   = CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)
        let circle = Path(ellipseIn: rect)
        if alpha > 0.5 {
            let glow = Path(ellipseIn: rect.insetBy(dx: -9, dy: -9))
            ctx.fill(glow, with: .color(color.opacity(0.07 * alpha)))
        }
        ctx.fill(circle, with: .radialGradient(
            Gradient(stops: [
                .init(color: color.opacity(0.40 * alpha), location: 0),
                .init(color: color.opacity(0.18 * alpha), location: 1),
            ]),
            center: CGPoint(x: cx - r*0.3, y: cy - r*0.3),
            startRadius: r * 0.1,
            endRadius: r
        ))
        ctx.stroke(circle, with: .color(color.opacity(0.65 * alpha)), lineWidth: 1)
    }

    private func portfolioGrid(_ ctx: GraphicsContext, _ size: CGSize,
                                xLo: CGFloat, xHi: CGFloat, yLo: CGFloat, yHi: CGFloat,
                                yFmt: (CGFloat) -> String) {
        let w = cW(size), h = cH(size)
        let xStep: CGFloat = (xHi - xLo) > 80 ? 20 : 10
        let yRange = yHi - yLo
        let yStep: CGFloat = yRange > 4 ? 1 : yRange > 2 ? 0.5 : 0.25

        var v = ceil(yLo / yStep) * yStep
        while v <= yHi + 0.001 {
            let yp = toY(v, lo: yLo, hi: yHi, sz: size)
            var l = Path(); l.move(to: CGPoint(x: cPL, y: yp)); l.addLine(to: CGPoint(x: cPL+w, y: yp))
            ctx.stroke(l, with: .color(.white.opacity(0.05)), lineWidth: 1)
            ctx.draw(tlabel(yFmt(v), size: 9, color: .secondary.opacity(0.5)),
                     at: CGPoint(x: cPL - 5, y: yp), anchor: .trailing)
            v += yStep
        }

        v = ceil(xLo / xStep) * xStep
        while v <= xHi + 0.001 {
            let xp = toX(v, lo: xLo, hi: xHi, sz: size)
            var l = Path(); l.move(to: CGPoint(x: xp, y: cPT)); l.addLine(to: CGPoint(x: xp, y: cPT+h))
            ctx.stroke(l, with: .color(.white.opacity(0.05)), lineWidth: 1)
            ctx.draw(tlabel(String(format: "%.0f", v), size: 9, color: .secondary.opacity(0.5)),
                     at: CGPoint(x: xp, y: cPT+h+10), anchor: .top)
            v += xStep
        }

        ctx.stroke(Path(CGRect(x: cPL, y: cPT, width: w, height: h)),
                   with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    private func portfolioAxes(_ ctx: GraphicsContext, _ size: CGSize, x: String, y: String) {
        ctx.draw(tlabel(x, size: 10, color: .secondary.opacity(0.55)),
                 at: CGPoint(x: size.width/2, y: size.height - 4), anchor: .bottom)
        ctx.drawLayer { inner in
            inner.transform = CGAffineTransform(translationX: 11, y: cPT + cH(size)/2)
                .rotated(by: -.pi/2)
            inner.draw(tlabel(y, size: 10, color: .secondary.opacity(0.55)), at: .zero, anchor: .center)
        }
    }
}

// MARK: - StrengthConstellationCard  (Lab tab)

struct StrengthConstellationCard: View {
    let log: [WorkoutLogEntry]
    let bodyWeightKg: Double?

    @State private var equipMode: EquipmentMode = .barbell

    private var activeDefs: [TrailLiftDef] {
        equipMode == .barbell ? kTrailDefs : kTrailDefsDB
    }

    private var liftData: [(def: TrailLiftDef, sessions: [LiftSesh])] {
        activeDefs.compactMap { def in
            let s = buildSessions(def, log)
            return s.count >= 2 ? (def, s) : nil
        }
    }

    var body: some View {
        let data   = liftData
        let bw     = bodyWeightKg ?? 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Trail")
                        .font(.system(size: 14, weight: .bold))
                    Text("e1RM vs relative strength — all lifts over time")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $equipMode) {
                    ForEach(EquipmentMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 148)
            }

            if data.isEmpty || bw == 0 {
                Text(bw == 0
                     ? "Set your body weight in Settings to enable relative-strength tracking."
                     : "Log at least 2 sessions of a compound lift to see the trail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
            } else {
                Canvas { ctx, size in
                    drawConstellation(ctx, size, data, bw)
                }
                .frame(height: 280)

                HStack(spacing: 14) {
                    ForEach(data, id: \.def.key) { item in
                        HStack(spacing: 5) {
                            Circle().fill(item.def.color).frame(width: 7, height: 7)
                            Text(item.def.short).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(Color.secondary.opacity(0.25)).frame(width: 5, height: 5)
                        Image(systemName: "arrow.right").font(.system(size: 8)).foregroundStyle(.secondary)
                        Circle().fill(Color.secondary).frame(width: 8, height: 8)
                        Text("older → recent").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func drawConstellation(_ ctx: GraphicsContext, _ size: CGSize,
                                    _ data: [(def: TrailLiftDef, sessions: [LiftSesh])],
                                    _ bw: Double) {
        let allE = data.flatMap { $0.sessions.map { CGFloat($0.e1rm) } }
        let allR = data.flatMap { $0.sessions.map { CGFloat($0.e1rm / bw) } }
        let xLo  = (allE.min() ?? 0) * 0.88
        let xHi  = (allE.max() ?? 100) * 1.06
        let yLo  = max(0, (allR.min() ?? 0) * 0.85)
        let yHi  = (allR.max() ?? 2) * 1.14
        let w    = cW(size), h = cH(size)

        // Grid
        let xStep: CGFloat = (xHi - xLo) > 80 ? 20 : 10
        let yRange = yHi - yLo
        let yStep: CGFloat = yRange > 1.5 ? 0.5 : 0.25

        var v = ceil(yLo / yStep) * yStep
        while v <= yHi + 0.001 {
            let yp = toY(v, lo: yLo, hi: yHi, sz: size)
            var l = Path(); l.move(to: CGPoint(x: cPL, y: yp)); l.addLine(to: CGPoint(x: cPL+w, y: yp))
            ctx.stroke(l, with: .color(.white.opacity(0.05)), lineWidth: 1)
            ctx.draw(tlabel(String(format: "%.2f×", v), size: 9, color: .secondary.opacity(0.5)),
                     at: CGPoint(x: cPL - 5, y: yp), anchor: .trailing)
            v += yStep
        }
        v = ceil(xLo / xStep) * xStep
        while v <= xHi + 0.001 {
            let xp = toX(v, lo: xLo, hi: xHi, sz: size)
            var l = Path(); l.move(to: CGPoint(x: xp, y: cPT)); l.addLine(to: CGPoint(x: xp, y: cPT+h))
            ctx.stroke(l, with: .color(.white.opacity(0.05)), lineWidth: 1)
            ctx.draw(tlabel(String(format: "%.0f", v), size: 9, color: .secondary.opacity(0.5)),
                     at: CGPoint(x: xp, y: cPT+h+10), anchor: .top)
            v += xStep
        }
        ctx.stroke(Path(CGRect(x: cPL, y: cPT, width: w, height: h)),
                   with: .color(.white.opacity(0.08)), lineWidth: 1)

        // Each lift: trail line + tapering dots (25% overlap, 10% reduction per step)
        for item in data {
            let sessions = item.sessions
            let n        = sessions.count
            let baseR: CGFloat = 7   // current dot radius

            // Trail line (opacity grows toward present)
            for i in 1..<n {
                let f1 = CGFloat(i) / CGFloat(n - 1)
                let x0 = toX(CGFloat(sessions[i-1].e1rm), lo: xLo, hi: xHi, sz: size)
                let y0 = toY(CGFloat(sessions[i-1].e1rm / bw), lo: yLo, hi: yHi, sz: size)
                let x1 = toX(CGFloat(sessions[i].e1rm),   lo: xLo, hi: xHi, sz: size)
                let y1 = toY(CGFloat(sessions[i].e1rm / bw), lo: yLo, hi: yHi, sz: size)
                var l  = Path(); l.move(to: CGPoint(x: x0, y: y0)); l.addLine(to: CGPoint(x: x1, y: y1))
                ctx.stroke(l, with: .color(item.def.color.opacity(0.08 + 0.35 * f1)),
                           lineWidth: 0.8 + f1 * 1.2)
            }

            // Dots: oldest → newest, each step back = 0.9× size and opacity
            for i in 0..<(n - 1) {
                let stepsBack = (n - 1) - i
                let scale = CGFloat(pow(0.9, Double(stepsBack)))
                let r  = baseR * scale
                let cx = toX(CGFloat(sessions[i].e1rm), lo: xLo, hi: xHi, sz: size)
                let cy = toY(CGFloat(sessions[i].e1rm / bw), lo: yLo, hi: yHi, sz: size)
                let circle = Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
                ctx.fill(circle, with: .color(item.def.color.opacity(scale * 0.65)))
            }

            // Current dot (full size, white ring)
            let last = sessions.last!
            let cx   = toX(CGFloat(last.e1rm), lo: xLo, hi: xHi, sz: size)
            let cy   = toY(CGFloat(last.e1rm / bw), lo: yLo, hi: yHi, sz: size)
            let cirC = Path(ellipseIn: CGRect(x: cx-baseR, y: cy-baseR, width: baseR*2, height: baseR*2))
            ctx.fill(cirC, with: .color(item.def.color))
            ctx.stroke(cirC, with: .color(.white.opacity(0.75)), lineWidth: 1.2)
            ctx.draw(tlabel(item.def.short, size: 9, weight: .semibold, color: item.def.color),
                     at: CGPoint(x: cx + baseR + 4, y: cy), anchor: .leading)
        }

        // Axis labels
        ctx.draw(tlabel("e1RM (kg)", size: 10, color: .secondary.opacity(0.55)),
                 at: CGPoint(x: size.width/2, y: size.height - 4), anchor: .bottom)
        ctx.drawLayer { inner in
            inner.transform = CGAffineTransform(translationX: 11, y: cPT + h/2).rotated(by: -.pi/2)
            inner.draw(tlabel("Relative Strength (×BW)", size: 10, color: .secondary.opacity(0.55)),
                       at: .zero, anchor: .center)
        }
    }
}
