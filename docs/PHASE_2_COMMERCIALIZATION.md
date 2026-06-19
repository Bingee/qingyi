# 轻译开源翻译能力落地方案

## 1. 目标

轻译后续不再走订阅、支付、账号、后台审核路线。

新的产品定位：

- 做成清爽、开源、可本地使用的 macOS 菜单栏翻译工具
- 默认翻译工具使用服务端托管的火山翻译
- 火山翻译每月按 200 万字符免费额度作为服务端全局上限
- GPT、DeepSeek-V4、Gemini-3.5 不再走作者代理，用户自行填写 API Key / Base URL / Model ID
- 用户配置成功后启用对应模型
- API Key 只保存在用户本机 Keychain
- 非敏感设置保存在 UserDefaults

这意味着原来的商业化链路全部取消：

- 不做账号登录
- 不做订阅套餐
- 不做支付
- 不做飞书 Webhook
- 不做网站后台
- 不做服务器数据库
- 不做服务端订阅鉴权

关键边界：

- 火山翻译由服务端代理调用，客户端不接触火山 AK/SK。
- 服务端保存火山 AK/SK，并做自然月全局字符统计。
- 火山后台可用于查看用量和费用，但不应作为精确的“超过 200 万字符立即停止服务”的唯一手段。
- 当前代码已把火山翻译切到服务端 `/api/translate`，超过服务端配置的月额度后停止继续请求火山。

当前的 `server/` 是火山默认翻译入口；GPT、DeepSeek-V4、Gemini-3.5 仍由 App 直接调用用户配置的 OpenAI-compatible Provider。

## 2. 当前代码状态

### 已具备

- macOS SwiftUI / AppKit 菜单栏 App
- 无 Dock 图标
- 全局快捷键唤起翻译浮窗
- 翻译浮窗输入、语言选择、Enter 翻译、结果展示
- 复制译文
- 朗读译文
- 打开浮窗时读取剪贴板文本
- 设置页操作即保存
- 设置页已有模型单选 UI
- 翻译结果标题显示当前模型名，例如 `GPT 翻译`
- `KeychainStore.swift` 已有多 Provider Keychain 读写能力
- 服务端已接入火山翻译文本翻译 API
- 已接入 OpenAI-compatible `/v1/chat/completions` 客户端
- 火山翻译已作为默认模型
- 火山翻译已走服务端代理
- 火山翻译已做服务端每月 200 万字符用量拦截
- GPT、DeepSeek-V4、Gemini-3.5 已切换为用户自填 API Key / Base URL / Model ID
- 当前本地代理支持 `GET /health`、`GET /api/models`、`POST /api/translate`

### 需要调整

- 需要增加 API 信息验证按钮，目前是保存后翻译时验证
- Gemini 当前按 OpenAI-compatible 配置处理；如果直接接 Google Gemini 官方 API，需要单独实现 Gemini 协议
- 需要把旧的 `translationServiceBaseURL` 本地代理配置继续降级为历史兼容字段

## 3. 新产品形态

### 设置页结构

设置页保留当前“翻译模型”区域，但改成“翻译引擎”或“模型服务”。

每个翻译引擎提供：

- 启用开关
- API Key 输入框
- 验证并启用按钮
- 验证状态
- 可选 Base URL
- 可选 Model ID
- 简短说明
- 获取 API Key 的官方链接

默认状态：

- 火山翻译为默认开启项
- 客户端不写死任何真实 AK/SK
- 客户端不展示火山 AK/SK 输入
- GPT、DeepSeek-V4、Gemini-3.5 默认不带 API Key
- GPT、DeepSeek-V4、Gemini-3.5 必须由用户填写 API Key / Base URL / Model ID 后才能翻译
- 未配置成功的 Provider 不参与翻译

### 翻译流程

```text
用户打开设置
-> 选择一个 Provider
-> 填写 API Key / Base URL / Model ID
-> 点击验证并启用
-> App 发起一次短文本测试请求
-> 验证成功后把 API Key 存入 Keychain
-> 非敏感配置写入 UserDefaults
-> 用户回到翻译浮窗
-> App 直接调用该 Provider 翻译
```

### 错误状态

必须明确展示：

- 未配置 API Key
- API Key 验证失败
- 模型 ID 不可用
- Base URL 无效
- Provider 限流
- Provider 余额不足或免费额度耗尽
- 网络不可用
- 返回格式无法解析

