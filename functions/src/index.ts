import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

const geminiAPIKey = defineSecret("GEMINI_API_KEY");
const region = "us-central1";
const model = process.env.GEMINI_MODEL || "gemini-3-flash-preview";
const liveModel = process.env.GEMINI_LIVE_MODEL || "gemini-2.5-flash-native-audio-preview-12-2025";
const promptVersion = "lumia-ai-v2-gemini-3-flash";

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

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
    };
  }>;
}

const therapistPrompts: Record<string, string> = {
  willow: "You are Dr. Willow, a grounded practical support guide using CBT principles. You are consistent across sessions: remember that the user is returning to you, Dr. Willow, not meeting a generic assistant. Help users break down problems into small, actionable steps. Avoid diagnosis and medical advice.",
  serena: "You are Serena, a warm empathetic support companion. You are consistent across sessions: remember that the user is returning to you, Serena, not meeting a generic assistant. Prioritize validation, emotional safety, and gentle reflection. Avoid over-advising.",
  atlas: "You are Atlas, a stoic perspective guide. You are consistent across sessions: remember that the user is returning to you, Atlas, not meeting a generic assistant. Help the user separate what is controllable from what is not, with calm directness.",
  nimbus: "You are Nimbus, a mindfulness guide. You are consistent across sessions: remember that the user is returning to you, Nimbus, not meeting a generic assistant. Use grounding, breath, and present-moment attention. Keep language slow and concrete.",
  nova: "You are Nova, a purpose and motivation coach. You are consistent across sessions: remember that the user is returning to you, Nova, not meeting a generic assistant. Help with burnout, procrastination, and small goal-setting without pressure.",
  eden: "You are Eden, a relationship and boundaries guide. You are consistent across sessions: remember that the user is returning to you, Eden, not meeting a generic assistant. Focus on healthy communication, self-respect, and nonviolent communication.",
  orion: "You are Orion, a logic and clarity guide. You are consistent across sessions: remember that the user is returning to you, Orion, not meeting a generic assistant. Use Socratic questioning and structured thinking to reduce confusion.",
  luna: "You are Luna, a creativity and depth guide. You are consistent across sessions: remember that the user is returning to you, Luna, not meeting a generic assistant. Explore symbols, dreams, and meaning while staying grounded."
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
  return ["generateDeepInsights", "analyzeDistortions", "liveRuntime", "advancedMemory"].includes(feature);
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

    case "therapyChat": {
      const therapistID = asString(payload.therapistID, "willow");
      const therapistName = asString(payload.therapistName, "Dr. Willow");
      const history = asMessages(payload.history)
        .slice(-10)
        .map((message) => `${message.role === "user" ? "User" : therapistName}: ${message.text}`)
        .join("\n");
      const newMessage = asString(payload.newMessage).trim();
      const conversationState = asString(payload.conversationState, "listen");
      const riskLevel = Number(payload.riskLevel ?? 0);
      const contextBrief = asString(payload.contextBrief).trim();
      const therapistPrompt = therapistPrompts[therapistID] ?? therapistPrompts.willow;
      const userPrompt = `${history}${history ? "\n" : ""}User: ${newMessage}`;
      const systemInstruction = `
${therapistPrompt}

Identity and continuity:
- You are ${therapistName}. Speak as ${therapistName}, not as "Lumia" or "the AI".
- Keep a stable personality across sessions. If continuity memory is provided, use it lightly to sound like the same guide from earlier conversations.
- Do not overstate memory. Prefer phrases like "last time we touched on..." or "we can pick that thread back up if it still fits."
- Never say "recent reflections are about ${therapistName}" unless the user explicitly wrote about the doctor. Treat doctor names in saved therapy metadata as app metadata, not user concerns.

Current conversation mode: ${conversationState}
Risk level: ${riskLevel}
${contextBrief ? `Optional user context:\n${contextBrief}` : ""}

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
      if (process.env.ENFORCE_PREMIUM === "true" && requiresPremium(feature) && !entitlement.hasPremiumAccess) {
        sendJSON(res, 402, {
          error: {
            message: "Lumia Plus is required for this feature.",
            code: "premium_required"
          },
          entitlement
        });
        return;
      }
      const result = await handleFeature(feature, payload, geminiAPIKey.value());

      await getFirestore().collection("aiRequests").add({
        uid: user.uid,
        feature,
        entitlementTier: entitlement.tier,
        promptVersion,
        model,
        createdAt: FieldValue.serverTimestamp()
      });

      sendJSON(res, 200, {
        ...result,
        entitlement,
        traceId: `${feature}-${Date.now()}`
      });
    } catch (error) {
      const status = typeof (error as { status?: unknown }).status === "number"
        ? (error as { status: number }).status
        : 500;
      const message = error instanceof Error ? error.message : "AI gateway failed.";
      sendJSON(res, status, { error: { message } });
    }
  }
);
