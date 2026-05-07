
import { GoogleGenAI, GenerateContentResponse, Type, Schema } from "@google/genai";
import { Distortion } from "../types";

// Lazy initialization of the client
const getAiClient = async (): Promise<GoogleGenAI> => {
  // We do not await window.aistudio.hasSelectedApiKey() here because it can hang the process
  // if the iframe communication is delayed. Instead, we directly use the injected environment variables.
  // process.env.API_KEY is the user-selected paid key (if any).
  // process.env.GEMINI_API_KEY is the default free key provided by the platform.
  const apiKey = process.env.API_KEY || process.env.GEMINI_API_KEY || '';
  
  if (!apiKey) {
    console.warn("[Lumina Debug] ⚠️ No API key found in environment variables.");
  }
  
  return new GoogleGenAI({ apiKey });
};

export const generateTherapistResponse = async (prompt: string, systemInstruction: string): Promise<string> => {
  try {
    const ai = await getAiClient();
    const response: GenerateContentResponse = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: prompt,
      config: {
        systemInstruction: systemInstruction,
        temperature: 0.6,
      },
    });
    return response.text || "I'm having trouble finding the right words. Could you say that again?";
  } catch (error: any) {
    console.error("Gemini API Error:", error);
    if (error.message?.includes('API key') || error.status === 403) {
        return "ERROR_API_KEY_MISSING";
    }
    if (error.name === 'TypeError' && error.message?.includes('fetch')) {
        return "I'm having trouble connecting to the network. Please check your internet connection and try again.";
    }
    if (error.name === 'AbortError' || error.message?.includes('timeout')) {
        return "The request took too long to complete. Please try again.";
    }
    if (error.status === 503 || error.status === 500) {
        return "The service is currently unavailable. Please try again later.";
    }
    return "I apologize, I'm feeling a bit disconnected right now. Please try again in a moment.";
  }
};

