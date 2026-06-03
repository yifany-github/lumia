import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

const geminiAPIKey = defineSecret("GEMINI_API_KEY");
const region = "us-central1";
const model = process.env.GEMINI_MODEL || "gemini-3-flash-preview";
const liveModel = process.env.GEMINI_LIVE_MODEL || "gemini-3.1-flash-live-preview";
const promptVersion = "lumia-ai-v4-natural-continuity";
const quotaVersion = "lumia-quota-v1";

const quotaLimits = {
  freeAIChatDaily: 20,
  freeVoiceDailySeconds: 5 * 60,
  premiumVoiceMonthlySeconds: 300 * 60
};

type Role = "user" | "model";

interface ChatMessage {
  role: Role;
  text: string;
}

interface JournalEntryPayload {
  date?: string;
  mood?: string;
  content: string;
}

interface GatewayRequest {
  feature: string;
  payload?: Record<string, unknown>;
}

interface EntitlementSnapshot {
  tier: "free" | "premium";
  status: "unknown" | "active" | "trialing" | "grace_period" | "expired" | "cancelled" | "billing_issue";
  hasPremiumAccess: boolean;
}

interface UsageSnapshot {
  dailyKey: string;
  monthlyKey: string;
  aiChatRepliesToday: number;
  liveCallSecondsToday: number;
  liveCallSecondsThisMonth: number;
  limits: typeof quotaLimits;
}

interface QuotaSnapshot {
  hasPremiumAccess: boolean;
  aiChatRemainingToday: number | null;
  voiceRemainingSeconds: number;
  usage: UsageSnapshot;
}

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
    };
  }>;
}

interface TherapistProfile {
  id: string;
  displayName: string;
  role: string;
  identity: string;
  method: string;
  voice: string;
  memoryFocus: string;
  avoid: string;
}

const therapistProfiles: Record<string, TherapistProfile> = {
  willow: {
    id: "willow",
    displayName: "Dr. Willow",
    role: "Growth & Structure",
    identity: "A grounded practical support guide using CBT-informed reflection.",
    method: "Name the pattern, separate facts from interpretations, and end with one small workable step.",
    voice: "Calm, direct, warm, and structured. Prefer short paragraphs and plain language.",
    memoryFocus: "Prioritize repeated stressors, cognitive patterns, action items, avoidance loops, and plans from prior Willow sessions.",
    avoid: "Do not become overly poetic or generic. Do not offer long lists."
  },
  serena: {
    id: "serena",
    displayName: "Serena",
    role: "Warmth & Empathy",
    identity: "A warm emotional support companion centered on validation and safety.",
    method: "Reflect the feeling first, then invite one gentle next sentence only if the user has room.",
    voice: "Soft, patient, emotionally precise, and low-pressure.",
    memoryFocus: "Prioritize emotional tone, loneliness, hurt, overwhelm, comfort needs, and prior moments where the user felt seen.",
    avoid: "Do not rush into problem solving. Do not sound clinical."
  },
  atlas: {
    id: "atlas",
    displayName: "Atlas",
    role: "Perspective & Stoicism",
    identity: "A steady perspective guide for resilience and what remains within the user's control.",
    method: "Separate what happened, what it means, what is controllable, and what can be released.",
    voice: "Sparse, steady, grounded, and respectful.",
    memoryFocus: "Prioritize recurring fears, difficult choices, control boundaries, and values named in prior Atlas sessions.",
    avoid: "Do not minimize pain. Do not quote philosophy at length."
  },
  nimbus: {
    id: "nimbus",
    displayName: "Nimbus",
    role: "Mindfulness & Flow",
    identity: "A mindfulness guide for anxiety, breath, sleep, and body tension.",
    method: "Slow the exchange down, use grounding, and ask one sensory question at a time.",
    voice: "Slow, concrete, spacious, and soothing.",
    memoryFocus: "Prioritize anxiety, sleep, breath, restlessness, bodily tension, and grounding practices that helped before.",
    avoid: "Do not over-explain mindfulness. Do not turn every reply into an exercise."
  },
  nova: {
    id: "nova",
    displayName: "Nova",
    role: "Purpose & Drive",
    identity: "A motivation and purpose coach for burnout, procrastination, and restarting momentum.",
    method: "Find the smallest next action and reduce pressure around starting.",
    voice: "Bright, practical, encouraging, and not pushy.",
    memoryFocus: "Prioritize stalled goals, energy, work pressure, small wins, and plans that the user previously chose.",
    avoid: "Do not use hype, hustle language, or toxic positivity."
  },
  eden: {
    id: "eden",
    displayName: "Eden",
    role: "Connection & Harmony",
    identity: "A relationship and boundaries guide for communication, repair, and self-respect.",
    method: "Clarify needs, boundaries, repair options, and possible words the user can actually say.",
    voice: "Gentle, honest, relational, and clear.",
    memoryFocus: "Prioritize relationship themes, recurring conflict, boundaries, family or partner dynamics, and prior scripts.",
    avoid: "Do not assign blame or diagnose other people."
  },
  orion: {
    id: "orion",
    displayName: "Orion",
    role: "Logic & Clarity",
    identity: "A clarity guide using Socratic questioning and structured reasoning.",
    method: "Identify assumptions, missing facts, competing interpretations, and a cleaner decision frame.",
    voice: "Precise, concise, analytical, and calm.",
    memoryFocus: "Prioritize decisions, confusion, evidence checks, assumptions, and unresolved questions from prior Orion sessions.",
    avoid: "Do not sound cold. Do not turn support into debate."
  },
  luna: {
    id: "luna",
    displayName: "Luna",
    role: "Dreams & Depth",
    identity: "A reflective creativity guide for symbols, dreams, meaning, and inner patterns.",
    method: "Explore imagery and meaning while keeping the user's real life anchored.",
    voice: "Intuitive, reflective, lightly poetic, and grounded.",
    memoryFocus: "Prioritize creative blocks, dreams, images, memories, and symbols the user returned to before.",
    avoid: "Do not become mystical to the point of vagueness. Do not claim certainty about symbols."
  }
};

