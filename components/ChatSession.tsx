import React, { useCallback, useState, useRef, useEffect } from 'react';
import { Send, Loader2, User, RefreshCcw, Lock, Key, Sparkles, Mic, MicOff } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { generateTherapistResponse, checkApiKeyAvailability, openApiKeySelector } from '../services/geminiService';
import { ChatMessage, Therapist } from '../types';
import Button from './Button';
import { ButtonVariant } from '../types';
import { useSpeechInput } from '../hooks/useSpeechInput';

interface ChatSessionProps {
  therapist: Therapist | null;
  initialPrompt?: string; 
  isLoggedIn: boolean;
  onShowAuth: () => void;
}

const markdownComponents = {
  strong: ({ node, ...props }: any) => <span className="font-bold" {...props} />,
  h1: ({ node, ...props }: any) => <h1 className="text-xl font-bold mb-2 block" {...props} />,
  h2: ({ node, ...props }: any) => <h2 className="text-lg font-bold mb-2 block" {...props} />,
  h3: ({ node, ...props }: any) => <h3 className="text-base font-bold mb-1 block" {...props} />,
  p: ({ node, ...props }: any) => <p className="mb-2 last:mb-0" {...props} />,
  ul: ({ node, ...props }: any) => <ul className="list-disc pl-4 mb-2 space-y-1" {...props} />,
  ol: ({ node, ...props }: any) => <ol className="list-decimal pl-4 mb-2 space-y-1" {...props} />,
  li: ({ node, ...props }: any) => <li className="" {...props} />,
};