## 4. Provider 设计

### ProviderKind

建议定义 Provider 类型：

```swift
enum TranslationProviderKind: String, Codable, CaseIterable {
    case volcengineTranslate
    case openAICompatible
    case gemini
    case azureTranslator
    case libreTranslate
    case myMemory
}
```

### ProviderConfig

非敏感配置建议存在 UserDefaults：

```swift
struct TranslationProviderConfig: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String
    var kind: TranslationProviderKind
    var isEnabled: Bool
    var baseURL: String
    var modelID: String
    var apiKeyStorageAccount: String
    var description: String
    var helpURL: String?
}
```

API Key 不进入这个结构体，只通过 `apiKeyStorageAccount` 到 Keychain 读取。

### Keychain 存储

建议把 `KeychainStore` 改成通用密钥存储：

```swift
final class KeychainStore {
    func saveSecret(_ value: String, account: String) throws
    func loadSecret(account: String) throws -> String
    func deleteSecret(account: String) throws
}
```

建议 service：

```text
com.local.light-translator.provider-key
```

建议 account 命名：

```text
provider.gpt.apiKey
provider.deepseek.apiKey
provider.gemini.apiKey
provider.deepl.apiKey
provider.openrouter.apiKey
provider.azure.apiKey
```

安全要求：

- API Key 只存 Keychain
- UserDefaults 只存 Provider、Base URL、Model ID、启用状态
- 日志中不能打印 API Key
- UI 中展示时只显示掩码，例如 `sk-...abcd`
- 删除 Provider 或关闭启用时，提供“删除本机密钥”操作

## 5. 内置 Provider 建议

### 第一批必须落地

#### 火山翻译

定位：默认免费翻译入口。

字段：

```text
Display Name: 火山翻译
Kind: volcengineTranslate
Host: translate.volcengineapi.com
Action: TranslateText
Version: 2020-06-01
Region: cn-north-1
Service: translate
```

额度策略：

- 产品层面按每月 200 万字符内免费使用设计。
- 当前实现由服务端记录自然月全局字符数，达到 200 万字符后停止继续请求火山。
- 客户端只请求服务端 `/api/translate`，不保存火山 AK/SK。
- 火山引擎官方计费说明显示文本翻译按自然月计费，每月前 200 万字符免费，超过后按量计费；同时官方说明后付费欠费不一定立即关停，因此不能只依赖火山后台做硬停止。

安全要求：

- 不要把作者火山 AK/SK 写入仓库。
- 不要把作者火山 AK/SK 编译进开源 App。
- 火山 AK/SK 只能放在后端环境变量或密钥管理服务。

参考：

- https://www.volcengine.com/docs/4640/68515
- https://www.volcengine.com/docs/6369/67269
- https://www.volcengine.com/docs/4640/65067

#### GPT

定位：OpenAI-compatible 入口。

不要把它绑定死到作者后端或 APIMart。用户可以填：

- OpenAI
- OpenRouter
- SiliconFlow
- Groq
- 阿里云百炼
- 其他 OpenAI-compatible 服务

字段：

```text
Display Name: GPT
Kind: openAICompatible
Base URL: 用户可编辑
Model ID: 用户可编辑
API Key: 用户填写
```

默认可以给示例 Base URL，但不建议默认启用：

```text
https://api.openai.com/v1
```

#### DeepSeek-V4

定位：DeepSeek / OpenAI-compatible 入口。

字段：

```text
Display Name: DeepSeek-V4
Kind: openAICompatible
Base URL: 用户可编辑
Model ID: 用户可编辑
API Key: 用户填写
```

注意：当前 `deepseek-v4-flash` 是现有代理里的上游模型名。开源版不应假设所有用户都能访问这个模型。应该允许用户编辑 Model ID。

#### Gemini

定位：当前先按 OpenAI-compatible 入口处理。

字段：

```text
Display Name: Gemini
Kind: openAICompatible
Base URL: 用户可编辑
Model ID: 用户可编辑
API Key: 用户填写
```

如果后续要直接接 Google Gemini 官方 API，需要新增单独的 Gemini Client，不复用 OpenAI-compatible 请求格式。

### 可选自定义 Provider

以下服务不作为 App 内“免费推荐”展示，只作为自定义配置示例。用户如果已有账号和 API Key，可以自行填写 Base URL、Model ID 和 API Key。

#### OpenRouter

定位：OpenAI-compatible 聚合入口。

