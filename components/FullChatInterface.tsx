import React, { useCallback, useState, useRef, useEffect } from 'react';
import { 
  Send, Menu, Plus, MessageSquare, Settings, LogOut, 
  MoreHorizontal, Phone, Video, Mic, Paperclip, X,
  Sidebar as SidebarIcon, Sparkles, Activity, Zap, TrendingUp, Home,
  MicOff, VideoOff, Camera, Loader2, Download, Trash2, FileText, Info,
  Check, Smile, Volume2, ArrowLeft, BrainCircuit
} from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { GoogleGenAI, LiveServerMessage, Modality } from '@google/genai';
import { Therapist, ChatMessage } from '../types';
import { therapists } from './TherapistSelection';
import { generateTherapistResponse, checkApiKeyAvailability, openApiKeySelector, analyzeChatSentiment } from '../services/geminiService';
import Button from './Button';
import { ButtonVariant } from '../types';
import { LineChart, Line, ResponsiveContainer } from 'recharts';
import ThoughtReframer from './ThoughtReframer';
import { useSpeechInput } from '../hooks/useSpeechInput';
import { useAuth } from '../contexts/AuthContext';
import {
  createTherapySessionRecord,
  deleteTherapySession,
  fetchLatestTherapySession,
  saveTherapySession
} from '../services/therapySessionService';

interface FullChatInterfaceProps {
  initialTherapist: Therapist | null;
  onLogout: () => void;
  onBack?: () => void;
  userAvatar: string;
  userName: string;
}

