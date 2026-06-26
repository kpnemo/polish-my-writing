import AppKit

enum Relauncher {
    /// Relaunch the app: spawn a detached shell that waits for THIS process to
    /// exit, then re-opens the bundle (so the new instance starts fully trusted
    /// and there's no two-instance global-hotkey conflict). Then terminate.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        NSLog("Relauncher: relaunch() called for pid \(pid), path \(path)")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open -n \"\(path)\""]
        do {
            try task.run()
            NSLog("Relauncher: helper spawned OK")
        } catch {
            NSLog("Relauncher: helper spawn FAILED: \(error); falling back to NSWorkspace")
            let url = Bundle.main.bundleURL
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: nil)
        }
        NSApp.terminate(nil)
    }
}
