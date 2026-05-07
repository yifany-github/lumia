import React, { useState, useEffect, useRef, useMemo } from 'react';
import { 
  Plus, Calendar, Activity, MessageSquare, 
  TrendingUp, Smile, Cloud, Sun, Zap, Moon, 
  MoreHorizontal, Search, PenLine, ArrowRight,
  Mic, MicOff, Sparkles, Loader2, Save, X, Shuffle,
  Lightbulb, CheckCircle2, Image as ImageIcon, Sliders, Music, Phone, Edit2, Trash2, Play,
  BarChart3, Zap as EnergyIcon, BrainCircuit, ScanEye, RefreshCw, Triangle, Share2,
  Leaf, Sprout, TreePine, Flower2, Droplet
} from 'lucide-react';
import { AreaChart, Area, XAxis, Tooltip, ResponsiveContainer, YAxis, CartesianGrid } from 'recharts';
import { JournalEntry, ButtonVariant, Therapist, VisualizerSettings, Distortion, Habit } from '../types';
import Button from './Button';
import { therapists } from './TherapistSelection';
import { PixelGarden } from './PixelGarden';
import { analyzeJournalEntry, analyzeDistortions, generateDeepInsights, generateEmotionImage, generateMeditationAudio, editEmotionImage } from '../services/geminiService';
import Visualizer from './Visualizer';

interface DashboardProps {
  userAvatar: string;
  userName: string;
  entries: JournalEntry[];
  setEntries: React.Dispatch<React.SetStateAction<JournalEntry[]>>;
  onNavigateToChat: (therapist?: Therapist) => void;
  onLogout: () => void;
  onOpenProfile: () => void;
}

const DEFAULT_SETTINGS: VisualizerSettings = {
    particleSize: 4.5, 
    intensity: 3,
    sensitivity: 80,
    density: 80,
    enabled: true
};

const moodIcons = {
  happy: <Sun size={18} className="text-orange-500" />,
  calm: <Cloud size={18} className="text-blue-400" />,
  anxious: <Activity size={18} className="text-purple-500" />,
  sad: <Moon size={18} className="text-indigo-500" />,
  neutral: <Smile size={18} className="text-gray-500" />,
  energetic: <Zap size={18} className="text-yellow-500" />,
};

const PROMPTS = [
    "What is one thing that made you smile today?",
    "What was a challenge you faced, and how did you handle it?",
    "Describe a moment where you felt truly at peace.",
    "What is weighing on your mind right now?",
    "What is one thing you are grateful for?",
    "If you could tell your younger self one thing today, what would it be?"
];

