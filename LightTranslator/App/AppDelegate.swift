import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = AppSettingsStore()
    private let keychainStore = KeychainStore()
    private let historyStore = TranslationHistoryStore()
    private lazy var clipboardManager = ClipboardManager()
    private lazy var translationService = TranslationService(
        settingsStore: settingsStore,
        keychainStore: keychainStore
    )
    private lazy var translationWindowController = TranslationWindowController(
        viewModel: TranslationViewModel(
            settingsStore: settingsStore,
            clipboardManager: clipboardManager,
            languageDetector: LanguageDetector(),
            translationService: translationService,
            historyStore: historyStore
        )
    )
    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: SettingsViewModel(
            settingsStore: settingsStore,
            keychainStore: keychainStore,
            clipboardManager: clipboardManager,
            historyStore: historyStore
        )
    )
    private lazy var menuBarController = MenuBarController(
        onOpenTranslator: { [weak self] in self?.showTranslator() },
        onOpenSettings: { [weak self] in self?.showSettings() },
        onQuit: { NSApp.terminate(nil) }
    )
    private lazy var hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore) { [weak self] in
        self?.showTranslator(fromHotkey: true)
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openHistorySettings),
            name: .openHistorySettings,
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

    private func showTranslator(fromHotkey: Bool = false) {
        translationWindowController.show(resetForHotkey: fromHotkey)
    }

    private func showSettings() {
        translationWindowController.hide()
        settingsWindowController.show()
    }

    private func showHistorySettings() {
        translationWindowController.hide()
        settingsWindowController.show(section: .history)
    }

    @objc private func hotkeySettingsDidChange() {
        hotkeyManager.registerConfiguredHotkey()
    }

    @objc private func openHistorySettings() {
        showHistorySettings()
    }
}
