import Foundation

/// Clears the current user's ATS (Apple Type Services) font cache via
/// `atsutil databases -removeUser` - the no-sudo, user-only path (`-remove`
/// needs root). The cache rebuilds itself from the fonts on disk next time
/// it's needed, so nothing is lost; a stale/corrupt cache is what shows up as
/// fonts not rendering or not appearing where expected. The rebuild only
/// takes effect after a log out or restart.
struct FontCacheCommand {
    /// Runs the command off the main thread. Delivers an error message on
    /// failure, nil on success, on the main queue.
    static func run(completion: @escaping @Sendable (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let message = removeUserDatabases()
            DispatchQueue.main.async { completion(message) }
        }
    }

    private static func removeUserDatabases() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/atsutil")
        process.arguments = ["databases", "-removeUser"]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            return "Could not run atsutil: \(error.localizedDescription)"
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (text?.isEmpty == false ? text : nil) ?? "atsutil exited with status \(process.terminationStatus)"
        }
        return nil
    }
}
