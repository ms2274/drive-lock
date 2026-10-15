import Foundation

/// Plain-text detection log on disk. Survives app suspension and relaunch, so a whole drive
/// (including background wake-ups the user never sees) can be read back and shared afterwards.
struct EventLogFile {
    let url: URL
    /// When the file grows past this, the oldest half is dropped.
    var maxBytes = 512 * 1024

    static let `default` = EventLogFile(url: FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("drivelock-events.log"))

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func line(_ text: String, at date: Date = Date()) -> String {
        "\(formatter.string(from: date))  \(text)"
    }

    func append(_ line: String) {
        let data = Data((line + "\n").utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            let size = (try? h.seekToEnd()) ?? 0
            try? h.write(contentsOf: data)
            if size > UInt64(maxBytes) { trim() }
        } else {
            // First write, or the file was cleared. Complete protection would block writes
            // while the phone is locked, which is exactly when background wakes happen.
            try? data.write(to: url, options: [.atomic, .noFileProtection])
        }
    }

    /// Newest last.
    func lines(last n: Int) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").suffix(n).map(String.init)
    }

    func clear() { try? FileManager.default.removeItem(at: url) }

    private func trim() {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n")
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n") + "\n"
        try? Data(kept.utf8).write(to: url, options: [.atomic, .noFileProtection])
    }
}