const baseSafetyPolicy = `
Lumia product and safety rules:
- Provide emotional support and self-help reflection, not diagnosis, treatment, medical advice, or emergency care.
- Do not claim to detect mental illness.
- If the user expresses self-harm, suicide, immediate danger, or inability to stay safe, prioritize emergency/crisis resources and nearby human support.
- Keep responses concise, warm, and practical.
`;

function sendJSON(res: Parameters<Parameters<typeof onRequest>[0]>[1], status: number, body: unknown) {
  res.status(status).json(body);
}

function parseBearerToken(header: string | undefined): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length).trim();
}

async function requireUser(req: Parameters<Parameters<typeof onRequest>[0]>[0]) {
  const token = parseBearerToken(req.header("Authorization"));
  if (!token) {
    throw Object.assign(new Error("Missing Firebase Auth token."), { status: 401 });
  }
  return getAuth().verifyIdToken(token);
}

async function getEntitlementSnapshot(uid: string): Promise<EntitlementSnapshot> {
  const snapshot = await getFirestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc("subscription")
    .get();
  const data = snapshot.data() ?? {};
  const tier = data.tier === "premium" ? "premium" : "free";
  const status = typeof data.status === "string" ? data.status : "unknown";
  const hasPremiumAccess = tier === "premium" && ["active", "trialing", "grace_period"].includes(status);
  return {
    tier,
    status: status as EntitlementSnapshot["status"],
    hasPremiumAccess
  };
}

function requiresPremium(feature: string): boolean {
  return ["generateDeepInsights", "analyzeDistortions", "advancedMemory", "memoryContext"].includes(feature);
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asMessages(value: unknown): ChatMessage[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const object = item as Record<string, unknown>;
      const role = object.role === "user" ? "user" : "model";
      const text = asString(object.text).trim();
      return text ? { role, text } : null;
    })
    .filter((item): item is ChatMessage => item !== null);
}

function asJournalEntries(value: unknown): JournalEntryPayload[] {
  if (!Array.isArray(value)) return [];
  const entries: JournalEntryPayload[] = [];
  for (const item of value) {
    if (!item || typeof item !== "object") continue;
    const object = item as Record<string, unknown>;
    const content = asString(object.content).trim();
    if (!content) continue;
    entries.push({
      date: asString(object.date),
      mood: asString(object.mood),
      content
    });
  }
  return entries;
}

