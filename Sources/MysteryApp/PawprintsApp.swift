import AppKit
import MysteryKit
import SwiftUI

@main
struct PawprintsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var game = GameModel()

    var body: some Scene {
        Window("Pawprints", id: "main") {
            RootView()
                .environment(game)
                .frame(minWidth: 1120, minHeight: 720)
                .onAppear { Launch.apply(to: game) }
        }
        .defaultSize(width: 1360, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Case") { game.newCase() }
                    .keyboardShortcut("n")
                Button("Back to Title") { game.backToTitle() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(game.phase == .title)
            }
            CommandMenu("Investigate") {
                Button("Name the Thief…") { game.showingAccusation = true }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(game.phase != .investigating)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Launch arguments, mostly for demos and screenshots:
///   --seed N        open case N straight away
///   --resume        continue the saved game
///   --autoplay      play the intended route by itself, slowly
///   --phase NAME    stop autoplay early: briefing, room, witness, confession, evidence, culprit
///   --appearance light|dark
///   --paint-all     paint every prompt in the content tables and log failures
@MainActor
enum Launch {
    static func apply(to game: GameModel) {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        switch value("--appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        if args.contains("--resume") {
            game.resume()
        } else if let seed = value("--seed").flatMap(UInt64.init) {
            game.newCase(seed: seed)
        }
        if let key = value("--paint"), let prompt = value("--prompt") {
            Task { _ = try? await Illustrator.shared(key: key, prompt: prompt, side: 1536) }
        }
        if args.contains("--paint-all") {
            Task { await PaintAll.run(file: value("--paint-all")?.hasPrefix("--") == false ? value("--paint-all") : nil) }
        }
        if args.contains("--autoplay") {
            Task { await Autoplay.run(game, until: value("--phase")) }
        }
        if game.phase == .title { game.paintTitleArt() }
    }
}