export const analyzeChatSentiment = async (history: string): Promise<{
  wellness: number;
  clarity: number;
  calm: number;
  energy: number;
} | null> => {
  try {
    const ai = await getAiClient();
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Analyze the following chat history and provide scores (0-100) for the user's emotional state:\n\n${history}`,
      config: {
        systemInstruction: "You are an expert psychological evaluator. Analyze the user's emotional state based on their conversation. Return precise numerical scores.",
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            wellness: { type: Type.INTEGER, description: "Overall emotional wellbeing 0-100" },
            clarity: { type: Type.INTEGER, description: "Mental clarity and focus 0-100" },
            calm: { type: Type.INTEGER, description: "Calmness vs agitation 0-100" },
            energy: { type: Type.INTEGER, description: "Vitality and motivation 0-100" }
          },
          required: ["wellness", "clarity", "calm", "energy"]
        }
      }
    });
    const text = response.text;
    return text ? JSON.parse(text) : null;
  } catch (error: any) {
    console.error("Sentiment analysis error", error);
    if (error.name === 'TypeError' && error.message?.includes('fetch')) {
        throw new Error("Network error: Unable to connect for sentiment analysis.");
    }
    if (error.name === 'AbortError' || error.message?.includes('timeout')) {
        throw new Error("Timeout: Sentiment analysis took too long.");
    }
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
    const ai = await getAiClient();
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Analyze this journal entry: "${content}"`,
      config: {
        systemInstruction: `You are an expert psychological analyst and journaling companion. Provide deep insights and quantitative metrics.`,
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            title: { type: Type.STRING },
            mood: { type: Type.STRING, enum: ["happy", "calm", "anxious", "sad", "neutral", "energetic"] },
            tags: { type: Type.ARRAY, items: { type: Type.STRING } },
            summary: { type: Type.STRING },
            reflection: { type: Type.STRING },
            actionItem: { type: Type.STRING },
            sentimentScore: { type: Type.INTEGER },
            energyLevel: { type: Type.INTEGER },
            anxietyLevel: { type: Type.INTEGER }
          },
          required: ["title", "mood", "tags", "summary", "reflection", "actionItem", "sentimentScore", "energyLevel", "anxietyLevel"]
        }
      }
    });
    const jsonText = response.text;
    return jsonText ? JSON.parse(jsonText) : null;
  } catch (error: any) {
    console.error("Analysis Error:", error);
    if (error.name === 'TypeError' && error.message?.includes('fetch')) {
        throw new Error("Network error: Please check your internet connection.");
    }
    if (error.name === 'AbortError' || error.message?.includes('timeout')) {
        throw new Error("Timeout: The analysis took too long. Please try again.");
    }
    if (error.status === 503 || error.status === 500) {
        throw new Error("Service unavailable: The AI service is currently down.");
    }
    throw new Error("An unexpected error occurred during analysis.");
  }
};

export const analyzeDistortions = async (content: string): Promise<Distortion[]> => {
  try {
    const ai = await getAiClient();
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Analyze for cognitive distortions: "${content}"`,
      config: {
        systemInstruction: `Identify cognitive distortions and provide 3 perspectives: Rational, Compassionate, Stoic.`,
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              originalText: { type: Type.STRING },
              type: { type: Type.STRING },
              explanation: { type: Type.STRING },
              reframes: {
                type: Type.ARRAY,
                items: {
                  type: Type.OBJECT,
                  properties: {
                    perspective: { type: Type.STRING, enum: ["rational", "compassionate", "stoic"] },
                    text: { type: Type.STRING }
                  },
                  required: ["perspective", "text"]
                }
              }
            },
            required: ["originalText", "type", "explanation", "reframes"]
          }
        }
      }
    });
    const jsonText = response.text;
    return jsonText ? JSON.parse(jsonText) : [];
  } catch (error: any) {
    console.error("Distortion Analysis Error:", error);
    if (error.name === 'TypeError' && error.message?.includes('fetch')) {
        throw new Error("Network error: Please check your internet connection.");
    }
    if (error.name === 'AbortError' || error.message?.includes('timeout')) {
        throw new Error("Timeout: The analysis took too long. Please try again.");
    }
    if (error.status === 503 || error.status === 500) {
        throw new Error("Service unavailable: The AI service is currently down.");
    }
    throw new Error("An unexpected error occurred during distortion analysis.");
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
    const ai = await getAiClient();
    const historyText = entries.map(e => `[${e.date}] Mood: ${e.mood} | Content: ${e.content}`).join('\n');
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Analyze the following journal entries and provide deep insights:\n\n${historyText}`,
      config: {
        systemInstruction: "You are an expert psychological data analyst. Identify hidden emotional triggers and generate a 'Mental Health Wrapped' summary based on the user's journal entries.",
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            triggerIdentification: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  trigger: { type: Type.STRING, description: "The identified trigger (e.g., 'Meetings', 'Mondays')" },
                  effect: { type: Type.STRING, description: "The effect on the user (e.g., 'Anxiety increases by 30%')" },
                  suggestion: { type: Type.STRING, description: "A gentle suggestion to handle this trigger" }
                },
                required: ["trigger", "effect", "suggestion"]
              }
            },
            mentalHealthWrapped: {
              type: Type.OBJECT,
              properties: {
                lowPointsOvercome: { type: Type.INTEGER, description: "Number of difficult moments the user successfully navigated" },
                topPositiveWords: { type: Type.ARRAY, items: { type: Type.STRING }, description: "Most frequently used positive words" },
                summary: { type: Type.STRING, description: "A warm, encouraging summary of their emotional journey" },
                growthArea: { type: Type.STRING, description: "The area where the user has shown the most growth" }
              },
              required: ["lowPointsOvercome", "topPositiveWords", "summary", "growthArea"]
            }
          },
          required: ["triggerIdentification", "mentalHealthWrapped"]
        }
      }
    });
    const text = response.text;
    return text ? JSON.parse(text) : null;
  } catch (error: any) {
    console.error("Deep Insights Error:", error);
    return null;
  }
};

export const generateEmotionImage = async (feeling: string): Promise<string | null> => {
  console.log("[Lumina Debug] 🎨 Starting 'Draw Feeling' process...");
  console.time("[Lumina Debug] Total Image Generation Time");
  try {
    const ai = await getAiClient();
    
    const prompt = `Generate an abstract, therapeutic, and beautiful art piece that visually represents this feeling or thought: "${feeling}". The art should be soothing, using colors and shapes that help externalize and accept this emotion. No text in the image.`;
    console.log("[Lumina Debug] 📝 Constructed Prompt:", prompt);
    
    console.log("[Lumina Debug] 🚀 Sending request to gemini-2.5-flash-image API...");
    console.time("[Lumina Debug] API Network Request Time");
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash-image',
      contents: {
        parts: [{ text: prompt }],
      },
      config: {
        imageConfig: { aspectRatio: "16:9" }
      },
    });
    console.timeEnd("[Lumina Debug] API Network Request Time");

    console.log("[Lumina Debug] 📥 Received response from API, parsing data...");
    if (response.candidates && response.candidates.length > 0 && response.candidates[0].content.parts) {
      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          console.log("[Lumina Debug] ✅ Successfully extracted image data (Base64).");
          console.timeEnd("[Lumina Debug] Total Image Generation Time");
          return `data:image/png;base64,${part.inlineData.data}`;
        }
      }
    }
    
    console.warn("[Lumina Debug] ⚠️ API responded, but no image data was found in the payload.");
    throw new Error("No image data returned from the model.");
  } catch (error: any) {
    console.error("[Lumina Debug] ❌ Image Generation Error:", error);
    console.timeEnd("[Lumina Debug] Total Image Generation Time");
    throw new Error(error.message || "Failed to generate image due to high demand or an unexpected error. Please try again later.");
  }
};

export const editEmotionImage = async (base64ImageData: string, mimeType: string, prompt: string): Promise<string | null> => {
  console.log("[Lumina Debug] 🖌️ Starting 'Edit Image' process...");
  console.time("[Lumina Debug] Total Image Edit Time");
  try {
    const ai = await getAiClient();
    
    console.log(`[Lumina Debug] 🚀 Sending edit request to gemini-2.5-flash-image API with prompt: "${prompt}"`);
    console.time("[Lumina Debug] API Edit Network Request Time");
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
    console.timeEnd("[Lumina Debug] API Edit Network Request Time");

    console.log("[Lumina Debug] 📥 Received edit response from API, parsing data...");
    if (response.candidates && response.candidates.length > 0 && response.candidates[0].content.parts) {
      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          console.log("[Lumina Debug] ✅ Successfully extracted edited image data.");
          console.timeEnd("[Lumina Debug] Total Image Edit Time");
          return `data:image/png;base64,${part.inlineData.data}`;
        }
      }
    }
    throw new Error("No image data returned from the model.");
  } catch (error: any) {
    console.error("[Lumina Debug] ❌ Image Editing Error:", error);
    console.timeEnd("[Lumina Debug] Total Image Edit Time");
    throw new Error(error.message || "Failed to edit image.");
  }
};

export const generateMeditationAudio = async (context: string): Promise<{ audioBase64: string, script: string } | null> => {
  try {
    const ai = await getAiClient();
    
    // First, generate the script
    const scriptResponse = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Based on the user's recent thoughts: "${context}", write a very short (3-4 sentences), personalized guided meditation script to help them find peace and center themselves. Keep it soothing and direct.`,
      config: {
        temperature: 0.7,
      }
    });
    
    const script = scriptResponse.text || "Breathe in deeply, and let go of any tension. You are safe, and you are exactly where you need to be.";

    // Then, generate the audio
    const audioResponse = await ai.models.generateContent({
      model: "gemini-2.5-flash-preview-tts",
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
  if (typeof window !== 'undefined' && (window as any).aistudio) {
    return await (window as any).aistudio.hasSelectedApiKey();
  }
  const key = (typeof process !== 'undefined' && process.env) ? process.env.API_KEY : '';
  return !!key;
};

export const openApiKeySelector = async (): Promise<void> => {
  if (typeof window !== 'undefined' && (window as any).aistudio) {
    await (window as any).aistudio.openSelectKey();
  }
};
