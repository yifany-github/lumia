import React, { useState, useRef, useEffect } from 'react';
import { Send, Sparkles, Loader2, User } from 'lucide-react';
import { generateTherapistResponse } from '../services/geminiService';
import { ChatMessage, ButtonVariant } from '../types';
import Button from './Button';

const GeminiChat: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([
    { 
      id: 'welcome', 
      role: 'model', 
      text: "Greetings. I am Moss, your guide to sustainable living. Ask me about biophilic design, slow living, or how to bring nature into your home." 
    }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim()) return;

    const userMsg: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      text: input
    };

    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      const systemInstruction = "You are Moss, a biophilic intelligence guide. You provide advice on sustainable living, nature connection, and biophilic design. You are calm, wise, and metaphorical.";
      const responseText = await generateTherapistResponse(userMsg.text, systemInstruction);
      const modelMsg: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'model',
        text: responseText
      };
      setMessages(prev => [...prev, modelMsg]);
    } catch (error) {
      // Error handled in service, but safety fallback
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <section id="wisdom" className="relative py-32 px-4 max-w-5xl mx-auto">
       {/* Background accent */}
       <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full max-w-3xl h-[600px] bg-accent/20 rounded-[4rem] -z-10 blur-3xl" />

      <div className="grid lg:grid-cols-5 gap-12 items-center">
        
        {/* Left Side Content */}
        <div className="lg:col-span-2 space-y-6">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary font-bold text-sm">
            <Sparkles size={16} />
            <span>AI Nature Guide</span>
          </div>
          <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold leading-[1.1]">
            Ask the <span className="text-primary italic">Forest</span>
          </h2>
          <p className="text-muted-foreground text-lg leading-relaxed">
            Connect with our biophilic intelligence. Whether you seek design advice or simple mindfulness, Moss is here to listen.
          </p>
        </div>

        {/* Chat Interface */}
        <div className="lg:col-span-3 bg-white/60 backdrop-blur-sm border border-border rounded-[2.5rem] shadow-[0_10px_40px_-10px_rgba(193,140,93,0.15)] overflow-hidden h-[500px] flex flex-col relative">
          
          {/* Messages Area */}
          <div className="flex-1 overflow-y-auto p-6 space-y-6" ref={scrollRef}>
            {messages.map((msg) => (
              <div 
                key={msg.id} 
                className={`flex gap-4 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}
              >
                {/* Avatar */}
                <div className={`
                  flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center shadow-sm
                  ${msg.role === 'model' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}
                `}>
                  {msg.role === 'model' ? <Sparkles size={18} /> : <User size={18} />}
                </div>

                {/* Bubble */}
                <div className={`
                  max-w-[80%] p-4 text-sm leading-relaxed shadow-sm
                  ${msg.role === 'model' 
                    ? 'bg-white text-foreground rounded-2xl rounded-tl-sm border border-border/40' 
                    : 'bg-primary text-primary-foreground rounded-2xl rounded-tr-sm'}
                `}>
                  {msg.text}
                </div>
              </div>
            ))}
            {isLoading && (
              <div className="flex gap-4">
                <div className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center">
                   <Sparkles size={18} />
                </div>
                <div className="bg-white p-4 rounded-2xl rounded-tl-sm border border-border/40 flex items-center gap-2 text-muted-foreground text-sm">
                  <Loader2 size={16} className="animate-spin" />
                  <span>Listening to the wind...</span>
                </div>
              </div>
            )}
          </div>

          {/* Input Area */}
          <div className="p-4 bg-white/80 border-t border-border/50">
            <div className="relative flex items-center">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                placeholder="How do I care for a bonsai?"
                className="w-full h-14 pl-6 pr-14 rounded-full border border-border bg-white/50 focus:outline-none focus:ring-2 focus:ring-primary/30 transition-all text-foreground placeholder:text-muted-foreground/70"
              />
              <button 
                onClick={handleSend}
                disabled={isLoading || !input.trim()}
                className="absolute right-2 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center hover:scale-105 active:scale-95 disabled:opacity-50 disabled:hover:scale-100 transition-all"
              >
                <Send size={18} />
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default GeminiChat;