import SwiftUI

struct StandaloneE1RMView: View {
    @AppStorage("weightUnitIsKg") private var isKg = true
    @State private var weightKg: Double = 100
    @State private var reps: Int = 5

    private func r5(_ v: Double) -> Int { Int((v / 5.0).rounded()) * 5 }
    private var epley:    Double { weightKg * (1 + Double(reps) / 30) }
    private var brzycki:  Double { reps == 1 ? weightKg : weightKg * 36 / (37 - Double(reps)) }
    private var lombardi: Double { weightKg * pow(Double(reps), 0.1) }
    private var best:     Double { [epley, brzycki, lombardi].reduce(0, +) / 3 }
    private func disp(_ kg: Double) -> String { isKg ? "\(r5(kg)) kg" : "\(r5(kg * 2.20462)) lbs" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Input
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Weight").font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Text(disp(weightKg)).font(.caption.bold())
                        }
                        Slider(value: $weightKg, in: isKg ? 20...300 : 44...660, step: isKg ? 2.5 : 5).accentColor(HONTheme.accent)
                    }
                    HStack {
                        Text("Reps").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Stepper("", value: $reps, in: 1...20).labelsHidden()
                        Text("\(reps) reps").font(.caption.bold()).frame(width: 70)
                    }
                }
                .padding(16).background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                // Big result
                VStack(spacing: 4) {
                    Text("Estimated 1RM").font(.caption).foregroundStyle(.secondary)
                    Text("~\(disp(best))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(HONTheme.accent)
                    Text("Average of 3 formulas · ±10% accuracy").font(.caption2).foregroundStyle(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity).padding(24)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                // Formulas
                VStack(alignment: .leading, spacing: 8) {
                    Text("Formulas").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach([("Epley", epley), ("Brzycki", brzycki), ("Lombardi", lombardi)], id: \.0) { n, v in
                        HStack { Text(n).font(.caption); Spacer(); Text(disp(v)).font(.caption.bold()) }
                    }
                }
                .padding(16).background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                // Rep max table
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rep Max Table").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach([(1, 100), (2, 97), (3, 94), (4, 91), (5, 87), (6, 85), (8, 80), (10, 75), (12, 70), (15, 65), (20, 60)], id: \.0) { r, pct in
                        HStack {
                            Text("\(r)RM").font(.caption).frame(width: 36, alignment: .leading)
                            Text("\(pct)%").font(.caption2).foregroundStyle(.secondary).frame(width: 32)
                            Spacer()
                            Text(disp(best * Double(pct) / 100)).font(.caption.bold())
                        }
                        if r < 20 { Divider() }
                    }
                }
                .padding(16).background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
        .background(HONTheme.background)
        .navigationTitle("1RM Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }
}
