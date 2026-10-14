import Foundation

/// Times the shield screen was shown. The shield extension appends, the app counts them at drive end.
/// A "pickup" is one attempt to open a shielded app, so the count is approximate by design.
/// Stored as a plain file in the App Group: unlike UserDefaults, the write lands before the extension is killed.
enum ShieldAttemptLog {
    private static let fileName = "shield-attempts.log"
    private static let maxEntries = 500
    /// The system may ask for a shield's look more than once per display; merge calls this close together.
    static let dedupeWindow: TimeInterval = 3

    static var defaultDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
    }

    static func record(at date: Date = Date(), directory: URL? = defaultDirectory) {
        guard let dir = directory else { note("no app group container", nil); return }
        let url = dir.appendingPathComponent(fileName)
        var times = read(url)
        let t = date.timeIntervalSince1970
        if let last = times.last, t - last < dedupeWindow { return }
        times.append(t)
        if times.count > maxEntries { times.removeFirst(times.count - maxEntries) }
        let data = Data(times.map { String($0) }.joined(separator: "\n").utf8)
        do { try data.write(to: url) }                    // direct write, no temp-file rename
        catch { note("write failed: \(error)", dir) }
    }

    /// Leaves a readable breadcrumb when logging fails, so a silent failure can be diagnosed.
    private static func note(_ text: String, _ dir: URL?) {
        guard let dir else { return }
        try? Data(text.utf8).write(to: dir.appendingPathComponent("shield-attempts.error.txt"))
    }

    static func count(from start: Date, to end: Date, directory: URL? = defaultDirectory) -> Int {
        guard let url = directory?.appendingPathComponent(fileName) else { return 0 }
        let s = start.timeIntervalSince1970, e = end.timeIntervalSince1970
        return read(url).filter { $0 >= s && $0 <= e }.count
    }

    private static func read(_ url: URL) -> [Double] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { Double($0) }
    }
}