function safeTimeZone(value: unknown): string {
  if (typeof value !== "string" || !value.trim()) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value });
    return value;
  } catch {
    return "UTC";
  }
}

function datePartsKey(timeZone: string, parts: Array<Intl.DateTimeFormatPart>, includeDay: boolean): string {
  const year = parts.find((part) => part.type === "year")?.value ?? "0000";
  const month = parts.find((part) => part.type === "month")?.value ?? "00";
  if (!includeDay) return `${year}-${month}`;
  const day = parts.find((part) => part.type === "day")?.value ?? "00";
  return `${year}-${month}-${day}`;
}

function dayKey(timeZone: string, date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);
  return datePartsKey(timeZone, parts, true);
}

function monthKey(timeZone: string, date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit"
  }).formatToParts(date);
  return datePartsKey(timeZone, parts, false);
}

function numberFrom(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function normalizedUsage(raw: Record<string, unknown> | undefined, timeZone: string): UsageSnapshot {
  const today = dayKey(timeZone);
  const month = monthKey(timeZone);
  const currentDailyKey = typeof raw?.dailyKey === "string" ? raw.dailyKey : today;
  const currentMonthlyKey = typeof raw?.monthlyKey === "string" ? raw.monthlyKey : month;
  return {
    dailyKey: today,
    monthlyKey: month,
    aiChatRepliesToday: currentDailyKey === today ? Math.max(0, Math.floor(numberFrom(raw?.aiChatRepliesToday))) : 0,
    liveCallSecondsToday: currentDailyKey === today ? Math.max(0, Math.floor(numberFrom(raw?.liveCallSecondsToday))) : 0,
    liveCallSecondsThisMonth: currentMonthlyKey === month ? Math.max(0, Math.floor(numberFrom(raw?.liveCallSecondsThisMonth))) : 0,
    limits: quotaLimits
  };
}

function quotaSnapshot(entitlement: EntitlementSnapshot, usage: UsageSnapshot): QuotaSnapshot {
  const voiceLimit = entitlement.hasPremiumAccess
    ? quotaLimits.premiumVoiceMonthlySeconds
    : quotaLimits.freeVoiceDailySeconds;
  const voiceUsed = entitlement.hasPremiumAccess
    ? usage.liveCallSecondsThisMonth
    : usage.liveCallSecondsToday;
  return {
    hasPremiumAccess: entitlement.hasPremiumAccess,
    aiChatRemainingToday: entitlement.hasPremiumAccess
      ? null
      : Math.max(0, quotaLimits.freeAIChatDaily - usage.aiChatRepliesToday),
    voiceRemainingSeconds: Math.max(0, voiceLimit - voiceUsed),
    usage
  };
}

function quotaError(message: string, quota: QuotaSnapshot) {
  return Object.assign(new Error(message), {
    status: 429,
    code: "quota_exceeded",
    quota
  });
}

async function readQuota(uid: string, entitlement: EntitlementSnapshot, payload: Record<string, unknown>): Promise<QuotaSnapshot> {
  const timeZone = safeTimeZone(payload.clientTimeZone);
  const ref = getFirestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc("subscription");
  const snapshot = await ref.get();
  const usage = normalizedUsage(snapshot.data()?.usage as Record<string, unknown> | undefined, timeZone);
  return quotaSnapshot(entitlement, usage);
}

async function consumeQuota(
  uid: string,
  entitlement: EntitlementSnapshot,
  feature: string,
  payload: Record<string, unknown>
): Promise<QuotaSnapshot> {
  const timeZone = safeTimeZone(payload.clientTimeZone);
  const ref = getFirestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc("subscription");

  return getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.data() ?? {};
    const nextUsage = normalizedUsage(current.usage as Record<string, unknown> | undefined, timeZone);
    let changed = false;

    if (feature === "therapyChat" && !entitlement.hasPremiumAccess) {
      if (nextUsage.aiChatRepliesToday >= quotaLimits.freeAIChatDaily) {
        throw quotaError("Today's free AI replies are used. You can continue tomorrow or upgrade for longer support.", quotaSnapshot(entitlement, nextUsage));
      }
      nextUsage.aiChatRepliesToday += 1;
      changed = true;
    }

    if (feature === "recordVoiceUsage") {
      const seconds = Math.max(0, Math.ceil(numberFrom(payload.seconds)));
      if (seconds > 0) {
        const currentQuota = quotaSnapshot(entitlement, nextUsage);
        if (currentQuota.voiceRemainingSeconds <= 0) {
          throw quotaError("Your voice time is used for this period. Text chat is still available.", currentQuota);
        }
        const allowedSeconds = Math.min(seconds, currentQuota.voiceRemainingSeconds);
        nextUsage.liveCallSecondsToday += allowedSeconds;
        nextUsage.liveCallSecondsThisMonth += allowedSeconds;
        changed = true;
      }
    }

    const nextQuota = quotaSnapshot(entitlement, nextUsage);
    if (feature === "startLiveCall" && nextQuota.voiceRemainingSeconds <= 0) {
      throw quotaError("Your voice time is used for this period. Text chat is still available.", nextQuota);
    }

    if (changed || !snapshot.exists) {
      transaction.set(ref, {
        schemaVersion: 1,
        tier: entitlement.tier,
        status: entitlement.status,
        usage: nextUsage,
        quotaVersion,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    }

    return nextQuota;
  });
}

function therapistProfileFor(id: string, fallbackName: string): TherapistProfile {
  const normalizedID = id.trim().toLowerCase();
  return therapistProfiles[normalizedID] ?? {
    id: normalizedID || "willow",
    displayName: fallbackName || "Dr. Willow",
    role: "Emotional Support",
    identity: "A steady emotional support guide.",
    method: "Listen first, reflect briefly, and offer one practical next step only when useful.",
    voice: "Warm, clear, concise, and respectful.",
    memoryFocus: "Prioritize recent user concerns and prior support that seemed useful.",
    avoid: "Do not sound generic or overconfident."
  };
}

function stripReasonCodes(text: string): string {
  return text.replace(/\s*Reason codes:\s*[^.\n]+\.?/gi, ".");
}

function sanitizeContextForGuide(raw: string, profile: TherapistProfile): string {
  const compact = stripReasonCodes(raw)
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => {
      const lower = line.toLowerCase();
      const guideNames = [
        profile.id.toLowerCase(),
        profile.displayName.toLowerCase(),
        profile.displayName.replace(/^dr\.?\s+/i, "").toLowerCase()
      ].filter(Boolean);
      const journalMetadataLine =
        lower.startsWith("- recurring themes:") ||
        lower.startsWith("- latest journal signal:") ||
        lower.startsWith("- useful reflections:") ||
        lower.startsWith("- saved action items:");
      return !(journalMetadataLine && guideNames.some((name) => lower.includes(name)));
    })
    .join("\n");
  return compact.slice(0, 3_600);
}

