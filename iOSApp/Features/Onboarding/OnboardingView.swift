import SwiftUI

struct OnboardingView: View {
    @Environment(SeedStore.self) private var store
    let onComplete: () -> Void

    @State private var page = 0
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg = true
    @State private var nameInput:       String = ""
    @State private var bodyWeightInput: String = ""
    @State private var ageInput:        String = ""
    @AppStorage("trainingLocation") private var trainingLocation: String = "gym"

    private let totalPages = 3

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                pageIndicator
                    .padding(.top, 60)
                    .padding(.bottom, 0)

                Spacer()

                Group {
                    switch page {
                    case 0:  pageWelcome
                    case 1:  pageBaseline
                    default: pageReady
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(page)

                Spacer()

                VStack(spacing: 14) {
                    ctaButton

                    if page == 1 {
                        Button("Skip for now") {
                            NotificationScheduler.requestPermission()
                            onComplete()
                        }
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(HONTheme.accent.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            let stored = userName
            nameInput = (stored.isEmpty || stored == "Alex") ? "" : stored
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? HONTheme.accent : HONTheme.textSecondary.opacity(0.25))
                    .frame(width: i == page ? 26 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
            }
        }
    }

    // MARK: - Page 0: Welcome + Name

    private var pageWelcome: some View {
        VStack(spacing: 36) {
            // HON wordmark
            VStack(spacing: 14) {
                amberRule.padding(.horizontal, 48)
                honMark
                amberRule.padding(.horizontal, 48)
            }

            VStack(spacing: 6) {
                Text("Track the work.")
                    .font(.custom("CormorantGaramond-LightItalic", size: 20))
                    .foregroundStyle(HONTheme.textSecondary)
                Text("Trust the process.")
                    .font(.custom("CormorantGaramond-LightItalic", size: 20))
                    .foregroundStyle(HONTheme.textSecondary)
                Text("Show up. That\u{2019}s enough.")
                    .font(.custom("CormorantGaramond-LightItalic", size: 16))
                    .foregroundStyle(HONTheme.accent.opacity(0.75))
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("WHAT DO WE CALL YOU")
                    .font(.custom("DMSans-Medium", size: 10))
                    .kerning(2)
                    .foregroundStyle(HONTheme.textSecondary.opacity(0.7))

                honTextField("Your name", text: $nameInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                // Unit preference
                VStack(spacing: 8) {
                    Text("Preferred units")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Picker("Units", selection: $weightUnitIsKg) {
                        Text("kg").tag(true)
                        Text("lbs").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 1: Baseline

    private var pageBaseline: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Text("Your Baseline")
                    .font(.custom("CormorantGaramond-Light", size: 40))
                    .foregroundStyle(HONTheme.textPrimary)

                Text("We use these to provide context for your training — always relative to your own starting point.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(HONTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 18) {
                // Body weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("BODY WEIGHT")
                        .font(.custom("DMSans-Medium", size: 10))
                        .kerning(2)
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.7))
                    HStack(spacing: 10) {
                        honTextField(weightUnitIsKg ? "e.g. 80" : "e.g. 175", text: $bodyWeightInput)
                            .keyboardType(.decimalPad)
                        Text(weightUnitIsKg ? "kg" : "lbs")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundStyle(HONTheme.textSecondary)
                            .frame(width: 28)
                    }
                }

                // Age
                VStack(alignment: .leading, spacing: 8) {
                    Text("AGE")
                        .font(.custom("DMSans-Medium", size: 10))
                        .kerning(2)
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.7))
                    honTextField("e.g. 28", text: $ageInput)
                        .keyboardType(.numberPad)
                }

                // Training location
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHERE DO YOU TRAIN")
                        .font(.custom("DMSans-Medium", size: 10))
                        .kerning(2)
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.7))
                    HStack(spacing: 8) {
                        ForEach([("gym", "Gym", "dumbbell.fill"), ("home", "Home", "house.fill"), ("both", "Both", "arrow.left.arrow.right")], id: \.0) { loc in
                            Button {
                                trainingLocation = loc.0
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: loc.2).font(.system(size: 11))
                                    Text(loc.1).font(.custom("DMSans-Medium", size: 13))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    trainingLocation == loc.0
                                        ? HONTheme.accent.opacity(0.18)
                                        : HONTheme.textSecondary.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            trainingLocation == loc.0 ? HONTheme.accent : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .foregroundStyle(trainingLocation == loc.0 ? HONTheme.accent : HONTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if trainingLocation == "home" || trainingLocation == "both" {
                        Text("Exercises will be tagged — you can filter by equipment in the workout tab at any time.")
                            .font(.system(size: 11))
                            .foregroundStyle(HONTheme.textSecondary.opacity(0.55))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 2: Ready

    private var pageReady: some View {
        VStack(spacing: 28) {
            amberRule.padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("You're ready,")
                    .font(.custom("CormorantGaramond-Light", size: 30))
                    .foregroundStyle(HONTheme.textSecondary)
                Text("\(displayName).")
                    .font(.custom("CormorantGaramond-Light", size: 46))
                    .foregroundStyle(HONTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Text("Log your first session.\nEverything else follows from there.")
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundStyle(HONTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            amberRule.padding(.horizontal, 40)

            Text("Show up. That\u{2019}s enough.")
                .font(.custom("CormorantGaramond-LightItalic", size: 17))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.55))
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: advance) {
            Text(page == totalPages - 1 ? "Begin" : "Continue")
                .font(.custom("DMSans-SemiBold", size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    page == 0 && nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                        ? HONTheme.accent.opacity(0.35)
                        : HONTheme.accent,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
        }
        .disabled(page == 0 && nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
        .animation(.easeInOut(duration: 0.2), value: nameInput)
    }

    // MARK: - Sub-components

    private var amberRule: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear,         location: 0.0),
                        .init(color: HONTheme.accent, location: 0.2),
                        .init(color: HONTheme.accent, location: 0.8),
                        .init(color: .clear,         location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    private var honMark: some View {
        HStack(spacing: 40 * 0.22) {
            Text("H").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
            Text("O").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
            Text("N").foregroundStyle(HONTheme.textPrimary)
            Text(".").foregroundStyle(HONTheme.accent)
        }
        .font(.custom("CormorantGaramond-Light", size: 40))
        .lineLimit(1)
        .fixedSize()
    }

    @ViewBuilder
    private func honTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt:
            Text(placeholder)
                .foregroundColor(HONTheme.textSecondary.opacity(0.45))
        )
        .font(.custom("DMSans-Regular", size: 16))
        .foregroundStyle(HONTheme.textPrimary)
        .tint(HONTheme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(HONTheme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Logic

    private var displayName: String {
        let n = userName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Athlete" : n
    }

    private func advance() {
        switch page {
        case 0:
            let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { userName = trimmed }

        case 1:
            if let bw = Double(bodyWeightInput.replacingOccurrences(of: ",", with: ".")), bw > 0 {
                store.userProfile.bodyWeightKg = weightUnitIsKg ? bw : bw * 0.453592
            }
            if let age = Int(ageInput), age > 0, age < 120 {
                store.userProfile.age = age
            }

        default:
            break
        }

        if page < totalPages - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
        } else {
            NotificationScheduler.requestPermission()
            onComplete()
        }
    }
}
