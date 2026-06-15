# 轻译二期商业化方案

## 1. 目标

二期目标是把轻译从“本地自用工具”升级为可商业化的订阅制产品。

核心方向：

- 用户在 App 内查看订阅方案
- 用户点击购买后跳转官网
- 官网展示微信 / 支付宝收款二维码
- 用户付款后提交付款信息
- 后台人工确认并开通订阅
- 客户端登录账号后同步订阅状态
- 订阅用户通过后端 AI 代理完成翻译
- 支持多个翻译模型切换和共同使用

本阶段暂不接入 Stripe、Paddle、微信支付商户号、支付宝开放平台等自动支付系统。

## 2. 产品形态

### 订阅方案

初始套餐：

| 套餐 | 价格 | 周期 |
| --- | --- | --- |
| 月付 | ¥6.6 | 1 个月 |
| 半年 | ¥29 | 6 个月 |
| 年付 | ¥49 | 12 个月 |

建议每个套餐都绑定用量额度，避免 AI 成本失控。

示例：

| 套餐 | 建议额度 |
| --- | --- |
| 月付 | 每月 50 万字符 |
| 半年 | 每月 80 万字符 |
| 年付 | 每月 100 万字符 |

额度可以按字符数、token 数或请求次数统计。MVP 建议先按字符数统计，简单直观。

### 模型策略

支持多个模型，但需要按成本分层。

示例：

| 模型类型 | 说明 | 额度倍率 |
| --- | --- | --- |
| 快速模型 | 默认翻译，成本低，速度快 | 1x |
| 高质量模型 | 长文本、正式表达、复杂语境 | 2x 或 3x |
| 备用模型 | 主模型失败时兜底 | 1x 或按实际成本 |

客户端可以展示模型选择入口，但模型 API Key 必须只保存在后端。

## 3. 账号体系

### 登录方式

采用邮箱 + 密码。

原因：

- 用户理解成本低
- 方便和付款记录绑定
- 不依赖邮件验证码实时送达
- 适合后续扩展账号中心、设备管理、订阅管理

### 账号功能

客户端需要支持：

- 注册
- 登录
- 退出登录
- 自动登录
- 查看当前邮箱
- 查看订阅状态
- 查看到期时间
- 查看剩余额度

二期可暂不做：

- 第三方登录
- 手机号登录
- 多团队账号
- 复杂账号资料
- 自助注销

### 密码规则

建议规则：

- 最少 8 位
- 允许数字、字母、符号
- 后端使用强哈希存储，例如 Argon2id 或 bcrypt
- 不保存明文密码
- 登录失败需要限流

### 忘记密码

二期建议支持最小闭环：

```text
用户输入邮箱
-> 后端发送重置密码链接
-> 用户打开网页设置新密码
```

如果要更快上线，可以先人工处理忘记密码，但不建议长期这样做。

## 4. 支付流程

### 前期支付方式

使用个人微信 / 支付宝收款二维码。

流程：

```text
App 内点击购买
-> 跳转官网订阅页
-> 用户选择套餐
-> 用户扫码付款
-> 用户提交付款信息
-> 后台人工审核
-> 审核通过后开通订阅
-> App 刷新订阅状态
```

### 官网订阅页

页面需要包含：

- 套餐价格
- 套餐权益
- 微信收款二维码
- 支付宝收款二维码
- 付款备注说明
- 付款后提交表单入口

付款备注建议：

```text
轻译 + 注册邮箱
```

例如：

```text
轻译 user@example.com
```

### 付款提交表单

用户付款后提交：

- 注册邮箱
- 选择套餐
- 付款方式：微信 / 支付宝
- 付款金额
- 付款时间
- 付款备注
- 付款截图，可选但建议提供

提交后进入待审核状态。

## 5. 后台管理

需要一个极简 admin 后台。

### 后台功能

必须有：

- 登录后台
- 查看待审核付款
- 查看用户邮箱
- 查看付款金额
- 查看套餐
- 查看付款截图
- 审核通过
- 审核拒绝
- 手动调整订阅到期时间
- 查看用户当前订阅状态
- 查看用户用量

后续可加：

- 搜索用户
- 订阅延期
- 封禁用户
- 退款备注
- 操作日志

### 审核通过逻辑

审核通过后：

