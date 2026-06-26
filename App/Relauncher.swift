import AppKit

enum Relauncher {
    /// Relaunch the app: spawn a detached shell that waits for THIS process to
    /// exit, then re-opens the bundle (so the new instance starts fully trusted
    /// and there's no two-instance global-hotkey conflict). Then terminate.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
