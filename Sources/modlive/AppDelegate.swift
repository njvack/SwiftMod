import AppKit
import SwiftModCore
import SwiftModEngine

class AppDelegate: NSObject, NSApplicationDelegate {
    let module: Module
    let sequencer: LiveSequencer
    var window: NSWindow?

    init(module: Module, sequencer: LiveSequencer) {
        self.module = module
        self.sequencer = sequencer
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.window = window
        let title = module.title.isEmpty ? "modlive" : "modlive — \(module.title)"
        window.title = title
        let view = LivePlayView(module: module, sequencer: sequencer)
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view.keyboardAreaView)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
