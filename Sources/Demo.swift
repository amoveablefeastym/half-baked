import AppKit

/// Demo mode for scripted recordings: `HalfBaked --demo <dir>`.
/// Ideas live in <dir>/items.json and settings in a throwaway defaults suite,
/// so a recording never reads or writes your real ideas or window layout.
enum Demo {
    static let dataDir: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo") else { return nil }
        let path = i + 1 < args.count ? args[i + 1] : NSTemporaryDirectory() + "half-baked-demo"
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var on: Bool { dataDir != nil }

    /// Fixed panel size so recordings are framed the same every time.
    static let size = NSSize(width: 1280, height: 800)

    static let defaults: UserDefaults = {
        guard on else { return .standard }
        let suite = "local.halfbaked.demo"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        d.set(true, forKey: "pinned") // stay open while the recorder drives it
        return d
    }()
}
