import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var draggedModelID: String?
    private let windowSize = CGSize(width: 920, height: 560)
    private let sidebarWidth: CGFloat = 170
    private let dividerWidth: CGFloat = 1

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar

                Divider()
                    .opacity(0.45)
                    .frame(width: dividerWidth)

                content
                    .frame(
                        width: windowSize.width - sidebarWidth - dividerWidth,
                        height: windowSize.height,
                        alignment: .topLeading
                    )
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("轻译")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 8)

            SidebarButton(
                title: "翻译模型",
                systemImage: "text.bubble",
                isSelected: viewModel.selectedSection == .models
            ) {
                viewModel.selectedSection = .models
            }

            SidebarButton(
                title: "设置",
                systemImage: "gearshape",
                isSelected: viewModel.selectedSection == .settings
            ) {
                viewModel.selectedSection = .settings
            }

            SidebarButton(
                title: "历史记录",
                systemImage: "clock.arrow.circlepath",
                isSelected: viewModel.selectedSection == .history
            ) {
                viewModel.selectedSection = .history
            }

            SidebarButton(
                title: "关于",
                systemImage: "info.circle",
                isSelected: viewModel.selectedSection == .about
            ) {
                viewModel.selectedSection = .about
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 16)
        .frame(width: sidebarWidth, height: windowSize.height)
        .background(.ultraThinMaterial.opacity(0.45))
    }

    private var content: some View {
        ZStack(alignment: .topLeading) {
            modelsContent
                .opacity(viewModel.selectedSection == .models ? 1 : 0)
                .allowsHitTesting(viewModel.selectedSection == .models)

            settingsContent
                .opacity(viewModel.selectedSection == .settings ? 1 : 0)
                .allowsHitTesting(viewModel.selectedSection == .settings)

            historyContent
                .opacity(viewModel.selectedSection == .history ? 1 : 0)
                .allowsHitTesting(viewModel.selectedSection == .history)

            aboutContent
                .opacity(viewModel.selectedSection == .about ? 1 : 0)
                .allowsHitTesting(viewModel.selectedSection == .about)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var modelsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("翻译模型")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 0) {
                    Text("打开多个模型后，翻译浮窗会按这里的顺序展示多个译文。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    ForEach(viewModel.availableModels) { model in
                        if model.id != viewModel.availableModels.first?.id {
                            Divider()
                                .opacity(0.55)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ModelToggleRow(
                                model: model,
                                isEnabled: modelToggleBinding(for: model),
                                dragProvider: {
                                    draggedModelID = model.id
                                    return NSItemProvider(object: model.id as NSString)
                                }
                            )

                            if viewModel.isModelEnabled(model),
                               model.id != TranslationModel.volcengineTranslateID {
                                customModelCredentialForm(for: model)
                            }
                        }
                        .padding(.vertical, 10)
                        .opacity(draggedModelID == model.id ? 0.55 : 1)
                        .onDrop(
                            of: [UTType.text],
                            delegate: ModelReorderDropDelegate(
                                destinationModelID: model.id,
                                draggedModelID: $draggedModelID,
                                viewModel: viewModel
                            )
                        )
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var settingsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("设置")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("全局快捷键")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HotkeyRecorder(hotkey: $viewModel.hotkey)
                            .frame(width: 190, height: 34)
                    }
                    .onChange(of: viewModel.hotkey) { _, _ in
                        viewModel.save()
                    }

                    Toggle("打开浮窗时读取剪贴板文本", isOn: $viewModel.readClipboardOnOpen)
                        .onChange(of: viewModel.readClipboardOnOpen) { _, _ in
                            viewModel.save()
                        }

                    Toggle("匿名使用统计", isOn: $viewModel.anonymousAnalyticsEnabled)
                        .onChange(of: viewModel.anonymousAnalyticsEnabled) { _, _ in
                            viewModel.save()
                        }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var historyContent: some View {
        HStack(spacing: 0) {
            historyList
                .frame(width: 250, height: windowSize.height)

            Divider()
                .opacity(0.45)

            historyDetail
                .frame(
                    width: windowSize.width - sidebarWidth - dividerWidth - 251,
                    height: windowSize.height,
                    alignment: .topLeading
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("历史记录")
                    .font(.title3.weight(.semibold))

                Text("\(viewModel.historyEntries.count) 项")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 22)
            .padding(.horizontal, 16)

            if viewModel.historyEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("暂无历史记录")
                        .font(.system(size: 14, weight: .semibold))

                    Text("完成翻译后，最近 100 条记录会保存在本地。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.historyEntries) { entry in
                            HistoryListRow(
                                entry: entry,
                                isSelected: viewModel.selectedHistoryEntry?.id == entry.id
                            ) {
                                viewModel.selectHistoryEntry(entry)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 18)
                }
            }
        }
        .background(.ultraThinMaterial.opacity(0.30))
    }

    @ViewBuilder
    private var historyDetail: some View {
        if let entry = viewModel.selectedHistoryEntry {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text(historyDateTitle(for: entry.createdAt))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            viewModel.deleteSelectedHistoryEntry()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(.regularMaterial.opacity(0.70))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("删除这条历史记录")
                    }

                    historySourceCard(entry)

                    HStack(spacing: 10) {
                        languagePill(entry.sourceLanguage.displayName)

                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)

                        languagePill(entry.targetLanguage.displayName)
                    }

                    ForEach(entry.results) { result in
                        historyResultCard(result)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("暂无历史记录")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func historySourceCard(_ entry: TranslationHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.sourceText)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 14)

            historyActions(
                copyKey: "source-\(entry.id.uuidString)",
                copyAction: { viewModel.copyHistorySource(entry) },
                speakAction: { viewModel.speakHistorySource(entry) }
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .glassCard(cornerRadius: 14)
    }

    private func historyResultCard(_ result: TranslationHistoryResult) -> some View {
        let isError = result.errorMessage != nil
        let text = result.errorMessage ?? result.translatedText

        return VStack(alignment: .leading, spacing: 14) {
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isError ? Color.red : Color.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 14)

            HStack(alignment: .center, spacing: 12) {
                historyActions(
                    copyKey: result.modelID,
                    copyAction: { viewModel.copyHistoryResult(result) },
                    speakAction: { viewModel.speakHistoryResult(result) }
                )

                Spacer()

                HStack(spacing: 8) {
                    Text("\(result.model.displayName) 翻译")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    ModelIconView(model: result.model, size: 22)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .glassCard(cornerRadius: 14)
    }

    private func historyActions(
        copyKey: String,
        copyAction: @escaping () -> Void,
        speakAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            historyActionButton(imageName: "SpeakerIcon", help: "朗读", action: speakAction)
            historyActionButton(imageName: "CopyIcon", help: "复制", action: copyAction)

            if !viewModel.historyCopyMessage(for: copyKey).isEmpty {
                Text(viewModel.historyCopyMessage(for: copyKey))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func historyActionButton(
        imageName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func languagePill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial.opacity(0.72))
            )
    }

    private func historyDateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        return formatter.string(from: date)
    }

    private func customModelCredentialForm(for model: TranslationModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsTextField(
                title: "API Key",
                isSecure: true,
                text: customModelAPIKeyBinding(for: model)
            )

            SettingsTextField(
                title: "Base URL",
                placeholder: model.defaultBaseURL ?? "https://api.openai.com/v1",
                text: customModelBaseURLBinding(for: model)
            )

            SettingsTextField(
                title: "Model ID",
                text: customModelProviderModelIDBinding(for: model)
            )

            HStack(spacing: 10) {
                Button {
                    Task {
                        await viewModel.saveCustomModelCredentials(for: model.id)
                    }
                } label: {
                    Label(
                        viewModel.customModelCredentialState(for: model.id) == .checking
                            ? "验证中..."
                            : "保存 API 信息",
                        systemImage: "key.fill"
                    )
                }
                .disabled(viewModel.customModelCredentialState(for: model.id) == .checking)

                Button {
                    viewModel.clearCustomModelCredentials(for: model.id)
                } label: {
                    Label("清除 Key", systemImage: "trash")
                }
                .disabled(viewModel.customModelCredentialState(for: model.id) == .checking)

                let message = viewModel.customModelCredentialMessage(for: model.id)
                if !message.isEmpty {
                    if viewModel.customModelCredentialState(for: model.id) == .checking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(customModelCredentialMessageColor(for: model.id))
                        .lineLimit(2)
                }
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modelToggleBinding(for model: TranslationModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.isModelEnabled(model) },
            set: { viewModel.setModel(model, isEnabled: $0) }
        )
    }

    private func customModelAPIKeyBinding(for model: TranslationModel) -> Binding<String> {
        Binding(
            get: { viewModel.customModelAPIKey(for: model.id) },
            set: { viewModel.setCustomModelAPIKey($0, for: model.id) }
        )
    }

    private func customModelBaseURLBinding(for model: TranslationModel) -> Binding<String> {
        Binding(
            get: { viewModel.customModelBaseURL(for: model.id) },
            set: { viewModel.setCustomModelBaseURL($0, for: model.id) }
        )
    }

    private func customModelProviderModelIDBinding(for model: TranslationModel) -> Binding<String> {
        Binding(
            get: { viewModel.customModelProviderModelID(for: model.id) },
            set: { viewModel.setCustomModelProviderModelID($0, for: model.id) }
        )
    }

    private func customModelCredentialMessageColor(for modelID: String) -> Color {
        switch viewModel.customModelCredentialState(for: modelID) {
        case .idle, .checking:
            return .secondary
        case .valid:
            return .green
        case .warning:
            return .orange
        case .invalid:
            return .red
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("关于")
                .font(.title2.weight(.semibold))

            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("轻译")
                    .font(.title2.weight(.semibold))

                Text("轻松翻译∙简单生活")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("版本")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1.0")
                        .font(.body.weight(.medium))
                }

                HStack {
                    Text("联系作者")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("lbq766@gmail.com")
                        .font(.body.weight(.medium))
                        .textSelection(.enabled)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}

private struct ModelToggleRow: View {
    let model: TranslationModel
    @Binding var isEnabled: Bool
    let dragProvider: () -> NSItemProvider

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 34)
                .contentShape(Rectangle())
                .onDrag(dragProvider)
                .help("拖动调整展示顺序")

            ModelIconView(model: model, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(model.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

private struct ModelReorderDropDelegate: DropDelegate {
    let destinationModelID: String
    @Binding var draggedModelID: String?
    let viewModel: SettingsViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedModelID else {
            return
        }

        viewModel.moveModel(sourceID: draggedModelID, before: destinationModelID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedModelID = nil
        return true
    }
}

private struct SettingsTextField: View {
    let title: String
    var placeholder = ""
    var isSecure = false
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            if isSecure {
                SecureField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

private struct ModelIconView: View {
    let model: TranslationModel
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName = model.assetName {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: model.systemImage)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HistoryListRow: View {
    let entry: TranslationHistoryEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.sourceText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.primaryResultText.isEmpty {
                    Text(entry.primaryResultText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .opacity(isSelected ? 0 : 0.55)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .frame(minHeight: 74, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum SettingsSection {
    case models
    case settings
    case history
    case about
}

private struct SidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
