import React, { useState } from 'react';
import { Wind, ShieldAlert, Sparkles, Quote } from 'lucide-react';

interface SelfCareToolkitProps {
  onOpenBreathing: () => void;
  onOpenCrisis: () => void;
}

const affirmations = [
  "I am worthy of peace and healing.",
  "My feelings are valid, even the difficult ones.",
  "This too shall pass. I am stronger than the storm.",
  "I am allowed to take up space.",
  "Rest is productive."
];

const SelfCareToolkit: React.FC<SelfCareToolkitProps> = ({ onOpenBreathing, onOpenCrisis }) => {
  const [affirmation, setAffirmation] = useState(affirmations[0]);
  const [isFlipped, setIsFlipped] = useState(false);

  const handleNewAffirmation = () => {
    setIsFlipped(false);
    setTimeout(() => {
      const next = affirmations[(affirmations.indexOf(affirmation) + 1) % affirmations.length];
      setAffirmation(next);
      setIsFlipped(true);
    }, 200);
  };

  return (
    <section className="py-20 px-4 max-w-7xl mx-auto">
      <div className="mb-12 flex items-end justify-between">
         <div>
            <h2 className="font-serif text-4xl text-foreground font-semibold mb-2">
              Self-Care <span className="text-secondary italic">Toolkit</span>
            </h2>
            <p className="text-muted-foreground">Tools to ground yourself, right here, right now.</p>
         </div>
      </div>

      <div className="grid md:grid-cols-3 gap-6">
        
        {/* Breathing Card */}
        <div 
          onClick={onOpenBreathing}
          className="group cursor-pointer bg-card rounded-[2.5rem] p-8 border border-border shadow-sm hover:shadow-xl transition-all hover:-translate-y-1 relative overflow-hidden"
        >
          <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:opacity-20 transition-opacity">
            <Wind size={100} />
          </div>
          <div className="h-14 w-14 rounded-2xl bg-primary/10 text-primary flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
            <Wind size={28} />
          </div>
          <h3 className="font-serif text-2xl font-bold text-foreground mb-2">Breathe</h3>
          <p className="text-muted-foreground text-sm mb-6">
            A guided 4-7-8 breathing exercise to calm your nervous system instantly.
          </p>
          <span className="text-primary font-bold text-sm underline decoration-2 underline-offset-4 group-hover:text-primary/80">Start Exercise</span>
        </div>

        {/* Affirmation Card */}
        <div 
          onClick={handleNewAffirmation}
          className="group cursor-pointer bg-card rounded-[2.5rem] p-8 border border-border shadow-sm hover:shadow-xl transition-all hover:-translate-y-1 relative overflow-hidden flex flex-col"
        >
          <div className="h-14 w-14 rounded-2xl bg-accent text-secondary flex items-center justify-center mb-6 group-hover:rotate-12 transition-transform">
            <Sparkles size={28} />
          </div>
          <h3 className="font-serif text-2xl font-bold text-foreground mb-4">Daily Wisdom</h3>
          
          <div className={`relative flex-1 flex items-center justify-center bg-background rounded-2xl p-6 border border-border/50 transition-all duration-500 ${isFlipped ? 'opacity-100 scale-100' : 'opacity-50 scale-95'}`}>
             <Quote className="absolute top-4 left-4 text-border opacity-50" size={24} />
             <p className="font-serif text-lg text-center text-foreground italic">
               "{affirmation}"
             </p>
          </div>
          <p className="text-center text-xs text-muted-foreground mt-4 font-bold uppercase tracking-widest group-hover:text-secondary transition-colors">Tap for new card</p>
        </div>

        {/* Crisis Card */}
        <div 
          onClick={onOpenCrisis}
          className="group cursor-pointer bg-secondary/5 rounded-[2.5rem] p-8 border border-secondary/20 shadow-sm hover:shadow-xl transition-all hover:-translate-y-1 relative overflow-hidden"
        >
           <div className="absolute top-0 right-0 p-8 text-secondary opacity-5 group-hover:opacity-10 transition-opacity">
            <ShieldAlert size={100} />
          </div>
          <div className="h-14 w-14 rounded-2xl bg-secondary text-white flex items-center justify-center mb-6 shadow-md group-hover:shadow-lg transition-all">
            <ShieldAlert size={28} />
          </div>
          <h3 className="font-serif text-2xl font-bold text-foreground mb-2">Support</h3>
          <p className="text-muted-foreground text-sm mb-6">
            Immediate resources for when things feel too heavy to carry alone.
          </p>
          <span className="text-secondary font-bold text-sm underline decoration-2 underline-offset-4">Get Help Now</span>
        </div>

      </div>
    </section>
  );
};

export default SelfCareToolkit;