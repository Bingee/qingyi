# 轻译 AI 代理服务

轻译客户端通过这个服务使用默认火山翻译。火山 AK/SK、月额度和用量统计放在服务端，不写入客户端。

GPT / DeepSeek / Gemini 当前仍支持用户在客户端自填 OpenAI-compatible API 信息。

## 本地运行

```bash
cd server
cp .env.example .env
# 填入 VOLCENGINE_ACCESS_KEY_ID / VOLCENGINE_SECRET_ACCESS_KEY
# 如果仍要使用旧 APIMart 代理模型，再填 APIMART_API_KEY
npm start
```

健康检查：

```bash
curl http://127.0.0.1:8791/health
```

模型列表：

```bash
curl http://127.0.0.1:8791/api/models
```

翻译：

```bash
curl -X POST http://127.0.0.1:8791/api/translate \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello","sourceLanguage":"auto","targetLanguage":"simplifiedChinese","modelIds":["volcengine-translate"]}'
```

火山翻译用量默认写入 `server/.data/volcengine-usage.json`，每月按北京时间自动切换计数周期。

## 防滥用限流

`POST /api/translate` 会按客户端 IP 和匿名安装 ID 同时限流。默认配置：

```text
每 IP 每分钟 30 次请求
每安装每分钟 20 次请求
每 IP 每天 500 次请求 / 200000 字符
每安装每天 200 次请求 / 50000 字符
每 IP 最多 6 个并发请求
每安装最多 3 个并发请求
```

超过限制时返回 `429`，并带 `Retry-After`。如果服务部署在 Nginx、负载均衡或 CDN 后面，确认代理会覆盖外部传入的 `X-Forwarded-For` 后，再设置：

```bash
TRUST_PROXY_HEADERS=true
```

浏览器 CORS 默认不开放；如果有网页需要调用服务，设置逗号分隔的白名单：

```bash
ALLOWED_ORIGINS=https://qingyi.example.com
```

## 匿名使用统计

客户端启用“匿名使用统计”后，请求默认翻译服务时会发送随机安装 ID、App 版本和系统版本。服务端只保存安装 ID 的 HMAC hash、日期、模型、字符数、成功状态和耗时，不保存原文、译文或 API Key。

事件默认追加写入：

```text
server/.data/usage-events.jsonl
```

查询最近 30 天日活和请求量：

```bash
curl http://127.0.0.1:8791/api/stats/daily?days=30 \
  -H "Authorization: Bearer $STATS_TOKEN"
```

返回字段里 `translationDAU` 是当天至少调用过默认翻译服务的匿名安装数。用户改用自填 OpenAI-compatible API 时，请求不经过这个服务端，不会计入这里的 DAU。
