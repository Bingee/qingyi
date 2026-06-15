# macOS 菜单栏 AI 翻译 App MVP 需求文档

## 1. 定位

### 产品是什么

这是一个运行在 macOS 菜单栏的轻量 AI 翻译 App。

它的核心形态是：

- App 常驻菜单栏
- 通过全局快捷键唤起翻译浮窗
- 用户输入、粘贴或读取剪贴板文本
- 自动判断中英文方向
- 调用 OpenAI-compatible API 完成翻译
- 用户一键复制译文

可以理解为一个简洁版 Bob，但只保留个人高频使用的最小翻译闭环。

### 用户是谁

目标用户是：

- macOS 用户
- 经常需要中英文互译的人
- 已经拥有 AI 大模型 API Key 的用户
- 偏好快捷键、菜单栏、小工具式工作流的用户
- 主要用于个人自用，不面向公开商业分发

典型用户包括：

- 程序员
- 产品经理
- 设计师
- 研究人员
- 写作者
- 需要阅读英文资料或将中文表达翻译成英文的人

### 解决什么问题

解决用户在日常工作中快速翻译文本的问题。

当前常见痛点：

- 打开网页翻译工具成本高
- 复制文本后还要切换应用
- 通用翻译软件功能太重
- 希望使用自己的 AI API，而不是固定翻译服务
- 希望翻译窗口足够轻，不干扰当前工作流

MVP 重点解决：

> 用户在任何 macOS 应用中复制或输入一段文本后，可以通过快捷键快速唤起浮窗，完成 AI 翻译，并复制结果。

### 不是什么

本产品不是：

- 完整版 Bob 替代品
- OCR 截图翻译工具
- 划词翻译工具
- 多翻译服务聚合工具
- 翻译历史管理工具
- 插件平台
- 面向 App Store 发布的正式商业产品
- 团队协作型翻译产品

## 2. 边界

### 基于什么

MVP 基于以下能力实现：

- macOS 原生菜单栏 App
- 全局快捷键监听
- 轻量浮窗 UI
- macOS 剪贴板读取与写入
- OpenAI-compatible Chat Completions API
- macOS Keychain 存储 API Key
- 本地 UserDefaults 或配置文件存储非敏感设置

推荐技术基础：

- Swift / SwiftUI
- AppKit 辅助实现菜单栏、窗口行为、快捷键
- Keychain Services 存储 API Key
- URLSession 调用 API
- UserDefaults 存储 Base URL、Model、语言偏好等非敏感配置

### 不做什么

MVP 暂不包含：

- 截图 OCR
- 划词自动取词
- 替换当前 App 中的选中文本
- 插件系统
- 多翻译服务
- 多模型 Provider 管理
- 历史记录
- 收藏夹
- 登录系统
- 云同步
- App Store 发布适配
- 自动更新
- DMG 自动打包流程
- 完整异常日志系统
- 多语言 UI
- 复杂快捷键自定义 UI

### 当前版本到哪里为止

当前 MVP 版本只做到：

1. App 能启动并常驻菜单栏
2. 菜单中可以打开翻译窗口、设置窗口、退出 App
3. 可以通过固定快捷键 `Option + Space` 唤起翻译窗口
4. 翻译窗口打开时自动读取剪贴板文本
5. 用户可以输入或编辑原文
6. 用户按 `Enter` 触发翻译
7. App 自动判断中英文方向
8. App 调用用户配置的 OpenAI-compatible API 获取译文
9. 用户可以复制译文
10. API Key 安全存储在 macOS Keychain
11. Base URL 和 Model 可在设置页保存

## 3. 模块

### 3.1 MenuBar 模块

**模块名**

MenuBarController

**职责**

- 创建菜单栏图标
- 管理菜单项
- 响应菜单操作
- 控制 App 是否显示 Dock 图标
- 提供打开翻译窗口、打开设置、退出入口

**主要状态**

- 菜单栏是否已初始化
- 翻译窗口是否已存在
- 设置窗口是否已存在

**和谁协作**

- TranslationWindowController
- SettingsWindowController
- AppLifecycleManager

### 3.2 快捷键模块

**模块名**

GlobalHotkeyManager

**职责**

- 注册全局快捷键
- 监听快捷键触发事件
- 触发翻译窗口显示
- 处理快捷键注册失败的情况

**主要状态**