```text
如果用户没有订阅：
  创建 active subscription

如果用户已有未过期订阅：
  在当前 expires_at 基础上顺延

如果用户订阅已过期：
  从当前时间开始计算新周期
```

## 6. 后端服务

### 后端职责

后端是订阅状态和 AI 调用的唯一可信入口。

负责：

- 用户注册 / 登录
- 密码哈希
- session / token 管理
- 订阅状态管理
- 付款审核
- 用量统计
- 模型路由
- AI API Key 管理
- 限流和防滥用
- 翻译请求代理

客户端不应内置你的大模型 API Key。

### 推荐接口

账号：

```text
POST /auth/register
POST /auth/login
POST /auth/logout
POST /auth/refresh
POST /auth/forgot-password
POST /auth/reset-password
GET  /me
```

订阅：

```text
GET  /plans
GET  /subscription
POST /manual-payment-claims
GET  /usage
```

翻译：

```text
GET  /models
POST /translate
```

后台：

```text
GET  /admin/payment-claims
POST /admin/payment-claims/:id/approve
POST /admin/payment-claims/:id/reject
GET  /admin/users
PATCH /admin/users/:id/subscription
```

## 7. 数据模型

### users

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | UUID | 用户 ID |
| email | String | 邮箱，唯一 |
| password_hash | String | 密码哈希 |
| created_at | Date | 创建时间 |
| last_login_at | Date? | 最近登录时间 |
| status | String | active / disabled |

### sessions

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | UUID | session ID |
| user_id | UUID | 用户 ID |
| refresh_token_hash | String | refresh token 哈希 |
| expires_at | Date | 过期时间 |
| revoked_at | Date? | 注销时间 |
| created_at | Date | 创建时间 |

### plans

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | String | monthly / half_year / yearly |
| name | String | 套餐名 |
| price_cny | Decimal | 人民币价格 |
| duration_days | Int | 有效天数 |
| monthly_quota_chars | Int | 每月额度 |
| enabled | Bool | 是否展示 |

### subscriptions

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | UUID | 订阅 ID |
| user_id | UUID | 用户 ID |
| plan_id | String | 套餐 ID |
| status | String | active / expired / canceled |
| starts_at | Date | 开始时间 |
| expires_at | Date | 到期时间 |
| created_at | Date | 创建时间 |
| updated_at | Date | 更新时间 |

### manual_payment_claims

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | UUID | 付款申报 ID |
| user_id | UUID | 用户 ID |
| plan_id | String | 套餐 ID |
| payment_method | String | wechat / alipay |
| amount_cny | Decimal | 付款金额 |
| paid_at | Date? | 用户填写的付款时间 |
| note | String? | 付款备注 |
| screenshot_url | String? | 截图 |
| status | String | pending / approved / rejected |
| reviewed_at | Date? | 审核时间 |
| reviewed_by | UUID? | 审核人 |
| created_at | Date | 创建时间 |

### usage_records

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | UUID | 用量记录 ID |
| user_id | UUID | 用户 ID |
| model_id | String | 使用模型 |
| source_chars | Int | 原文字数 |
| billed_chars | Int | 计费用量 |
| created_at | Date | 创建时间 |

### model_configs

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | String | 模型 ID |
| display_name | String | 展示名称 |
| provider | String | 供应商 |
| model_name | String | 实际模型名 |
| cost_multiplier | Int | 额度倍率 |
| enabled | Bool | 是否可用 |

## 8. 客户端改造

### 需要新增页面

- 登录页
- 注册页
- 订阅方案页
- 账号状态页
- 用量展示
- 模型选择

### 设置页改造

设置页需要区分两种模式：

1. 订阅模式
   - 用户登录账号
   - 使用后端提供的模型
   - 不需要填写 API Key

2. 自带 Key 模式
   - 用户填写 Base URL / API Key / Model
   - 适合高级用户
   - 可作为 Pro 或高级设置保留

建议默认展示订阅模式，自带 Key 模式折叠到高级设置。

### Token 存储

客户端登录后：

- access token 可以短期内存
- refresh token 存 macOS Keychain
- 不把 token 明文写入 UserDefaults

## 9. AI 代理与用量控制

### 翻译请求流程

```text
App 发起 /translate
-> 后端校验 access token
-> 查询订阅状态
-> 查询剩余额度
-> 根据用户选择模型计算倍率
-> 调用对应 AI Provider
-> 记录 usage_records
-> 返回译文
```

### 用量规则

