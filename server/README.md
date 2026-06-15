# 轻译 AI 代理服务

轻译客户端只连接这个服务，不保存上游模型 API Key。后续账号、订阅状态、模型额度和用量统计都应放在这一层。

## 本地运行

```bash
cd server
cp .env.example .env
# 填入 APIMART_API_KEY
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
  -d '{"text":"Hello","sourceLanguage":"auto","targetLanguage":"simplifiedChinese","modelIds":["gpt-5.4-nano"]}'
```
