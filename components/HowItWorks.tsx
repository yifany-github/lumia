import React from 'react';
import { UserPlus, MessageCircleHeart, Sparkles } from 'lucide-react';

const steps = [
  {
    icon: <UserPlus className="w-8 h-8 text-primary" />,
    title: "1. Choose a Companion",
    description: "Select an AI guide that resonates with your current emotional needs."
  },
  {
    icon: <MessageCircleHeart className="w-8 h-8 text-secondary" />,
    title: "2. Open Your Heart",
    description: "Share your thoughts in a private, judgment-free space whenever you need."
  },
  {
    icon: <Sparkles className="w-8 h-8 text-[#4A90E2]" />,
    title: "3. Find Clarity",
    description: "Receive empathetic insights and actionable wisdom to help you grow."
  }
];

const HowItWorks: React.FC = () => {
  return (
    <section className="py-10 px-4 max-w-7xl mx-auto">
      <div className="bg-card/50 backdrop-blur-sm rounded-[3rem] p-12 border border-border/30">
        <div className="grid md:grid-cols-3 gap-12 relative">
          {/* Connector Line (Desktop) */}
          <div className="hidden md:block absolute top-12 left-[16%] right-[16%] h-0.5 bg-gradient-to-r from-transparent via-border to-transparent -z-10" />
          
          {steps.map((step, idx) => (
            <div key={idx} className="flex flex-col items-center text-center space-y-4 group">
              <div className="w-24 h-24 rounded-full bg-card border border-border/50 shadow-[0_8px_30px_-6px_rgba(0,0,0,0.05)] flex items-center justify-center relative z-10 group-hover:scale-110 transition-transform duration-300">
                <div className="w-20 h-20 rounded-full bg-background flex items-center justify-center">
                  {step.icon}
                </div>
              </div>
              <h3 className="font-serif text-xl font-bold text-foreground">{step.title}</h3>
              <p className="text-muted-foreground text-sm max-w-[250px] leading-relaxed">{step.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;