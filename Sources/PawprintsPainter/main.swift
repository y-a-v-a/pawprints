import AppKit
import ImagePlayground
import MysteryKit

// Pawprints Painter: a faceless helper that paints the queued pictures for Pawprints and
// quits as soon as the queue has been empty for a moment. See PaintJob for why it exists.
//
// Image Playground only paints for a process with something visible on screen, so the helper
// shows a 2-point transparent panel that never takes focus or clicks.

@MainActor
final class Painter: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var creator: ImageCreator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard others.isEmpty else {
            NSApp.terminate(nil) // another painter is already on the queue
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 2, height: 2),
                            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.orderFrontRegardless()
        self.panel = panel
        Task { await work() }
    }

    private func work() async {
        var idleSince = Date()
        while Date().timeIntervalSince(idleSince) < 2.5 {
            guard let next = PaintJob.pending().first else {
                try? await Task.sleep(for: .milliseconds(250))
                continue
            }
            if let data = try? Data(contentsOf: next), let job = try? JSONDecoder().decode(PaintJob.self, from: data) {
                await paint(job)
            }
            try? FileManager.default.removeItem(at: next)
            idleSince = Date()
        }
        creator = nil
        NSApp.terminate(nil)
    }

    private func paint(_ job: PaintJob) async {
        let output = URL(fileURLWithPath: job.output)
        var lastError = "no prompt accepted"
        for prompt in job.prompts {
            do {
                if creator == nil { creator = try await ImageCreator() }
                for try await created in creator!.images(for: [.text(prompt)], style: .illustration, limit: 1) {
                    try ImageFiles.writeJPEG(created.cgImage, to: output, side: job.side)
                    return
                }
            } catch {
                lastError = "\(error)"
                if case ImageCreator.Error.notSupported = error { break }
                if case ImageCreator.Error.unavailable = error { break }
            }
        }
        try? lastError.write(to: PaintJob.failureMarker(for: output), atomically: true, encoding: .utf8)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let painter = Painter()
app.delegate = painter
app.run()
