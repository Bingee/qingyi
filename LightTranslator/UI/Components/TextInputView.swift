import AppKit
import SwiftUI

struct TextInputView: NSViewRepresentable {
    @Binding var text: String
    @Binding var hasVisibleContent: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var fontSize: CGFloat = 15
    var textColor: NSColor = .labelColor
    var insertionPointColor: NSColor? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? KeyHandlingTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = textColor
        textView.insertionPointColor = insertionPointColor ?? textColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onVisibleContentChange = context.coordinator.updateVisibleContent
        textView.string = text

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            context.coordinator.updateVisibleContent(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? KeyHandlingTextView else {
            return
        }

        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onVisibleContentChange = context.coordinator.updateVisibleContent
        textView.font = .systemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = textColor
        textView.insertionPointColor = insertionPointColor ?? textColor

        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
        }

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            context.coordinator.updateVisibleContent(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: TextInputView

        init(_ parent: TextInputView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string
            updateVisibleContent(textView)
        }

        @MainActor
        func updateVisibleContent(_ textView: NSTextView) {
            let hasContent = !textView.string.isEmpty || textView.hasMarkedText()
            if parent.hasVisibleContent != hasContent {
                parent.hasVisibleContent = hasContent
            }
        }
    }
}

private final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onVisibleContentChange: ((KeyHandlingTextView) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if (event.keyCode == 36 || event.keyCode == 76),
           !event.modifierFlags.contains(.shift) {
            if hasMarkedText() {
                super.keyDown(with: event)
                onVisibleContentChange?(self)
                return
            }

            onSubmit?()
            return
        }

        super.keyDown(with: event)
        onVisibleContentChange?(self)
    }

    override func setMarkedText(
        _ string: Any,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        onVisibleContentChange?(self)
    }

    override func unmarkText() {
        super.unmarkText()
        onVisibleContentChange?(self)
    }

}

private extension NSTextView {
    static func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = KeyHandlingTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.drawsBackground = false

        scrollView.documentView = textView
        return scrollView
    }
}
