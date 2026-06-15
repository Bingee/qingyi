import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsSection = .settings

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar

                Divider()
                    .opacity(0.45)

                content
            }
        }
        .frame(width: 680, height: 460)
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
        .frame(width: 150)
        .padding(.horizontal, 10)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial.opacity(0.45))
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .settings:
            settingsContent
        case .about:
            aboutContent
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                labeledField("API Base URL") {
                    TextField("https://api.openai.com", text: $viewModel.baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("API Key") {
                    SecureField("sk-...", text: $viewModel.apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("Model Name") {
                    TextField("gpt-4.1-mini", text: $viewModel.modelName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("全局快捷键")
                        .foregroundStyle(.secondary)
                    Spacer()
                    HotkeyRecorder(hotkey: $viewModel.hotkey)
                        .frame(width: 190, height: 34)
                }

                Toggle("打开浮窗时读取剪贴板文本", isOn: $viewModel.readClipboardOnOpen)
            }
            .padding(18)
            .glassCard()

            Spacer()

            HStack {
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else if !viewModel.message.isEmpty {
                    Text(viewModel.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("保存") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("关于")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("版本")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1.0")
                        .font(.body.weight(.medium))
                }
            }
            .padding(18)
            .glassCard()

            Spacer()
        }
        .padding(24)
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
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
