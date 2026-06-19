import http from "node:http";
import { createHmac, createHash } from "node:crypto";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

loadEnvFile(new URL("../.env", import.meta.url));

const host = process.env.HOST || "127.0.0.1";
const port = Number(process.env.PORT || 8791);
const apimartBaseURL =
  process.env.APIMART_BASE_URL || "https://api.apimart.ai/v1";
const apimartAPIKey = process.env.APIMART_API_KEY || "";
const volcengineAccessKeyID = process.env.VOLCENGINE_ACCESS_KEY_ID || "";
const volcengineSecretAccessKey = process.env.VOLCENGINE_SECRET_ACCESS_KEY || "";
const volcengineMonthlyCharacterLimit = Number(
  process.env.VOLCENGINE_MONTHLY_CHARACTER_LIMIT || 2_000_000,
);
const volcengineUsageFile =
  process.env.VOLCENGINE_USAGE_FILE ||
  new URL("../.data/volcengine-usage.json", import.meta.url).pathname;
const usageEventFile =
  process.env.USAGE_EVENT_FILE ||
  new URL("../.data/usage-events.jsonl", import.meta.url).pathname;
const analyticsSalt =
  process.env.ANALYTICS_SALT ||
  process.env.STATS_TOKEN ||
  volcengineSecretAccessKey ||
  "qingyi-local-development-salt";
const statsToken = process.env.STATS_TOKEN || "";
const maxBodyBytes = 128 * 1024;
const volcengineModelID = "volcengine-translate";
const translateWindowMs = envNumber("TRANSLATE_RATE_LIMIT_WINDOW_MS", 60_000);
const translateIPWindowRequestLimit = envNumber(
  "TRANSLATE_IP_WINDOW_REQUEST_LIMIT",
  30,
);
const translateInstallWindowRequestLimit = envNumber(
  "TRANSLATE_INSTALL_WINDOW_REQUEST_LIMIT",
  20,
);
const translateIPDailyRequestLimit = envNumber(
  "TRANSLATE_IP_DAILY_REQUEST_LIMIT",
  500,
);
const translateInstallDailyRequestLimit = envNumber(
  "TRANSLATE_INSTALL_DAILY_REQUEST_LIMIT",
  200,
);
const translateIPDailyCharacterLimit = envNumber(
  "TRANSLATE_IP_DAILY_CHARACTER_LIMIT",
  200_000,
);
const translateInstallDailyCharacterLimit = envNumber(
  "TRANSLATE_INSTALL_DAILY_CHARACTER_LIMIT",
  50_000,
);
const translateIPConcurrentLimit = envNumber("TRANSLATE_IP_CONCURRENT_LIMIT", 6);
const translateInstallConcurrentLimit = envNumber(
  "TRANSLATE_INSTALL_CONCURRENT_LIMIT",
  3,
);
const trustProxyHeaders = process.env.TRUST_PROXY_HEADERS === "true";
const allowedOrigins = new Set(
  (process.env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);
const translateRateLimitState = {
  windows: new Map(),
  days: new Map(),
  active: new Map(),
};

const models = [
  { id: volcengineModelID, displayName: "火山翻译", icon: "flame" },
  { id: "gpt-5.4-nano", displayName: "GPT 5.4 Nano", icon: "sparkles" },
  {
    id: "deepseek-v4-flash",
    displayName: "DeepSeek V4 Flash",
    icon: "bolt.circle",
  },
  { id: "gemini-3.5-flash", displayName: "Gemini 3.5 Flash", icon: "diamond" },
];

const modelIDs = new Set(models.map((model) => model.id));

const languageNames = {
  auto: "Auto",
  simplifiedChinese: "Simplified Chinese",
  english: "English",
};

const server = http.createServer(async (req, res) => {
  try {
    setCommonHeaders(req, res);

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(
      req.url || "/",
      `http://${req.headers.host || "localhost"}`,
    );

    if (req.method === "GET" && url.pathname === "/health") {
      sendJSON(res, 200, { ok: true });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/models") {
      sendJSON(res, 200, { models });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/stats/daily") {
      assertStatsAuthorized(req, url);
      sendJSON(res, 200, dailyUsageStats(url));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/translate") {
      const requestStartedAt = Date.now();
      const body = await readJSON(req);
      const payload = validateTranslateRequest(body);
      const rateLimitContext = assertTranslateAllowed(req, payload);
      let results = [];

      try {
        results = await Promise.all(
          payload.modelIds.map((modelId) => translateWithModel(modelId, payload)),
        );
      } finally {
        releaseTranslateConcurrency(rateLimitContext);
      }

      recordTranslateUsage(req, payload, results, Date.now() - requestStartedAt);
      sendJSON(res, 200, { results });
      return;
    }

    sendJSON(res, 404, { message: "Not found" });
  } catch (error) {
    const status = error.statusCode || 500;
    if (error.retryAfterSeconds) {
      res.setHeader("Retry-After", String(error.retryAfterSeconds));
    }
    sendJSON(res, status, {
      message: error.publicMessage || "Internal server error",
    });
  }
});

server.listen(port, host, () => {
  console.log(`qingyi-translate-api listening on http://${host}:${port}`);
});

function loadEnvFile(fileURL) {
  let content = "";

  try {
    content = readFileSync(fileURL, "utf8");
  } catch {
    return;
  }

  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    let value = trimmed.slice(separatorIndex + 1).trim();

    if (!key || process.env[key] !== undefined) {
      continue;
    }

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    process.env[key] = value;
  }
}

