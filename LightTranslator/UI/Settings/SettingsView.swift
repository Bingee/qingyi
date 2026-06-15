import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsSection = .settings
    private let windowSize = CGSize(width: 680, height: 480)
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
                title: "设置",
                systemImage: "gearshape",
                isSelected: selectedSection == .settings
            ) {
                selectedSection = .settings
            }

            SidebarButton(
                title: "关于",
                systemImage: "info.circle",
                isSelected: selectedSection == .about
            ) {
                selectedSection = .about
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
            settingsContent
                .opacity(selectedSection == .settings ? 1 : 0)
                .allowsHitTesting(selectedSection == .settings)

            aboutContent
                .opacity(selectedSection == .about ? 1 : 0)
                .allowsHitTesting(selectedSection == .about)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("翻译模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.availableModels) { model in
                        ModelSelectionRow(
                            model: model,
                            isSelected: viewModel.isModelSelected(model)
                        ) {
                            viewModel.selectModel(model)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

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
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct ModelSelectionRow: View {
    let model: TranslationModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ModelIconView(model: model, size: 40)

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

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

private enum SettingsSection {
    case settings
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