- 当前快捷键配置
- 快捷键是否注册成功
- 快捷键是否被系统或其他 App 占用

**和谁协作**

- TranslationWindowController
- AppSettingsStore

### 3.3 翻译浮窗模块

**模块名**

TranslationWindowController / TranslationViewModel

**职责**

- 管理翻译浮窗的展示、隐藏、置顶
- 读取剪贴板文本
- 管理原文输入
- 管理译文展示
- 响应 Enter 翻译
- 响应 Escape 关闭
- 响应复制译文
- 展示翻译状态和错误信息

**主要状态**

- `sourceText`：原文
- `translatedText`：译文
- `sourceLanguage`：源语言，默认 `auto`
- `targetLanguage`：目标语言，默认 `auto`
- `detectedDirection`：自动识别的翻译方向
- `isTranslating`：是否正在翻译
- `errorMessage`：错误信息
- `hasCopied`：是否已复制成功

**和谁协作**

- ClipboardManager
- LanguageDetector
- TranslationService
- AppSettingsStore

### 3.4 语言判断模块

**模块名**

LanguageDetector

**职责**

- 根据输入文本判断主要语言
- 决定默认目标语言
- 支持用户手动选择源语言和目标语言

**主要状态**

- `sourceText`
- `detectedSourceLanguage`
- `inferredTargetLanguage`

**和谁协作**

- TranslationViewModel

**初版判断规则**

- 如果中文字符占比较高，认为主要语言是中文，目标语言为英文
- 如果英文字符占比较高，认为主要语言是英文，目标语言为简体中文
- 如果文本为空，不触发翻译
- 如果无法判断，默认翻译成简体中文

### 3.5 AI 翻译模块

**模块名**

TranslationService

**职责**

- 构造 OpenAI-compatible API 请求
- 调用 `/v1/chat/completions`
- 解析模型返回结果
- 处理网络错误、鉴权错误、模型错误、响应格式错误
- 返回干净译文

**主要状态**

- `baseURL`
- `apiKey`
- `model`
- `requestStatus`
- `lastError`

**和谁协作**

- SettingsStore
- KeychainStore
- TranslationViewModel

**API 调用方式**

请求地址：

```text
{API Base URL}/v1/chat/completions
```

请求方法：

```text
POST
```

请求头：

```text
Authorization: Bearer {API Key}
Content-Type: application/json
```

核心请求体：

```json
{
  "model": "user-configured-model",
  "messages": [
    {
      "role": "system",
      "content": "You are a professional translation engine. Only return the translated text."
    },
    {
      "role": "user",
      "content": "Translate the following text into Simplified Chinese or English according to the target language..."
    }
  ],
  "temperature": 0.2
}
```

### 3.6 设置模块

**模块名**

SettingsWindowController / SettingsViewModel

**职责**

- 提供 API Base URL 输入
- 提供 API Key 输入
- 提供 Model Name 输入
- 保存设置
- 从 Keychain 读取 API Key
- 校验基础配置是否完整
- 可选：提供测试连接能力，后置实现

**主要状态**

- `baseURL`
- `apiKey`
- `modelName`
- `saveStatus`
- `validationError`

**和谁协作**

- AppSettingsStore
- KeychainStore
- TranslationService

### 3.7 配置存储模块

**模块名**

AppSettingsStore

**职责**

- 持久化非敏感配置
- 读取当前配置
- 提供默认值

**主要状态**

- `baseURL`
- `modelName`
- `sourceLanguagePreference`
- `targetLanguagePreference`
- `hotkeyConfig`

**持久化方式**

- UserDefaults 或本地配置文件
- 不存储 API Key 明文

**和谁协作**

- SettingsViewModel
- TranslationService
- GlobalHotkeyManager

### 3.8 Keychain 模块

**模块名**

KeychainStore

**职责**

- 保存 API Key
- 读取 API Key
- 更新 API Key
- 删除 API Key

**主要状态**

- `serviceName`
- `accountName`
- `keychainOperationResult`

**和谁协作**

- SettingsViewModel
- TranslationService

### 3.9 剪贴板模块

**模块名**

ClipboardManager

**职责**

- 读取当前剪贴板文本
- 将译文写入剪贴板
- 判断剪贴板内容是否为文本

**主要状态**

- `currentClipboardText`
- `copyStatus`

**和谁协作**

- TranslationViewModel