字段：

```text
Display Name: OpenRouter
Kind: openAICompatible
Base URL: https://openrouter.ai/api/v1
Model ID: 用户选择或填写
API Key: 用户填写
```

参考：

- https://openrouter.ai/docs/api/reference/authentication

#### Groq

定位：高速 OpenAI-compatible LLM API，适合短文本翻译。

字段：

```text
Display Name: Groq
Kind: openAICompatible
Base URL: https://api.groq.com/openai/v1
Model ID: 用户填写
API Key: 用户填写
```

参考：

- https://console.groq.com/docs/quickstart
- https://console.groq.com/docs/api-reference
- https://groq.com/pricing

#### SiliconFlow

定位：国内访问更友好的 OpenAI-compatible Provider。

字段：

```text
Display Name: SiliconFlow
Kind: openAICompatible
Base URL: https://api.siliconflow.cn/v1
Model ID: 用户填写
API Key: 用户填写
```

参考：

- https://docs.siliconflow.com/en/userguide/quickstart

### 高级可选 Provider

#### Azure Translator

定位：专门翻译 API。

优点：

- 翻译质量稳定

缺点：

- Azure 配置比 OpenAI-compatible 入口复杂
- 需要 Endpoint、Key、Region

参考：

- https://azure.microsoft.com/en-us/pricing/details/translator/

#### LibreTranslate

定位：开源、自托管翻译 API。

优点：

- 可以完全自托管
- 符合开源工具气质

缺点：

- 官方托管 API Key 通常需要购买
- 翻译质量和语言覆盖取决于实例和模型

参考：

- https://libretranslate.com/
- https://docs.libretranslate.com/guides/manage_api_keys/

#### MyMemory

定位：低门槛翻译 API。

优点：

- 匿名可用

缺点：

- 质量和稳定性不适合作为主力
- 单段文本限制较小

参考：

- https://mymemory.translated.net/doc/usagelimits.php
- https://mymemory.translated.net/doc/spec.php

## 6. 默认免费 Provider 参考

开源版当前只内置一个默认免费翻译入口：火山翻译。

| Provider | 类型 | 免费情况 | 适合程度 |
| --- | --- | --- | --- |
| 火山翻译 | 专门翻译 | 官方文本翻译每月前 200 万字符免费，超过后按量计费 | 默认推荐 |

其他 Provider 不在 App 内承诺免费。GPT、DeepSeek-V4、Gemini-3.5、OpenRouter、Groq、SiliconFlow、Azure Translator、Mistral、Hugging Face、LibreTranslate、MyMemory 等只作为用户自定义配置或高级扩展方向。它们是否免费、是否需要绑卡、额度多少、是否可商用，都以各自官方页面为准。

## 7. 请求实现规范

### OpenAI-compatible

适用于：

- GPT
- DeepSeek-V4
- Gemini-3.5 当前自定义入口
- OpenRouter
- Groq
- SiliconFlow
- 其他兼容接口

请求规则：

```text
POST {baseURL}/chat/completions
Authorization: Bearer {apiKey}
Content-Type: application/json
```

请求体：

```json
{
  "model": "user-configured-model-id",
  "stream": false,
  "temperature": 0.2,
  "messages": [
    {
      "role": "system",
      "content": "You are a professional translation engine. Only return the translated text."
    },
    {
      "role": "user",
      "content": "Translate the following text into English..."
    }
  ]
}
```

解析：

```text
choices[0].message.content
```

### 火山翻译

请求规则：

```text
POST https://translate.volcengineapi.com/?Action=TranslateText&Version=2020-06-01
Host: translate.volcengineapi.com
Region: cn-north-1
Service: translate
Authorization: HMAC-SHA256 ...
```

请求体：

```json
{
  "TargetLanguage": "zh",
  "TextList": [
    "Hello world"
  ]
}
```

语言映射：

```text
auto -> 不传 SourceLanguage
简体中文 -> zh
英文 -> en
```

限制：

- 单次 `TextList` 当前客户端只传 1 条。
- 单次文本长度不超过 5000 字符。
- 服务端每月累计超过 200 万字符后停止继续请求。

### Gemini

当前 Gemini-3.5 入口先按 OpenAI-compatible 配置处理。

如果后续要接 Google Gemini 官方 API，再新增以下支持：

需要支持：

- API Key
- Model ID
- `generateContent`
- 从 response 中提取文本