function stripJSONFences(text: string): string {
  return text
    .trim()
    .replace(/^```json/i, "")
    .replace(/^```/i, "")
    .replace(/```$/i, "")
    .trim();
}

function safeParseJSON<T>(text: string): T {
  return JSON.parse(stripJSONFences(text)) as T;
}

async function generateGeminiText(params: {
  apiKey: string;
  userPrompt: string;
  systemInstruction?: string;
  jsonMode?: boolean;
}): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${params.apiKey}`;
  const body: Record<string, unknown> = {
    contents: [
      {
        role: "user",
        parts: [{ text: params.userPrompt }]
      }
    ]
  };

  if (params.systemInstruction) {
    body.systemInstruction = {
      parts: [{ text: params.systemInstruction }]
    };
  }

  if (params.jsonMode) {
    body.generationConfig = {
      response_mime_type: "application/json"
    };
  }

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });

  const raw = await response.text();
  if (!response.ok) {
    throw Object.assign(new Error(raw || `Gemini request failed with ${response.status}.`), {
      status: 502
    });
  }

  const parsed = JSON.parse(raw) as GeminiResponse;
  const text = parsed.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!text) {
    throw Object.assign(new Error("Gemini returned an empty response."), { status: 502 });
  }
  return text;
}

async function handleFeature(feature: string, payload: Record<string, unknown>, apiKey: string) {
  switch (feature) {
    case "runtimeConfig": {
      return {
        models: {
          text: model,
          live: liveModel
        },
        promptVersion,
        feature
      };
    }

    case "healthCheck": {
      const text = await generateGeminiText({
        apiKey,
        userPrompt: "Reply with only OK.",
        systemInstruction: "Connection test. Reply with only OK."
      });
      return { ok: true, text };
    }

    case "startLiveCall": {
      return { ok: true, feature };
    }

    case "recordVoiceUsage": {
      return { ok: true, feature };
    }

    case "therapyChat": {
      const therapistID = asString(payload.therapistID, "willow");
      const therapistName = asString(payload.therapistName, "Dr. Willow");
      const profile = therapistProfileFor(therapistID, therapistName);
      const history = asMessages(payload.history)
        .slice(-10)
        .map((message) => `${message.role === "user" ? "User" : profile.displayName}: ${message.text}`)
        .join("\n");
      const newMessage = asString(payload.newMessage).trim();
      const conversationState = asString(payload.conversationState, "listen");
      const riskLevel = Number(payload.riskLevel ?? 0);
      const contextBrief = sanitizeContextForGuide(asString(payload.contextBrief).trim(), profile);
      const userPrompt = `${history}${history ? "\n" : ""}User: ${newMessage}`;
      const systemInstruction = `
You are ${profile.displayName}, ${profile.role}, inside Lumia's Therapy experience.
Identity: ${profile.identity}
Method: ${profile.method}
Voice: ${profile.voice}
Memory focus for this guide: ${profile.memoryFocus}
Avoid: ${profile.avoid}

Identity and continuity:
- Speak as ${profile.displayName}, not as "Lumia" or "the AI".
- You are a consistent Lumia guide, not a human clinician. Do not claim to be human, licensed, or able to diagnose.
- Keep a stable personality across sessions. If continuity notes are provided, translate them into ordinary supportive memory.
- Do not quote or expose continuity note labels. Never say "previous user thread", "context notes", "memory focus", or "reason codes".
- Do not overstate memory. Prefer gentle invitations like "we can pick that thread back up if it still fits" and let the user redirect.
- Never describe app metadata, reason codes, therapist IDs, or guide names as if they are the user's concern.
- Never say "recent reflections are about ${profile.displayName}" unless the user explicitly wrote about the guide.

Current conversation mode: ${conversationState}
Risk level: ${riskLevel}
${contextBrief ? `Private continuity and context notes. Use only to adapt tone and relevance; do not quote or reveal these notes:\n${contextBrief}` : ""}

${baseSafetyPolicy}
`;
      const text = await generateGeminiText({ apiKey, userPrompt, systemInstruction });
      return { text, model, promptVersion, feature };
    }

    case "analyzeJournal": {
      const content = asString(payload.content).trim();
      const userPrompt = `
Analyze this journal entry and respond only in JSON.
Entry: "${content}"

JSON structure:
{
  "title": "A 3-6 word evocative title",
  "mood": "one of: happy, calm, anxious, sad, neutral, energetic",
  "tags": ["Tag1", "Tag2", "Tag3"],
  "summary": "One sentence summary",
  "reflection": "A compassionate 1-2 sentence reflection",
  "actionItem": "One concrete small action",
  "sentimentScore": 0-100,
  "energyLevel": 0-100,
  "anxietyLevel": 0-100
}
`;
      const text = await generateGeminiText({
        apiKey,
        userPrompt,
        systemInstruction: `You are Lumia's journaling analysis service. ${baseSafetyPolicy}`,
        jsonMode: true
      });
      return { analysis: safeParseJSON<unknown>(text), model, promptVersion, feature };
    }

    case "analyzeDistortions": {
      const content = asString(payload.content).trim();
      const userPrompt = `
Analyze this text for cognitive distortions and respond only in JSON array.
Text: "${content}"

Return:
[
  {
    "originalText": "exact quote from the text",
    "type": "Distortion name",
    "explanation": "Brief explanation",
    "reframes": [
      {"perspective": "rational", "text": "A rational reframe"},
      {"perspective": "compassionate", "text": "A compassionate reframe"},
      {"perspective": "stoic", "text": "A stoic reframe"}
    ]
  }
]
If no distortions are found, return [].
`;
      const text = await generateGeminiText({
        apiKey,
        userPrompt,
        systemInstruction: `You are Lumia's CBT reframing service. ${baseSafetyPolicy}`,
        jsonMode: true
      });
      return { distortions: safeParseJSON<unknown>(text), model, promptVersion, feature };
    }

    case "analyzeSentiment": {
      const history = asMessages(payload.history)
        .slice(-12)
        .map((message) => `${message.role === "user" ? "User" : "Therapist"}: ${message.text}`)
        .join("\n");
      const userPrompt = `
Analyze this conversation and return only JSON with 4 scores from 0-100:
${history}

JSON: {"wellness": 0-100, "clarity": 0-100, "calm": 0-100, "energy": 0-100}
`;
      const text = await generateGeminiText({
        apiKey,
        userPrompt,
        systemInstruction: "You score emotional support conversations conservatively. Return JSON only.",
        jsonMode: true
      });
      return { metrics: safeParseJSON<unknown>(text), model, promptVersion, feature };
    }

    case "generateDeepInsights": {
      const entries = asJournalEntries(payload.entries).slice(0, 7);
      const historyText = entries.map((entry) => `[${entry.date ?? ""}] Mood: ${entry.mood ?? ""} | ${entry.content}`).join("\n");
      const userPrompt = `
Analyze these journal entries and return only JSON:
${historyText}

JSON structure:
{
  "triggers": [
    {"trigger": "...", "effect": "...", "suggestion": "..."}
  ],
  "wrapped": {
    "lowPointsOvercome": 0-10,
    "topPositiveWords": ["word1", "word2", "word3"],
    "summary": "Warm encouraging summary",
    "growthArea": "Area of most growth"
  }
}
`;
      const text = await generateGeminiText({
        apiKey,
        userPrompt,
        systemInstruction: `You are Lumia's psychological data insight service. ${baseSafetyPolicy}`,
        jsonMode: true
      });
      return { insights: safeParseJSON<unknown>(text), model, promptVersion, feature };
    }

    default:
      throw Object.assign(new Error(`Unknown AI feature: ${feature}`), { status: 400 });
  }
}

