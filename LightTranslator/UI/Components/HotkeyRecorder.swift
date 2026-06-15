import AppKit
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: HotkeyConfig

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.hotkey = hotkey
        view.onChange = { newHotkey in
            hotkey = newHotkey
        }
        return view
    }

    func updateNSView(_ view: HotkeyRecorderNSView, context: Context) {
        view.hotkey = hotkey
    }
}

final class HotkeyRecorderNSView: NSView {
    var hotkey = HotkeyConfig.default {
        didSet {
            needsDisplay = true
        }
    }
    var onChange: ((HotkeyConfig) -> Void)?
    private var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 180, height: 34) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            return
        }

        guard let newHotkey = HotkeyConfig(event: event) else {
            NSSound.beep()
            return
        }

        hotkey = newHotkey
        isRecording = false
        onChange?(newHotkey)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9)
        let fillColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.20)
            : NSColor.white.withAlphaComponent(0.16)
        fillColor.setFill()
        path.fill()

        let strokeColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.70)
            : NSColor.white.withAlphaComponent(0.34)
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "按下快捷键..." : hotkey.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedText.draw(in: textRect)
    }
}
