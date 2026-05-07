import React from 'react';
import Button from './Button';
import { ButtonVariant } from '../types';
import BlobBackground from './BlobBackground';
import { ArrowDown } from 'lucide-react';

const Hero: React.FC = () => {
  return (
    <section id="hero" className="relative min-h-[95vh] flex flex-col items-center justify-center px-4 pt-32 sm:pt-40 md:pt-48 pb-16 overflow-hidden bg-gradient-to-b from-background via-background to-muted">
      
      {/* Ambient Background Blobs with differentiated speeds */}
      <BlobBackground 
        variant="moss" 
        className="w-[300px] h-[300px] sm:w-[500px] sm:h-[500px] top-0 -left-20 md:w-[900px] md:h-[900px] md:-top-40 md:-left-40 blur-[80px] sm:blur-[120px]" 
      />
      <BlobBackground 
        variant="terracotta" 
        className="w-[250px] h-[250px] sm:w-[400px] sm:h-[400px] bottom-0 -right-20 md:w-[800px] md:h-[800px] md:-bottom-40 md:-right-40 blur-[80px] sm:blur-[120px]" 
        delay={2}
      />
      <BlobBackground 
        variant="sand" 
        className="w-[200px] h-[200px] sm:w-[300px] sm:h-[300px] top-1/2 right-0 md:w-[600px] md:h-[600px] md:top-20 md:right-1/4 blur-[80px] sm:blur-[120px]" 
        delay={4}
      />

      <div className="relative z-10 max-w-5xl mx-auto text-center space-y-8 sm:space-y-10 flex flex-col items-center mb-20 sm:mb-24 mt-4 sm:mt-8">
        
        {/* Animated Avatars Group - Scaled for smaller screens */}
        <div className="flex justify-center -space-x-3 sm:-space-x-4 animate-in fade-in slide-in-from-top-6 duration-1000">
          {[
            { seed: 'Willow', bg: 'e6dccd' },
            { seed: 'Serena', bg: 'ffe0b2' },
            { seed: 'Atlas', bg: 'e0e0e0' },
            { seed: 'Nimbus', bg: 'bbdefb' },
          ].map((item, i) => (
            <div 
              key={i} 
              className={`w-11 h-11 sm:w-14 sm:h-14 rounded-full border-[3px] sm:border-4 border-background overflow-hidden bg-card shadow-xl animate-float`}
              style={{ animationDelay: `${i * 0.4}s` }}
            >
              <img src={`https://api.dicebear.com/7.x/notionists/svg?seed=${item.seed}&backgroundColor=${item.bg}`} alt="Companion" className="w-full h-full object-cover" />
            </div>
          ))}
          <div 
            onClick={() => document.getElementById('companions')?.scrollIntoView({ behavior: 'smooth' })}
            className="w-11 h-11 sm:w-14 sm:h-14 rounded-full border-[3px] sm:border-4 border-background bg-card/80 backdrop-blur-md flex items-center justify-center text-[10px] sm:text-xs font-bold text-primary shadow-xl cursor-pointer hover:scale-105 transition-transform"
          >
            8+
          </div>
        </div>

        <div className="animate-in fade-in slide-in-from-bottom-10 duration-1000 flex flex-col items-center px-2">
          <span className="inline-block px-4 py-1.5 sm:px-5 sm:py-2 rounded-full border border-primary/10 bg-card/40 text-primary font-bold text-[10px] sm:text-xs tracking-[0.25em] sm:tracking-[0.3em] mb-6 sm:mb-8 backdrop-blur-md shadow-sm uppercase">
            Private Emotional Sanctuary
          </span>
          <h1 className="font-serif text-5xl sm:text-7xl md:text-8xl lg:text-9xl text-foreground font-bold tracking-tight leading-tight sm:leading-tight mb-6 sm:mb-8 text-center max-w-[90vw]">
            Clarify your <br/>
            <span className="italic text-primary relative inline-block group">
              internal world.
              <svg className="absolute w-full h-2 sm:h-4 -bottom-1 sm:-bottom-2 left-0 text-secondary/40 transition-transform duration-500 group-hover:scale-x-110" viewBox="0 0 100 10" preserveAspectRatio="none">
                <path d="M0 5 Q 50 10 100 5" stroke="currentColor" strokeWidth="5" fill="none" strokeLinecap="round" />
              </svg>
            </span>
          </h1>
          <p className="text-lg sm:text-xl md:text-3xl text-muted-foreground/80 max-w-xl md:max-w-3xl mx-auto leading-relaxed font-sans font-light text-center px-4">
            Empathetic AI companions to listen, guide, and help you find steady ground. Always present, entirely private.
          </p>
        </div>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-6 pt-4 sm:pt-6 w-full sm:w-auto animate-in fade-in slide-in-from-bottom-12 duration-1000 delay-300">
          <Button variant={ButtonVariant.PRIMARY} className="h-14 sm:h-16 px-10 sm:px-12 text-lg sm:text-xl w-[90%] sm:w-auto shadow-2xl shadow-primary/20" onClick={() => document.getElementById('companions')?.scrollIntoView({ behavior: 'smooth' })}>
            Begin Consultation
          </Button>
          <Button 
            variant={ButtonVariant.OUTLINE} 
            className="h-14 sm:h-16 px-10 sm:px-12 text-lg sm:text-xl w-[90%] sm:w-auto bg-card/50 backdrop-blur-sm border-border/50"
            onClick={() => document.getElementById('philosophy')?.scrollIntoView({ behavior: 'smooth' })}
          >
            View Philosophy
          </Button>
        </div>
      </div>
      
      {/* Refined Scroll Indicator - Hidden on very small heights to prevent clutter */}
      <div className="absolute bottom-6 left-0 right-0 z-20 flex flex-col items-center animate-bounce text-muted-foreground/40 hidden sm:flex pointer-events-none">
         <span className="text-[10px] uppercase font-bold tracking-[0.4em] mb-3">Descend</span>
         <div className="w-px h-12 md:h-16 bg-gradient-to-b from-muted-foreground/30 to-transparent" />
      </div>
      
      <style>{`
        @keyframes float {
          0%, 100% { transform: translateY(0) rotate(0); }
          50% { transform: translateY(-15px) rotate(2deg); }
        }
        .animate-float {
          animation: float 5s ease-in-out infinite;
        }
      `}</style>
    </section>
  );
};

export default Hero;