验证时用短文本：

```text
Translate "Hello" into Simplified Chinese. Return only the translation.
```

### Azure Translator

需要支持：

- API Key
- Endpoint
- Region
- source language
- target language

由于配置项比其他 Provider 多，建议放到第二批。

## 8. 验证逻辑

每个 Provider 都应实现：

```swift
protocol TranslationProviderClient {
    func validate(config: TranslationProviderConfig, apiKey: String) async throws
    func translate(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        config: TranslationProviderConfig,
        apiKey: String
    ) async throws -> String
}
```

验证成功条件：

- HTTP 状态码为 2xx
- 返回文本非空
- 返回文本不是错误 JSON

验证失败时：

- 不启用 Provider
- 不覆盖旧的可用 Key，除非用户明确保存
- 显示可读错误

建议验证样例：

```text
Hello
```

目标语言：

```text
简体中文
```

预期只要求返回非空文本，不强校验必须等于“你好”。

## 9. 设置页交互

### Provider 列表

每个 Provider 行展示：

- 图标
- 名称
- 一句描述
- 启用状态
- 验证状态

状态文案：

```text
未配置
待验证
验证中
已启用
验证失败
```

### Provider 详情

点击 Provider 后展示：

- 火山翻译展示托管状态，不展示 AK/SK 输入
- 其他模型展示 API Key SecureField
- Base URL TextField，按 Provider 需要显示
- Model ID TextField，按 Provider 需要显示
- Endpoint/Region 字段，按 Provider 需要显示
- 获取 API Key 链接
- 验证并启用按钮
- 删除本机密钥按钮

### 翻译模型开关

允许同时开启多个 Provider。

如果用户启用了多个 Provider：

- 翻译浮窗按设置页顺序展示多个结果
- 每个 Provider 一个结果模块
- 单个 Provider 失败时只展示该 Provider 的错误，不影响其他结果

## 10. 当前文件改造清单

### `LightTranslator/Core/TranslationModel.swift`

建议改名或重构为：

```text
TranslationProvider.swift
TranslationProviderConfig.swift
```

职责：

- Provider 定义
- Provider kind
- 默认 Provider 顺序
- 展示名称、图标、描述

### `LightTranslator/Core/AppSettings.swift`

新增：

```swift
var enabledModelIDs: [String]
var providerConfigs: [TranslationProviderConfig]
```

移除或逐步废弃：

```swift
selectedModelID
translationServiceBaseURL
```

如果需要兼容旧设置：

- `selectedModelID` 迁移到 `selectedProviderID`
- `translationServiceBaseURL` 可迁移到 GPT/OpenAI-compatible Provider 的 `baseURL`

### `LightTranslator/Services/AppSettingsStore.swift`

需要支持：

- 读写 Provider configs
- 迁移旧的 selected model
- 只保存非敏感字段
- 不保存 API Key

### `LightTranslator/Services/KeychainStore.swift`

需要支持：

- 按 account 保存不同 Provider 的 key
- 删除 key
- 加载 key

### `LightTranslator/Services/TranslationService.swift`

改造为：

```text
读取 selectedProviderID
-> 读取 Provider config
-> 从 Keychain 读取 API Key
-> 根据 Provider kind 创建 client
-> 直接请求 Provider
-> 返回 ModelTranslationResult
```

不再默认调用本地代理 `/api/translate`。

### `LightTranslator/UI/Settings/SettingsView.swift`

需要改造：

- Provider 列表
- Provider 详情表单
- API Key 输入
- Base URL / Model ID 输入
- 验证并启用按钮
- 删除密钥按钮
- 验证状态

### `LightTranslator/UI/Settings/SettingsViewModel.swift`

需要新增：

- 加载 Provider configs
- 保存非敏感配置
- 保存 Keychain secret
- 删除 Keychain secret
- 验证 Provider
- 设置启用 Provider 列表
- 处理验证错误

### `LightTranslator/UI/Translation/TranslationViewModel.swift`

需要：

- 展示启用 Provider 名称
- 未配置 Provider 时提示用户去设置
- 翻译前检查 Provider 是否启用且 Keychain 有 key

### `server/`

客户端默认火山翻译依赖 `server/`。

处理方式：

- 服务端保存火山 AK/SK
- 服务端提供 `/translate` 接口
- 服务端记录自然月全局字符数
- 超过 2,000,000 字符后停止继续请求火山
- 客户端不接触作者 AK/SK

