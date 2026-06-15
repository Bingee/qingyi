import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = AppSettingsStore()
    private lazy var clipboardManager = ClipboardManager()
    private lazy var translationService = TranslationService(
        settingsStore: settingsStore
    )
    private lazy var translationWindowController = TranslationWindowController(
        viewModel: TranslationViewModel(
            settingsStore: settingsStore,
            clipboardManager: clipboardManager,
            languageDetector: LanguageDetector(),
            translationService: translationService
        )
    )
    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: SettingsViewModel(
            settingsStore: settingsStore
        )
    )
    private lazy var menuBarController = MenuBarController(
        onOpenTranslator: { [weak self] in self?.showTranslator() },
        onOpenSettings: { [weak self] in self?.showSettings() },
        onQuit: { NSApp.terminate(nil) }
    )
    private lazy var hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore) { [weak self] in
        self?.showTranslator()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController.install()
        hotkeyManager.registerConfiguredHotkey()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsDidChange),
            name: .hotkeySettingsDidChange,
            object: nil
        )

        if ProcessInfo.processInfo.arguments.contains("--show-translator") {
            DispatchQueue.main.async { [weak self] in
                self?.showTranslator()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        hotkeyManager.unregister()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    private func showTranslator() {
        translationWindowController.show()
    }

    private func showSettings() {
        translationWindowController.hide()
        settingsWindowController.show()
    }

    @objc private func hotkeySettingsDidChange() {
        hotkeyManager.registerConfiguredHotkey()
    }
}
