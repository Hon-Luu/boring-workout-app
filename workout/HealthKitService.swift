import Foundation
import HealthKit
import Observation

// MARK: - Shared data model

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date      // start-of-day
    let value: Double
}

@Observable
final class HealthKitService {

    // MARK: - Published state

    // Recovery metrics
    var hrv: Double?            // ms, last night avg SDNN
    var restingHR: Double?      // bpm, most recent
    var sleepHours: Double?     // hours, last night (deduped)
    var respiratoryRate: Double? // breaths/min, last night avg
    var oxygenSaturation: Double? // %, last night avg

    // Body metrics
    var bodyweight: Double?     // kg, most recent
    var bodyFatPercentage: Double? // %, most recent
    var leanBodyMass: Double?   // kg, most recent

    // Activity
    var vo2Max: Double?         // ml/kg/min, most recent
    var activeCaloriesToday: Double? // kcal, today
    var stepsToday: Int?        // steps, today

    // Historical arrays for correlation charts (90-day window)
    var sleepHistory:      [HealthDataPoint] = []
    var hrvHistory:        [HealthDataPoint] = []
    var restingHRHistory:  [HealthDataPoint] = []
    var stepsHistory:      [HealthDataPoint] = []

    // 30-day personal HRV baseline (nil if fewer than 7 data points)
    var hrvBaseline: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = hrvHistory.filter { $0.date >= cutoff }.map(\.value)
        guard recent.count >= 7 else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    var isAuthorized = false
    var authDenied   = false
    var lastFetched: Date?