function envNumber(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function validateTranslateRequest(body) {
  const text = typeof body?.text === "string" ? body.text.trim() : "";
  if (!text) {
    throw publicError(400, "请输入要翻译的文本。");
  }

  if (text.length > 12000) {
    throw publicError(400, "文本过长，请缩短后重试。");
  }

  const modelIds = Array.isArray(body?.modelIds)
    ? body.modelIds.filter(
        (modelId) => typeof modelId === "string" && modelIDs.has(modelId),
      )
    : [];

  if (modelIds.length === 0) {
    throw publicError(400, "请至少选择一个可用模型。");
  }

  return {
    text,
    sourceLanguage: normalizeLanguage(body?.sourceLanguage),
    targetLanguage: normalizeLanguage(body?.targetLanguage),
    modelIds: [...new Set(modelIds)],
  };
}

function normalizeLanguage(value) {
  return languageNames[value] ? value : "auto";
}

function assertTranslateAllowed(req, payload) {
  const now = Date.now();
  const characters = countTextCharacters(payload.text);
  const dimensions = translateRateLimitDimensions(req);

  pruneTranslateRateLimitState(now);

  const checks = dimensions.map((dimension) => {
    const windowBucket = translateWindowBucket(dimension.key, now);
    const dayBucket = translateDayBucket(dimension.key);
    const activeCount = translateRateLimitState.active.get(dimension.key) || 0;

    return {
      dimension,
      windowBucket,
      dayBucket,
      activeCount,
    };
  });

  for (const check of checks) {
    const { dimension, windowBucket, dayBucket, activeCount } = check;

    if (activeCount >= dimension.concurrentLimit) {
      throw rateLimitError(
        "当前请求过多，请稍后再试。",
        10,
      );
    }

    if (windowBucket.requestCount + 1 > dimension.windowRequestLimit) {
      throw rateLimitError(
        "请求过于频繁，请稍后再试。",
        Math.ceil((windowBucket.resetAt - now) / 1000),
      );
    }

    if (dayBucket.requestCount + 1 > dimension.dailyRequestLimit) {
      throw rateLimitError("今日请求次数已达到上限，请明天再试。", secondsUntilTomorrow());
    }

    if (dayBucket.characterCount + characters > dimension.dailyCharacterLimit) {
      throw rateLimitError("今日翻译字符数已达到上限，请明天再试。", secondsUntilTomorrow());
    }
  }

  for (const check of checks) {
    check.windowBucket.requestCount += 1;
    check.dayBucket.requestCount += 1;
    check.dayBucket.characterCount += characters;
    translateRateLimitState.active.set(
      check.dimension.key,
      check.activeCount + 1,
    );
  }

  return {
    keys: checks.map((check) => check.dimension.key),
  };
}

function releaseTranslateConcurrency(context) {
  for (const key of context?.keys || []) {
    const nextCount = Math.max(0, (translateRateLimitState.active.get(key) || 0) - 1);
    if (nextCount === 0) {
      translateRateLimitState.active.delete(key);
    } else {
      translateRateLimitState.active.set(key, nextCount);
    }
  }
}

function translateRateLimitDimensions(req) {
  const ipKey = rateLimitKey("ip", clientIP(req));
  const installKey = anonymousInstallIDHash(req);
  const dimensions = [
    {
      key: ipKey,
      windowRequestLimit: translateIPWindowRequestLimit,
      dailyRequestLimit: translateIPDailyRequestLimit,
      dailyCharacterLimit: translateIPDailyCharacterLimit,
      concurrentLimit: translateIPConcurrentLimit,
    },
  ];

  if (installKey) {
    dimensions.push({
      key: `install:${installKey}`,
      windowRequestLimit: translateInstallWindowRequestLimit,
      dailyRequestLimit: translateInstallDailyRequestLimit,
      dailyCharacterLimit: translateInstallDailyCharacterLimit,
      concurrentLimit: translateInstallConcurrentLimit,
    });
  }

  return dimensions;
}

function translateWindowBucket(key, now) {
  const windowStart = Math.floor(now / translateWindowMs) * translateWindowMs;
  const resetAt = windowStart + translateWindowMs;
  const savedBucket = translateRateLimitState.windows.get(key);

  if (savedBucket?.windowStart === windowStart) {
    return savedBucket;
  }

  const bucket = {
    windowStart,
    resetAt,
    requestCount: 0,
  };
  translateRateLimitState.windows.set(key, bucket);
  return bucket;
}

function translateDayBucket(key) {
  const date = currentDateKey();
  const savedBucket = translateRateLimitState.days.get(key);

  if (savedBucket?.date === date) {
    return savedBucket;
  }

  const bucket = {
    date,
    requestCount: 0,
    characterCount: 0,
  };
  translateRateLimitState.days.set(key, bucket);
  return bucket;
}

function pruneTranslateRateLimitState(now) {
  const date = currentDateKey();

  for (const [key, bucket] of translateRateLimitState.windows) {
    if (bucket.resetAt <= now) {
      translateRateLimitState.windows.delete(key);
    }
  }

  for (const [key, bucket] of translateRateLimitState.days) {
    if (bucket.date !== date) {
      translateRateLimitState.days.delete(key);
    }
  }
}

function rateLimitKey(kind, value) {
  return `${kind}:${hmacHex(Buffer.from(analyticsSalt, "utf8"), value || "unknown")}`;
}

function clientIP(req) {
  if (trustProxyHeaders) {
    const forwardedFor = sanitizedHeader(req, "x-forwarded-for", 512)
      .split(",")
      .map((value) => value.trim())
      .find(Boolean);
    if (forwardedFor) {
      return forwardedFor;
    }

    const realIP = sanitizedHeader(req, "x-real-ip", 128);
    if (realIP) {
      return realIP;
    }
  }

  return req.socket.remoteAddress || "unknown";
}

function rateLimitError(publicMessage, retryAfterSeconds) {
  const error = publicError(429, publicMessage);
  error.retryAfterSeconds = Math.max(1, Number(retryAfterSeconds) || 1);
  return error;
}

async function translateWithModel(modelId, payload) {
  if (modelId === volcengineModelID) {
    return translateWithVolcengine(payload);
  }

  const startedAt = Date.now();

  if (!apimartAPIKey) {
    return {
      modelId,
      text: null,
      error: "翻译服务未配置上游 API Key。",
      latencyMs: Date.now() - startedAt,
    };
  }

  try {
    const response = await fetch(makeChatCompletionsURL(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apimartAPIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: modelId,
        stream: false,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content:
              "You are a professional translation engine. Only return the translated text. Do not explain, quote, or add notes.",
          },
          {
            role: "user",
            content: makePrompt(payload),
          },
        ],
      }),
    });

    const rawText = await response.text();
    const upstreamPayload = safeJSON(rawText);

    if (!response.ok) {
      return {
        modelId,
        text: null,
        error:
          extractErrorMessage(upstreamPayload) ||
          `Upstream HTTP ${response.status}`,
        latencyMs: Date.now() - startedAt,
      };
    }

    const translatedText = extractAssistantText(upstreamPayload);
    if (!translatedText) {
      return {
        modelId,
        text: null,
        error: "模型返回格式无法解析。",
        latencyMs: Date.now() - startedAt,
      };
    }

    return {
      modelId,
      text: translatedText,
      error: null,
      latencyMs: Date.now() - startedAt,
    };
  } catch {
    return {
      modelId,
      text: null,
      error: "模型请求失败。",
      latencyMs: Date.now() - startedAt,
    };
  }
}