## 4. 核心功能

### 必须有的能力

MVP 必须包含：

1. 菜单栏常驻
2. 无 Dock 图标
3. 菜单项：打开翻译窗口、设置、退出
4. 固定全局快捷键 `Option + Space`
5. 快捷键唤起浮窗
6. 浮窗居中显示在当前屏幕
7. 浮窗置顶
8. 原文输入框
9. 译文结果区
10. 复制译文按钮
11. 读取剪贴板文本
12. 按 Enter 翻译
13. 自动判断中英文方向
14. 支持手动选择目标语言：简体中文、英语
15. 设置 API Base URL
16. 设置 API Key
17. 设置 Model Name
18. API Key 存储到 Keychain
19. 调用 OpenAI-compatible `/v1/chat/completions`
20. 展示翻译中、成功、失败状态

### 先做哪些

第一优先级：

1. App 菜单栏常驻
2. 翻译浮窗基础 UI
3. 设置页基础 UI
4. 配置保存和读取
5. Keychain 存储 API Key
6. 固定快捷键唤起
7. 剪贴板读取
8. 按 Enter 调用翻译
9. 复制译文

### 后做哪些

MVP 后置但可以预留结构：

1. 快捷键自定义
2. 测试 API 连接
3. 翻译失败重试
4. 简单翻译历史
5. 多语言扩展
6. 更多 Provider 配置
7. DMG 打包
8. 自动更新
9. 划词翻译
10. OCR

## 5. 数据模型

### 5.1 AppSettings

**说明**

保存 App 的非敏感配置。

**字段**

| 字段 | 类型 | 说明 | 持久化方式 |
| --- | --- | --- | --- |
| baseURL | String | OpenAI-compatible API Base URL | UserDefaults |
| modelName | String | 模型名称 | UserDefaults |
| defaultSourceLanguage | LanguageOption | 默认源语言，初版为 auto | UserDefaults |
| defaultTargetLanguage | LanguageOption | 默认目标语言，初版为 auto | UserDefaults |
| hotkey | HotkeyConfig | 快捷键配置，初版固定 | UserDefaults |
| readClipboardOnOpen | Bool | 打开浮窗时是否读取剪贴板 | UserDefaults |

**默认值**

```text
baseURL = ""
modelName = ""
defaultSourceLanguage = auto
defaultTargetLanguage = auto
hotkey = Option + Space
readClipboardOnOpen = true
```

### 5.2 APIKeyCredential

**说明**

保存 API Key 的 Keychain 记录。

**字段**

| 字段 | 类型 | 说明 | 持久化方式 |
| --- | --- | --- | --- |
| service | String | Keychain service 名称 | Keychain |
| account | String | Keychain account 名称 | Keychain |
| apiKey | String | 用户 API Key | Keychain |

**建议值**

```text
service = com.local.light-translator.api-key
account = default
```

### 5.3 TranslationRequest

**说明**

一次翻译请求。

**字段**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| sourceText | String | 待翻译文本 |
| sourceLanguage | LanguageOption | 源语言 |
| targetLanguage | LanguageOption | 目标语言 |
| resolvedTargetLanguage | LanguageOption | 自动判断后的目标语言 |
| modelName | String | 调用模型 |
| createdAt | Date | 请求创建时间 |

### 5.4 TranslationResult

**说明**

一次翻译结果。

**字段**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| sourceText | String | 原文 |
| translatedText | String | 译文 |
| sourceLanguage | LanguageOption | 源语言 |
| targetLanguage | LanguageOption | 目标语言 |
| status | TranslationStatus | 翻译状态 |
| errorMessage | String? | 错误信息 |
| createdAt | Date | 创建时间 |
| completedAt | Date? | 完成时间 |

MVP 不要求持久化 TranslationResult。

### 5.5 LanguageOption

**字段**

```text
auto
simplifiedChinese
english
```

显示名称：

| 值 | 显示 |
| --- | --- |
| auto | 自动 |
| simplifiedChinese | 简体中文 |
| english | 英语 |

### 5.6 TranslationStatus

**字段**

```text
idle
editing
translating
success
failed
```

### 5.7 HotkeyConfig

**字段**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| key | String | 主键，例如 Space |
| modifiers | [String] | 修饰键，例如 Option |
| enabled | Bool | 是否启用 |

MVP 固定为：

