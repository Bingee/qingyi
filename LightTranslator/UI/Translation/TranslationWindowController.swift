import AppKit
import SwiftUI

@MainActor
final class TranslationWindowController {
    private let viewModel: TranslationViewModel
    private var panel: TranslatorPanel?

    init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    func show(resetForHotkey: Bool = false) {
        let wasVisible = panel?.isVisible == true
        let panel = panel ?? makePanel()
        self.panel = panel

        if resetForHotkey {
            viewModel.prepareForHotkeyOpen()
        } else if !wasVisible {
            viewModel.prepareForOpen()
        }

        position(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> TranslatorPanel {
        let rootView = TranslationView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.panel?.orderOut(nil) },
            onPreferredSizeChange: { [weak self] size in
                self?.resizePanel(to: size)
            },
            onPinStateChange: { [weak self] isPinned in
                self?.applyPinState(isPinned)
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController.view.layer?.cornerRadius = 24
        hostingController.view.layer?.masksToBounds = true

        let panel = TranslatorPanel(
            contentRect: NSRect(x: 0, y: 0, width: 368, height: 284),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hostingController
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = 24
        panel.contentView?.layer?.masksToBounds = true
        applyPinState(viewModel.isPinned, to: panel)
        return panel
    }

    private func applyPinState(_ isPinned: Bool) {
        guard let panel else {
            return
        }

        applyPinState(isPinned, to: panel)
    }

    private func applyPinState(_ isPinned: Bool, to panel: NSPanel) {
        panel.level = isPinned ? .statusBar : .floating
        panel.hidesOnDeactivate = !isPinned
        panel.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        if isPinned, panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main

        guard let screen else {
            panel.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = panel.frame
        let origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.maxY - visibleFrame.height * 0.10 - frame.height
        )
        panel.setFrameOrigin(origin)
    }

    private func resizePanel(to size: CGSize) {
        guard let panel else {
            return
        }

        let oldFrame = panel.frame
        panel.setContentSize(NSSize(width: size.width, height: size.height))

        var newFrame = panel.frame
        newFrame.origin.x = oldFrame.midX - newFrame.width / 2
        newFrame.origin.y = oldFrame.maxY - newFrame.height
        panel.setFrame(newFrame, display: true, animate: panel.isVisible)
        panel.invalidateShadow()
    }
}

private final class TranslatorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