async function translateWithVolcengine(payload) {
  const startedAt = Date.now();
  let reservedCharacters = 0;

  try {
    if (!volcengineAccessKeyID || !volcengineSecretAccessKey) {
      return {
        modelId: volcengineModelID,
        text: null,
        error: "火山翻译服务未配置密钥。",
        latencyMs: Date.now() - startedAt,
      };
    }

    const textCharacters = countTextCharacters(payload.text);
    if (textCharacters > 5000) {
      return {
        modelId: volcengineModelID,
        text: null,
        error: "火山翻译单次最多支持 5000 字符。",
        latencyMs: Date.now() - startedAt,
      };
    }

    const reservation = reserveVolcengineUsage(textCharacters);
    if (!reservation.ok) {
      return {
        modelId: volcengineModelID,
        text: null,
        error: `火山翻译本月免费额度已用完。本月已用 ${reservation.usage.usedCharacters} / ${volcengineMonthlyCharacterLimit} 字符。`,
        latencyMs: Date.now() - startedAt,
      };
    }
    reservedCharacters = textCharacters;

    const requestBody = {
      TargetLanguage: volcengineLanguageCode(payload.targetLanguage) || "zh",
      TextList: [payload.text],
    };
    const sourceLanguage = volcengineLanguageCode(payload.sourceLanguage);
    if (sourceLanguage) {
      requestBody.SourceLanguage = sourceLanguage;
    }

    const response = await fetch(
      "https://translate.volcengineapi.com/?Action=TranslateText&Version=2020-06-01",
      makeVolcengineRequestOptions(JSON.stringify(requestBody)),
    );
    const rawText = await response.text();
    const responsePayload = safeJSON(rawText);
    const upstreamError = responsePayload?.ResponseMetadata?.Error;

    if (!response.ok || upstreamError) {
      releaseVolcengineUsage(reservedCharacters);
      reservedCharacters = 0;
      return {
        modelId: volcengineModelID,
        text: null,
        error:
          upstreamError?.Message ||
          responsePayload?.message ||
          `火山翻译 HTTP ${response.status}`,
        latencyMs: Date.now() - startedAt,
      };
    }

    const translatedText = responsePayload?.TranslationList?.[0]?.Translation;
    if (typeof translatedText !== "string" || !translatedText.trim()) {
      releaseVolcengineUsage(reservedCharacters);
      reservedCharacters = 0;
      return {
        modelId: volcengineModelID,
        text: null,
        error: "火山翻译返回格式无法解析。",
        latencyMs: Date.now() - startedAt,
      };
    }

    return {
      modelId: volcengineModelID,
      text: translatedText.trim(),
      error: null,
      latencyMs: Date.now() - startedAt,
    };
  } catch {
    releaseVolcengineUsage(reservedCharacters);
    return {
      modelId: volcengineModelID,
      text: null,
      error: "火山翻译请求失败。",
      latencyMs: Date.now() - startedAt,
    };
  }
}