```text
Option + Space
```

## 6. 关键交互

### 用户主流程

#### 流程一：首次配置

1. 用户启动 App
2. App 出现在菜单栏
3. 用户点击菜单栏图标
4. 用户点击设置
5. 用户填写：
   - API Base URL
   - API Key
   - Model Name
6. 用户点击保存
7. App 将 API Key 存入 Keychain
8. App 将 Base URL、Model Name 存入 UserDefaults
9. 设置完成

#### 流程二：快捷翻译

1. 用户在任意 App 中复制一段文本
2. 用户按 `Option + Space`
3. App 在当前屏幕中央打开翻译浮窗
4. App 自动读取剪贴板文本并填入原文输入框
5. 用户可直接按 Enter 翻译
6. App 自动判断翻译方向
7. App 调用 AI API
8. App 在译文区域展示结果
9. 用户点击复制按钮
10. 译文写入剪贴板
11. 用户关闭浮窗或继续编辑原文

#### 流程三：手动输入翻译

1. 用户按 `Option + Space`
2. App 打开翻译浮窗
3. 用户清空或编辑原文输入框
4. 用户输入文本
5. 用户按 Enter
6. App 翻译并展示结果
7. 用户复制译文

### 不能出错的交互规则

1. 没有配置 API Key 时，不应发起翻译请求，应提示用户去设置页配置。
2. 没有配置 Base URL 时，不应发起翻译请求。
3. 没有配置 Model Name 时，不应发起翻译请求。
4. 原文为空时，按 Enter 不应调用 API。
5. 正在翻译时，重复按 Enter 不应并发发起多次请求。
6. 浮窗打开时必须聚焦到原文输入框。
7. 翻译结果为空时，复制按钮应不可用或提示无内容可复制。
8. API Key 不允许明文保存到 UserDefaults 或普通配置文件。
9. 网络错误、401 鉴权失败、模型不存在等错误必须显示可理解提示。
10. Escape 应能快速关闭浮窗。
11. 菜单中的退出必须真正退出 App。
12. 快捷键唤起时，如果浮窗已存在，应激活并置顶，而不是重复创建多个窗口。

### 容易冲突的状态关系

#### 1. 剪贴板读取 vs 用户正在输入

问题：

- 浮窗每次打开时读取剪贴板
- 但如果窗口已经打开，用户正在编辑文本，再次唤起可能覆盖输入

规则：

- 只有在窗口从隐藏变为显示时，才读取剪贴板
- 如果窗口已显示，再次按快捷键只聚焦窗口，不覆盖当前输入
- 可后续增加重新读取剪贴板按钮

#### 2. 自动语言方向 vs 手动选择目标语言

问题：

- 默认自动判断目标语言
- 用户也可以手动选择目标语言

规则：

- 如果目标语言是 `auto`，则根据原文自动判断
- 如果用户手动选择简体中文或英语，则优先使用用户选择
- 源语言 MVP 可保持 `auto`，不强制用户选择

#### 3. 翻译中 vs 文本继续编辑

问题：

- 用户发起翻译后继续修改原文，返回结果可能对应旧文本

MVP 规则：

- 翻译请求开始时记录 `requestText`
- 返回结果只展示到当前请求对应的结果区
- 如果返回时输入框内容已经变化，可仍展示结果，但不自动清空输入
- 后续可增加请求取消或结果版本校验

#### 4. 快捷键占用

问题：

- `Option + Space` 可能被其他应用占用

MVP 规则：

- App 启动时尝试注册快捷键
- 注册失败时，在设置页或菜单中提示快捷键不可用
- MVP 不做复杂快捷键配置

#### 5. 设置变更 vs 正在翻译

问题：

- 用户修改 API 配置时，翻译请求可能正在进行

MVP 规则：

- 正在翻译的请求使用发起时读取到的配置
- 新设置只影响下一次翻译

## 7. 开发顺序

### Phase 1：应用骨架与基础窗口

目标：

完成 App 可以运行、常驻菜单栏、打开窗口的基础能力。

任务：

1. 创建 macOS App 项目
2. 设置 App 不显示 Dock 图标
3. 实现菜单栏图标
4. 实现菜单项：
   - 打开翻译窗口
   - 设置
   - 退出
5. 实现翻译浮窗基础 UI：
   - 原文输入框
   - 译文结果区
   - 复制按钮
   - 语言选择入口