建议：

- 每次按原文字符数计量
- 高级模型按倍率扣除
- 每月重置额度
- 超额后提示升级或等待下月

示例：

```text
原文 1000 字
快速模型 1x：扣 1000
高质量模型 3x：扣 3000
```

## 10. 安全与风控

必须注意：

- 后端保存大模型 API Key，客户端不保存
- 所有订阅状态以后端为准
- 客户端本地缓存只用于展示，不能作为最终授权依据
- 登录接口限流
- 翻译接口限流
- 单用户每日请求上限
- 单 IP 请求上限
- 密码使用强哈希
- 后台操作需要管理员权限

## 11. 开发顺序

### Phase 2.1：账号和订阅基础

- 后端用户注册 / 登录
- 客户端登录页
- token 存 Keychain
- 订阅状态接口
- App 内展示订阅方案

### Phase 2.2：人工收款流程

- 官网订阅页
- 微信 / 支付宝二维码展示
- 付款申报表单
- 后台付款审核
- 审核通过后开通订阅

### Phase 2.3：AI 代理翻译

- 后端 `/translate`
- 模型配置
- 用量统计
- 订阅校验
- 客户端切换到云端翻译模式

### Phase 2.4：多模型与额度

- 模型列表接口
- 客户端模型选择
- 不同模型倍率
- 用量展示
- 超额提示

## 12. 当前不做

二期暂不做：

- App Store 内购
- Stripe / Paddle 自动订阅
- 微信支付商户号
- 支付宝开放平台
- 企业团队版
- 发票系统
- 自动退款
- 复杂 CRM

## 13. 完成定义

二期 MVP 完成标准：

```text
用户注册登录
-> 在 App 内看到套餐
-> 跳官网扫码付款
-> 提交付款信息
-> 后台人工审核通过
-> App 同步订阅状态
-> 订阅用户通过后端代理完成翻译
-> 后端记录用量并支持模型切换
```

## 14. 当前项目上下文

### 项目路径

本地项目路径：

```text
/Users/a1234/Documents/轻译
```

### 技术栈

- macOS SwiftUI / AppKit 菜单栏 App
- 使用 XcodeGen 生成 `LightTranslator.xcodeproj`
- 本地 AI 代理服务为 Node.js 20 原生 `http` 服务
- 客户端不保存上游大模型 API Key，只请求本地或后端代理
- Node 代理服务调用 APIMart OpenAI-compatible `/v1/chat/completions`

### 本地运行和构建

生成 Xcode 工程：

```bash
xcodegen generate
```

构建 Debug 版本：

```bash
xcodebuild -project LightTranslator.xcodeproj -scheme LightTranslator -configuration Debug -derivedDataPath .build/DerivedData build CODE_SIGNING_ALLOWED=NO
```

打开菜单栏 App，并强制显示翻译窗口：

```bash
open -n .build/DerivedData/Build/Products/Debug/轻译.app --args --show-translator
```

### 本地代理服务

当前本地代理默认监听：

```text
127.0.0.1:8791
```

启动命令：

```bash
cd /Users/a1234/Documents/轻译
APIMART_API_KEY='真实 key 不要写入仓库' PORT=8791 HOST=127.0.0.1 node server/src/index.js
```

本地代理接口：

```text
GET  /health
GET  /api/models
POST /api/translate
```

`.env` 和真实 API Key 不应写入仓库。`server/.env.example` 只放占位 key。

### 已实现功能

- 菜单栏常驻 App，无 Dock 图标
- 全局快捷键唤起翻译浮窗
- 翻译浮窗包含输入框、语言选择、Enter 翻译、结果区、复制、朗读
- 自动语言方向：主要中文译英文，主要英文译中文
- 设置页支持模型选择、快捷键、是否打开时读取剪贴板
- 设置页已改为操作即保存，无保存按钮
- 模型选择为单选，并带图标和一句描述
- 翻译结果标题会显示当前模型名，例如 `GPT 翻译`

当前客户端模型映射：

| 客户端模型 | 上游模型 |
| --- | --- |
| `GPT` | `gpt-5.4-nano` |
| `DeepSeek-V4` | `deepseek-v4-flash` |
| `Gemini-3.5` | `gemini-3.5-flash` |

模型图标位于 `Assets.xcassets`。

### 关键文件