const Dashboard: React.FC<DashboardProps> = ({ 
    userAvatar, userName, entries, setEntries, onNavigateToChat, onLogout, onOpenProfile 
}) => {
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  
  // Editor State
  const [editingId, setEditingId] = useState<string | null>(null);
  const [currentPrompt, setCurrentPrompt] = useState(PROMPTS[0]);
  const [newTitle, setNewTitle] = useState('');
  const [newContent, setNewContent] = useState('');
  const [selectedMood, setSelectedMood] = useState<keyof typeof moodIcons>('neutral');
  const [generatedTags, setGeneratedTags] = useState<string[]>([]);
  const [aiReflection, setAiReflection] = useState('');
  const [aiAction, setAiAction] = useState('');
  const [aiSummary, setAiSummary] = useState('');
  
  // Quantitative Metrics State
  const [sentimentScore, setSentimentScore] = useState<number>(50);
  const [energyLevel, setEnergyLevel] = useState<number>(50);
  const [anxietyLevel, setAnxietyLevel] = useState<number>(0);
  
  // The Prism (Reframing) State
  const [isPrismMode, setIsPrismMode] = useState(false);
  const [distortions, setDistortions] = useState<Distortion[]>([]);
  const [activeDistortion, setActiveDistortion] = useState<Distortion | null>(null);
  const [isAnalyzingDistortions, setIsAnalyzingDistortions] = useState(false);

  // Immersive Mode State (Visualizer)
  const [backgroundImage, setBackgroundImage] = useState<string | null>(null);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [visualizerSettings, setVisualizerSettings] = useState<VisualizerSettings>(DEFAULT_SETTINGS);
  const [activeTab, setActiveTab] = useState<'timeline' | 'insights' | 'soundscapes' | 'garden'>('timeline');
  const [deepInsights, setDeepInsights] = useState<any>(null);
  const [isGeneratingInsights, setIsGeneratingInsights] = useState(false);
  const [isGeneratingImage, setIsGeneratingImage] = useState(false);
  const [isEditingImage, setIsEditingImage] = useState(false);
  const [imageEditPrompt, setImageEditPrompt] = useState('');
  const [showImageEditInput, setShowImageEditInput] = useState(false);
  
  // Garden State
  const [habits, setHabits] = useState<Habit[]>([
    { id: '1', title: 'Drink a glass of warm water', description: 'Start the day hydrated.', completedAt: null, createdAt: Date.now(), plantType: 'sprout', growth: 30 },
    { id: '2', title: 'Look out the window for 2 mins', description: 'Rest your eyes and mind.', completedAt: null, createdAt: Date.now(), plantType: 'flower', growth: 70 },
  ]);
  const [waterDrops, setWaterDrops] = useState(5);
  
  // Soundscapes State
  const [meditationAudio, setMeditationAudio] = useState<string | null>(null);
  const [meditationScript, setMeditationScript] = useState<string | null>(null);
  const [isGeneratingMeditation, setIsGeneratingMeditation] = useState(false);
  const [isPlayingMeditation, setIsPlayingMeditation] = useState(false);
  const meditationAudioRef = useRef<HTMLAudioElement | null>(null);

  // Audio / Voice State
  const [isListening, setIsListening] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const recognitionRef = useRef<any>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);

  // --- Dynamic Chart Data Calculation ---
  const chartData = useMemo(() => {
    const sorted = [...entries].sort((a, b) => a.timestamp - b.timestamp);
    const last7 = sorted.slice(-7);
    return last7.map(e => ({
      day: e.date,
      score: e.sentimentScore || 50,
      energy: e.energyLevel || 50,
      anxiety: e.anxietyLevel || 0
    }));
  }, [entries]);

  const averageScore = useMemo(() => {
    if (entries.length === 0) return 0;
    const sum = entries.reduce((acc, curr) => acc + (curr.sentimentScore || 50), 0);
    return Math.round(sum / entries.length);
  }, [entries]);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      if (SpeechRecognition) {
        recognitionRef.current = new SpeechRecognition();
        recognitionRef.current.continuous = true;
        recognitionRef.current.interimResults = true;
        recognitionRef.current.onresult = (event: any) => {
          let finalTranscript = '';
          for (let i = event.resultIndex; i < event.results.length; ++i) {
            if (event.results[i].isFinal) finalTranscript += event.results[i][0].transcript;
          }
          if (finalTranscript) setNewContent(prev => prev + (prev ? ' ' : '') + finalTranscript);
        };
      }
    }
  }, []);

  const startAudioContext = async () => {
     try {
         if (!audioContextRef.current) {
             const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
             mediaStreamRef.current = stream;
             const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
             const analyser = audioCtx.createAnalyser();
             const source = audioCtx.createMediaStreamSource(stream);
             analyser.fftSize = 256;
             source.connect(analyser);
             audioContextRef.current = audioCtx;
             analyserRef.current = analyser;
         } else if (audioContextRef.current.state === 'suspended') {
             await audioContextRef.current.resume();
         }
     } catch (e) { console.error("Audio access denied or failed", e); }
  };

  const toggleListening = async () => {
    if (!recognitionRef.current) {
        alert("Voice input is not supported in this browser.");
        return;
    }
    if (isListening) {
      recognitionRef.current.stop();
      setIsListening(false);
    } else {
      await startAudioContext(); 
      recognitionRef.current.start();
      setIsListening(true);
    }
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) {
          const url = URL.createObjectURL(file);
          setBackgroundImage(url);
          startAudioContext(); 
      }
  };

  const shufflePrompt = () => {
      const nextIndex = (PROMPTS.indexOf(currentPrompt) + 1) % PROMPTS.length;
      setCurrentPrompt(PROMPTS[nextIndex]);
  };

  const handleAnalyze = async () => {
      if (!newContent.trim()) return;
      setIsAnalyzing(true);
      try {
          const analysis = await analyzeJournalEntry(newContent);
          if (analysis) {
              setNewTitle(analysis.title);
              setSelectedMood(analysis.mood as any);
              setGeneratedTags(analysis.tags);
              setAiReflection(analysis.reflection);
              setAiAction(analysis.actionItem);
              setAiSummary(analysis.summary);
              setSentimentScore(analysis.sentimentScore);
              setEnergyLevel(analysis.energyLevel);
              setAnxietyLevel(analysis.anxietyLevel);
          }
      } catch (error: any) {
          alert(error.message || "An error occurred during analysis.");
      } finally {
          setIsAnalyzing(false);
      }
  };

  const handlePrismAnalyze = async () => {
    if (!newContent.trim()) return;
    setIsAnalyzingDistortions(true);
    setIsPrismMode(true);
    try {
        const result = await analyzeDistortions(newContent);
        setDistortions(result);
    } catch (error: any) {
        alert(error.message || "An error occurred during prism analysis.");
        setIsPrismMode(false);
    } finally {
        setIsAnalyzingDistortions(false);
    }
  };

  const handleShare = async (e: React.MouseEvent, entry: JournalEntry) => {
    e.stopPropagation();
    const shareData = {
      title: entry.title,
      text: `"${entry.title}"\n\n${entry.content}\n\n- ${entry.date}`,
    };
    try {
      if (navigator.share) {
        await navigator.share(shareData);
      } else {
        const mailtoLink = `mailto:?subject=${encodeURIComponent(shareData.title)}&body=${encodeURIComponent(shareData.text)}`;
        window.open(mailtoLink, '_blank');
      }
    } catch (err) {
      console.error('Error sharing:', err);
    }
  };

  const handleApplyReframe = (reframeText: string, originalText: string) => {
    setNewContent(prev => prev.replace(originalText, reframeText));
    setActiveDistortion(null);
    setDistortions(prev => prev.filter(d => d.originalText !== originalText));
  };

  const fetchDeepInsights = async () => {
    if (entries.length === 0) return;
    setIsGeneratingInsights(true);
    try {
      const data = entries.map(e => ({ date: e.date, content: e.content, mood: e.mood }));
      const insights = await generateDeepInsights(data);
      if (insights) {
        setDeepInsights(insights);
      }
    } catch (error) {
      console.error("Failed to fetch deep insights", error);
    } finally {
      setIsGeneratingInsights(false);
    }
  };

  const handleGenerateImage = async () => {
    if (!newContent.trim()) return;
    setIsGeneratingImage(true);
    try {
      const imageUrl = await generateEmotionImage(newContent);
      if (imageUrl) {
        setBackgroundImage(imageUrl);
        startAudioContext();
      }
    } catch (error: any) {
      console.error("Failed to generate image", error);
      alert(error.message || "Failed to generate image. Please try again.");
    } finally {
      setIsGeneratingImage(false);
    }
  };

  const handleEditImage = async () => {
    if (!backgroundImage || !imageEditPrompt.trim()) return;
    setIsEditingImage(true);
    try {
      let base64Data = '';
      let mimeType = '';

      // Check if it's a blob URL (from file upload)
      if (backgroundImage.startsWith('blob:')) {
        const response = await fetch(backgroundImage);
        const blob = await response.blob();
        mimeType = blob.type;
        
        base64Data = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => {
            const result = reader.result as string;
            const match = result.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/);
            if (match) {
              resolve(match[2]);
            } else {
              reject(new Error("Failed to extract base64 from blob"));
            }
          };
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      } else {
        // It's already a data URL (from AI generation)
        const match = backgroundImage.match(/^data:(image\/[a-zA-Z+]+);base64,(.+)$/);
        if (!match) throw new Error("Invalid image format. Must be a generated image or uploaded file.");
        mimeType = match[1];
        base64Data = match[2];
      }
      
      const newImageUrl = await editEmotionImage(base64Data, mimeType, imageEditPrompt);
      if (newImageUrl) {
        setBackgroundImage(newImageUrl);
        setImageEditPrompt('');
        setShowImageEditInput(false);
      }
    } catch (error: any) {
      console.error("Failed to edit image", error);
      alert(error.message || "Failed to edit image. Please try again.");
    } finally {
      setIsEditingImage(false);
    }
  };

  const handleGenerateMeditation = async () => {
    if (entries.length === 0) return;
    setIsGeneratingMeditation(true);
    try {
      const recentContext = entries.slice(0, 3).map(e => e.content).join(" ");
      const result = await generateMeditationAudio(recentContext);
      if (result) {
        setMeditationAudio(`data:audio/wav;base64,${result.audioBase64}`);
        setMeditationScript(result.script);
      }
    } catch (error) {
      console.error("Failed to generate meditation", error);
    } finally {
      setIsGeneratingMeditation(false);
    }
  };

  const toggleMeditationPlayback = () => {
    if (meditationAudioRef.current) {
      if (isPlayingMeditation) {
        meditationAudioRef.current.pause();
      } else {
        meditationAudioRef.current.play();
      }
      setIsPlayingMeditation(!isPlayingMeditation);
    }
  };

  const handleCompleteHabit = (id: string) => {
    setHabits(prev => prev.map(h => {
      if (h.id === id) {
        if (!h.completedAt) {
          setWaterDrops(w => w + 3); // Earn 3 water drops!
        }
        return { ...h, completedAt: h.completedAt ? null : Date.now() };
      }
      return h;
    }));
  };

  const handleWaterPlant = (id: string) => {
    if (waterDrops <= 0) return;
    
    setHabits(prev => prev.map(h => {
      if (h.id === id && h.plantType !== 'tree') {
        const currentGrowth = h.growth || 0;
        const newGrowth = Math.min(100, currentGrowth + 20);
        let nextType = h.plantType;
        
        if (newGrowth >= 100) nextType = 'tree';
        else if (newGrowth >= 60) nextType = 'flower';
        else if (newGrowth >= 30) nextType = 'sprout';
        else nextType = 'seed';

        setWaterDrops(w => w - 1);
        return { ...h, growth: newGrowth, plantType: nextType };
      }
      return h;
    }));
  };

  useEffect(() => {
    if (activeTab === 'insights' && !deepInsights && entries.length > 0) {
      fetchDeepInsights();
    }
  }, [activeTab, entries.length]);

  const handleSaveEntry = () => {
    if (!newContent.trim() && !backgroundImage) return;
    const now = new Date();
    const entryData: JournalEntry = {
      id: editingId || Date.now().toString(),
      date: now.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      timestamp: now.getTime(),
      title: newTitle || (backgroundImage ? 'Visual Memory' : 'Untitled Reflection'),
      content: newContent,
      mood: selectedMood,
      tags: generatedTags.length > 0 ? generatedTags : ['Journal'],
      reflection: aiReflection,
      actionItem: aiAction,
      summary: aiSummary,
      image: backgroundImage || undefined,
      visualizerSettings: backgroundImage ? visualizerSettings : undefined,
      sentimentScore,
      energyLevel,
      anxietyLevel
    };
    if (editingId) setEntries(entries.map(e => e.id === editingId ? entryData : e));
    else setEntries([entryData, ...entries]);
    setIsEditorOpen(false);
    resetEditor();
  };
  
  const handleEditEntry = (entry: JournalEntry) => {
      setEditingId(entry.id);
      setNewTitle(entry.title);
      setNewContent(entry.content);
      setSelectedMood(entry.mood);
      setGeneratedTags(entry.tags);
      setAiReflection(entry.reflection || '');
      setAiAction(entry.actionItem || '');
      setAiSummary(entry.summary || '');
      setBackgroundImage(entry.image || null);
      setVisualizerSettings(entry.visualizerSettings ? { ...DEFAULT_SETTINGS, ...entry.visualizerSettings } : DEFAULT_SETTINGS);
      setSentimentScore(entry.sentimentScore || 50);
      setEnergyLevel(entry.energyLevel || 50);
      setAnxietyLevel(entry.anxietyLevel || 0);
      setIsEditorOpen(true);
  };
  
  const resetEditor = () => {
      setEditingId(null);
      setNewTitle('');
      setNewContent('');
      setSelectedMood('neutral');
      setGeneratedTags([]);
      setAiReflection('');
      setAiAction('');
      setAiSummary('');
      setSentimentScore(50);
      setEnergyLevel(50);
      setAnxietyLevel(0);
      setIsPrismMode(false);
      setDistortions([]);
      setActiveDistortion(null);
      setIsListening(false);
      setBackgroundImage(null);
      setVisualizerSettings(DEFAULT_SETTINGS);
      setIsSettingsOpen(false);
      if (mediaStreamRef.current) {
          mediaStreamRef.current.getTracks().forEach(track => track.stop());
          mediaStreamRef.current = null;
      }
      if (audioContextRef.current) {
          audioContextRef.current.close();
          audioContextRef.current = null;
      }
      analyserRef.current = null;
  };

  const isImmersive = !!backgroundImage;

  const renderPrismContent = () => {
    if (distortions.length === 0 && !isAnalyzingDistortions) {
        return (
            <div className="flex flex-col items-center justify-center h-full text-center p-8 opacity-60">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mb-4 text-primary">
                    <ScanEye size={32} />
                </div>
                <p className="font-serif text-lg">Your thoughts appear balanced through the prism.</p>
                <button onClick={() => setIsPrismMode(false)} className="mt-4 text-primary font-bold hover:underline">Return to Clarity</button>
            </div>
        );
    }

    if (isAnalyzingDistortions) {
        return (
             <div className="flex flex-col items-center justify-center h-full text-center p-8">
                <div className="relative w-20 h-20 mb-6">
                    <div className="absolute inset-0 bg-primary/20 rounded-full animate-ping" />
                    <div className="absolute inset-2 bg-secondary/20 rounded-full animate-ping delay-75" />
                    <div className="relative z-10 w-full h-full bg-white border border-border rounded-full flex items-center justify-center">
                        <Triangle size={32} className="text-primary animate-pulse" />
                    </div>
                </div>
                <p className="font-serif text-xl animate-pulse">The Prism is refracting your thoughts...</p>
                <p className="text-muted-foreground text-sm mt-2">Searching for cognitive distortions</p>
            </div>
        );
    }

    let lastIndex = 0;
    const elements = [];
    const sortedDistortions = [...distortions].sort((a,b) => newContent.indexOf(a.originalText) - newContent.indexOf(b.originalText));

    sortedDistortions.forEach((d, i) => {
        const index = newContent.indexOf(d.originalText, lastIndex);
        if (index === -1) return;
        if (index > lastIndex) elements.push(<span key={`text-${i}`}>{newContent.substring(lastIndex, index)}</span>);
        elements.push(
            <span 
                key={`dist-${i}`}
                onClick={() => setActiveDistortion(d)}
                className={`
                    relative cursor-pointer inline-block px-1 rounded-md mx-0.5 transition-all duration-300
                    ${activeDistortion === d 
                        ? 'bg-red-500 text-white shadow-lg shadow-red-500/20 scale-105 z-10' 
                        : 'bg-red-50 text-red-900 hover:bg-red-100 border-b-2 border-red-200'}
                `}
            >
                {d.originalText}
                {activeDistortion !== d && <span className="absolute -top-1 -right-1 w-2 h-2 bg-red-400 rounded-full animate-bounce"></span>}
            </span>
        );
        lastIndex = index + d.originalText.length;
    });

    if (lastIndex < newContent.length) elements.push(<span key="text-end">{newContent.substring(lastIndex)}</span>);

    return (
        <div className="text-xl leading-[1.8] text-foreground font-serif p-4 relative min-h-[200px]">
            <div className="relative z-10">{elements}</div>
            {activeDistortion && (
                <div className="absolute top-0 left-0 right-0 z-50 mt-4 p-6 bg-white/98 backdrop-blur-2xl border border-border shadow-2xl rounded-3xl animate-in fade-in slide-in-from-bottom-4">
                    <div className="flex justify-between items-start mb-5">
                        <div className="flex gap-3 items-center">
                            <div className="p-2 rounded-xl bg-red-50 text-red-500">
                                <ScanEye size={20} />
                            </div>
                            <div>
                                <span className="text-[10px] font-bold text-red-500 uppercase tracking-widest">{activeDistortion.type}</span>
                                <h4 className="font-bold text-lg text-foreground">A New Perspective</h4>
                            </div>
                        </div>
                        <button onClick={() => setActiveDistortion(null)} className="p-1.5 hover:bg-muted rounded-full transition-colors"><X size={18} /></button>
                    </div>
                    <p className="text-sm text-muted-foreground leading-relaxed mb-6 bg-muted/20 p-4 rounded-2xl">"{activeDistortion.explanation}"</p>
                    <div className="grid md:grid-cols-3 gap-3">
                        {activeDistortion.reframes.map((opt, idx) => (
                            <button 
                                key={idx}
                                onClick={() => handleApplyReframe(opt.text, activeDistortion.originalText)}
                                className="text-left p-4 rounded-2xl bg-white border border-border hover:border-primary/50 hover:bg-primary/5 transition-all group"
                            >
                                <div className="flex items-center gap-2 mb-2">
                                    <span className={`w-2 h-2 rounded-full ${opt.perspective === 'rational' ? 'bg-blue-400' : opt.perspective === 'compassionate' ? 'bg-pink-400' : 'bg-gray-400'}`}></span>
                                    <span className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground group-hover:text-primary">{opt.perspective}</span>
                                </div>
                                <p className="text-sm font-medium text-foreground leading-relaxed">"{opt.text}"</p>
                            </button>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
  };

  return (
    <div className="min-h-screen bg-background text-foreground font-sans">
      <header className="sticky top-0 z-30 bg-background/80 backdrop-blur-md border-b border-border/50 px-4 md:px-6 py-4 flex items-center justify-between">
         <div className="flex items-center gap-3">
             <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center text-primary shadow-sm">
                 <Activity size={20} />
             </div>
             <h1 className="font-serif font-bold text-xl tracking-tight">Lumina <span className="text-muted-foreground font-sans font-normal text-base ml-1 hidden sm:inline">Dashboard</span></h1>
         </div>
         <div className="flex items-center gap-3 sm:gap-4">
             <button onClick={onLogout} className="text-sm font-bold text-muted-foreground hover:text-red-500 transition-colors hidden sm:inline">Log Out</button>
             <div className="w-10 h-10 rounded-full overflow-hidden border border-border shadow-sm cursor-pointer hover:border-primary transition-colors" onClick={onOpenProfile}>
                 <img src={userAvatar} alt={userName} className="w-full h-full object-cover" />
             </div>
         </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8 grid lg:grid-cols-12 gap-8">
        <div className="lg:col-span-4 space-y-6">
            <div className="bg-card p-6 sm:p-8 rounded-[2rem] sm:rounded-[2.5rem] border border-border/60 shadow-sm relative overflow-hidden group">
                <div className="relative z-10">
                    <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-2 block">Welcome Home</span>
                    <h2 className="font-serif text-2xl sm:text-3xl font-bold text-foreground mb-6 leading-tight">Ready to reflect,<br/><span className="text-secondary italic">{userName.split(' ')[0]}?</span></h2>
                    <Button onClick={() => { resetEditor(); setIsEditorOpen(true); }} className="w-full justify-between hover:shadow-lg transition-all">
                        <span>New Reflection</span>
                        <PenLine size={18} />
                    </Button>
                </div>
                <div className="absolute top-0 right-0 w-32 h-32 bg-secondary/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/3" />
            </div>

            <div className="bg-card p-6 sm:p-8 rounded-[2rem] sm:rounded-[2.5rem] border border-border/60 shadow-sm">
                <div className="flex items-center justify-between mb-8">
                    <div>
                        <h3 className="font-serif font-bold text-lg">Wellness Flow</h3>
                        <p className="text-xs text-muted-foreground">Historical Resonance</p>
                    </div>
                    <div className="bg-primary/10 text-primary px-3 py-1 rounded-full text-xs font-bold flex items-center gap-1 border border-primary/20">
                        <TrendingUp size={14} /> {averageScore}%
                    </div>
                </div>
                <div className="h-44 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={chartData}>
                            <defs>
                                <linearGradient id="colorScore" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="5%" stopColor="#5D7052" stopOpacity={0.3}/>
                                    <stop offset="95%" stopColor="#5D7052" stopOpacity={0}/>
                                </linearGradient>
                            </defs>
                            <Tooltip 
                                contentStyle={{ borderRadius: '20px', border: 'none', boxShadow: '0 10px 30px -10px rgba(0,0,0,0.1)', padding: '12px' }}
                                itemStyle={{ color: '#5D7052', fontWeight: 'bold' }}
                            />
                            <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{ fill: '#9CA3AF', fontSize: 10, fontWeight: 'bold' }} dy={10} />
                            <Area type="monotone" dataKey="score" stroke="#5D7052" strokeWidth={4} fillOpacity={1} fill="url(#colorScore)" animationDuration={1500} />
                        </AreaChart>
                    </ResponsiveContainer>
                </div>
            </div>

            <div className="bg-muted/50 p-6 sm:p-8 rounded-[2rem] sm:rounded-[2.5rem] border border-border/40">
                 <h3 className="font-serif font-bold text-lg mb-6">Support Team</h3>
                 <div className="space-y-4">
                     {therapists.slice(0, 3).map(t => (
                         <div key={t.id} onClick={() => onNavigateToChat(t)} className="flex items-center gap-4 p-4 bg-card rounded-2xl border border-border/40 hover:border-primary/30 cursor-pointer transition-all hover:shadow-md group">
                             <div className="w-12 h-12 rounded-full overflow-hidden bg-muted/10 border-2 border-white shadow-sm transition-transform group-hover:scale-105">
                                 <img src={t.avatarUrl} alt={t.name} className="object-cover w-full h-full" />
                             </div>
                             <div className="flex-1">
                                 <div className="font-bold text-sm text-foreground group-hover:text-primary transition-colors">{t.name}</div>
                                 <div className="text-[10px] text-muted-foreground font-bold uppercase tracking-widest">{t.role}</div>
                             </div>
                             <div className="w-9 h-9 rounded-full bg-muted/20 flex items-center justify-center text-muted-foreground group-hover:bg-primary group-hover:text-white transition-all">
                                 <MessageSquare size={16} />
                             </div>
                         </div>
                     ))}
                 </div>
                 <button onClick={() => onNavigateToChat()} className="w-full mt-6 py-2 text-[10px] font-bold text-muted-foreground uppercase tracking-[0.2em] hover:text-primary transition-colors flex items-center justify-center gap-2">
                     Consult Full Sanctuary <ArrowRight size={14} />
                 </button>
            </div>
        </div>

        <div className="lg:col-span-8">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-8 sm:mb-10 gap-4">
                <div className="flex bg-muted/50 p-1 rounded-full border border-border/40 overflow-x-auto hide-scrollbar">
                    <button 
                        onClick={() => setActiveTab('timeline')}
                        className={`px-4 sm:px-6 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap ${activeTab === 'timeline' ? 'bg-card shadow-sm text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
                    >
                        Timeline
                    </button>
                    <button 
                        onClick={() => setActiveTab('insights')}
                        className={`px-4 sm:px-6 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap ${activeTab === 'insights' ? 'bg-card shadow-sm text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
                    >
                        Insights
                    </button>
                    <button 
                        onClick={() => setActiveTab('soundscapes')}
                        className={`px-4 sm:px-6 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap ${activeTab === 'soundscapes' ? 'bg-card shadow-sm text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
                    >
                        Soundscapes
                    </button>
                    <button 
                        onClick={() => setActiveTab('garden')}
                        className={`px-4 sm:px-6 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap flex items-center gap-2 ${activeTab === 'garden' ? 'bg-card shadow-sm text-green-600' : 'text-muted-foreground hover:text-green-600'}`}
                    >
                        <Leaf size={16} /> Garden
                    </button>
                </div>
                <div className="flex gap-2 w-full sm:w-auto">
                    <button className="flex-1 sm:flex-none p-3 text-muted-foreground hover:text-foreground bg-card border border-border/40 rounded-full transition-all shadow-sm hover:shadow-md flex justify-center"><Search size={20} /></button>
                    <button className="flex-1 sm:flex-none p-3 text-muted-foreground hover:text-foreground bg-card border border-border/40 rounded-full transition-all shadow-sm hover:shadow-md flex justify-center"><Calendar size={20} /></button>
                </div>
            </div>

            {activeTab === 'timeline' && (
                <div className="relative space-y-8 sm:space-y-10 pl-6 sm:pl-0 animate-in fade-in slide-in-from-bottom-4 duration-500">
                    <div className="absolute left-3 sm:left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-border/50 via-border to-transparent sm:-translate-x-1/2" />
                    
                    <div className="relative flex items-center justify-center mb-12 sm:mb-16">
                         <div onClick={() => { resetEditor(); setIsEditorOpen(true); }} className="bg-card border-2 border-dashed border-primary/20 rounded-full px-6 sm:px-10 py-3 sm:py-4 flex items-center gap-3 sm:gap-4 cursor-pointer hover:border-primary/50 hover:bg-primary/5 transition-all group z-10 shadow-sm">
                            <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center group-hover:rotate-90 transition-transform duration-500"><Plus size={18} /></div>
                            <span className="font-serif text-base sm:text-lg font-bold text-primary">Capture a Thought</span>
                         </div>
                    </div>

                    {entries.sort((a,b) => b.timestamp - a.timestamp).map((entry, index) => {
                        const isLeft = index % 2 === 0;
                        return (
                            <div key={entry.id} onClick={() => handleEditEntry(entry)} className={`relative md:flex items-center justify-between ${isLeft ? 'md:flex-row-reverse' : ''} group cursor-pointer animate-in fade-in slide-in-from-bottom-8 duration-500`} style={{ animationDelay: `${index * 100}ms` }}>
                            <div className="absolute left-3 sm:left-1/2 w-5 h-5 sm:w-6 sm:h-6 rounded-full border-[3px] sm:border-4 border-background bg-card shadow-md z-10 -translate-x-1/2 flex items-center justify-center transition-all group-hover:scale-125 group-hover:bg-primary">
                                <div className="w-1.5 h-1.5 rounded-full bg-primary group-hover:bg-primary-foreground transition-colors" />
                            </div>
                            <div className="hidden md:block w-[42%] text-center md:text-right px-6"><span className={`text-[10px] font-bold text-muted-foreground uppercase tracking-[0.2em] ${isLeft ? 'md:text-left' : ''}`}>{entry.date}</span></div>
                            <div className="w-full md:w-[46%] bg-card p-6 sm:p-8 rounded-[1.5rem] sm:rounded-[2.5rem] border border-border/50 shadow-sm hover:shadow-2xl hover:-translate-y-2 transition-all duration-500 relative overflow-hidden group-hover:border-primary/20">
                                {entry.image && (
                                    <div className="w-[calc(100%+3rem)] sm:w-[calc(100%+4rem)] h-48 sm:h-64 -mx-6 sm:-mx-8 -mt-6 sm:-mt-8 mb-6 relative overflow-hidden bg-black/90">
                                        <Visualizer imageSrc={entry.image} audioAnalyser={null} settings={entry.visualizerSettings || DEFAULT_SETTINGS} className="w-full h-full opacity-80" />
                                        <div className="absolute inset-0 bg-gradient-to-t from-white/20 to-transparent pointer-events-none" />
                                    </div>
                                )}
                                <div className="absolute top-4 right-4 sm:top-6 sm:right-6 z-10 flex gap-2">
                                    <button 
                                      onClick={(e) => handleShare(e, entry)}
                                      className="p-1.5 sm:p-2 rounded-xl bg-muted/30 backdrop-blur-sm border border-white/50 text-muted-foreground hover:text-primary hover:bg-muted/50 transition-colors"
                                      title="Share Entry"
                                    >
                                      <Share2 size={18} />
                                    </button>
                                    <div className="p-1.5 sm:p-2 rounded-xl bg-muted/30 backdrop-blur-sm border border-white/50">{moodIcons[entry.mood]}</div>
                                </div>
                                <span className="md:hidden text-[10px] font-bold text-muted-foreground uppercase tracking-[0.2em] mb-2 block">{entry.date}</span>
                                <h3 className="font-serif text-xl sm:text-2xl font-bold text-foreground mb-2 sm:mb-3 leading-tight group-hover:text-primary transition-colors">{entry.title}</h3>
                                <p className="text-muted-foreground text-sm leading-relaxed mb-4 sm:mb-6 line-clamp-3 font-medium opacity-80">{entry.content}</p>
                                {(entry.reflection || entry.actionItem) && (
                                    <div className="mb-4 sm:mb-6 p-4 sm:p-5 bg-muted/50 rounded-2xl sm:rounded-3xl space-y-3 sm:space-y-4 border border-border/20">
                                        {entry.reflection && (
                                            <div className="flex gap-2 sm:gap-3 items-start">
                                                <div className="p-1.5 rounded-lg bg-card shadow-sm shrink-0"><Lightbulb size={12} className="text-secondary" /></div>
                                                <p className="text-[11px] sm:text-xs text-foreground/70 italic leading-relaxed">"{entry.reflection}"</p>
                                            </div>
                                        )}
                                        {entry.sentimentScore !== undefined && (
                                            <div className="flex items-center gap-3 pt-2 sm:pt-3 border-t border-border/30">
                                                <div className="flex-1 h-1 bg-muted/50 rounded-full overflow-hidden">
                                                    <div className="h-full bg-secondary rounded-full transition-all duration-1000" style={{ width: `${entry.sentimentScore}%` }}></div>
                                                </div>
                                                <span className="text-[9px] font-bold text-secondary uppercase tracking-widest">{entry.sentimentScore}% Score</span>
                                            </div>
                                        )}
                                    </div>
                                )}
                                <div className="flex flex-wrap gap-1.5 pt-4 sm:pt-6 border-t border-border/20">
                                    {entry.tags.map(tag => (
                                        <span key={tag} className="px-2.5 py-1 rounded-full bg-muted/20 text-[9px] font-bold uppercase tracking-widest text-muted-foreground transition-colors hover:bg-muted/40">#{tag}</span>
                                    ))}
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>
            )}

            {activeTab === 'insights' && (
                <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 space-y-6">
                    {entries.length === 0 ? (
                        <div className="bg-card p-8 rounded-[2rem] border border-border/60 shadow-sm flex flex-col items-center justify-center min-h-[400px] text-center">
                            <div className="w-16 h-16 bg-secondary/10 text-secondary rounded-full flex items-center justify-center mb-4">
                                <BarChart3 size={32} />
                            </div>
                            <h3 className="font-serif text-2xl font-bold mb-2">Deeper Insights</h3>
                            <p className="text-muted-foreground max-w-md">Advanced analytics and mood patterns will appear here as you continue your journaling journey.</p>
                        </div>
                    ) : isGeneratingInsights ? (
                        <div className="bg-card p-12 rounded-[2rem] border border-border/60 shadow-sm flex flex-col items-center justify-center min-h-[400px] text-center">
                            <Loader2 size={40} className="text-secondary animate-spin mb-6" />
                            <h3 className="font-serif text-2xl font-bold mb-2">Analyzing Your Journey</h3>
                            <p className="text-muted-foreground max-w-md">Lumina is looking for hidden patterns and generating your mental health summary...</p>
                        </div>
                    ) : deepInsights ? (
                        <>
                            <div className="grid md:grid-cols-2 gap-6">
                                <div className="bg-gradient-to-br from-primary/10 to-secondary/10 p-8 rounded-[2rem] border border-border/60 shadow-sm relative overflow-hidden">
                                    <div className="relative z-10">
                                        <h3 className="font-serif text-3xl font-bold mb-2 text-foreground">Your Journey</h3>
                                        <p className="text-muted-foreground mb-6">A summary of your emotional landscape.</p>
                                        
                                        <div className="space-y-6">
                                            <div>
                                                <span className="text-[10px] font-bold uppercase tracking-widest text-primary mb-1 block">Low Points Overcome</span>
                                                <div className="text-4xl font-bold text-foreground">{deepInsights.mentalHealthWrapped.lowPointsOvercome}</div>
                                            </div>
                                            
                                            <div>
                                                <span className="text-[10px] font-bold uppercase tracking-widest text-secondary mb-2 block">Top Positive Words</span>
                                                <div className="flex flex-wrap gap-2">
                                                    {deepInsights.mentalHealthWrapped.topPositiveWords.map((word: string, i: number) => (
                                                        <span key={i} className="px-3 py-1.5 bg-white/50 dark:bg-black/20 rounded-full text-sm font-medium border border-border/50">
                                                            {word}
                                                        </span>
                                                    ))}
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-primary/20 rounded-full blur-3xl"></div>
                                </div>

                                <div className="bg-card p-8 rounded-[2rem] border border-border/60 shadow-sm flex flex-col justify-center">
                                    <div className="mb-6">
                                        <div className="w-10 h-10 bg-secondary/10 text-secondary rounded-xl flex items-center justify-center mb-4">
                                            <Sparkles size={20} />
                                        </div>
                                        <h4 className="font-serif text-xl font-bold mb-2">Lumina's Summary</h4>
                                        <p className="text-muted-foreground text-sm leading-relaxed italic">"{deepInsights.mentalHealthWrapped.summary}"</p>
                                    </div>
                                    <div className="pt-6 border-t border-border/40">
                                        <span className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground mb-2 block">Area of Greatest Growth</span>
                                        <p className="font-medium text-foreground">{deepInsights.mentalHealthWrapped.growthArea}</p>
                                    </div>
                                </div>
                            </div>

                            <div className="bg-card p-8 rounded-[2rem] border border-border/60 shadow-sm">
                                <div className="flex items-center gap-3 mb-8">
                                    <div className="w-10 h-10 bg-red-500/10 text-red-500 rounded-xl flex items-center justify-center">
                                        <Activity size={20} />
                                    </div>
                                    <div>
                                        <h3 className="font-serif text-xl font-bold">Trigger Identification</h3>
                                        <p className="text-xs text-muted-foreground">Patterns Lumina noticed in your entries</p>
                                    </div>
                                </div>

                                <div className="space-y-4">
                                    {deepInsights.triggerIdentification.map((trigger: any, i: number) => (
                                        <div key={i} className="p-5 rounded-2xl bg-muted/30 border border-border/40 flex flex-col sm:flex-row gap-4 sm:items-center">
                                            <div className="sm:w-1/3">
                                                <span className="text-[10px] font-bold uppercase tracking-widest text-red-500 mb-1 block">Trigger</span>
                                                <div className="font-bold text-lg">{trigger.trigger}</div>
                                            </div>
                                            <div className="sm:w-1/3">
                                                <span className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground mb-1 block">Observed Effect</span>
                                                <div className="text-sm">{trigger.effect}</div>
                                            </div>
                                            <div className="sm:w-1/3">
                                                <span className="text-[10px] font-bold uppercase tracking-widest text-primary mb-1 block">Suggestion</span>
                                                <div className="text-sm italic text-muted-foreground">"{trigger.suggestion}"</div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </>
                    ) : (
                        <div className="bg-card p-8 rounded-[2rem] border border-border/60 shadow-sm flex flex-col items-center justify-center min-h-[400px] text-center">
                            <p className="text-muted-foreground">Unable to generate insights at this time.</p>
                            <Button onClick={fetchDeepInsights} className="mt-4">Try Again</Button>
                        </div>
                    )}
                </div>
            )}

            {activeTab === 'soundscapes' && (
                <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 space-y-6">
                    <div className="bg-card p-8 rounded-[2rem] border border-border/60 shadow-sm flex flex-col items-center justify-center min-h-[400px] text-center relative overflow-hidden">
                        <div className="relative z-10 w-full max-w-2xl mx-auto flex flex-col items-center">
                            <div className="w-20 h-20 bg-blue-500/10 text-blue-500 rounded-full flex items-center justify-center mb-6 shadow-inner">
                                <Music size={40} />
                            </div>
                            <h3 className="font-serif text-3xl font-bold mb-4">Sonic Sanctuary</h3>
                            
                            {isGeneratingMeditation ? (
                                <div className="flex flex-col items-center mt-8">
                                    <Loader2 size={32} className="text-blue-500 animate-spin mb-4" />
                                    <p className="text-muted-foreground">Crafting your personalized meditation...</p>
                                </div>
                            ) : meditationAudio ? (
                                <div className="mt-8 w-full bg-background/50 backdrop-blur-sm p-8 rounded-3xl border border-border/50 shadow-lg">
                                    <div className="flex flex-col items-center gap-6">
                                        <button 
                                            onClick={toggleMeditationPlayback}
                                            className="w-20 h-20 rounded-full bg-blue-500 text-white flex items-center justify-center hover:bg-blue-600 hover:scale-105 transition-all shadow-xl shadow-blue-500/20"
                                        >
                                            {isPlayingMeditation ? <Activity size={32} className="animate-pulse" /> : <Play size={32} className="ml-2" />}
                                        </button>
                                        <div className="text-center space-y-4">
                                            <p className="text-sm font-bold uppercase tracking-widest text-blue-500">Your Guided Meditation</p>
                                            <p className="font-serif text-lg italic text-foreground/80 leading-relaxed">"{meditationScript}"</p>
                                        </div>
                                        <audio 
                                            ref={meditationAudioRef} 
                                            src={meditationAudio} 
                                            onEnded={() => setIsPlayingMeditation(false)}
                                            className="hidden"
                                        />
                                    </div>
                                </div>
                            ) : (
                                <>
                                    <p className="text-muted-foreground max-w-md mb-8 text-lg">Generate a personalized guided meditation based on your recent thoughts and feelings.</p>
                                    <Button 
                                        onClick={handleGenerateMeditation} 
                                        disabled={entries.length === 0}
                                        className="bg-blue-500 hover:bg-blue-600 text-white shadow-lg shadow-blue-500/20 px-8 py-6 rounded-full text-lg"
                                    >
                                        <Sparkles size={20} className="mr-2" /> Generate My Meditation
                                    </Button>
                                    {entries.length === 0 && (
                                        <p className="text-xs text-muted-foreground mt-4">Add some journal entries first so Lumina can personalize your meditation.</p>
                                    )}
                                </>
                            )}
                        </div>
                        <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-blue-500/5 to-purple-500/5 pointer-events-none"></div>
                    </div>
                </div>
            )}

            {activeTab === 'garden' && (
                <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 w-full h-full pb-10">
                    <PixelGarden 
                        habits={habits} 
                        waterDrops={waterDrops} 
                        onWaterPlant={handleWaterPlant} 
                        onAddDrop={() => setWaterDrops(w => w + 5)}
                    />
                </div>
            )}
        </div>
      </main>

      {isEditorOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-0 sm:p-4 md:p-6 overflow-hidden">
              <div className="absolute inset-0 bg-black/70 backdrop-blur-md animate-in fade-in duration-500" onClick={() => setIsEditorOpen(false)} />
              <div className={`relative z-10 w-full max-w-4xl bg-background shadow-2xl overflow-hidden flex flex-col animate-in zoom-in-95 duration-500 h-full sm:h-[95vh] md:h-[92vh] sm:rounded-[2rem] md:rounded-[3rem] ${isImmersive ? 'bg-black text-white' : ''}`}>
                  
                  {isGeneratingImage && (
                      <div className="absolute inset-0 z-[100] bg-background/80 backdrop-blur-sm flex flex-col items-center justify-center animate-in fade-in duration-300">
                          <Loader2 size={48} className="text-primary animate-spin mb-6" />
                          <h3 className="font-serif text-2xl font-bold mb-2">Visualizing Your Feelings...</h3>
                          <p className="text-muted-foreground">This may take a few moments.</p>
                      </div>
                  )}

                  {isImmersive && backgroundImage && (
                      <div className="absolute inset-0 z-0">
                          <Visualizer imageSrc={backgroundImage} audioAnalyser={analyserRef.current} settings={visualizerSettings} />
                          <div className="absolute inset-0 bg-black/50 pointer-events-none" />
                      </div>
                  )}

                  <div className={`p-4 sm:p-6 md:p-8 flex justify-between items-center relative z-30 ${isImmersive ? 'bg-transparent text-white' : 'bg-background/50 backdrop-blur-xl border-b border-border/30'}`}>
                      <div className="flex items-center gap-3 sm:gap-4">
                        <div className={`w-9 h-9 sm:w-10 sm:h-10 rounded-xl flex items-center justify-center ${isImmersive ? 'bg-white/10 text-white' : 'bg-primary/10 text-primary'}`}><Sparkles size={18} /></div>
                        <div>
                            <h3 className={`font-serif text-lg sm:text-xl font-bold ${isImmersive ? 'text-white' : 'text-foreground'}`}>{editingId ? 'Edit Memory' : 'New Reflection'}</h3>
                            <p className={`text-[9px] font-bold uppercase tracking-widest ${isImmersive ? 'text-white/50' : 'text-muted-foreground'}`}>{isPrismMode ? 'Refraction Mode Active' : 'Clarity View'}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2 sm:gap-3 relative">
                         {editingId && (
                             <button 
                               onClick={(e) => {
                                 const entry = entries.find(e => e.id === editingId);
                                 if (entry) handleShare(e, entry);
                               }}
                               className={`p-2 sm:p-3 rounded-full transition-all ${isImmersive ? 'hover:bg-white/10 text-white' : 'hover:bg-muted text-foreground'}`}
                               title="Share Entry"
                             >
                               <Share2 size={18} />
                             </button>
                         )}
                         {isImmersive && (
                             <>
                                <button onClick={toggleListening} className={`p-2 sm:p-3 rounded-full transition-all duration-300 ${isListening ? 'bg-red-500 text-white shadow-lg shadow-red-500/20' : 'bg-white/10 hover:bg-white/20 text-white'}`}><Phone size={18} /></button>
                                <div className="relative">
                                  <button onClick={() => setIsSettingsOpen(!isSettingsOpen)} className={`p-2 sm:p-3 rounded-full transition-all ${isSettingsOpen ? 'bg-white text-black' : 'bg-white/10 hover:bg-white/20 text-white'}`}><Sliders size={18} /></button>
                                  {isSettingsOpen && (
                                    <div className="absolute top-full right-0 mt-2 w-64 bg-black/80 backdrop-blur-xl border border-white/20 rounded-2xl p-4 shadow-2xl z-50 animate-in fade-in slide-in-from-top-2">
                                      <div className="flex justify-between items-center mb-4 border-b border-white/10 pb-2">
                                        <h4 className="text-white text-xs font-bold uppercase tracking-widest">Visualizer Settings</h4>
                                        <button 
                                          onClick={() => setVisualizerSettings(prev => ({...prev, enabled: !prev.enabled}))}
                                          className={`w-8 h-4 rounded-full transition-colors relative ${visualizerSettings.enabled ? 'bg-primary' : 'bg-white/20'}`}
                                        >
                                          <div className={`w-3 h-3 rounded-full bg-white absolute top-0.5 transition-all ${visualizerSettings.enabled ? 'left-4.5' : 'left-0.5'}`} />
                                        </button>
                                      </div>
                                      <div className={`space-y-4 transition-opacity ${visualizerSettings.enabled ? 'opacity-100' : 'opacity-50 pointer-events-none'}`}>
                                        <div>
                                          <div className="flex justify-between text-white/70 text-xs mb-1">
                                            <span>Particle Size</span>
                                            <span>{visualizerSettings.particleSize.toFixed(1)}</span>
                                          </div>
                                          <input type="range" min="0.5" max="5" step="0.1" value={visualizerSettings.particleSize} onChange={(e) => setVisualizerSettings(prev => ({...prev, particleSize: parseFloat(e.target.value)}))} className="w-full accent-white" />
                                        </div>
                                        <div>
                                          <div className="flex justify-between text-white/70 text-xs mb-1">
                                            <span>Density</span>
                                            <span>{visualizerSettings.density}</span>
                                          </div>
                                          <input type="range" min="10" max="100" step="1" value={visualizerSettings.density} onChange={(e) => setVisualizerSettings(prev => ({...prev, density: parseInt(e.target.value)}))} className="w-full accent-white" />
                                        </div>
                                        <div>
                                          <div className="flex justify-between text-white/70 text-xs mb-1">
                                            <span>Intensity</span>
                                            <span>{visualizerSettings.intensity.toFixed(1)}</span>
                                          </div>
                                          <input type="range" min="0.5" max="5" step="0.1" value={visualizerSettings.intensity} onChange={(e) => setVisualizerSettings(prev => ({...prev, intensity: parseFloat(e.target.value)}))} className="w-full accent-white" />
                                        </div>
                                        <div>
                                          <div className="flex justify-between text-white/70 text-xs mb-1">
                                            <span>Sensitivity</span>
                                            <span>{visualizerSettings.sensitivity}</span>
                                          </div>
                                          <input type="range" min="50" max="150" step="1" value={visualizerSettings.sensitivity} onChange={(e) => setVisualizerSettings(prev => ({...prev, sensitivity: parseInt(e.target.value)}))} className="w-full accent-white" />
                                        </div>
                                      </div>
                                    </div>
                                  )}
                                </div>
                             </>
                         )}
                         <button onClick={() => setIsEditorOpen(false)} className={`p-2 sm:p-3 rounded-full transition-all ${isImmersive ? 'hover:bg-white/10 text-white' : 'hover:bg-muted text-foreground'}`}><X size={22} /></button>
                      </div>
                  </div>

                  <div className="flex-1 overflow-y-auto p-4 sm:p-8 md:p-12 relative z-20 custom-scrollbar">
                      {!isImmersive && !isPrismMode && (
                        <div className="mb-8 sm:mb-10 p-4 sm:p-6 bg-secondary/5 border border-secondary/10 rounded-[1.5rem] sm:rounded-[2rem] flex items-center gap-4 sm:gap-6 animate-in slide-in-from-top-4">
                            <div className="p-2 sm:p-3 bg-card rounded-xl sm:rounded-2xl shadow-sm text-secondary shrink-0"><Shuffle size={18} /></div>
                            <div className="flex-1">
                                <span className="text-[9px] font-bold uppercase tracking-[0.2em] text-secondary mb-1 block">Daily Prompt</span>
                                <p className="font-serif text-base sm:text-xl text-foreground/90 italic leading-relaxed">"{currentPrompt}"</p>
                            </div>
                            <button onClick={shufflePrompt} className="p-2 text-muted-foreground hover:text-secondary transition-colors"><RefreshCw size={16} /></button>
                        </div>
                      )}

                      <div className={`relative min-h-[250px] transition-all duration-500 ${isImmersive ? 'text-center' : ''} ${isPrismMode ? 'bg-gradient-to-br from-red-50/50 via-white to-blue-50/50 rounded-[1.5rem] sm:rounded-[2.5rem] p-6 sm:p-8 border border-white/50 shadow-inner' : ''}`}>
                          {isImmersive && (
                              <div className="mb-8 sm:mb-10">
                                  <input type="text" value={newTitle} onChange={e => setNewTitle(e.target.value)} className="w-full text-center text-3xl sm:text-4xl md:text-6xl font-serif font-bold bg-transparent border-none focus:ring-0 placeholder:text-white/20 text-white drop-shadow-xl" placeholder="Title Your Memory" />
                              </div>
                          )}
                          {isPrismMode ? renderPrismContent() : (
                              <textarea 
                                  placeholder={isImmersive ? "Speak to your memory..." : "Share what's on your mind..."}
                                  value={newContent}
                                  onChange={e => setNewContent(e.target.value)}
                                  className={`w-full bg-transparent border-none focus:ring-0 resize-none font-serif leading-relaxed ${isImmersive ? 'text-center text-xl sm:text-2xl md:text-3xl text-white/80 placeholder:text-white/20' : 'text-xl sm:text-2xl text-foreground placeholder:text-muted-foreground/20 min-h-[200px] mb-8'}`}
                                  autoFocus={!editingId} 
                              />
                          )}
                          {isListening && !isPrismMode && (
                              <div className={`flex items-center justify-center gap-2 animate-pulse ${isImmersive ? 'mt-8' : 'absolute bottom-0 right-0'}`}>
                                  <div className="w-2.5 h-2.5 bg-red-500 rounded-full shadow-[0_0_10px_rgba(239,68,68,0.5)]" />
                                  <span className="text-[9px] font-bold text-red-500 uppercase tracking-[0.2em]">Voice Active</span>
                              </div>
                          )}
                      </div>

                      {!isImmersive && !isPrismMode && (
                        <div className={`space-y-8 sm:space-y-10 transition-all duration-1000 ${aiReflection || editingId ? 'opacity-100 translate-y-0' : 'opacity-20 translate-y-8 grayscale pointer-events-none blur-sm'}`}>
                            <div className="grid sm:grid-cols-2 gap-4 sm:gap-6">
                               <div className="p-5 sm:p-6 rounded-[1.5rem] sm:rounded-[2rem] bg-muted border border-border/30">
                                  <div className="flex items-center gap-3 mb-3 sm:mb-4 text-muted-foreground"><Lightbulb size={18} /><span className="text-[9px] font-bold uppercase tracking-[0.2em]">AI Insight</span></div>
                                  <p className="text-sm sm:text-base italic leading-relaxed text-foreground">{aiReflection || "Reflecting..."}</p>
                               </div>
                               <div className="p-5 sm:p-6 rounded-[1.5rem] sm:rounded-[2rem] bg-primary/10 border border-primary/20">
                                  <div className="flex items-center gap-3 mb-3 sm:mb-4 text-primary"><CheckCircle2 size={18} /><span className="text-[9px] font-bold uppercase tracking-[0.2em]">Action Step</span></div>
                                  <p className="text-sm sm:text-base font-bold leading-relaxed text-foreground">{aiAction || "A gentle path forward..."}</p>
                               </div>
                            </div>

                            <div className="bg-card p-6 sm:p-8 rounded-[1.5rem] sm:rounded-[2.5rem] border border-border/50 shadow-sm space-y-6 sm:space-y-8">
                                <div className="flex items-center gap-3 pb-4 border-b border-border/30">
                                    <BrainCircuit size={18} className="text-primary" />
                                    <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">Psychological Evaluation</span>
                                </div>
                                <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 sm:gap-8">
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-[9px] font-bold text-muted-foreground uppercase tracking-wider"><span>Positivity</span><span>{sentimentScore}%</span></div>
                                        <div className="h-1 w-full bg-muted rounded-full overflow-hidden"><div className="h-full bg-primary rounded-full transition-all duration-1000" style={{ width: `${sentimentScore}%` }} /></div>
                                    </div>
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-[9px] font-bold text-muted-foreground uppercase tracking-wider"><span>Energy</span><span>{energyLevel}%</span></div>
                                        <div className="h-1 w-full bg-muted rounded-full overflow-hidden"><div className="h-full bg-yellow-500 rounded-full transition-all duration-1000" style={{ width: `${energyLevel}%` }} /></div>
                                    </div>
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-[9px] font-bold text-muted-foreground uppercase tracking-wider"><span>Anxiety</span><span>{anxietyLevel}%</span></div>
                                        <div className="h-1 w-full bg-muted rounded-full overflow-hidden"><div className={`h-full rounded-full transition-all duration-1000 ${anxietyLevel > 50 ? 'bg-red-400' : 'bg-blue-400'}`} style={{ width: `${anxietyLevel}%` }} /></div>
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 sm:gap-10">
                                <div className="flex flex-col gap-4">
                                    <label className="text-[9px] font-bold text-muted-foreground uppercase tracking-[0.2em]">Current Mood</label>
                                    <div className="flex gap-4 items-center">
                                        <div className="p-3 rounded-2xl bg-card border border-border shadow-sm">{moodIcons[selectedMood]}</div>
                                        <span className="font-serif text-lg sm:text-xl font-bold capitalize text-foreground">{selectedMood}</span>
                                    </div>
                                </div>
                                <div className="flex flex-col gap-4">
                                   <label className="text-[9px] font-bold text-muted-foreground uppercase tracking-[0.2em]">Metadata Tags</label>
                                   <div className="flex flex-wrap gap-2">
                                      {generatedTags.map((tag, i) => (<span key={i} className="px-3 py-1 rounded-full bg-card border border-border text-[9px] font-bold uppercase tracking-widest text-muted-foreground">#{tag}</span>))}
                                   </div>
                                </div>
                            </div>
                        </div>
                      )}
                  </div>

                  <div className={`p-4 sm:p-6 md:p-8 border-t flex flex-col sm:flex-row gap-4 items-center justify-between relative z-20 ${isImmersive ? 'border-white/10 bg-black/50 backdrop-blur-xl' : 'border-border/30 bg-background/50 backdrop-blur-xl'}`}>
                      <div className="flex flex-wrap justify-center sm:justify-start gap-2 sm:gap-3 w-full sm:w-auto">
                          {!isPrismMode && (
                              <>
                                <button onClick={toggleListening} className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all ${isListening ? 'bg-red-500 text-white border-red-500' : isImmersive ? 'bg-white/10 border-white/20 text-white' : 'bg-card border-border shadow-sm'}`}>
                                    {isListening ? <MicOff size={16} /> : <Mic size={16} />} <span className="text-[10px] font-bold uppercase tracking-widest">{isListening ? 'End' : 'Voice'}</span>
                                </button>
                                <div className="relative">
                                    <input type="file" accept="image/*" className="absolute inset-0 w-full h-full opacity-0 cursor-pointer" onChange={handleImageUpload} />
                                    <button className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all ${isImmersive ? 'bg-white/10 border-white/20 text-white' : 'bg-card border-border shadow-sm'}`}>
                                        <ImageIcon size={16} /> <span className="text-[10px] font-bold uppercase tracking-widest">Image</span>
                                    </button>
                                </div>
                                <button 
                                    onClick={handleGenerateImage} 
                                    disabled={!newContent || isGeneratingImage}
                                    className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all disabled:opacity-50 ${isImmersive ? 'bg-white/10 border-white/20 text-white' : 'bg-card border-border shadow-sm'}`}
                                >
                                    {isGeneratingImage ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />} 
                                    <span className="text-[10px] font-bold uppercase tracking-widest">Draw Feeling</span>
                                </button>
                                {backgroundImage && (
                                    <div className="relative">
                                        <button 
                                            onClick={() => setShowImageEditInput(!showImageEditInput)}
                                            className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all ${isImmersive ? 'bg-white/10 border-white/20 text-white' : 'bg-card border-border shadow-sm'}`}
                                        >
                                            <Edit2 size={16} /> <span className="text-[10px] font-bold uppercase tracking-widest">Edit Image</span>
                                        </button>
                                        {showImageEditInput && (
                                            <div className="absolute bottom-full mb-4 left-0 w-[280px] sm:w-80 bg-background/95 backdrop-blur-xl rounded-2xl shadow-2xl border border-border p-2 flex gap-2 animate-in slide-in-from-bottom-2 z-50">
                                                <input 
                                                    type="text" 
                                                    value={imageEditPrompt} 
                                                    onChange={e => setImageEditPrompt(e.target.value)} 
                                                    placeholder="e.g. Add a retro filter..." 
                                                    className="flex-1 bg-transparent border-none focus:ring-0 text-sm text-foreground placeholder:text-muted-foreground px-2 min-w-0"
                                                    onKeyDown={e => { if (e.key === 'Enter') handleEditImage(); }}
                                                    autoFocus
                                                />
                                                <button 
                                                    onClick={handleEditImage} 
                                                    disabled={!imageEditPrompt || isEditingImage}
                                                    className="p-2 bg-primary text-primary-foreground rounded-xl disabled:opacity-50 transition-colors shrink-0"
                                                >
                                                    {isEditingImage ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
                                                </button>
                                            </div>
                                        )}
                                    </div>
                                )}
                              </>
                          )}
                          {!isImmersive && (
                            <>
                                <button 
                                    onClick={isPrismMode ? () => setIsPrismMode(false) : handlePrismAnalyze} 
                                    disabled={!newContent || isAnalyzing || isAnalyzingDistortions}
                                    className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all disabled:opacity-50 ${isPrismMode ? 'bg-foreground text-background border-foreground shadow-xl' : 'bg-card border-border text-foreground shadow-sm'}`}
                                >
                                    {isAnalyzingDistortions ? <Loader2 size={16} className="animate-spin" /> : <ScanEye size={16} />}
                                    <span className="text-[10px] font-bold uppercase tracking-widest">Prism</span>
                                </button>
                                <button onClick={handleAnalyze} disabled={!newContent || isAnalyzing || isPrismMode} className={`flex items-center gap-2 px-4 py-2 sm:px-6 sm:py-3 rounded-full border transition-all disabled:opacity-50 ${aiReflection ? 'bg-primary/10 border-primary/30 text-primary' : 'bg-primary text-white border-primary shadow-lg shadow-primary/30'}`}>
                                    {isAnalyzing ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
                                    <span className="text-[10px] font-bold uppercase tracking-widest">Insight</span>
                                </button>
                            </>
                          )}
                      </div>
                      <div className="flex gap-3 w-full sm:w-auto">
                        <Button variant={ButtonVariant.GHOST} onClick={() => setIsEditorOpen(false)} className={`flex-1 sm:flex-none ${isImmersive ? 'text-white' : ''}`}>Discard</Button>
                        <Button onClick={handleSaveEntry} disabled={!newContent.trim() && !backgroundImage} className="flex-1 sm:flex-none shadow-lg">
                            <Save size={16} className="mr-2" /> {editingId ? 'Update' : 'Archive'}
                        </Button>
                      </div>
                  </div>
              </div>
          </div>
      )}
    </div>
  );
};

export default Dashboard;