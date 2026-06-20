# 轻译

轻译是一个 macOS 菜单栏 AI 翻译 App。当前 MVP 支持菜单栏常驻、全局快捷键唤起翻译浮窗、读取剪贴板、配置 OpenAI-compatible API、自动判断中英文方向并复制译文。

官方网站：https://bingee.github.io/qingyi/

## 开发环境

- macOS beta
- Xcode beta，目前验证环境为 Xcode 26.5
- Swift 6.3.2
- XcodeGen

确认环境：

```bash
xcode-select -p
xcodebuild -version
swift --version
```

## 生成工程

```bash
xcodegen generate
```

生成后可打开：

```bash
open LightTranslator.xcodeproj
```

## 构建

```bash
xcodebuild -project LightTranslator.xcodeproj \
  -scheme LightTranslator \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

构建产物：

```text
.build/DerivedData/Build/Products/Debug/轻译.app
```

## 使用

1. 启动 App 后只显示菜单栏图标。
2. 从菜单栏打开设置，填写 API Base URL、API Key、Model Name。
3. 复制一段文本，按全局快捷键打开浮窗，默认是 `Option + Space`。
4. 按 Enter 翻译，Shift + Enter 换行，Esc 关闭。
5. 翻译完成后点击复制按钮复制译文。

## 当前限制

- 快捷键可在设置页录制修改。
- 暂不支持 OCR、划词翻译、替换选中文本、历史记录和多服务管理。
- API Key 存储在 macOS Keychain，Base URL 和 Model 存储在 UserDefaults。
- 默认翻译服务会记录匿名使用统计，用于估算翻译 DAU、请求量和字符量；不上传原文、译文或 API Key，可在设置中关闭。
