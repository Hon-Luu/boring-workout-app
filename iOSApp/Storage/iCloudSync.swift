import Foundation

/// Lightweight iCloud Document sync.
///
/// Each persisted key is written as a separate JSON file inside the app's iCloud
/// Documents container (`iCloud.com.honluu.workout`).  When iCloud is unavailable
/// (simulator without iCloud, no Apple ID, airplane mode first launch) every call
/// is a silent no-op and the app falls back to UserDefaults transparently.
///
/// Conflict resolution: last-write-wins via file modification date.  This is correct
/// for a single-user workout app where the phone is always the authoritative writer.
///
/// Usage
/// ─────
/// Call `iCloudSync.shared.write(data, forKey:)` wherever UserDefaults is written.
/// Call `iCloudSync.shared.mergeOnLaunch(keys:into:)` once during SeedStore init
/// to pull any cloud data that is newer than local UserDefaults.
///
/// IMPORTANT: To activate iCloud sync you must also enable the iCloud capability in
/// Xcode → Signing & Capabilities → + Capability → iCloud → ✓ iCloud Documents,
/// then add the container "iCloud.com.honluu.workout".  The entitlements keys are
/// already present in workout.entitlements.

final class iCloudSync {

    static let shared = iCloudSync()
    private init() {}

    // MARK: - Container URL (background-safe, cached after first resolve)

    private var _containerURL: URL? = nil
    private let lock = NSLock()

    /// Returns the Documents sub-directory of the iCloud container, or nil when
    /// iCloud is not configured/available.  Must be called from a background thread
    /// on first access (FileManager may block while the container is located).
    var containerURL: URL? {
        lock.lock(); defer { lock.unlock() }
        if let cached = _containerURL { return cached }
        guard let base = FileManager.default
                .url(forUbiquityContainerIdentifier: "iCloud.com.honluu.workout") else {
            return nil
        }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        _containerURL = docs
        return docs
    }

    // MARK: - Write

    /// Writes `data` to iCloud Documents as `<key>.json`.
    /// Safe to call from any thread; uses NSFileCoordinator.
    func write(_ data: Data, forKey key: String) {
        guard let dir = containerURL else { return }
        let url = dir.appendingPathComponent("\(key).json")
        let coordinator = NSFileCoordinator()
        var err: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &err) { dest in
            try? data.write(to: dest, options: .atomic)
        }
    }

    // MARK: - Read

    /// Returns the raw Data stored in iCloud for `key`, or nil.
    func data(forKey key: String) -> Data? {
        guard let dir = containerURL else { return nil }
        let url = dir.appendingPathComponent("\(key).json")
        var result: Data?
        let coordinator = NSFileCoordinator()
        var err: NSError?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &err) { src in
            result = try? Data(contentsOf: src)
        }
        return result
    }

    // MARK: - Modification Date

    private func modDate(forKey key: String) -> Date? {
        guard let dir = containerURL else { return nil }
        let url = dir.appendingPathComponent("\(key).json")
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    // MARK: - Launch Merge

    /// For each key, checks whether the iCloud copy is newer than the local
    /// UserDefaults copy.  If so, writes the cloud data into UserDefaults so the
    /// rest of the app sees it transparently.
    ///
    /// Call once from a background thread during SeedStore init, before reading
    /// UserDefaults into memory.
    func mergeOnLaunch(keys: [String]) {
        guard containerURL != nil else { return }   // iCloud not available
        for key in keys {
            guard let cloudData = data(forKey: key) else { continue }

            // Compare modification dates: cloud wins when it's newer
            let localMod  = UserDefaults.standard.object(forKey: "\(key)__modDate") as? Date ?? .distantPast
            let cloudMod  = modDate(forKey: key) ?? .distantPast

            if cloudMod > localMod {
                UserDefaults.standard.set(cloudData, forKey: key)
                UserDefaults.standard.set(cloudMod, forKey: "\(key)__modDate")
            }
        }
    }

    // MARK: - Convenience: write + stamp local mod date

    /// Writes `data` to both UserDefaults (immediate) and iCloud Documents (async sync).
    /// Also stamps a `__modDate` key in UserDefaults so the next merge comparison works.
    func persist(_ data: Data, forKey key: String) {
        let now = Date()
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(now, forKey: "\(key)__modDate")
        // Fire-and-forget on a background queue — never blocks the caller
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.write(data, forKey: key)
        }
    }
}