- `LightTranslator/Core/TranslationModel.swift`
- `LightTranslator/Core/AppSettings.swift`
- `LightTranslator/Services/AppSettingsStore.swift`
- `LightTranslator/Services/TranslationService.swift`
- `LightTranslator/UI/Settings/SettingsView.swift`
- `LightTranslator/UI/Settings/SettingsViewModel.swift`
- `LightTranslator/UI/Translation/TranslationView.swift`
- `LightTranslator/UI/Translation/TranslationViewModel.swift`
- `server/src/index.js`
- `docs/PHASE_2_COMMERCIALIZATION.md`

### 当前仓库注意事项

- 仓库有大量未提交改动，后续开发不要回退他人或历史未提交改动
- 新增商业化能力时，优先保持现有本地代理模式可用
- 客户端不能写入、缓存或打包真实上游大模型 API Key

## 15. 服务器部署上下文

### SSH 连接

服务器：

```text
ubuntu@45.43.57.11
```

本机已有 SSH key：

```bash
ssh -i ~/.ssh/hotwell_codex_ed25519 -o IdentitiesOnly=yes ubuntu@45.43.57.11
```

不要把私钥内容发出去。如果对方在同一台 Mac 上操作，用上面这个本地 key 路径即可。

### 现有线上项目

服务器上已有项目必须保持不受影响。

#### 图火 tuhuo-image

- 域名：`https://tuhuo3.com`
- 部署目录：`/var/www/tuhuo-image`
- systemd：`tuhuo-image.service`
- 本地端口：`127.0.0.1:8790`
- Nginx 配置：`/etc/nginx/conf.d/tuhuo-image.conf`
- 静态目录：`/var/www/tuhuo-image/dist/client`

#### hotwell / hooowell

- 部署目录：`/var/www/hotwell`
- systemd：`hotwell-api.service`
- 端口：`*:8787`
- 不要覆盖 `/var/www/hotwell`
- 不要复用或重启 `hotwell-api.service`

#### openclaw

不要停止、重启或修改：

- `openclaw`
- `openclaw-gateway`

保持以下端口不受影响：

- `127.0.0.1:18789`
- `127.0.0.1:18791`
- `127.0.0.1:40071`
- UDP `5353`

### 新项目部署隔离要求

轻译商业化后端或官网部署到该服务器时，必须和现有项目隔离：

- 新建独立目录，例如 `/var/www/light-translator`
- 新建独立 systemd service，例如 `light-translator.service`
- 使用新的本地端口，例如从 `127.0.0.1:8791` 往后选择
- 部署前先用 `ss -lntup` 查端口占用
- 新建独立 Nginx 配置，例如 `/etc/nginx/conf.d/light-translator.conf`
- 只 reload Nginx，不重启其他业务

部署前建议检查：

```bash
hostname
uptime
free -h
df -h /
systemctl is-active tuhuo-image.service hotwell-api.service openclaw-gateway.service
ss -lntup
ls -la /var/www
```

Nginx 变更后只执行：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 禁止操作

明确不要做：

- 不要 `rm -rf /var/www/hotwell`
- 不要覆盖 `/var/www/tuhuo-image`
- 不要改 `/etc/nginx/conf.d/tuhuo-image.conf`，除非任务就是改图火
- 不要停止或重启 `hotwell-api.service`
- 不要停止或重启 `openclaw`
- 不要停止或重启 `openclaw-gateway`
- 不要复用端口 `8787`
- 不要复用端口 `8790`
- 不要复用端口 `18789`
- 不要复用端口 `18791`
- 不要复用端口 `40071`
- 不要复用 UDP `5353`

### 当前服务器资源概况

- 2 vCPU
- 3.8GiB RAM
- 磁盘 77G，已用约 11G
- 当前负载很低
- 可以再跑一个小项目，但要使用独立端口、目录、systemd service 和 Nginx 配置

## 16. 商业化开发优先级补充

下一步应优先补齐：

- 账号登录
- 订阅状态
- token Keychain 存储
- 后端鉴权
- 用量统计
- 套餐接口
- 支付申报接口

推荐先把本地代理升级为商业化后端雏形：

```text
现有 /api/translate
-> 增加用户 access token 校验
-> 查询订阅状态
-> 计算和记录用量
-> 调用 APIMart
-> 返回翻译结果和剩余额度
```

这样可以最大限度复用当前客户端翻译流程，同时逐步接入登录、订阅和后台审核。