    // MARK: - Private

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
        ]
        let optionals: [HKQuantityTypeIdentifier] = [
            .vo2Max, .bodyFatPercentage, .leanBodyMass, .bodyMassIndex, .waistCircumference,
            .respiratoryRate, .oxygenSaturation, .walkingHeartRateAverage,
            .appleExerciseTime, .appleStandTime,
        ]
        for id in optionals {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
        ]
    }

    // MARK: - Public API

    func requestAndFetch() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        store.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self?.isAuthorized = true
                    self?.fetchAll()
                } else {
                    self?.authDenied = true
                }
            }
        }
    }

    // MARK: - Fetch all

    private func fetchAll() {
        lastFetched = Date()
        fetchHRV()
        fetchRestingHR()
        fetchSleep()
        fetchBodyweight()
        fetchVO2Max()
        fetchBodyFat()
        fetchLeanMass()
        fetchRespiratoryRate()
        fetchOxygenSaturation()
        fetchActiveCaloriesToday()
        fetchStepsToday()
        fetchSleepHistory()
        fetchHRVHistory()
        fetchRestingHRHistory()
        fetchStepsHistory()
    }

    private func fetchSleepHistory() {
        Task { @MainActor in
            sleepHistory = await fetchDailySleepHistory(days: 90)
        }
    }

    private func fetchHRVHistory() {
        Task { @MainActor in
            hrvHistory = await fetchDailyQuantity(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), options: .discreteAverage, days: 90)
        }
    }

    private func fetchRestingHRHistory() {
        Task { @MainActor in
            restingHRHistory = await fetchDailyQuantity(.restingHeartRate, unit: HKUnit(from: "count/min"), options: .discreteAverage, days: 90)
        }
    }

    private func fetchStepsHistory() {
        Task { @MainActor in
            stepsHistory = await fetchDailyQuantity(.stepCount, unit: .count(), options: .cumulativeSum, days: 90)
        }
    }

    // MARK: - Recovery

    private func fetchHRV() {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 20, sortDescriptors: [sort]) { [weak self] _, samples, error in
            if let error { print("HealthKit HRV error: \(error)"); return }
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
            let avg = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) }.reduce(0, +) / Double(samples.count)
            DispatchQueue.main.async { self?.hrv = avg }
        }
        store.execute(q)
    }

    private func fetchRestingHR() {
        let type = HKQuantityType(.restingHeartRate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let bpm = s.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async { self?.restingHR = bpm }
        }
        store.execute(q)
    }

    private func fetchSleep() {
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12; comps.minute = 0; comps.second = 0
        let todayNoon = cal.date(from: comps) ?? Date()
        let windowStart = todayNoon.addingTimeInterval(-18 * 3600)

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: todayNoon)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, error in
            if let error { print("HealthKit sleep error: \(error)"); return }
            guard let samples = samples as? [HKCategorySample] else { return }
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            ]
            let intervals = samples
                .filter { asleepValues.contains($0.value) }
                .map { (start: $0.startDate, end: $0.endDate) }
                .sorted { $0.start < $1.start }
            let merged = Self.mergeIntervals(intervals)
            let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
            guard totalSeconds > 0 else { return }
            DispatchQueue.main.async { self?.sleepHours = totalSeconds / 3600 }
        }
        store.execute(q)
    }

    private func fetchRespiratoryRate() {
        guard let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return }
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 20, sortDescriptors: [sort]) { [weak self] _, samples, error in
            if let error { print("HealthKit respiratory rate error: \(error)"); return }
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
            let avg = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }.reduce(0, +) / Double(samples.count)
            DispatchQueue.main.async { self?.respiratoryRate = avg }
        }
        store.execute(q)
    }

    private func fetchOxygenSaturation() {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 10, sortDescriptors: [sort]) { [weak self] _, samples, error in
            if let error { print("HealthKit SpO2 error: \(error)"); return }
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
            let avg = samples.map { $0.quantity.doubleValue(for: HKUnit.percent()) }.reduce(0, +) / Double(samples.count)
            DispatchQueue.main.async { self?.oxygenSaturation = avg * 100 } // store as 0–100
        }
        store.execute(q)
    }

    // MARK: - Body metrics

    private func fetchBodyweight() {
        let type = HKQuantityType(.bodyMass)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let kg = s.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async { self?.bodyweight = kg }
        }
        store.execute(q)
    }

    private func fetchBodyFat() {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let pct = s.quantity.doubleValue(for: HKUnit.percent()) * 100
            DispatchQueue.main.async { self?.bodyFatPercentage = pct }
        }
        store.execute(q)
    }

    private func fetchLeanMass() {
        guard let type = HKObjectType.quantityType(forIdentifier: .leanBodyMass) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let kg = s.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async { self?.leanBodyMass = kg }
        }
        store.execute(q)
    }

    // MARK: - Activity & Fitness

    private func fetchVO2Max() {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let unit = HKUnit(from: "ml/kg·min")
            let val = s.quantity.doubleValue(for: unit)
            DispatchQueue.main.async { self?.vo2Max = val }
        }
        store.execute(q)
    }

    private func fetchActiveCaloriesToday() {
        let type = HKQuantityType(.activeEnergyBurned)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let q = HKStatisticsQuery(quantityType: type,
                                  quantitySamplePredicate: predicate,
                                  options: .cumulativeSum) { [weak self] _, stats, _ in
            let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            DispatchQueue.main.async { self?.activeCaloriesToday = kcal }
        }
        store.execute(q)
    }

    private func fetchStepsToday() {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let q = HKStatisticsQuery(quantityType: type,
                                  quantitySamplePredicate: predicate,
                                  options: .cumulativeSum) { [weak self] _, stats, _ in
            let steps = stats?.sumQuantity().map { Int($0.doubleValue(for: .count())) }
            DispatchQueue.main.async { self?.stepsToday = steps }
        }
        store.execute(q)
    }

    // MARK: - On-demand queries

    func fetchAverageHeartRate(from start: Date, to end: Date) async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else { return nil }
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                let bpm = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            store.execute(q)
        }
    }

    func fetchActiveCalories(from start: Date, to end: Date) async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else { return nil }
        let type = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: kcal)
            }
            store.execute(q)
        }
    }

    // MARK: - Save workout to HealthKit

    /// Saves a completed workout as an HKWorkout (strength training) so it appears in Apple Fitness.
    /// Attaches an estimated active-energy sample so Apple Fitness shows a real calorie number.
    /// Uses MET 5.0 (ACSM Compendium of Physical Activities — moderate strength training).
    func saveWorkout(_ entry: WorkoutLogEntry, bodyWeightKg: Double? = nil) {
        guard HKHealthStore.isHealthDataAvailable(), let end = entry.finishedAt else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        builder.beginCollection(withStart: entry.startedAt) { success, error in
            if let error { print("HealthKit beginCollection error: \(error)"); return }
            guard success else { return }

            var samples: [HKSample] = []
            if let bw = bodyWeightKg, bw > 0,
               let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                let kcal = 5.0 * bw * (entry.duration / 3600.0)
                if kcal > 0 {
                    samples.append(HKQuantitySample(
                        type: energyType,
                        quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                        start: entry.startedAt, end: end
                    ))
                }
            }

            let finish: () -> Void = {
                builder.endCollection(withEnd: end) { success, error in
                    if let error { print("HealthKit endCollection error: \(error)"); return }
                    guard success else { return }
                    builder.finishWorkout { _, error in
                        if let error { print("HealthKit finishWorkout error: \(error)") }
                    }
                }
            }
            if samples.isEmpty {
                finish()
            } else {
                builder.add(samples) { success, _ in
                    guard success else { return }
                    finish()
                }
            }
        }
    }

    // MARK: - Save cardio session to HealthKit

    func saveCardioSession(_ entry: CardioLogEntry) {
        guard HKHealthStore.isHealthDataAvailable(), let end = entry.finishedAt else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .highIntensityIntervalTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        builder.beginCollection(withStart: entry.startedAt) { success, error in
            if let error { print("HealthKit cardio beginCollection error: \(error)"); return }
            guard success else { return }
            builder.endCollection(withEnd: end) { success, error in
                if let error { print("HealthKit cardio endCollection error: \(error)"); return }
                guard success else { return }
                builder.finishWorkout { _, error in
                    if let error { print("HealthKit cardio finishWorkout error: \(error)") }
                }
            }
        }
    }

    // MARK: - Body composition sync helper

    /// Returns the latest body fat % and body weight from Health for auto-populating UserProfile.
    func fetchBodyCompositionSnapshot() async -> (bodyFatPct: Double?, bodyWeightKg: Double?, leanMassKg: Double?) {
        async let fat = latestQuantity(.bodyFatPercentage, unit: .percent())
        async let weight = latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let lean = latestQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo))
        let (f, w, l) = await (fat, weight, lean)
        return (f.map { $0 * 100 }, w, l)
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let val = (samples as? [HKQuantitySample])?.first?.quantity.doubleValue(for: unit)
                continuation.resume(returning: val)
            }
            store.execute(q)
        }
    }

    // MARK: - Historical data (for trend charts)

    /// Fetches daily data points for the requested metric over the last `days` days.
    func fetchHistoricalData(metric: HealthMetric, days: Int) async -> [HealthDataPoint] {
        switch metric.id {
        case "hrv":             return await fetchDailyQuantity(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"),       options: .discreteAverage, days: days)
        case "restingHR":       return await fetchDailyQuantity(.restingHeartRate,          unit: HKUnit(from: "count/min"), options: .discreteAverage, days: days)
        case "walkingHR":       return await fetchDailyQuantity(.walkingHeartRateAverage,   unit: HKUnit(from: "count/min"), options: .discreteAverage, days: days)
        case "sleep":           return await fetchDailySleepHistory(days: days)
        case "respiratoryRate": return await fetchDailyQuantity(.respiratoryRate,           unit: HKUnit(from: "count/min"), options: .discreteAverage, days: days)
        case "spo2":            return await fetchDailySpo2(days: days)
        case "weight":          return await fetchDailyQuantity(.bodyMass,                  unit: .gramUnit(with: .kilo),    options: .discreteAverage, days: days)
        case "bodyFat":         return await fetchDailyBodyFat(days: days)
        case "leanMass":        return await fetchDailySparseQuantity(.leanBodyMass,        unit: .gramUnit(with: .kilo),    days: days)
        case "bmi":             return await fetchDailySparseQuantity(.bodyMassIndex,       unit: .count(),                  days: days)
        case "waist":           return await fetchDailySparseQuantity(.waistCircumference,  unit: .meterUnit(with: .centi),  days: days)
        case "steps":           return await fetchDailyQuantity(.stepCount,                 unit: .count(),                  options: .cumulativeSum,   days: days)
        case "distance":        return await fetchDailyQuantity(.distanceWalkingRunning,    unit: .meterUnit(with: .kilo),   options: .cumulativeSum,   days: days)
        case "flights":         return await fetchDailyQuantity(.flightsClimbed,            unit: .count(),                  options: .cumulativeSum,   days: days)
        case "activeCalories":  return await fetchDailyQuantity(.activeEnergyBurned,        unit: .kilocalorie(),            options: .cumulativeSum,   days: days)
        case "basalCalories":   return await fetchDailyQuantity(.basalEnergyBurned,         unit: .kilocalorie(),            options: .cumulativeSum,   days: days)
        case "exerciseTime":    return await fetchDailyQuantity(.appleExerciseTime,         unit: .minute(),                 options: .cumulativeSum,   days: days)
        case "standTime":       return await fetchDailyQuantity(.appleStandTime,            unit: .minute(),                 options: .cumulativeSum,   days: days)
        case "vo2Max":          return await fetchDailyVO2Max(days: days)
        default:                return []
        }
    }

    private func fetchDailyQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        days: Int
    ) async -> [HealthDataPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: end,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else { continuation.resume(returning: []); return }
                var points: [HealthDataPoint] = []
                results.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    let val: Double?
                    if options.contains(.cumulativeSum) {
                        val = stat.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        val = stat.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let val, val > 0 {
                        points.append(HealthDataPoint(date: stat.startDate, value: val))
                    }
                }
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // Body fat and SpO2: stats collection returns 0-1 fraction; multiply by 100 for %
    private func fetchDailyBodyFat(days: Int) async -> [HealthDataPoint] {
        guard HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) != nil else { return [] }
        let raw = await fetchDailyQuantity(.bodyFatPercentage, unit: .percent(), options: .discreteAverage, days: days)
        return raw.map { HealthDataPoint(date: $0.date, value: $0.value * 100) }
    }

    private func fetchDailySpo2(days: Int) async -> [HealthDataPoint] {
        guard HKObjectType.quantityType(forIdentifier: .oxygenSaturation) != nil else { return [] }
        let raw = await fetchDailyQuantity(.oxygenSaturation, unit: .percent(), options: .discreteAverage, days: days)
        return raw.map { HealthDataPoint(date: $0.date, value: $0.value * 100) }
    }

    // Sparse metrics (scale data, VO2Max): scan all samples, group by start-of-day
    private func fetchDailySparseQuantity(_ identifier: HKQuantityTypeIdentifier,
                                          unit: HKUnit, days: Int) async -> [HealthDataPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let cal  = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                // Average multiple readings on the same day
                var byDay: [Date: [Double]] = [:]
                for s in samples {
                    let day = cal.startOfDay(for: s.startDate)
                    byDay[day, default: []].append(s.quantity.doubleValue(for: unit))
                }
                let points = byDay
                    .map { HealthDataPoint(date: $0.key, value: $0.value.reduce(0, +) / Double($0.value.count)) }
                    .sorted { $0.date < $1.date }
                continuation.resume(returning: points)
            }
            store.execute(q)
        }
    }

    // VO2Max updates infrequently — use a sample scan and carry last value forward per day
    private func fetchDailyVO2Max(days: Int) async -> [HealthDataPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return [] }
        let unit = HKUnit(from: "ml/kg·min")
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample] else { continuation.resume(returning: []); return }
                let points = samples.map {
                    HealthDataPoint(date: cal.startOfDay(for: $0.startDate), value: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: points)
            }
            store.execute(q)
        }
    }

    private func fetchDailySleepHistory(days: Int) async -> [HealthDataPoint] {
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { print("HealthKit sleep history error: \(error)"); continuation.resume(returning: []); return }
                guard let samples = samples as? [HKCategorySample] else { continuation.resume(returning: []); return }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                ]
                // Group intervals by wake-up day, then merge overlapping sources (Watch + iPhone)
                // before summing — same approach as fetchSleep() to avoid double-counting.
                var byDay: [Date: [(start: Date, end: Date)]] = [:]
                for sample in samples where asleepValues.contains(sample.value) {
                    let wakeDay = cal.startOfDay(for: sample.endDate)
                    byDay[wakeDay, default: []].append((sample.startDate, sample.endDate))
                }
                let points: [HealthDataPoint] = byDay.compactMap { day, intervals in
                    let sorted = intervals.sorted { $0.start < $1.start }
                    let merged = Self.mergeIntervals(sorted)
                    let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                    guard totalSeconds > 0 else { return nil }
                    return HealthDataPoint(date: day, value: totalSeconds / 3600)
                }.sorted { $0.date < $1.date }
                continuation.resume(returning: points)
            }
            store.execute(q)
        }
    }

    // MARK: - Helpers

    private static func mergeIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        var merged = [intervals[0]]
        for interval in intervals.dropFirst() {
            if interval.start <= merged[merged.count - 1].end {
                merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}