function makeVolcengineRequestOptions(body) {
  const host = "translate.volcengineapi.com";
  const path = "/";
  const queryString = "Action=TranslateText&Version=2020-06-01";
  const region = "cn-north-1";
  const service = "translate";
  const contentType = "application/json; charset=utf-8";
  const xDate = volcengineDateString(new Date());
  const shortDate = xDate.slice(0, 8);
  const payloadHash = sha256Hex(body);
  const signedHeaders = "host;x-date;x-content-sha256;content-type";
  const canonicalHeaders = [
    `host:${host}`,
    `x-date:${xDate}`,
    `x-content-sha256:${payloadHash}`,
    `content-type:${contentType}`,
  ].join("\n");
  const canonicalRequest = [
    "POST",
    path,
    queryString,
    `${canonicalHeaders}\n`,
    signedHeaders,
    payloadHash,
  ].join("\n");
  const credentialScope = `${shortDate}/${region}/${service}/request`;
  const stringToSign = [
    "HMAC-SHA256",
    xDate,
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join("\n");
  const signature = hmacHex(
    volcengineSigningKey(volcengineSecretAccessKey, shortDate, region, service),
    stringToSign,
  );
  const authorization = [
    `HMAC-SHA256 Credential=${volcengineAccessKeyID}/${credentialScope}`,
    `SignedHeaders=${signedHeaders}`,
    `Signature=${signature}`,
  ].join(", ");

  return {
    method: "POST",
    headers: {
      "Content-Type": contentType,
      "X-Date": xDate,
      "X-Content-Sha256": payloadHash,
      Authorization: authorization,
    },
    body,
  };
}

function volcengineLanguageCode(language) {
  if (language === "simplifiedChinese") {
    return "zh";
  }
  if (language === "english") {
    return "en";
  }
  return "";
}

function readVolcengineUsage() {
  const monthKey = currentMonthKey();

  try {
    const usage = JSON.parse(readFileSync(volcengineUsageFile, "utf8"));
    if (usage?.monthKey === monthKey && Number.isFinite(usage?.usedCharacters)) {
      return {
        monthKey,
        usedCharacters: Math.max(0, Number(usage.usedCharacters)),
      };
    }
  } catch {
    // Missing or invalid usage file starts a fresh current-month counter.
  }

  return { monthKey, usedCharacters: 0 };
}

function reserveVolcengineUsage(characters) {
  const usage = readVolcengineUsage();
  if (usage.usedCharacters + characters > volcengineMonthlyCharacterLimit) {
    return { ok: false, usage };
  }

  const nextUsage = {
    monthKey: usage.monthKey,
    usedCharacters: usage.usedCharacters + characters,
    monthlyLimit: volcengineMonthlyCharacterLimit,
    updatedAt: new Date().toISOString(),
  };
  writeVolcengineUsage(nextUsage);
  return { ok: true, usage: nextUsage };
}

function releaseVolcengineUsage(characters) {
  if (!characters) {
    return;
  }

  const usage = readVolcengineUsage();
  writeVolcengineUsage({
    monthKey: usage.monthKey,
    usedCharacters: Math.max(0, usage.usedCharacters - characters),
    monthlyLimit: volcengineMonthlyCharacterLimit,
    updatedAt: new Date().toISOString(),
  });
}

function writeVolcengineUsage(nextUsage) {
  mkdirSync(dirname(volcengineUsageFile), { recursive: true });
  writeFileSync(volcengineUsageFile, JSON.stringify(nextUsage, null, 2));
}

function recordTranslateUsage(req, payload, results, latencyMs) {
  const now = new Date();
  const successModelIds = results
    .filter((result) => !result.error && typeof result.text === "string" && result.text.trim())
    .map((result) => result.modelId);
  const failedModelIds = results
    .filter((result) => result.error)
    .map((result) => result.modelId);

  appendUsageEvent({
    event: "translate",
    timestamp: now.toISOString(),
    date: currentDateKey(now),
    installIdHash: anonymousInstallIDHash(req),
    appVersion: sanitizedHeader(req, "x-qingyi-app-version", 64),
    osVersion: sanitizedHeader(req, "x-qingyi-os-version", 96),
    modelIds: payload.modelIds,
    successModelIds,
    failedModelIds,
    sourceLanguage: payload.sourceLanguage,
    targetLanguage: payload.targetLanguage,
    characterCount: countTextCharacters(payload.text),
    latencyMs,
  });
}

function appendUsageEvent(event) {
  try {
    mkdirSync(dirname(usageEventFile), { recursive: true });
    appendFileSync(usageEventFile, `${JSON.stringify(event)}\n`);
  } catch (error) {
    console.warn(`Failed to write usage event: ${error.message}`);
  }
}

function anonymousInstallIDHash(req) {
  const installID = sanitizedHeader(req, "x-qingyi-install-id", 128);
  if (!/^[A-Za-z0-9._:-]{8,128}$/.test(installID)) {
    return null;
  }

  return hmacHex(Buffer.from(analyticsSalt, "utf8"), installID);
}

function sanitizedHeader(req, name, maxLength) {
  const value = req.headers[name];
  const rawValue = Array.isArray(value) ? value[0] : value;
  if (typeof rawValue !== "string") {
    return "";
  }

  return rawValue
    .replace(/[\r\n\t]/g, " ")
    .trim()
    .slice(0, maxLength);
}

function dailyUsageStats(url) {
  const requestedDays = Number(url.searchParams.get("days") || 30);
  const days = Number.isFinite(requestedDays)
    ? Math.min(365, Math.max(1, requestedDays))
    : 30;
  const aggregates = new Map();

  for (const event of readUsageEvents()) {
    if (event?.event !== "translate" || typeof event.date !== "string") {
      continue;
    }

    const day = usageDay(aggregates, event.date);
    day.requestCount += 1;
    day.characterCount += Math.max(0, Number(event.characterCount) || 0);

    if (event.installIdHash) {
      day.installIds.add(event.installIdHash);
      day.anonymousRequestCount += 1;
    }

    if (Array.isArray(event.successModelIds) && event.successModelIds.length > 0) {
      day.successCount += 1;
    } else {
      day.failureCount += 1;
    }

    for (const modelId of arrayOfStrings(event.modelIds)) {
      day.modelCounts[modelId] = (day.modelCounts[modelId] || 0) + 1;
    }

    if (typeof event.appVersion === "string" && event.appVersion) {
      day.appVersions[event.appVersion] = (day.appVersions[event.appVersion] || 0) + 1;
    }
  }

  const daily = [...aggregates.values()]
    .sort((a, b) => b.date.localeCompare(a.date))
    .slice(0, days)
    .map((day) => ({
      date: day.date,
      translationDAU: day.installIds.size,
      requestCount: day.requestCount,
      anonymousRequestCount: day.anonymousRequestCount,
      characterCount: day.characterCount,
      successCount: day.successCount,
      failureCount: day.failureCount,
      modelCounts: day.modelCounts,
      appVersions: day.appVersions,
    }));

  return {
    generatedAt: new Date().toISOString(),
    days,
    daily,
  };
}

function usageDay(aggregates, date) {
  if (!aggregates.has(date)) {
    aggregates.set(date, {
      date,
      installIds: new Set(),
      requestCount: 0,
      anonymousRequestCount: 0,
      characterCount: 0,
      successCount: 0,
      failureCount: 0,
      modelCounts: {},
      appVersions: {},
    });
  }

  return aggregates.get(date);
}

function readUsageEvents() {
  try {
    return readFileSync(usageEventFile, "utf8")
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => safeJSON(line))
      .filter(Boolean);
  } catch {
    return [];
  }
}