const ChatSession: React.FC<ChatSessionProps> = ({ therapist, initialPrompt, isLoggedIn, onShowAuth }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [apiKeyMissing, setApiKeyMissing] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  
  const hasHandledInitialPrompt = useRef(false);
  const appendVoiceTranscript = useCallback((text: string) => {
    setInput(prev => `${prev}${prev.trim() ? ' ' : ''}${text}`.trimStart());
  }, []);
  const voiceInput = useSpeechInput({ onTranscript: appendVoiceTranscript });

  // Initialize chat when therapist changes
  useEffect(() => {
    if (therapist) {
      setApiKeyMissing(false);
      hasHandledInitialPrompt.current = false;
      
      // If there is an initialPrompt, we show that as a User message, and trigger the AI to respond
      if (initialPrompt && !hasHandledInitialPrompt.current) {
         setMessages([
           { id: 'init-context', role: 'user', text: initialPrompt }
         ]);
         setIsLoading(true);
         
         generateTherapistResponse(initialPrompt, therapist.systemInstruction)
           .then(response => {
              if (response === "ERROR_API_KEY_MISSING") {
                  setApiKeyMissing(true);
              } else {
                  setMessages(prev => [...prev, {
                    id: 'init-response', 
                    role: 'model', 
                    text: response
                  }]);
              }
              setIsLoading(false);
           })
           .catch(() => setIsLoading(false));

         hasHandledInitialPrompt.current = true;
      } else {
         // Standard greeting
         setMessages([
          { 
            id: 'welcome', 
            role: 'model', 
            text: therapist.greeting 
          }
         ]);
      }
      
      checkApiKeyAvailability().then(hasKey => {
         if (typeof window !== 'undefined' && (window as any).aistudio && !hasKey) {
             setApiKeyMissing(true);
         }
      });
    }
  }, [therapist, initialPrompt]); 

  // Auto-scroll to bottom
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isLoading, apiKeyMissing]);

  // Determine if chat should be locked based on Auth state
  // We lock if not logged in AND we have exchanged at least one real round (3+ messages including greeting, or 2+ if using initial prompt)
  const isLocked = !isLoggedIn && messages.filter(m => m.role === 'model').length >= 2;

  const handleSend = async () => {
    if (!input.trim() || !therapist) return;
    if (voiceInput.isListening) voiceInput.stop();
    
    // Safety check just in case
    if (isLocked) {
        onShowAuth();
        return;
    }

    const messageText = input.trim();
    const userMsg: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      text: messageText
    };

    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      const historyContext = messages.slice(-5).map(m => `${m.role}: ${m.text}`).join('\n');
      const prompt = `${historyContext}\nuser: ${messageText}`;

      const responseText = await generateTherapistResponse(prompt, therapist.systemInstruction);
      
      if (responseText === "ERROR_API_KEY_MISSING") {
          setApiKeyMissing(true);
          setMessages(prev => [...prev, {
              id: Date.now().toString(),
              role: 'model',
              text: "Please sign in so I can connect securely to Lumina AI."
          }]);
      } else {
          const modelMsg: ChatMessage = {
            id: (Date.now() + 1).toString(),
            role: 'model',
            text: responseText
          };
          setMessages(prev => [...prev, modelMsg]);
      }

    } catch (error) {
      // Error handling
    } finally {
      setIsLoading(false);
      // Only focus if not about to lock
      if (!(!isLoggedIn && messages.length >= 1)) { // This logic is approximate, the redraw will handle the lock state
         setTimeout(() => inputRef.current?.focus(), 100);
      }
    }
  };
  
  const handleConnectKey = async () => {
      try {
        await openApiKeySelector();
        setApiKeyMissing(false);
        if (inputRef.current) inputRef.current.focus();
      } catch (e) {
        console.error("Failed to open key selector", e);
      }
  };

  if (!therapist) {
    return (
      <section id="chat-session" className="py-12 px-4 max-w-5xl mx-auto">
         <div className="bg-card/40 backdrop-blur-md border border-border/50 rounded-[2.5rem] p-12 text-center h-[500px] flex flex-col items-center justify-center relative overflow-hidden group hover:bg-card/60 transition-colors">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] bg-gradient-to-tr from-primary/10 to-secondary/10 rounded-full blur-3xl -z-10" />
            
            <div className="w-20 h-20 rounded-full bg-card shadow-lg flex items-center justify-center mb-6 text-muted-foreground relative">
              <Lock size={32} />
              <div className="absolute top-0 right-0 w-6 h-6 bg-secondary rounded-full flex items-center justify-center text-white animate-pulse">
                <span className="relative inline-flex rounded-full h-3 w-3 bg-background"></span>
              </div>
            </div>
            
            <h3 className="font-serif text-3xl font-bold text-foreground mb-3">Your Safe Space Awaits</h3>
            <p className="text-muted-foreground text-lg max-w-md mx-auto mb-8">
              Select a companion or start a journey from the Discovery section to begin.
            </p>
            
            <div className="flex gap-4">
              <button 
                onClick={() => document.getElementById('companions')?.scrollIntoView({ behavior: 'smooth' })}
                className="px-8 py-3 rounded-full bg-foreground text-background font-bold hover:scale-105 transition-transform shadow-lg"
              >
                Choose Companion
              </button>
               <button 
                onClick={() => document.getElementById('discovery')?.scrollIntoView({ behavior: 'smooth' })}
                className="px-8 py-3 rounded-full border-2 border-foreground text-foreground font-bold hover:bg-foreground hover:text-background transition-all"
              >
                Explore Topics
              </button>
            </div>
         </div>
      </section>
    );
  }

  return (
    <section id="chat-session" className="py-12 px-4 max-w-5xl mx-auto">
      <div className="grid lg:grid-cols-5 gap-8 items-start">
        
        {/* Chat Header / Info - Mobile: Top, Desktop: Left */}
        <div className="lg:col-span-2 space-y-6 lg:sticky lg:top-32">
          <div className={`inline-flex items-center gap-2 px-4 py-2 rounded-full font-bold text-sm text-white shadow-sm ${therapist.bgClass} animate-in slide-in-from-left-4 duration-500`}>
            {therapist.icon}
            <span>{isLocked ? 'Preview Session' : 'Active Session'}</span>
            <span className={`w-2 h-2 rounded-full bg-white ml-1 ${isLocked ? '' : 'animate-pulse'}`} />
          </div>
          <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold leading-[1.1]">
             Chatting with <br/>
            <span className={`italic ${therapist.colorClass}`}>{therapist.name}</span>
          </h2>
          <p className="text-muted-foreground text-lg leading-relaxed">
            This is a safe, private space. {therapist.name} is here to offer {therapist.role.toLowerCase()}.
          </p>
          
          {!isLoggedIn && (
              <div className="p-4 bg-secondary/10 border border-secondary/20 rounded-2xl flex items-start gap-3">
                  <Sparkles className="text-secondary shrink-0 mt-1" size={20} />
                  <div>
                      <h4 className="font-bold text-secondary text-sm">Free Preview</h4>
                      <p className="text-xs text-muted-foreground mt-1">You are in a preview session. Create a free account to unlock unlimited conversations.</p>
                  </div>
              </div>
          )}
        </div>

        {/* Chat Interface */}
        <div className="lg:col-span-3 bg-card/80 backdrop-blur-xl border border-border rounded-[2.5rem] shadow-[0_10px_40px_-10px_rgba(0,0,0,0.05)] overflow-hidden h-[600px] flex flex-col relative animate-in fade-in slide-in-from-bottom-8 duration-700">
          
          {/* Header Bar */}
          <div className="p-4 border-b border-border/50 bg-card/50 flex justify-between items-center">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-full overflow-hidden flex items-center justify-center border border-background shadow-sm`}>
                <img src={therapist.avatarUrl} alt={therapist.name} className="w-full h-full object-cover" />
              </div>
              <span className="font-bold text-foreground">{therapist.name}</span>
            </div>
            <button 
              onClick={() => setMessages([{ id: 'reset', role: 'model', text: therapist.greeting }])}
              className="text-xs font-bold text-muted-foreground hover:text-primary flex items-center gap-1 px-3 py-1 rounded-full hover:bg-muted transition-colors"
            >
              <RefreshCcw size={12} />
              Reset
            </button>
          </div>

          {/* Messages Area */}
          <div className="flex-1 overflow-y-auto p-6 space-y-6" ref={scrollRef}>
            {messages.map((msg) => (
              <div 
                key={msg.id} 
                className={`flex gap-4 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}
              >
                {/* Avatar */}
                <div className={`
                  flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center shadow-sm overflow-hidden
                  ${msg.role === 'model' ? 'bg-transparent' : 'bg-muted text-muted-foreground'}
                `}>
                  {msg.role === 'model' ? (
                    <img src={therapist.avatarUrl} alt={therapist.name} className="w-full h-full object-cover" />
                  ) : (
                    <User size={18} />
                  )}
                </div>

                {/* Bubble */}
                <div className={`
                  max-w-[85%] p-5 text-base leading-relaxed shadow-sm animate-in slide-in-from-bottom-2 duration-300
                  ${msg.role === 'model' 
                    ? 'bg-card text-foreground rounded-2xl rounded-tl-sm border border-border/40' 
                    : `${therapist.bgClass} text-white rounded-2xl rounded-tr-sm`}
                `}>
                  <ReactMarkdown components={markdownComponents}>
                    {msg.text}
                  </ReactMarkdown>
                </div>
              </div>
            ))}
            
            {isLoading && (
              <div className="flex gap-4 animate-pulse">
                <div className={`w-10 h-10 rounded-full overflow-hidden`}>
                   <img src={therapist.avatarUrl} alt={therapist.name} className="w-full h-full object-cover" />
                </div>
                <div className="bg-card p-4 rounded-2xl rounded-tl-sm border border-border/40 flex items-center gap-2 text-muted-foreground text-sm">
                  <Loader2 size={16} className="animate-spin" />
                  <span>Thinking...</span>
                </div>
              </div>
            )}

            {/* Locked State CTA */}
            {isLocked && !isLoading && (
                <div className="my-8 mx-auto max-w-sm bg-card border border-secondary/20 rounded-2xl p-6 shadow-xl text-center animate-in zoom-in-95 duration-500">
                    <div className="w-12 h-12 bg-secondary/10 text-secondary rounded-full flex items-center justify-center mx-auto mb-4">
                        <Lock size={20} />
                    </div>
                    <h4 className="font-serif font-bold text-xl text-foreground mb-2">Continue your Journey</h4>
                    <p className="text-muted-foreground text-sm mb-6">
                        Create a free account to unlock deep, unlimited conversations with {therapist.name}.
                    </p>
                    <Button onClick={onShowAuth} variant={ButtonVariant.PRIMARY} className="w-full h-12 text-sm">
                        Create Free Account
                    </Button>
                    <button onClick={onShowAuth} className="mt-3 text-xs text-muted-foreground hover:text-foreground underline">
                        Already have an account? Log in
                    </button>
                </div>
            )}

            {/* AI connection alert */}
            {apiKeyMissing && (
                <div className="flex flex-col items-center justify-center p-6 bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-900/30 rounded-2xl animate-in fade-in">
                    <div className="w-12 h-12 bg-red-100 dark:bg-red-900/40 text-red-500 rounded-full flex items-center justify-center mb-3">
                        <Key size={20} />
                    </div>
                    <h4 className="font-bold text-red-900 dark:text-red-100 mb-2">Connection Required</h4>
                    <p className="text-sm text-red-700 dark:text-red-200 text-center mb-4">
                        Sign in so Lumina can connect securely to the AI backend.
                    </p>
                    <Button onClick={handleConnectKey} className="h-10 text-sm">
                        Sign In
                    </Button>
                </div>
            )}
          </div>

          {/* Input Area */}
          <div className="p-4 bg-card border-t border-border/50">
            <div className="relative flex items-center">
              {isLocked ? (
                  <div className="w-full h-14 rounded-full border border-border/50 bg-muted/20 flex items-center justify-between px-6">
                      <span className="text-muted-foreground text-sm italic">Conversation locked. Please sign in to continue.</span>
                      <Lock size={16} className="text-muted-foreground" />
                  </div>
              ) : (
                <>
                  <input
                    ref={inputRef}
                    type="text"
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                    disabled={apiKeyMissing || isLoading}
                    placeholder={apiKeyMissing ? "Sign in to continue..." : "Share what's on your mind..."}
                    className="w-full h-14 pl-6 pr-24 rounded-full border border-border bg-muted/30 focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all text-foreground placeholder:text-muted-foreground/70 disabled:opacity-60 disabled:cursor-not-allowed"
                  />
                  <button
                    onClick={voiceInput.toggle}
                    disabled={!voiceInput.isSupported || apiKeyMissing || isLoading}
                    className={`
                      absolute right-14 w-10 h-10 rounded-full flex items-center justify-center transition-all
                      ${voiceInput.isListening ? 'bg-red-500 text-white shadow-lg shadow-red-500/20' : 'text-muted-foreground hover:text-primary hover:bg-muted'}
                      disabled:opacity-40 disabled:hover:bg-transparent disabled:hover:text-muted-foreground
                    `}
                    title={voiceInput.isSupported ? (voiceInput.isListening ? 'Stop voice input' : 'Start voice input') : 'Voice input is not supported in this browser'}
                    aria-label={voiceInput.isListening ? 'Stop voice input' : 'Start voice input'}
                  >
                    {voiceInput.isListening ? <MicOff size={18} /> : <Mic size={18} />}
                  </button>
                  <button 
                    onClick={handleSend}
                    disabled={isLoading || !input.trim() || apiKeyMissing}
                    className={`
                      absolute right-2 w-10 h-10 text-white rounded-full flex items-center justify-center 
                      hover:scale-105 active:scale-95 disabled:opacity-50 disabled:hover:scale-100 transition-all
                      ${therapist.bgClass}
                    `}
                  >
                    <Send size={18} />
                  </button>
                </>
              )}
            </div>
            {(voiceInput.isListening || voiceInput.interimTranscript || voiceInput.error) && !isLocked && (
              <div className="mt-2 px-5 text-xs font-bold text-muted-foreground flex items-center gap-2">
                <span className={`w-2 h-2 rounded-full ${voiceInput.error ? 'bg-red-400' : 'bg-primary animate-pulse'}`} />
                <span>{voiceInput.error || voiceInput.interimTranscript || 'Listening...'}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

export default ChatSession;
