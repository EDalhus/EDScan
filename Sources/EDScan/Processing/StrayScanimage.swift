import Foundation

/// Finds `scanimage` processes left behind (e.g. an eject that never finished, or one orphaned when
/// the app quit mid-command). While one holds the USB device every preview fails with no useful error.
enum StrayScanimage {
    struct Item {
        var pid: pid_t
        var elapsed: String     // ps etime, e.g. "33:35"
        var command: String

        /// "--eject (running 33:35)"
        var summary: String {
            let args = command.split(separator: " ").dropFirst().filter { !$0.hasPrefix("-d") && !$0.hasPrefix("coolscan3:") }
            return "scanimage \(args.joined(separator: " ")) — running \(elapsed)"
        }
    }

    static func find() -> [Item] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axo", "pid=,etime=,command="]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = pid_t(parts[0]),
                  let exe = parts[2].split(separator: " ").first, exe.hasSuffix("/scanimage") || exe == "scanimage"
            else { return nil }
            return Item(pid: pid, elapsed: String(parts[1]), command: String(parts[2]))
        }
    }

    static func stop(_ items: [Item]) {
        for item in items { kill(item.pid, SIGTERM) }
    }
}