function arrayOfStrings(value) {
  return Array.isArray(value)
    ? value.filter((item) => typeof item === "string" && item)
    : [];
}

function countTextCharacters(text) {
  return Array.from(text).length;
}

function currentDateKey(date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function secondsUntilTomorrow() {
  return 24 * 60 * 60;
}

function currentMonthKey(date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}`;
}

function volcengineDateString(date) {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function sha256Hex(value) {
  return createHash("sha256").update(value).digest("hex");
}

function hmac(key, value) {
  return createHmac("sha256", key).update(value).digest();
}

function hmacHex(key, value) {
  return createHmac("sha256", key).update(value).digest("hex");
}

function volcengineSigningKey(secretAccessKey, shortDate, region, service) {
  const dateKey = hmac(Buffer.from(secretAccessKey, "utf8"), shortDate);
  const regionKey = hmac(dateKey, region);
  const serviceKey = hmac(regionKey, service);
  return hmac(serviceKey, "request");
}

function makePrompt(payload) {
  const sourceLanguage =
    languageNames[payload.sourceLanguage] || languageNames.auto;
  const targetLanguage =
    languageNames[payload.targetLanguage] || languageNames.auto;

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

function assertStatsAuthorized(req, url) {
  if (!statsToken) {
    throw publicError(404, "Not found");
  }

  const authorization = sanitizedHeader(req, "authorization", 512);
  const bearerToken = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  const queryToken = url.searchParams.get("token") || "";

  if (bearerToken !== statsToken && queryToken !== statsToken) {
    throw publicError(401, "Unauthorized");
  }
}

function setCommonHeaders(req, res) {
  const origin = sanitizedHeader(req, "origin", 512);
  if (origin && allowedOrigins.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
  }

  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Content-Type,Authorization,X-Qingyi-Install-Id,X-Qingyi-App-Version,X-Qingyi-OS-Version",
  );
}

function sendJSON(res, statusCode, body) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
  });
  res.end(JSON.stringify(body));
}

function publicError(statusCode, publicMessage) {
  const error = new Error(publicMessage);
  error.statusCode = statusCode;
  error.publicMessage = publicMessage;
  return error;
}
