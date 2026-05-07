import React from 'react';
import { BrainCircuit, ShieldCheck, HeartHandshake, Scale } from 'lucide-react';

const values = [
  {
    icon: <BrainCircuit size={28} />,
    title: "Cognitive Science",
    description: "Our companions are trained on principles of Cognitive Behavioral Therapy (CBT) to help identify and reshape negative thought patterns."
  },
  {
    icon: <Scale size={28} />,
    title: "Stoic Wisdom",
    description: "Drawing from ancient philosophy to help you distinguish between what you can control and what you cannot, fostering true resilience."
  },
  {
    icon: <ShieldCheck size={28} />,
    title: "Absolute Privacy",
    description: "Your emotional data is encrypted and local. We believe your sanctuary should be completely free from surveillance."
  },
  {
    icon: <HeartHandshake size={28} />,
    title: "Human-Centric AI",
    description: "Technology designed not to replace human connection, but to bridge the gap when you need support the most."
  }
];

const PhilosophySection: React.FC = () => {
  return (
    <section id="philosophy" className="py-24 px-4 bg-muted/30 relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-background rounded-full mix-blend-overlay filter blur-3xl opacity-50 -translate-y-1/2 translate-x-1/3" />

      <div className="max-w-6xl mx-auto relative z-10">
        <div className="grid lg:grid-cols-2 gap-16 items-center mb-20">
          <div>
            <span className="inline-block px-3 py-1 rounded-full border border-primary/20 bg-primary/5 text-primary text-xs font-bold tracking-widest uppercase mb-6">
              Our Mission
            </span>
            <h2 className="font-serif text-4xl md:text-5xl lg:text-6xl text-foreground font-semibold leading-[1.1] mb-8">
              Technology for the <br/>
              <span className="italic text-secondary">Soul.</span>
            </h2>
            <p className="text-xl text-muted-foreground leading-relaxed">
              In a world of constant noise and digital exhaustion, Lumina was born from a simple question: Can AI be taught to care?
            </p>
          </div>
          <div className="text-muted-foreground leading-relaxed space-y-6 text-lg">
            <p>
              We believe that mental health support should be accessible, immediate, and free of judgment. While AI cannot replace a human therapist, it can offer a profound sense of presence when you feel most alone.
            </p>
            <p>
              By combining clinical frameworks with empathetic design, we create digital spaces that feel less like machines and more like sanctuaries.
            </p>
          </div>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          {values.map((val, idx) => (
            <div 
              key={idx}
              className="bg-card p-8 rounded-[2rem] border border-border/50 hover:border-secondary/30 hover:shadow-lg transition-all duration-300 group"
            >
              <div className="w-14 h-14 rounded-2xl bg-accent text-accent-foreground flex items-center justify-center mb-6 group-hover:bg-secondary group-hover:text-white transition-colors duration-300">
                {val.icon}
              </div>
              <h3 className="font-serif text-xl font-bold text-foreground mb-3">{val.title}</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                {val.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default PhilosophySection;