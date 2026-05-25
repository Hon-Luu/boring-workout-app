import SwiftUI

struct PlateCalculatorView: View {
    @AppStorage("weightUnitIsKg") private var isKg = true
    @State private var targetWeight: Double = 100
    @State private var barKg: Double = 20

    init(initialWeight: Double? = nil) {
        if let w = initialWeight, w > 0 {
            _targetWeight = State(initialValue: w)
        }
    }

    private let kgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    private var platesPerSide: [(kg: Double, count: Int)] {
        var rem = max(0, targetWeight - barKg) / 2.0
        var result: [(Double, Int)] = []
        for p in kgPlates {
            let n = Int(rem / p)
            if n > 0 { result.append((p, n)); rem -= Double(n) * p }
        }
        return result
    }

    private func plateColor(_ kg: Double) -> Color {
        switch kg {
        case 25: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case 20: return Color(red: 0.15, green: 0.4, blue: 0.85)
        case 15: return Color(red: 0.9, green: 0.6, blue: 0.1)
        case 10: return Color(red: 0.2, green: 0.65, blue: 0.2)
        case 5:  return Color(white: 0.85)
        default: return Color.secondary
        }
    }

    private func fmt(_ kg: Double) -> String {
        isKg ? "\(Int(kg)) kg" : "\(Int((kg * 2.20462).rounded())) lbs"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Target weight
                VStack(spacing: 12) {
                    Text("Target Weight").font(.caption.bold()).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Button { targetWeight = max(barKg, targetWeight - 2.5) } label: {
                            Image(systemName: "minus.circle.fill").font(.title).foregroundStyle(HONTheme.accent)
                        }
                        Text(fmt(targetWeight))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .frame(minWidth: 140)
                        Button { targetWeight += 2.5 } label: {
                            Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(HONTheme.accent)
                        }
                    }
                    HStack(spacing: 8) {
                        if isKg {
                            ForEach([60.0, 80.0, 100.0, 120.0, 140.0, 180.0], id: \.self) { w in
                                Button("\(Int(w)) kg") { targetWeight = w }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(abs(targetWeight - w) < 0.1 ? HONTheme.accent.opacity(0.2) : Color.secondary.opacity(0.1), in: Capsule())
                                    .foregroundStyle(HONTheme.accent)
                            }
                        } else {
                            ForEach([95.0, 135.0, 185.0, 225.0, 275.0, 315.0], id: \.self) { lbs in
                                let wKg = lbs * 0.453592
                                Button("\(Int(lbs)) lbs") { targetWeight = wKg }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(abs(targetWeight - wKg) < 0.5 ? HONTheme.accent.opacity(0.2) : Color.secondary.opacity(0.1), in: Capsule())
                                    .foregroundStyle(HONTheme.accent)
                            }
                        }
                    }
                }
                .padding(16).background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                // Bar
                Picker("Bar weight", selection: $barKg) {
                    Text("20 kg / 44 lb").tag(20.0)
                    Text("15 kg / 33 lb").tag(15.0)
                    Text("10 kg / 22 lb").tag(10.0)
                }
                .pickerStyle(.segmented)

                // Plates
                VStack(alignment: .leading, spacing: 10) {
                    Text("Plates per side").font(.caption.bold()).foregroundStyle(.secondary)
                    if platesPerSide.isEmpty {
                        Text("Just the bar (\(fmt(barKg)))").foregroundStyle(.secondary)
                    } else {
                        ForEach(platesPerSide, id: \.kg) { p in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(plateColor(p.kg))
                                    .frame(width: 48, height: 28)
                                    .overlay(Text(p.kg < 2 ? String(format: "%.2f", p.kg) : String(format: "%.4g", p.kg))
                                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                                Text("× \(p.count)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                Spacer()
                                Text(fmt(p.kg)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(16).background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                // Visual bar
                HStack(spacing: 2) {
                    ForEach(platesPerSide.reversed(), id: \.kg) { p in
                        ForEach(0..<min(p.count, 5), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(plateColor(p.kg))
                                .frame(width: 10, height: CGFloat(16 + p.kg * 0.8))
                        }
                    }
                    Capsule().fill(Color(white: 0.5)).frame(width: 24, height: 10)
                    ForEach(platesPerSide, id: \.kg) { p in
                        ForEach(0..<min(p.count, 5), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(plateColor(p.kg))
                                .frame(width: 10, height: CGFloat(16 + p.kg * 0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .padding(20)
        }
        .background(HONTheme.background)
        .navigationTitle("Plate Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }
}