## 11. 落地顺序

### Phase A：配置模型改造

1. 新增 `TranslationProviderKind`
2. 新增 `TranslationProviderConfig`
3. 新增默认 Provider 顺序
4. 改造 `AppSettings`
5. 改造 `AppSettingsStore`
6. 保留旧设置迁移

验收：

- App 能启动
- 设置页能展示 Provider 列表
- 切换 Provider 开关后能持久化

### Phase B：Keychain 多 Key

1. 改造 `KeychainStore`
2. 支持 `saveSecret`
3. 支持 `loadSecret`
4. 支持 `deleteSecret`
5. API Key 不进入 UserDefaults

验收：

- 每个 Provider 能单独保存 key
- 删除一个 Provider key 不影响其他 Provider
- 重启 App 后 key 仍能读取

### Phase C：Provider Client

1. 实现 `VolcengineTranslateClient`
2. 实现 `OpenAICompatibleProviderClient`
3. 实现火山服务端月用量拦截
4. 实现统一错误模型
5. 实现验证请求

验收：

- 火山翻译可请求
- 火山翻译超过服务端 200 万字符后停止请求
- OpenAI-compatible Provider 可验证
- GPT / DeepSeek-V4 / Gemini-3.5 自定义 API 信息可验证
- 无 Key 时不会发请求

### Phase D：设置页落地

1. API Key 输入框
2. Base URL / Model ID 配置
3. 验证并启用按钮
4. 删除密钥按钮
5. 验证状态展示
6. 获取 API Key 链接

验收：

- 用户能从设置页完成 Provider 配置
- 验证失败有明确错误
- 验证成功后该 Provider 可用于翻译

### Phase E：翻译流程切换

1. `TranslationService` 不再调用本地代理
2. 按 selected Provider 直接调用 Provider API
3. 翻译浮窗标题显示 Provider 名称
4. 未配置时提示去设置

验收：

- 配置成功后可以翻译
- 未配置时不崩溃
- 本地代理不启动也可以使用已配置 Provider

## 12. 不做

开源版 MVP 不做：

- 用户账号
- 订阅套餐
- 支付
- 官网
- 飞书 Webhook
- 管理后台
- Neon 数据库
- systemd 部署
- Nginx 配置
- 云端用量统计

火山翻译默认服务需要保留：

- 服务器火山翻译代理
- 服务端全局月用量统计
- 服务端 2,000,000 字符硬拦截
- 作者托管火山 AK/SK

## 13. 风险与注意事项

### 用户 Key 暴露风险

这是桌面 App，本地 Keychain 是合理方案，但仍要提醒用户：

- API Key 是用户自己的资产
- 不要分享截图
- 不要提交日志
- 不要把 Key 写进 issue

### 免费额度变化

Provider 免费政策会变：

- App 内不要承诺永久免费
- 文档使用“可能有免费额度”
- 设置页使用“查看官方额度说明”

### Provider 协议差异

OpenAI-compatible 能覆盖很多服务，但不能覆盖全部。

需要单独实现：

- Gemini
- Azure Translator
- LibreTranslate

### 翻译质量差异

LLM 翻译和专门翻译 API 风格不同：

- 火山翻译/Azure 更像传统翻译工具
- Gemini/Groq/OpenRouter 更适合自然语言润色和上下文翻译
- MyMemory/LibreTranslate 适合作为轻量或自托管选择

## 14. 完成定义

开源托管火山 MVP 完成标准：

```text
用户首次打开 App
-> 客户端默认没有任何火山 API Key
-> 用户打开设置页
-> 选择 Provider
-> 输入 API Key / Base URL / Model ID
-> 点击验证并启用
-> API Key 存入 Keychain
-> Provider 配置存入 UserDefaults
-> 用户回到翻译浮窗
-> 输入文本并翻译
-> App 直接调用用户配置的 Provider
-> 返回译文、复制、朗读均可用
```

技术验收：

- 不启动 `server/` 也能翻译
- 仓库不包含任何真实 API Key
- UserDefaults 不包含 API Key
- Keychain 可保存多个 Provider Key
- 验证失败不会启用 Provider
- 构建命令通过：

```bash
xcodegen generate
xcodebuild -project LightTranslator.xcodeproj -scheme LightTranslator -configuration Debug -derivedDataPath .build/DerivedData build CODE_SIGNING_ALLOWED=NO
```
