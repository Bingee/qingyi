import AppKit

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpenTranslator: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        onOpenTranslator: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenTranslator = onOpenTranslator
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    func install() {
        if let button = statusItem.button {
            button.image = menuBarImage()
            button.image?.isTemplate = true
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "轻译"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开翻译窗口", action: #selector(openTranslator), keyEquivalent: "")
        openItem.image = menuItemImage("character.bubble.fill")
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = menuItemImage("gearshape")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.image = menuItemImage("power")
        menu.addItem(quitItem)

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func openTranslator() {
        onOpenTranslator()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }

    private func menuBarImage() -> NSImage? {
        NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "轻译")
            ?? NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "轻译")
    }

    private func menuItemImage(_ symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }
}
