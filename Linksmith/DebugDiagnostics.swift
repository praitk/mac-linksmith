import Foundation
import LinksmithCore

@MainActor
@Observable
final class DebugDiagnostics {
    private let store = DebugLogStore()
    private var timer: Timer?

    var entries: [DebugLogEntry] = []

    var buildDescription: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let timestamp = executableTimestamp.map(Self.timestampFormatter.string(from:)) ?? "unknown"
        return "Version \(version) (\(build)) - built \(timestamp)\n\(bundle.bundlePath)"
    }

    func start() {
        reload()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clear() {
        store.clear()
        reload()
    }

    func log(_ message: String) {
        store.append(message, process: "App")
        reload()
    }

    private func reload() {
        entries = store.entries()
    }

    private var executableTimestamp: Date? {
        guard let executableURL = Bundle.main.executableURL,
              let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return values.contentModificationDate
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
