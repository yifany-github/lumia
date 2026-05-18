
import { GoogleGenAI } from "@google/genai";
import { Distortion } from "../types";
import { auth } from "../firebase";

const firebaseProjectId = import.meta.env.VITE_FIREBASE_PROJECT_ID || "lumia-cd3d2";
const aiGatewayURL = `https://us-central1-${firebaseProjectId}.cloudfunctions.net/aiGateway`;
const textModel = import.meta.env.VITE_GEMINI_TEXT_MODEL || "gemini-3.1-pro-preview";
const ttsModel = import.meta.env.VITE_GEMINI_TTS_MODEL || "gemini-3.1-flash-tts-preview";

const getFirebaseToken = async (): Promise<string> => {
  const user = auth?.currentUser;
  if (!user) {
    throw new Error("SIGN_IN_REQUIRED");
  }
  return user.getIdToken();
};

const callAiGateway = async <T,>(feature: string, payload: Record<string, unknown>): Promise<T> => {
  const token = await getFirebaseToken();
  const response = await fetch(aiGatewayURL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`
    },
    body: JSON.stringify({ feature, payload })
  });

  const raw = await response.text();
  let json: any = {};
  try {
    json = raw ? JSON.parse(raw) : {};
  } catch {
    json = {};
  }

  if (!response.ok) {
    if (raw.trim().toLowerCase().startsWith("<html")) {
      if (response.status === 404) {
        throw new Error("Lumia AI is not deployed yet. Deploy the Firebase aiGateway function, then try again.");
      }
      if (response.status === 401 || response.status === 403) {
        throw new Error("Lumia AI is deployed but not callable yet. Redeploy aiGateway with public invoker access.");
      }
    }
    const message = json?.error?.message || json?.error || raw || `Lumia AI request failed (${response.status})`;
    throw new Error(message);
  }

  return json as T;
};

const friendlyAiError = (error: any): string => {
  if (error?.message === "SIGN_IN_REQUIRED") {
    return "ERROR_API_KEY_MISSING";
  }
  if (error?.name === 'TypeError' && error?.message?.includes('fetch')) {
    return "I'm having trouble connecting to Lumia AI. Please check your internet connection and try again.";
  }
  if (error?.name === 'AbortError' || error?.message?.includes('timeout')) {
    return "The request took too long to complete. Please try again.";
  }
  return "I apologize, I'm feeling a bit disconnected right now. Please try again in a moment.";
};

// Temporary direct client for image/audio experiments that are not yet routed
// through the production AI gateway.
const getAiClient = async (): Promise<GoogleGenAI> => {
  // We do not await window.aistudio.hasSelectedApiKey() here because it can hang the process
  // if the iframe communication is delayed. Instead, we directly use the injected environment variables.
  // process.env.API_KEY is the user-selected paid key (if any).
  // process.env.GEMINI_API_KEY is the default free key provided by the platform.
  const apiKey = process.env.API_KEY || process.env.GEMINI_API_KEY || '';
  
  if (!apiKey) {
    console.warn("[Lumia Debug] ⚠️ No API key found in environment variables.");
  }
  
  return new GoogleGenAI({ apiKey });
};

export const generateTherapistResponse = async (prompt: string, systemInstruction: string): Promise<string> => {
  try {
    const therapistMatch = systemInstruction.match(/You are\s+([^,.]+)/i);
    const therapistName = therapistMatch?.[1]?.trim() || "Lumia";
    const response = await callAiGateway<{ text?: string }>("therapyChat", {
      therapistID: therapistName.toLowerCase().replace(/^dr\.\s*/, "").split(/\s+/)[0] || "willow",
      therapistName,
      history: [],
      newMessage: prompt,
      conversationState: "listen",
      riskLevel: 0,
      contextBrief: ""
    });
    return response.text || "I'm having trouble finding the right words. Could you say that again?";
  } catch (error: any) {
    console.error("Lumia AI gateway error:", error);
    return friendlyAiError(error);
  }
};

export const analyzeChatSentiment = async (history: string): Promise<{
  wellness: number;
  clarity: number;
  calm: number;
  energy: number;
} | null> => {
  try {
    const response = await callAiGateway<{ metrics?: { wellness: number; clarity: number; calm: number; energy: number } }>("analyzeSentiment", {
      history: history.split('\n').filter(Boolean).map((line) => ({
        role: line.toLowerCase().startsWith('user') ? 'user' : 'model',
        text: line.replace(/^[^:]+:\s*/, '')
      }))
    });
    return response.metrics ?? null;
  } catch (error: any) {
    console.error("Sentiment analysis gateway error", error);
    return null;
  }
};

export const analyzeJournalEntry = async (content: string): Promise<{ 
  title: string; 
  mood: string; 
  tags: string[]; 
  summary: string; 
  reflection: string; 
  actionItem: string;
  sentimentScore: number;
  energyLevel: number;
  anxietyLevel: number;
} | null> => {
  try {
    const response = await callAiGateway<{ analysis?: {
      title: string;
      mood: string;
      tags: string[];
      summary: string;
      reflection: string;
      actionItem: string;
      sentimentScore: number;
      energyLevel: number;
      anxietyLevel: number;
    } }>("analyzeJournal", {
      content
    });
    return response.analysis ?? null;
  } catch (error: any) {
    console.error("Journal analysis gateway error:", error);
    throw new Error(error?.message === "SIGN_IN_REQUIRED" ? "Please sign in to use Lumia AI." : "Lumia AI could not analyze this entry right now.");
  }
};

export const analyzeDistortions = async (content: string): Promise<Distortion[]> => {
  try {
    const response = await callAiGateway<{ distortions?: Distortion[] }>("analyzeDistortions", { content });
    return response.distortions ?? [];
  } catch (error: any) {
    console.error("Distortion analysis gateway error:", error);
    throw new Error(error?.message === "SIGN_IN_REQUIRED" ? "Please sign in to use Lumia AI." : "Lumia AI could not reframe this right now.");
  }
};

export const generateDeepInsights = async (entries: { date: string, content: string, mood: string }[]): Promise<{
  triggerIdentification: { trigger: string, effect: string, suggestion: string }[];
  mentalHealthWrapped: {
    lowPointsOvercome: number;
    topPositiveWords: string[];
    summary: string;
    growthArea: string;
  };
} | null> => {
  try {
    const response = await callAiGateway<{ insights?: {
      triggers?: { trigger: string, effect: string, suggestion: string }[];
      wrapped?: {
        lowPointsOvercome: number;
        topPositiveWords: string[];
        summary: string;
        growthArea: string;
      };
    } }>("generateDeepInsights", {
      entries
    });
    if (!response.insights) return null;
    return {
      triggerIdentification: response.insights.triggers ?? [],
      mentalHealthWrapped: response.insights.wrapped ?? {
        lowPointsOvercome: 0,
        topPositiveWords: [],
        summary: "",
        growthArea: ""
      }
    };
  } catch (error: any) {
    console.error("Deep insights gateway error:", error);
    return null;
  }
};

export const generateEmotionImage = async (feeling: string): Promise<string | null> => {
  console.log("[Lumia Debug] 🎨 Starting 'Draw Feeling' process...");
  console.time("[Lumia Debug] Total Image Generation Time");
  try {
    const ai = await getAiClient();
    
    const prompt = `Generate an abstract, therapeutic, and beautiful art piece that visually represents this feeling or thought: "${feeling}". The art should be soothing, using colors and shapes that help externalize and accept this emotion. No text in the image.`;
    console.log("[Lumia Debug] 📝 Constructed Prompt:", prompt);
    
    console.log("[Lumia Debug] 🚀 Sending request to gemini-2.5-flash-image API...");
    console.time("[Lumia Debug] API Network Request Time");
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash-image',
      contents: {
        parts: [{ text: prompt }],
      },
      config: {
        imageConfig: { aspectRatio: "16:9" }
      },
    });
    console.timeEnd("[Lumia Debug] API Network Request Time");

    console.log("[Lumia Debug] 📥 Received response from API, parsing data...");
    if (response.candidates && response.candidates.length > 0 && response.candidates[0].content.parts) {
      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          console.log("[Lumia Debug] ✅ Successfully extracted image data (Base64).");
          console.timeEnd("[Lumia Debug] Total Image Generation Time");
          return `data:image/png;base64,${part.inlineData.data}`;
        }
      }
    }
    
    console.warn("[Lumia Debug] ⚠️ API responded, but no image data was found in the payload.");
    throw new Error("No image data returned from the model.");
  } catch (error: any) {
    console.error("[Lumia Debug] ❌ Image Generation Error:", error);
    console.timeEnd("[Lumia Debug] Total Image Generation Time");
    throw new Error(error.message || "Failed to generate image due to high demand or an unexpected error. Please try again later.");
  }
};

export const editEmotionImage = async (base64ImageData: string, mimeType: string, prompt: string): Promise<string | null> => {
  console.log("[Lumia Debug] 🖌️ Starting 'Edit Image' process...");
  console.time("[Lumia Debug] Total Image Edit Time");
  try {
    const ai = await getAiClient();
    
    console.log(`[Lumia Debug] 🚀 Sending edit request to gemini-2.5-flash-image API with prompt: "${prompt}"`);
    console.time("[Lumia Debug] API Edit Network Request Time");
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash-image',
      contents: {
        parts: [
          {
            inlineData: {
              data: base64ImageData,
              mimeType: mimeType,
            },
          },
          { text: prompt },
        ],
      },
    });
    console.timeEnd("[Lumia Debug] API Edit Network Request Time");

    console.log("[Lumia Debug] 📥 Received edit response from API, parsing data...");
    if (response.candidates && response.candidates.length > 0 && response.candidates[0].content.parts) {
      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          console.log("[Lumia Debug] ✅ Successfully extracted edited image data.");
          console.timeEnd("[Lumia Debug] Total Image Edit Time");
          return `data:image/png;base64,${part.inlineData.data}`;
        }
      }
    }
    throw new Error("No image data returned from the model.");
  } catch (error: any) {
    console.error("[Lumia Debug] ❌ Image Editing Error:", error);
    console.timeEnd("[Lumia Debug] Total Image Edit Time");
    throw new Error(error.message || "Failed to edit image.");
  }
};

export const generateMeditationAudio = async (context: string): Promise<{ audioBase64: string, script: string } | null> => {
  try {
    const ai = await getAiClient();
    
    // First, generate the script
    const scriptResponse = await ai.models.generateContent({
      model: textModel,
      contents: `Based on the user's recent thoughts: "${context}", write a very short (3-4 sentences), personalized guided meditation script to help them find peace and center themselves. Keep it soothing and direct.`,
      config: {
        temperature: 0.7,
      }
    });
    
    const script = scriptResponse.text || "Breathe in deeply, and let go of any tension. You are safe, and you are exactly where you need to be.";

    // Then, generate the audio
    const audioResponse = await ai.models.generateContent({
      model: ttsModel,
      contents: [{ parts: [{ text: script }] }],
      config: {
        responseModalities: ['AUDIO'],
        speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: { voiceName: 'Kore' }, // Soothing voice
            },
        },
      },
    });

    const base64Audio = audioResponse.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
    
    if (base64Audio) {
      return { audioBase64: base64Audio, script };
    }
    return null;
  } catch (error) {
    console.error("Meditation Audio Generation Error:", error);
    return null;
  }
};

export const checkApiKeyAvailability = async (): Promise<boolean> => {
  return Boolean(auth?.currentUser);
};

export const openApiKeySelector = async (): Promise<void> => {
  window.dispatchEvent(new CustomEvent("lumina:show-auth"));
};