6. 实现设置窗口基础 UI：
   - Base URL
   - API Key
   - Model Name
   - 保存按钮
7. 实现窗口置顶、居中、快速关闭

验收标准：

- 启动后只显示菜单栏图标
- 点击菜单可以打开翻译窗口
- 点击菜单可以打开设置窗口
- 点击退出可以关闭 App
- 翻译浮窗可以输入文本
- 设置页可以填写内容

### Phase 2：配置、快捷键与剪贴板

目标：

完成本地配置、安全存储、快捷键唤起和剪贴板辅助。

任务：

1. 实现 UserDefaults 配置存储
2. 实现 Keychain API Key 存储
3. 设置页保存和读取配置
4. 注册固定快捷键 `Option + Space`
5. 快捷键唤起翻译浮窗
6. 浮窗打开时读取剪贴板文本
7. 实现复制译文到剪贴板
8. 实现 Escape 关闭浮窗
9. 实现 Enter 触发翻译事件，但可以先接假翻译结果

验收标准：

- 设置重启后仍保留
- API Key 不明文保存在本地配置中
- 按 `Option + Space` 能打开浮窗
- 复制文本后打开浮窗，文本自动出现在输入框
- 点击复制按钮能写入剪贴板
- 按 Enter 能触发翻译流程

### Phase 3：AI 翻译闭环

目标：

完成真实 API 调用和最小可用翻译闭环。

任务：

1. 实现语言方向判断
2. 构造翻译 Prompt
3. 调用 OpenAI-compatible `/v1/chat/completions`
4. 解析返回结果
5. 展示翻译中状态
6. 展示成功结果
7. 展示失败错误
8. 防止重复请求
9. 完成基础异常处理
10. 进行完整手动测试

验收标准：

- 中文文本默认翻译成英文
- 英文文本默认翻译成简体中文
- 手动选择目标语言后按选择翻译
- API 配置正确时能拿到真实译文
- API 配置错误时能显示错误
- 翻译完成后可以复制结果
- 快捷键唤起浮窗、输入文本、翻译、复制结果形成完整闭环

## 8. 输出要求

### MVP 交付物

最终交付应包含：

1. 一个可本地运行的 macOS `.app`
2. 项目源代码
3. 基础 README
4. 本地运行说明
5. 配置说明
6. 已知限制说明

### README 需要包含

1. 产品简介
2. 系统要求
3. 本地运行方式
4. API 配置方式
5. 默认快捷键
6. 使用流程
7. 当前不支持的能力
8. 常见问题

### 最小验收用例

#### 用例 1：启动 App

操作：

- 启动 App

期望：

- Dock 不显示 App 图标
- 菜单栏显示 App 图标
- 菜单可展开

#### 用例 2：打开设置并保存

操作：

- 打开设置
- 填写 Base URL、API Key、Model
- 保存
- 重启 App

期望：

- Base URL 和 Model 仍存在
- API Key 可正常读取
- API Key 不明文出现在本地配置文件中

#### 用例 3：快捷键唤起

操作：

- 按 `Option + Space`

期望：

- 当前屏幕中央出现翻译浮窗
- 输入框自动聚焦
- 窗口置顶

#### 用例 4：剪贴板读取

操作：

- 复制一段英文文本
- 按 `Option + Space`

期望：

- 英文文本自动填入原文输入框

#### 用例 5：英文翻译中文

操作：

- 输入英文
- 按 Enter

期望：

- App 调用 API
- 返回简体中文译文
- 译文显示在结果区

#### 用例 6：中文翻译英文

操作：

- 输入中文
- 按 Enter

期望：

- App 调用 API
- 返回英文译文
- 译文显示在结果区

#### 用例 7：复制译文

操作：

- 翻译完成后点击复制按钮

期望：

- 译文写入剪贴板
- 用户可在其他 App 粘贴译文

#### 用例 8：配置缺失

操作：

- 不填写 API Key
- 输入文本按 Enter

期望：

- 不发起 API 请求
- 显示明确提示：请先配置 API Key

### MVP 完成定义

当以下闭环稳定可用时，MVP 视为完成：

> 启动 App → 菜单栏常驻 → 快捷键打开浮窗 → 自动读取剪贴板或输入文本 → 自动判断中英文方向 → 调用 AI API → 展示译文 → 一键复制结果。
