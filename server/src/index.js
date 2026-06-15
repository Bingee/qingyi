import http from "node:http";

const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 8791);
const apimartBaseURL = process.env.APIMART_BASE_URL || "https://api.apimart.ai/v1";
const apimartAPIKey = process.env.APIMART_API_KEY || "";
const maxBodyBytes = 128 * 1024;

const models = [
  { id: "gpt-5.4-nano", displayName: "GPT 5.4 Nano", icon: "sparkles" },
  { id: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash", icon: "bolt.circle" },
  { id: "gemini-3.5-flash", displayName: "Gemini 3.5 Flash", icon: "diamond" }
];

const modelIDs = new Set(models.map((model) => model.id));

const languageNames = {
  auto: "Auto",
  simplifiedChinese: "Simplified Chinese",
  english: "English"
};

const server = http.createServer(async (req, res) => {
  try {
    setCommonHeaders(res);

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

    if (req.method === "GET" && url.pathname === "/health") {
      sendJSON(res, 200, { ok: true });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/models") {
      sendJSON(res, 200, { models });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/translate") {
      const body = await readJSON(req);
      const payload = validateTranslateRequest(body);
      const results = await Promise.all(
        payload.modelIds.map((modelId) => translateWithModel(modelId, payload))
      );

      sendJSON(res, 200, { results });
      return;
    }

    sendJSON(res, 404, { message: "Not found" });
  } catch (error) {
    const status = error.statusCode || 500;
    sendJSON(res, status, { message: error.publicMessage || "Internal server error" });
  }
});

server.listen(port, host, () => {
  console.log(`qingyi-translate-api listening on http://${host}:${port}`);
});

function validateTranslateRequest(body) {
  if (!apimartAPIKey) {
    throw publicError(500, "翻译服务未配置上游 API Key。");
  }

  const text = typeof body?.text === "string" ? body.text.trim() : "";
  if (!text) {
    throw publicError(400, "请输入要翻译的文本。");
  }

  if (text.length > 12000) {
    throw publicError(400, "文本过长，请缩短后重试。");
  }

  const modelIds = Array.isArray(body?.modelIds)
    ? body.modelIds.filter((modelId) => typeof modelId === "string" && modelIDs.has(modelId))
    : [];

  if (modelIds.length === 0) {
    throw publicError(400, "请至少选择一个可用模型。");
  }

  return {
    text,
    sourceLanguage: normalizeLanguage(body?.sourceLanguage),
    targetLanguage: normalizeLanguage(body?.targetLanguage),
    modelIds: [...new Set(modelIds)]
  };
}

function normalizeLanguage(value) {
  return languageNames[value] ? value : "auto";
}

async function translateWithModel(modelId, payload) {
  const startedAt = Date.now();

  try {
    const response = await fetch(makeChatCompletionsURL(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apimartAPIKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: modelId,
        stream: false,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content:
              "You are a professional translation engine. Only return the translated text. Do not explain, quote, or add notes."
          },
          {
            role: "user",
            content: makePrompt(payload)
          }
        ]
      })
    });

    const rawText = await response.text();
    const upstreamPayload = safeJSON(rawText);

    if (!response.ok) {
      return {
        modelId,
        text: null,
        error: extractErrorMessage(upstreamPayload) || `Upstream HTTP ${response.status}`,
        latencyMs: Date.now() - startedAt
      };
    }

    const translatedText = extractAssistantText(upstreamPayload);
    if (!translatedText) {
      return {
        modelId,
        text: null,
        error: "模型返回格式无法解析。",
        latencyMs: Date.now() - startedAt
      };
    }

    return {
      modelId,
      text: translatedText,
      error: null,
      latencyMs: Date.now() - startedAt
    };
  } catch {
    return {
      modelId,
      text: null,
      error: "模型请求失败。",
      latencyMs: Date.now() - startedAt
    };
  }
}

function makePrompt(payload) {
  const sourceLanguage = languageNames[payload.sourceLanguage] || languageNames.auto;
  const targetLanguage = languageNames[payload.targetLanguage] || languageNames.auto;

  return `Translate the following text into ${targetLanguage}.
Source language: ${sourceLanguage}.

Requirements:
- Preserve meaning, tone, punctuation, and formatting.
- Return only the translated text.

Text:
${payload.text}`;
}

function makeChatCompletionsURL() {
  const normalized = apimartBaseURL.replace(/\/+$/, "");
  if (normalized.endsWith("/chat/completions")) {
    return normalized;
  }

  if (normalized.endsWith("/v1")) {
    return `${normalized}/chat/completions`;
  }

  return `${normalized}/v1/chat/completions`;
}

function extractAssistantText(payload) {
  const choices = payload?.data?.choices || payload?.choices || [];
  const content = choices[0]?.message?.content;
  return typeof content === "string" ? content.trim() : "";
}

function extractErrorMessage(payload) {
  const message =
    payload?.error?.message ||
    payload?.message ||
    payload?.data?.error?.message ||
    payload?.data?.message;

  return typeof message === "string" ? message : "";
}

function safeJSON(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function readJSON(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    let size = 0;

    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      size += Buffer.byteLength(chunk);
      if (size > maxBodyBytes) {
        reject(publicError(413, "请求体过大。"));
        req.destroy();
        return;
      }

      raw += chunk;
    });
    req.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(publicError(400, "请求 JSON 格式不正确。"));
      }
    });
    req.on("error", reject);
  });
}

function setCommonHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type,Authorization");
}

function sendJSON(res, statusCode, body) {
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body));
}

function publicError(statusCode, publicMessage) {
  const error = new Error(publicMessage);
  error.statusCode = statusCode;
  error.publicMessage = publicMessage;
  return error;
}
