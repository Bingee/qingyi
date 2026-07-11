import AppKit
import SwiftUI
import Translation

struct TranslationView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: TranslationViewModel
    let onClose: () -> Void
    var onPreferredSizeChange: (CGSize) -> Void = { _ in }
    var onPinStateChange: (Bool) -> Void = { _ in }
    @State private var inputHasVisibleContent = false
    @State private var isResultCollapsed = false
    @State private var collapsedModelIDs: Set<String> = []
    @State private var idleResultIsHovered = false

    private let panelWidth: CGFloat = 368
    private let collapsedHeight: CGFloat = 256
    private let minExpandedTranslationBlockHeight: CGFloat = 98
    private let maxExpandedTranslationBlockHeight: CGFloat = 460
    private let maxResultCardHeight: CGFloat = 190
    private let resultCardTopPadding: CGFloat = 12
    private let resultCardBottomPadding: CGFloat = 10

    var body: some View {
        if #available(macOS 15.0, *) {
            translationContent
                .modifier(AppleLocalTranslationTaskModifier(viewModel: viewModel))
        } else {
            translationContent
        }
    }

    private var translationContent: some View {
        VStack(spacing: 12) {
            inputBlock
            languageBar
            translationBlock
        }
        .padding(16)
        .frame(width: panelWidth, height: preferredSize.height)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            onPreferredSizeChange(preferredSize)
            onPinStateChange(viewModel.isPinned)
        }
        .onChange(of: hasExpandedOutput) { _, _ in
            onPreferredSizeChange(preferredSize)
        }
        .onChange(of: viewModel.translationResults) { _, _ in
            if hasResultOutput {
                isResultCollapsed = false
                collapsedModelIDs = []
            }
            onPreferredSizeChange(preferredSize)
        }
        .onChange(of: viewModel.sourceText) { _, _ in
            isResultCollapsed = false
            collapsedModelIDs = []
            viewModel.markEditing()
        }
        .onChange(of: viewModel.isPinned) { _, isPinned in
            onPinStateChange(isPinned)
        }
    }

    private var inputBlock: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(blockColor)

            TextInputView(
                text: $viewModel.sourceText,
                hasVisibleContent: $inputHasVisibleContent,
                onSubmit: viewModel.translate,
                onPaste: viewModel.translate,
                onCancel: onClose,
                fontSize: 16,
                textColor: inputTextColor,
                insertionPointColor: showsEmptyPlaceholder ? .clear : .systemBlue
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if showsEmptyPlaceholder {
                HStack(alignment: .center, spacing: 4) {
                    BlinkingInsertionCursor()

                    Text("请粘贴要翻译的文字")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(placeholderColor)
                }
                .padding(.leading, 12)
                .padding(.top, 10)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 112)
    }

    private var showsEmptyPlaceholder: Bool {
        viewModel.sourceText.isEmpty && !inputHasVisibleContent
    }

    private var languageBar: some View {
        HStack(spacing: 0) {
            LanguageMenu(
                title: sourceLanguageTitle,
                selection: $viewModel.sourceLanguage,
                tint: primaryTextColor
            )
            .frame(maxWidth: .infinity)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("互换语言")
            .frame(maxWidth: .infinity)

            LanguageMenu(
                title: targetLanguageTitle,
                selection: $viewModel.targetLanguage,
                tint: primaryTextColor
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(blockColor)
        )
    }

    private var translationBlock: some View {
        Group {
            if hasExpandedOutput {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(visibleResultModels) { model in
                            resultCard(for: model)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(height: translationBlockHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity)
            } else {
                idleTranslationCard
            }
        }
    }

    private var idleTranslationCard: some View {
        let showsQuickActions = idleResultIsHovered

        return HStack(spacing: 8) {
            modelIcon(for: viewModel.selectedModel, size: 18)

            Text("\(viewModel.selectedModel.displayName) 翻译")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(primaryTextColor)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    viewModel.togglePinned()
                } label: {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPinned ? "取消置顶" : "置顶浮窗")

                Button {
                    viewModel.openHistorySettings()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("查看历史记录")
            }
            .opacity(showsQuickActions ? 1 : 0)
            .allowsHitTesting(showsQuickActions)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryTextColor)
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(blockColor)
        )
        .onHover { isHovered in
            idleResultIsHovered = isHovered
        }
    }

    private func resultCard(for model: TranslationModel) -> some View {
        let isCollapsed = collapsedModelIDs.contains(model.id)
        let text = resultText(for: model)
        let result = result(for: model)
        let isError = result?.errorMessage != nil || (translationResultsAreEmpty && statusFailureMessage != nil)
        let textViewportHeight = resultTextViewportHeight(for: model)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                modelIcon(for: model, size: 20)

                Text("\(model.displayName) 翻译")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.status.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.72)
                }

                Button {
                    viewModel.togglePinned()
                } label: {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPinned ? "取消置顶" : "置顶浮窗")

                Button {
                    viewModel.openHistorySettings()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("查看历史记录")

                Button {
                    toggleResultCard(modelID: model.id)
                } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "展开结果" : "收起结果")
            }
            .frame(height: 22)

            if !isCollapsed {
                resultTextViewport(
                    text: text,
                    isError: isError,
                    height: textViewportHeight,
                    showsScrollIndicator: measuredResultTextHeight(for: model) > textViewportHeight + 1
                )

                resultActions(modelID: model.id, canUseResult: result?.errorMessage == nil && result?.hasText == true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, resultCardTopPadding)
        .padding(.bottom, resultCardBottomPadding)
        .frame(height: resultCardHeight(for: model), alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(blockColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func resultTextViewport(
        text: String,
        isError: Bool,
        height: CGFloat,
        showsScrollIndicator: Bool
    ) -> some View {
        ScrollView(.vertical, showsIndicators: showsScrollIndicator) {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isError ? Color.red : primaryTextColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func resultActions(modelID: String, canUseResult: Bool) -> some View {
        HStack(spacing: 8) {
            resultActionButton(
                imageName: "SpeakerIcon",
                help: "朗读",
                isDisabled: !canUseResult
            ) {
                viewModel.speakResult(modelID: modelID)
            }

            resultActionButton(
                imageName: "CopyIcon",
                help: "复制译文",
                isDisabled: !canUseResult
            ) {
                viewModel.copyResult(modelID: modelID)
            }

            if !viewModel.copyMessage(for: modelID).isEmpty {
                Text(viewModel.copyMessage(for: modelID))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .frame(height: 16)
    }

    private func resultActionButton(
        imageName: String,
        help: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(primaryTextColor)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
    }

    private func modelIcon(for model: TranslationModel, size: CGFloat) -> some View {
        Group {
            if let assetName = model.assetName {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: model.systemImage)
                    .font(.system(size: size * 0.76, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func resultText(for model: TranslationModel) -> String {
        if let result = result(for: model) {
            return result.errorMessage ?? result.translatedText
        }

        switch viewModel.status {
        case .idle, .editing:
            return ""
        case .translating:
            return "正在翻译..."
        case .success:
            return "翻译服务未返回结果。"
        case .failed(let message):
            return message
        }
    }

    private func result(for model: TranslationModel) -> ModelTranslationResult? {
        viewModel.translationResults.first { $0.modelID == model.id }
    }

    private var visibleResultModels: [TranslationModel] {
        if viewModel.status.isTranslating, !viewModel.enabledModels.isEmpty {
            return viewModel.enabledModels
        }

        if !viewModel.translationResults.isEmpty {
            return viewModel.translationResults.map(\.model)
        }

        if !viewModel.enabledModels.isEmpty {
            return viewModel.enabledModels
        }

        return [viewModel.selectedModel]
    }

    private var translationResultsAreEmpty: Bool {
        viewModel.translationResults.isEmpty
    }

    private var statusFailureMessage: String? {
        if case .failed(let message) = viewModel.status {
            return message
        }
        return nil
    }

    private func toggleResultCard(modelID: String) {
        if collapsedModelIDs.contains(modelID) {
            collapsedModelIDs.remove(modelID)
        } else {
            collapsedModelIDs.insert(modelID)
        }
    }

    private var sourceLanguageTitle: String {
        viewModel.sourceLanguage == .auto ? "自动检测" : viewModel.sourceLanguage.displayName
    }

    private var targetLanguageTitle: String {
        viewModel.targetLanguage == .auto ? "自动选择" : viewModel.targetLanguage.displayName
    }

    private var hasResultOutput: Bool {
        switch viewModel.status {
        case .translating, .success, .failed:
            return true
        case .idle, .editing:
            return false
        }
    }

    private var hasExpandedOutput: Bool {
        hasResultOutput && !isResultCollapsed
    }

    private var preferredSize: CGSize {
        let expandedHeight = collapsedHeight - 44 + translationBlockHeight
        return CGSize(width: panelWidth, height: hasExpandedOutput ? expandedHeight : collapsedHeight)
    }

    private var translationBlockHeight: CGFloat {
        guard hasExpandedOutput else {
            return 44
        }

        let totalHeight = visibleResultModels
            .map { resultCardHeight(for: $0) }
            .reduce(0, +) + CGFloat(max(0, visibleResultModels.count - 1)) * 10
        return min(max(totalHeight, minExpandedTranslationBlockHeight), maxExpandedTranslationBlockHeight)
    }

    private func resultCardHeight(for model: TranslationModel) -> CGFloat {
        guard !collapsedModelIDs.contains(model.id) else {
            return 46
        }

        let totalHeight = resultCardTopPadding + 22 + 8 + resultTextViewportHeight(for: model) + 8 + 16 + resultCardBottomPadding
        return min(max(totalHeight, minExpandedTranslationBlockHeight), maxResultCardHeight)
    }

    private func resultTextViewportHeight(for model: TranslationModel) -> CGFloat {
        let maxTextHeight = maxResultCardHeight - resultCardTopPadding - 22 - 8 - 8 - 16 - resultCardBottomPadding
        return min(measuredResultTextHeight(for: model), maxTextHeight)
    }

    private func measuredResultTextHeight(for model: TranslationModel) -> CGFloat {
        let text = resultText(for: model).isEmpty ? " " : resultText(for: model)
        let availableWidth = panelWidth - 32 - 32 - 32
        let font = NSFont.systemFont(ofSize: 16, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let rect = (text as NSString).boundingRect(
            with: NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )

        return max(22, ceil(rect.height))
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 24 / 255, green: 24 / 255, blue: 26 / 255).opacity(0.96)
            : Color.white.opacity(0.96)
    }

    private var blockColor: Color {
        colorScheme == .dark
            ? Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
            : Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255)
            : Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255)
    }

    private var placeholderColor: Color {
        colorScheme == .dark
            ? Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
            : Color(red: 189 / 255, green: 189 / 255, blue: 189 / 255)
    }

    private var inputTextColor: NSColor {
        colorScheme == .dark
            ? NSColor(calibratedRed: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 1)
            : NSColor(calibratedRed: 51 / 255, green: 51 / 255, blue: 51 / 255, alpha: 1)
    }

}

/// `translationTask` is intentionally owned by the SwiftUI view. Apple tracks
/// configuration changes through view state; keeping it in the view model can
/// leave a new request without a running TranslationSession.
@available(macOS 15.0, *)
private struct AppleLocalTranslationTaskModifier: ViewModifier {
    @ObservedObject var viewModel: TranslationViewModel
    @State private var configuration: TranslationSession.Configuration?
    @State private var activeRequest: AppleLocalTranslationRequest?

    func body(content: Content) -> some View {
        content
            .onAppear {
                updateConfiguration(for: viewModel.appleTranslationRequest)
            }
            .onChange(of: viewModel.appleTranslationRequest) { _, request in
                updateConfiguration(for: request)
            }
            .translationTask(configuration) { session in
                guard let activeRequest else {
                    return
                }
                await viewModel.translateWithAppleLocal(session, request: activeRequest)
            }
    }

    private func updateConfiguration(for request: AppleLocalTranslationRequest?) {
        activeRequest = request

        guard let request else {
            configuration = nil
            return
        }

        // A fresh configuration is deliberate: it retriggers translation even
        // when the source and target languages are unchanged but the text differs.
        configuration = TranslationSession.Configuration(
            source: request.sourceLanguageIdentifier.map(Locale.Language.init(identifier:)),
            target: request.targetLanguageIdentifier.map(Locale.Language.init(identifier:))
        )
    }
}

private struct BlinkingInsertionCursor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color(nsColor: .systemBlue))
            .frame(width: 2, height: 20)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                guard !reduceMotion else {
                    isVisible = true
                    return
                }

                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    isVisible = true
                }
            }
    }
}

private struct LanguageMenu: View {
    let title: String
    @Binding var selection: LanguageOption
    let tint: Color
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Image(systemName: isPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 88, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(LanguageOption.allCases) { language in
                    Button {
                        selection = language
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(tint)

                            Spacer(minLength: 12)

                            if selection == language {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(tint)
                            }
                        }
                        .frame(width: 112, height: 28)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
}