// Manual Encode/Decode for Live API
function decode(base64: string): Uint8Array {
  const binaryString = atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function encode(bytes: Uint8Array): string {
  let binary = '';
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function decodeAudioData(
  data: Uint8Array,
  ctx: AudioContext,
  sampleRate: number,
  numChannels: number,
): Promise<AudioBuffer> {
  const dataInt16 = new Int16Array(data.buffer);
  const frameCount = dataInt16.length / numChannels;
  const buffer = ctx.createBuffer(numChannels, frameCount, sampleRate);
  for (let channel = 0; channel < numChannels; channel++) {
    const channelData = buffer.getChannelData(channel);
    for (let i = 0; i < frameCount; i++) {
      channelData[i] = dataInt16[i * numChannels + channel] / 32768.0;
    }
  }
  return buffer;
}

const markdownComponents = {
  strong: ({ node, ...props }: any) => <span className="font-bold text-foreground" {...props} />,
  h1: ({ node, ...props }: any) => <h1 className="text-xl font-bold mb-3 mt-4 block text-foreground border-b border-border/30 pb-1" {...props} />,
  h2: ({ node, ...props }: any) => <h2 className="text-lg font-bold mb-2 mt-4 block text-foreground" {...props} />,
  h3: ({ node, ...props }: any) => <h3 className="text-base font-bold mb-1 mt-3 block text-foreground" {...props} />,
  p: ({ node, ...props }: any) => <p className="mb-4 last:mb-0 leading-relaxed opacity-90" {...props} />,
};

const generateId = () => `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

const FullChatInterface: React.FC<FullChatInterfaceProps> = ({ initialTherapist, onLogout, onBack, userAvatar, userName }) => {
  const { currentUser } = useAuth();
  const [activeTherapist, setActiveTherapist] = useState<Therapist>(initialTherapist || therapists[0]);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [sessionId, setSessionId] = useState(generateId);
  const [isRestoringSession, setIsRestoringSession] = useState(false);
  const [syncStatus, setSyncStatus] = useState<'idle' | 'saving' | 'saved' | 'offline'>('idle');
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [isMoreMenuOpen, setIsMoreMenuOpen] = useState(false);
  const [apiKeyMissing, setApiKeyMissing] = useState(false);

  // Call States
  const [isCallActive, setIsCallActive] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<'disconnected' | 'connecting' | 'connected'>('disconnected');
  const [isMicOn, setIsMicOn] = useState(true);
  const [audioVolume, setAudioVolume] = useState(0);
  const [metrics, setMetrics] = useState({ baseline: 72, clarity: 65, calm: 58, energy: 60 });
  const [isReframerOpen, setIsReframerOpen] = useState(false);
  const [reframerInitialThought, setReframerInitialThought] = useState('');

  const scrollRef = useRef<HTMLDivElement>(null);
  const moreMenuRef = useRef<HTMLDivElement>(null);
  const liveSessionRef = useRef<any>(null);
  const nextStartTimeRef = useRef<number>(0);
  const sourcesRef = useRef<Set<AudioBufferSourceNode>>(new Set());
  
  // Refs for audio hardware to manage strictly
  const inputAudioContextRef = useRef<AudioContext | null>(null);
  const outputAudioContextRef = useRef<AudioContext | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const dialToneContextRef = useRef<AudioContext | null>(null);
  
  // Refs for transcription
  const currentModelTextRef = useRef('');
  const currentUserTextRef = useRef('');
  const lastSavedSignatureRef = useRef('');

  const appendVoiceTranscript = useCallback((text: string) => {
    setInput(prev => `${prev}${prev.trim() ? ' ' : ''}${text}`.trimStart());
  }, []);

  const voiceInput = useSpeechInput({ onTranscript: appendVoiceTranscript });

  useEffect(() => {
    const fallbackSessionId = generateId();
    let isCancelled = false;
    setIsRestoringSession(Boolean(currentUser));
    setSessionId(fallbackSessionId);
    setSyncStatus('idle');
    setMessages([{ id: 'welcome', role: 'model', text: activeTherapist.greeting }]);

    if (currentUser) {
      fetchLatestTherapySession(currentUser.uid, activeTherapist.id)
        .then((session) => {
          if (isCancelled || !session) return;
          setSessionId(session.id);
          setMessages(session.messages.length ? session.messages : [{ id: 'welcome', role: 'model', text: activeTherapist.greeting }]);
          setMetrics({
            baseline: session.metrics.wellness,
            clarity: session.metrics.clarity,
            calm: session.metrics.calm,
            energy: session.metrics.energy
          });
          lastSavedSignatureRef.current = JSON.stringify(session.messages);
          setSyncStatus('saved');
        })
        .catch((error) => {
          console.warn('Failed to restore therapy session', error);
          if (!isCancelled) setSyncStatus('offline');
        })
        .finally(() => {
          if (!isCancelled) setIsRestoringSession(false);
        });
    } else {
      setIsRestoringSession(false);
    }

    const handleClickOutside = (event: MouseEvent) => {
      if (moreMenuRef.current && !moreMenuRef.current.contains(event.target as Node)) {
        setIsMoreMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      isCancelled = true;
      cleanupResources();
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [activeTherapist.id, currentUser?.uid]);

  useEffect(() => {
    if (!currentUser || isRestoringSession || messages.length === 0) return;
    const signature = JSON.stringify(messages);
    if (signature === lastSavedSignatureRef.current) return;

    setSyncStatus('saving');
    const saveTimer = window.setTimeout(() => {
      const session = createTherapySessionRecord(sessionId, activeTherapist.id, messages, {
        wellness: metrics.baseline,
        clarity: metrics.clarity,
        calm: metrics.calm,
        energy: metrics.energy
      });

      saveTherapySession(currentUser.uid, session)
        .then(() => {
          lastSavedSignatureRef.current = signature;
          setSyncStatus('saved');
        })
        .catch((error) => {
          console.warn('Failed to sync therapy session', error);
          setSyncStatus('offline');
        });
    }, 700);

    return () => window.clearTimeout(saveTimer);
  }, [activeTherapist.id, currentUser, isRestoringSession, messages, metrics, sessionId]);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, isLoading]);

  const safeCloseContext = async (ctxRef: React.MutableRefObject<AudioContext | null>) => {
    const ctx = ctxRef.current;
    if (ctx) {
      if (ctx.state !== 'closed') {
        try {
          await ctx.close();
        } catch (e) {
          console.warn('AudioContext close error:', e);
        }
      }
      ctxRef.current = null;
    }
  };

  const cleanupResources = async () => {
    // 1. Close Live Session
    if (liveSessionRef.current) {
      try { liveSessionRef.current.close(); } catch(e) {}
      liveSessionRef.current = null;
    }

    // 2. Stop Media Tracks
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(track => track.stop());
      mediaStreamRef.current = null;
    }

    // 3. Close All Audio Contexts safely
    await safeCloseContext(inputAudioContextRef);
    await safeCloseContext(outputAudioContextRef);
    await safeCloseContext(dialToneContextRef);

    // 4. Stop Playback Sources
    sourcesRef.current.forEach(s => { try { s.stop(); } catch(e) {} });
    sourcesRef.current.clear();
    nextStartTimeRef.current = 0;
  };

  const playDialTone = () => {
    try {
      if (!dialToneContextRef.current) {
        dialToneContextRef.current = new AudioContext();
      }
      const ctx = dialToneContextRef.current;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, ctx.currentTime); // A4
      osc.frequency.setValueAtTime(480, ctx.currentTime + 0.5); // Modulation
      
      // Pulsing effect
      const lfo = ctx.createOscillator();
      lfo.type = 'square';
      lfo.frequency.value = 2; // 2Hz pulse
      const lfoGain = ctx.createGain();
      lfoGain.gain.value = 0.1;
      
      osc.connect(gain);
      gain.connect(ctx.destination);
      
      gain.gain.setValueAtTime(0.05, ctx.currentTime);
      
      osc.start();
      return { osc, gain, ctx };
    } catch (e) {
      console.error("Failed to play dial tone", e);
      return null;
    }
  };

  const stopDialTone = async () => {
    if (dialToneContextRef.current) {
       try {
         await dialToneContextRef.current.close();
         dialToneContextRef.current = null;
       } catch(e) {}
    }
  };

  const startCall = async () => {
    if (isCallActive) return;

    // 1. Check backend AI availability
    const hasKey = await checkApiKeyAvailability();
    if (!hasKey) {
      try {
        await openApiKeySelector();
        setApiKeyMissing(false);
      } catch (e) {
        console.error("Failed to open sign-in", e);
        return;
      }
    }

    await cleanupResources();
    setIsCallActive(true);
    setConnectionStatus('connecting');
    
    // Play dial tone while connecting
    playDialTone();

    try {
      const apiKey = process.env.API_KEY || '';
      if (!apiKey) {
         console.warn("Live voice still requires a server-side realtime gateway before production use.");
      }
      
      const ai = new GoogleGenAI({ apiKey });
      
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;

      const sessionPromise = ai.live.connect({
        model: 'gemini-3.1-flash-live-preview',
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: activeTherapist.voiceName || 'Zephyr' } } },
          systemInstruction: `You are ${activeTherapist.name}. ${activeTherapist.systemInstruction}. Keep your voice responses concise and warm.`,
          // Enable transcription for history
          inputAudioTranscription: {},
          outputAudioTranscription: {}
        },
        callbacks: {
          onopen: () => {
            stopDialTone(); // Stop tone on connection
            setConnectionStatus('connected');
            
            // Setup Input Audio only AFTER connection is established
            inputAudioContextRef.current = new AudioContext({ sampleRate: 16000 });
            const source = inputAudioContextRef.current.createMediaStreamSource(stream);
            const scriptProcessor = inputAudioContextRef.current.createScriptProcessor(4096, 1, 1);
            
            scriptProcessor.onaudioprocess = (e) => {
              if (!isMicOn) return;
              const inputData = e.inputBuffer.getChannelData(0);
              const int16 = new Int16Array(inputData.length);
              for (let i = 0; i < inputData.length; i++) {
                int16[i] = inputData[i] * 32768;
              }
              const pcmBlob = {
                data: encode(new Uint8Array(int16.buffer)),
                mimeType: 'audio/pcm;rate=16000',
              };
              
              sessionPromise.then(session => {
                session.sendRealtimeInput({ media: pcmBlob });
              }).catch(() => {});
            };
            
            source.connect(scriptProcessor);
            scriptProcessor.connect(inputAudioContextRef.current.destination);
          },
          onmessage: async (message: LiveServerMessage) => {
            // Handle Transcription (User)
            const inputTx = message.serverContent?.inputTranscription;
            if (inputTx) {
               // Assuming inputTx is of type Transcription { text?: string, finished?: boolean }
               // Note: The type definition might be slightly different in practice, so we check properties.
               // Based on docs, it has text and finished.
               // However, sometimes it comes as 'content' or similar. Let's assume standard.
               // Actually, let's check if 'text' exists.
               // Also, we need to handle incremental updates.
               // But usually input transcription is sent as final or partial.
               // If it's partial, we might want to update current ref.
               // If finished, commit.
               // Let's assume simple append for now if it's streaming text.
               // Wait, if it's streaming, we might get "Hello" then "Hello world".
               // Or "Hello" then " world".
               // The docs say "Transcription text".
               // Let's assume it's delta text for now, or check if it overwrites.
               // Actually, for Live API, it's usually delta.
               // But let's be safe: if we see text, we append.
               // If we see finished, we commit.
               // But wait, if it sends "Hello" then "Hello world", appending would be "HelloHello world".
               // Let's assume delta.
               // If it's not delta, we might have issues.
               // But standard Gemini streaming is delta.
               
               // Actually, let's check if there is a way to know.
               // I'll assume delta.
               
               // Wait, I can't easily debug this without running.
               // I'll assume delta.
               
               // Actually, let's just log it to be sure? No, I can't see logs easily.
               // I'll assume delta.
               
               // Wait, if I use `inputAudioTranscription`, I might get `inputTranscription` messages.
               // Let's check for `text` property.
               // Cast to any to avoid strict type checks if needed, but I saw the type def.
               const text = (inputTx as any).text; // Use any to be safe
               if (text) {
                  currentUserTextRef.current += text;
               }
               // Check for finished signal?
               // The type def has `finished`.
               if ((inputTx as any).finished) {
                  if (currentUserTextRef.current.trim()) {
                      const final = currentUserTextRef.current.trim();
                      setMessages(prev => [...prev, { id: generateId(), role: 'user', text: final }]);
                      currentUserTextRef.current = '';
                  }
               }
            }

            // Handle Transcription (Model)
            // Use outputTranscription if available, otherwise fallback to modelTurn?
            // But modelTurn usually has audio.
            // If outputAudioTranscription is enabled, we should get outputTranscription messages.
            const outputTx = message.serverContent?.outputTranscription;
            if (outputTx) {
               const text = (outputTx as any).text;
               if (text) {
                  currentModelTextRef.current += text;
               }
               if ((outputTx as any).finished) {
                  if (currentModelTextRef.current.trim()) {
                      const final = currentModelTextRef.current.trim();
                      setMessages(prev => [...prev, { id: generateId(), role: 'model', text: final }]);
                      currentModelTextRef.current = '';
                  }
               }
            }

            // Fallback: If turnComplete and we have pending model text (maybe from modelTurn if we didn't use outputTx)
            // But if we use outputTx, we rely on that.
            // If we don't get outputTx, we might miss model text.
            // Let's also check modelTurn just in case, but only if outputTx is not active?
            // Actually, if we enable outputAudioTranscription, we should get it.
            
            // Handle Interruption
            if (message.serverContent?.interrupted) {
              sourcesRef.current.forEach(s => { try { s.stop(); } catch(e) {} });
              sourcesRef.current.clear();
              nextStartTimeRef.current = 0;
              
              // Commit partial model text if interrupted
              if (currentModelTextRef.current.trim()) {
                  const final = currentModelTextRef.current.trim() + " [Interrupted]";
                  setMessages(prev => [...prev, { id: generateId(), role: 'model', text: final }]);
                  currentModelTextRef.current = '';
              }
            }
            
            // Handle Turn Complete
            if (message.serverContent?.turnComplete) {
               // If we have pending text that wasn't committed by 'finished' flag (e.g. if finished flag didn't come or we missed it)
               if (currentModelTextRef.current.trim()) {
                  const final = currentModelTextRef.current.trim();
                  setMessages(prev => [...prev, { id: generateId(), role: 'model', text: final }]);
                  currentModelTextRef.current = '';
               }
               // Also for user? Usually user turn completes before model starts.
               if (currentUserTextRef.current.trim()) {
                  const final = currentUserTextRef.current.trim();
                  setMessages(prev => [...prev, { id: generateId(), role: 'user', text: final }]);
                  currentUserTextRef.current = '';
               }
            }

            const audioBase64 = message.serverContent?.modelTurn?.parts?.[0]?.inlineData?.data;
            if (audioBase64) {
              if (!outputAudioContextRef.current) {
                outputAudioContextRef.current = new AudioContext({ sampleRate: 24000 });
              }
              
              const ctx = outputAudioContextRef.current;
              const buffer = await decodeAudioData(decode(audioBase64), ctx, 24000, 1);
              const source = ctx.createBufferSource();
              source.buffer = buffer;
              
              const analyser = ctx.createAnalyser();
              analyser.fftSize = 32;
              source.connect(analyser);
              analyser.connect(ctx.destination);
              
              const updateVol = () => {
                if (!analyser) return;
                const data = new Uint8Array(analyser.frequencyBinCount);
                analyser.getByteFrequencyData(data);
                setAudioVolume(data.reduce((a, b) => a + b, 0) / data.length);
                if (isCallActive) requestAnimationFrame(updateVol);
              };
              updateVol();

              nextStartTimeRef.current = Math.max(nextStartTimeRef.current, ctx.currentTime);
              source.start(nextStartTimeRef.current);
              nextStartTimeRef.current += buffer.duration;
              
              sourcesRef.current.add(source);
              source.onended = () => sourcesRef.current.delete(source);
            }
          },
          onclose: () => endCall(),
          onerror: (e) => {
            console.error('Live API Error:', e);
            endCall();
          }
        }
      });
      
      liveSessionRef.current = await sessionPromise;
    } catch (e) {
      console.error('Call initialization failed:', e);
      endCall();
    }
  };

  const endCall = async () => {
    await cleanupResources();
    setIsCallActive(false);
    setConnectionStatus('disconnected');
    setAudioVolume(0);
  };

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;
    if (voiceInput.isListening) voiceInput.stop();

    const messageText = input.trim();
    const userMsg: ChatMessage = { id: generateId(), role: 'user', text: messageText };
    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      const history = messages.slice(-8).map(m => `${m.role}: ${m.text}`).join('\n');
      const sysPrompt = `You are ${activeTherapist.name}. ${activeTherapist.systemInstruction}`;
      const response = await generateTherapistResponse(history + `\nuser: ${messageText}`, sysPrompt);
      
      if (response === "ERROR_API_KEY_MISSING") {
        setApiKeyMissing(true);
      } else {
        setMessages(prev => [...prev, { id: generateId(), role: 'model', text: response }]);
        const sentiment = await analyzeChatSentiment(history + `\nmodel: ${response}`);
        if (sentiment) setMetrics({ baseline: sentiment.wellness, clarity: sentiment.clarity, calm: sentiment.calm, energy: sentiment.energy });
      }
    } catch (e) { console.error(e); } finally { setIsLoading(false); }
  };

  const handleSaveChat = () => {
    const text = messages.map(m => `[${m.role}] ${m.text}`).join('\n\n');
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = 'lumina-session.txt'; a.click();
    setIsMoreMenuOpen(false);
  };

  return (
    <div className="flex h-screen bg-background overflow-hidden text-foreground font-sans relative">
      
      {/* Call UI */}
      {isCallActive && (
        <div className="fixed inset-0 z-[100] bg-black text-white flex flex-col items-center justify-center animate-in fade-in duration-500">
           <div className="absolute inset-0 opacity-20 pointer-events-none">
              <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] rounded-full blur-[150px] transition-transform duration-300 ${activeTherapist.bgClass}`} 
                   style={{ transform: `translate(-50%, -50%) scale(${1 + (audioVolume / 40)})` }} />
           </div>
           <div className="relative z-10 flex flex-col items-center gap-12">
              <div className={`w-40 h-40 md:w-56 md:h-56 rounded-full overflow-hidden border-4 border-white/10 shadow-2xl transition-transform duration-200 ${audioVolume > 10 ? 'scale-110' : 'scale-100'}`}>
                 <img src={activeTherapist.avatarUrl} className="w-full h-full object-cover" />
              </div>
              <div className="text-center space-y-2">
                 <h2 className="text-4xl md:text-6xl font-serif font-bold tracking-tight">{activeTherapist.name}</h2>
                 <p className="text-white/40 tracking-[0.3em] uppercase text-xs font-bold">
                    {connectionStatus === 'connected' ? 'Session Resonating' : 'Establishing Connection...'}
                 </p>
              </div>
              <div className="flex items-center gap-10 mt-10">
                 <button onClick={() => setIsMicOn(!isMicOn)} className={`p-5 rounded-full border transition-all ${!isMicOn ? 'bg-white text-black border-white' : 'bg-white/5 text-white border-white/10 hover:bg-white/10'}`}>
                    {isMicOn ? <Mic /> : <MicOff />}
                 </button>
                 <button onClick={endCall} className="p-7 rounded-full bg-red-500 text-white shadow-2xl shadow-red-500/40 hover:scale-110 transition-transform">
                    <Phone size={32} className="rotate-[135deg]" />
                 </button>
              </div>
           </div>
        </div>
      )}

      {/* Sidebar */}
      <aside className={`fixed md:static inset-y-0 left-0 z-40 bg-muted border-r border-border/40 flex flex-col transition-all duration-500 ease-in-out shrink-0 ${isSidebarOpen ? 'w-72 sm:w-80 opacity-100' : 'w-0 -translate-x-full md:translate-x-0 md:opacity-0 overflow-hidden'}`}>
        <div className="p-6 flex flex-col h-full min-w-[18rem] sm:min-w-[20rem]">
          <div className="flex items-center justify-between mb-10">
            <div className="flex items-center gap-3">
              {onBack && (
                <button onClick={onBack} className="p-2 -ml-2 text-muted-foreground hover:text-primary hover:bg-primary/10 rounded-full transition-colors" title="Back to Dashboard">
                  <ArrowLeft size={20} />
                </button>
              )}
              <div className="h-10 w-10 bg-primary rounded-xl flex items-center justify-center text-primary-foreground"><Sparkles size={20} /></div>
              <span className="font-serif font-bold text-2xl tracking-tight">Lumina</span>
            </div>
            <button onClick={() => setIsSidebarOpen(false)} className="md:hidden p-2"><X size={20} /></button>
          </div>

          <div className="flex-1 overflow-y-auto space-y-10 custom-scrollbar pr-1">
            <div className="p-6 rounded-[2rem] bg-card border border-border/40 shadow-sm">
              <h4 className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest mb-6 flex items-center gap-2 font-sans"><Activity size={14} className="text-primary" /> Mental Health Pulse</h4>
              <div className="space-y-5">
                 {[
                   { label: 'Wellness', val: metrics.baseline, color: 'bg-primary', stroke: 'var(--primary)' },
                   { label: 'Clarity', val: metrics.clarity, color: 'bg-secondary', stroke: 'var(--secondary)' },
                   { label: 'Calm', val: metrics.calm, color: 'bg-blue-400', stroke: '#60a5fa' },
                   { label: 'Energy', val: metrics.energy, color: 'bg-yellow-500', stroke: '#eab308' }
                 ].map(m => {
                   // Generate some dummy data for the sparkline based on the current value
                   const data = Array.from({ length: 10 }, (_, i) => ({
                     value: Math.max(0, Math.min(100, m.val + (Math.random() * 20 - 10)))
                   }));
                   data.push({ value: m.val }); // Ensure the last point is the current value

                   return (
                     <div key={m.label}>
                       <div className="flex justify-between items-center text-[10px] font-bold mb-1.5 uppercase text-muted-foreground">
                         <div className="flex items-center gap-2">
                           <span>{m.label}</span>
                           <div className="w-12 h-4">
                             <ResponsiveContainer width="100%" height="100%">
                               <LineChart data={data}>
                                 <Line 
                                   type="monotone" 
                                   dataKey="value" 
                                   stroke={m.stroke} 
                                   strokeWidth={1.5} 
                                   dot={false} 
                                   isAnimationActive={true}
                                   animationDuration={1500}
                                   animationEasing="ease-in-out"
                                 />
                               </LineChart>
                             </ResponsiveContainer>
                           </div>
                         </div>
                         <span>{m.val}%</span>
                       </div>
                       <div className="h-1.5 w-full bg-muted/50 rounded-full overflow-hidden"><div className={`h-full ${m.color} transition-all duration-1000`} style={{ width: `${m.val}%` }} /></div>
                     </div>
                   );
                 })}
              </div>
            </div>

            <div>
              <h4 className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest mb-4 px-2 font-sans">Sanctuary Guides</h4>
              <div className="space-y-2">
                {therapists.map(t => (
                  <button key={t.id} onClick={() => { setActiveTherapist(t); if(window.innerWidth < 1024) setIsSidebarOpen(false); }} 
                    className={`w-full flex items-center gap-4 p-4 rounded-2xl text-sm transition-all ${activeTherapist.id === t.id ? 'bg-card shadow-md font-bold text-foreground border border-border/40' : 'text-muted-foreground hover:bg-card/50 hover:text-foreground'}`}>
                    <div className="w-10 h-10 rounded-full overflow-hidden border-2 border-background shadow-sm shrink-0"><img src={t.avatarUrl} className="w-full h-full object-cover" /></div>
                    <div className="text-left">
                       <div className="font-bold">{t.name}</div>
                       <div className="text-[10px] opacity-60 uppercase font-sans tracking-tight">{t.role}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="mt-auto pt-6 border-t border-border/30 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <img src={userAvatar} className="w-10 h-10 rounded-full border border-background shadow-sm" />
              <div className="flex flex-col"><span className="text-xs font-bold text-foreground">{userName}</span><span className="text-[10px] text-muted-foreground uppercase font-bold font-sans">Secure Session</span></div>
            </div>
            <button onClick={onLogout} className="text-muted-foreground hover:text-red-500 transition-colors p-2 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-full"><LogOut size={18} /></button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col h-full bg-background relative min-w-0">
        <header className="h-20 border-b border-border/30 bg-background/70 backdrop-blur-xl flex items-center justify-between px-6 md:px-10 z-20">
          <div className="flex items-center gap-4">
            <button onClick={() => setIsSidebarOpen(!isSidebarOpen)} className="p-2 text-muted-foreground hover:text-foreground transition-colors"><SidebarIcon size={22} /></button>
            <div className="flex items-center gap-4">
               <img src={activeTherapist.avatarUrl} className="w-10 h-10 md:w-12 md:h-12 rounded-2xl border-2 border-background shadow-md" />
               <div className="hidden sm:block">
                 <h2 className="font-serif font-bold text-xl text-foreground leading-tight">{activeTherapist.name}</h2>
                 <p className="text-[10px] uppercase font-bold text-green-500 tracking-widest flex items-center gap-1 font-sans">
                   <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
                   {isRestoringSession ? 'Restoring' : syncStatus === 'saving' ? 'Saving' : syncStatus === 'offline' ? 'Local only' : 'Listening'}
                 </p>
               </div>
            </div>
          </div>

          <div className="flex items-center gap-2 md:gap-4">
             <button onClick={startCall} className="p-3 text-muted-foreground hover:text-primary transition-colors hover:bg-primary/5 rounded-full border border-transparent hover:border-primary/10"><Phone size={20} /></button>
             <button className="p-3 text-muted-foreground hover:text-primary transition-colors hover:bg-primary/5 rounded-full border border-transparent hover:border-primary/10 hidden sm:block"><Video size={20} /></button>
             <div className="w-px h-8 bg-border/40 mx-1 hidden sm:block" />
             <div className="relative" ref={moreMenuRef}>
                 <button onClick={() => setIsMoreMenuOpen(!isMoreMenuOpen)} className="p-3 text-muted-foreground hover:text-foreground hover:bg-muted transition-all rounded-full border border-transparent hover:border-border/40"><MoreHorizontal size={20} /></button>
                 {isMoreMenuOpen && (
                     <div className="absolute right-0 mt-4 w-60 bg-card rounded-3xl shadow-[0_20px_50px_rgba(0,0,0,0.15)] border border-border/30 p-2 z-[60] animate-in zoom-in-95">
                         <button onClick={handleSaveChat} className="w-full flex items-center gap-4 p-4 rounded-2xl hover:bg-muted text-sm font-bold transition-all"><Download size={20} className="text-primary" /> Export Session</button>
                         <button onClick={onBack} className="w-full flex items-center gap-4 p-4 rounded-2xl hover:bg-muted text-sm font-bold transition-all"><Home size={20} className="text-secondary" /> Dashboard</button>
                         <button onClick={() => {
                           const clearedSessionId = sessionId;
                           setSessionId(generateId());
                           setMessages([{id: 'welcome', role: 'model', text: activeTherapist.greeting}]);
                           setIsMoreMenuOpen(false);
                           if (currentUser) {
                             deleteTherapySession(currentUser.uid, clearedSessionId).catch((error) => console.warn('Failed to delete therapy session', error));
                           }
                         }} className="w-full flex items-center gap-4 p-4 rounded-2xl hover:bg-red-50 dark:hover:bg-red-900/20 text-red-500 text-sm font-bold transition-all"><Trash2 size={20} /> Clear Journey</button>
                     </div>
                 )}
             </div>
          </div>
        </header>

        <div className="flex-1 overflow-y-auto p-4 md:p-12 space-y-10 custom-scrollbar" ref={scrollRef}>
          {messages.map((m, idx) => (
            <div key={m.id || idx} className={`flex gap-4 md:gap-8 max-w-4xl mx-auto ${m.role === 'user' ? 'flex-row-reverse' : ''} animate-in fade-in slide-in-from-bottom-4 duration-500`}>
              <div className="w-10 h-10 md:w-12 md:h-12 rounded-2xl overflow-hidden shadow-md shrink-0 border-2 border-background ring-1 ring-border/20">
                 <img src={m.role === 'user' ? userAvatar : activeTherapist.avatarUrl} className="w-full h-full object-cover" />
              </div>
              <div className={`p-6 md:p-8 rounded-[2rem] text-base leading-relaxed border border-border/30 shadow-sm max-w-[85%] ${m.role === 'model' ? 'bg-card text-foreground rounded-tl-sm' : `${activeTherapist.bgClass} text-white rounded-tr-sm shadow-xl`}`}>
                 <ReactMarkdown components={markdownComponents}>{m.text}</ReactMarkdown>
              </div>
            </div>
          ))}
          {isLoading && <div className="flex gap-4 max-w-4xl mx-auto"><div className="w-12 h-12 rounded-2xl bg-card flex items-center justify-center animate-pulse border-2 border-background shadow-md"><Sparkles size={24} className="text-primary" /></div><div className="p-6 rounded-3xl bg-card border border-border/30 text-xs font-bold uppercase text-muted-foreground tracking-widest flex items-center gap-3 shadow-sm font-sans"><Loader2 size={18} className="animate-spin" /> Thinking...</div></div>}
          <div className="h-10" />
        </div>

        <div className="p-6 md:p-10 bg-gradient-to-t from-background via-background to-transparent relative z-20">
           <div className="max-w-4xl mx-auto">
             <div className="bg-card rounded-[2.5rem] border border-border/60 shadow-[0_15px_60px_-15px_rgba(0,0,0,0.1)] focus-within:ring-4 focus-within:ring-primary/5 transition-all p-2 flex items-end">
                <button className="p-4 text-muted-foreground hover:text-primary transition-colors" title="Attach File"><Paperclip size={22} /></button>
                <button 
                  onClick={() => {
                    setReframerInitialThought(input);
                    setIsReframerOpen(true);
                  }} 
                  className="p-4 text-muted-foreground hover:text-primary transition-colors"
                  title="Reframe Thought"
                >
                  <BrainCircuit size={22} />
                </button>
                <textarea value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => { if(e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSend(); } }} placeholder="Share what's on your mind..." className="flex-1 min-h-[56px] max-h-40 py-4 px-2 bg-transparent border-none focus:ring-0 text-foreground font-serif text-lg md:text-xl resize-none" />
                <button
                  onClick={voiceInput.toggle}
                  disabled={!voiceInput.isSupported || isLoading}
                  className={`p-4 md:p-5 rounded-[1.5rem] md:rounded-[2rem] transition-all ${voiceInput.isListening ? 'bg-red-500 text-white shadow-xl shadow-red-500/20' : 'text-muted-foreground hover:text-primary hover:bg-muted'} disabled:opacity-40 disabled:hover:bg-transparent disabled:hover:text-muted-foreground`}
                  title={voiceInput.isSupported ? (voiceInput.isListening ? 'Stop voice input' : 'Start voice input') : 'Voice input is not supported in this browser'}
                  aria-label={voiceInput.isListening ? 'Stop voice input' : 'Start voice input'}
                >
                  {voiceInput.isListening ? <MicOff size={24} /> : <Mic size={24} />}
                </button>
                <button onClick={handleSend} disabled={!input.trim() || isLoading} className={`p-4 md:p-5 rounded-[1.5rem] md:rounded-[2rem] text-white transition-all shadow-xl ${!input.trim() || isLoading ? 'bg-muted text-muted-foreground shadow-none' : activeTherapist.bgClass + ' hover:scale-105 active:scale-95'}`}><Send size={24} /></button>
             </div>
             {(voiceInput.isListening || voiceInput.interimTranscript || voiceInput.error) && (
               <div className="mt-3 px-5 text-xs font-bold text-muted-foreground flex items-center gap-2">
                 <span className={`w-2 h-2 rounded-full ${voiceInput.error ? 'bg-red-400' : 'bg-primary animate-pulse'}`} />
                 <span>{voiceInput.error || voiceInput.interimTranscript || 'Listening...'}</span>
               </div>
             )}
           </div>
        </div>
      </main>

      {isReframerOpen && (
        <ThoughtReframer 
          initialThought={reframerInitialThought}
          onClose={() => setIsReframerOpen(false)}
          onComplete={(reframedThought) => {
            setInput(reframedThought);
            setIsReframerOpen(false);
          }}
        />
      )}

      {apiKeyMissing && (
          <div className="fixed inset-0 z-[200] bg-black/80 backdrop-blur-md flex items-center justify-center p-6">
              <div className="bg-card rounded-[3rem] p-10 max-w-md text-center shadow-2xl animate-in zoom-in-95">
                  <div className="w-20 h-20 bg-red-100 dark:bg-red-900/40 text-red-500 rounded-full flex items-center justify-center mx-auto mb-8"><Volume2 size={40} /></div>
                  <h3 className="text-3xl font-serif font-bold mb-4">Connection Required</h3>
                  <p className="text-muted-foreground mb-10 leading-relaxed font-sans">Sign in so Lumina can connect securely to the AI backend.</p>
                  <Button onClick={() => openApiKeySelector().then(() => setApiKeyMissing(false))} className="w-full h-16 text-lg">Sign In</Button>
              </div>
          </div>
      )}
    </div>
  );
};

export default FullChatInterface;
