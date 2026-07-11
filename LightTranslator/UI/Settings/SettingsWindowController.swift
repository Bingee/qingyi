import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let viewModel: SettingsViewModel
    private var window: NSWindow?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func show(section: SettingsSection? = nil) {
        let window = window ?? makeWindow()
        self.window = window
        viewModel.load()
        if let section {
            viewModel.selectedSection = section
        }
        NSApp.activate(ignoringOtherApps: true)
        position(window)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(viewModel: viewModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "轻译设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        return window
    }

    private func position(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main

        guard let screen else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        window.setFrameOrigin(
            NSPoint(
                x: visibleFrame.midX - frame.width / 2,
                y: visibleFrame.maxY - visibleFrame.height * 0.10 - frame.height
            )
        )
    }
}