export const aiGateway = onRequest(
  {
    region,
    secrets: [geminiAPIKey],
    timeoutSeconds: 60,
    memory: "512MiB",
    cors: true,
    invoker: "public"
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      sendJSON(res, 405, { error: { message: "Use POST." } });
      return;
    }

    try {
      const user = await requireUser(req);
      const body = req.body as GatewayRequest;
      const feature = asString(body.feature).trim();
      const payload = (body.payload ?? {}) as Record<string, unknown>;
      const entitlement = await getEntitlementSnapshot(user.uid);
      if (requiresPremium(feature) && !entitlement.hasPremiumAccess) {
        sendJSON(res, 402, {
          error: {
            message: "Lumia Plus is required for this feature.",
            code: "premium_required"
          },
          entitlement
        });
        return;
      }
      const quota = feature === "runtimeConfig" || feature === "healthCheck"
        ? await readQuota(user.uid, entitlement, payload)
        : await consumeQuota(user.uid, entitlement, feature, payload);
      const payloadForFeature = feature === "therapyChat" && !entitlement.hasPremiumAccess
        ? { ...payload, contextBrief: "" }
        : payload;
      const result = await handleFeature(feature, payloadForFeature, geminiAPIKey.value());

      await getFirestore().collection("aiRequests").add({
        uid: user.uid,
        feature,
        entitlementTier: entitlement.tier,
        quotaVersion,
        promptVersion,
        model,
        createdAt: FieldValue.serverTimestamp()
      });

      sendJSON(res, 200, {
        ...result,
        entitlement,
        quota,
        traceId: `${feature}-${Date.now()}`
      });
    } catch (error) {
      const status = typeof (error as { status?: unknown }).status === "number"
        ? (error as { status: number }).status
        : 500;
      const message = error instanceof Error ? error.message : "AI gateway failed.";
      const code = typeof (error as { code?: unknown }).code === "string"
        ? (error as { code: string }).code
        : undefined;
      const quota = (error as { quota?: unknown }).quota;
      sendJSON(res, status, { error: { message, code }, quota });
    }
  }
);
