import React, { useState, useEffect } from 'react';
import { X, Wind } from 'lucide-react';
import Button from './Button';
import { ButtonVariant } from '../types';

interface BreathingExerciseProps {
  isOpen: boolean;
  onClose: () => void;
}

const BreathingExercise: React.FC<BreathingExerciseProps> = ({ isOpen, onClose }) => {
  const [phase, setPhase] = useState<'inhale' | 'hold' | 'exhale'>('inhale');
  const [text, setText] = useState('Breathe In');
  const [isActive, setIsActive] = useState(false);

  useEffect(() => {
    if (!isOpen) {
      setIsActive(false);
      return;
    }

    let timeout: ReturnType<typeof setTimeout>;

    const cycle = () => {
      // Inhale (4s)
      setPhase('inhale');
      setText('Inhale...');
      
      timeout = setTimeout(() => {
        // Hold (4s - simplified from 7 for better UI pacing)
        setPhase('hold');
        setText('Hold...');
        
        timeout = setTimeout(() => {
          // Exhale (4s - simplified from 8)
          setPhase('exhale');
          setText('Exhale...');
          
          timeout = setTimeout(() => {
            if (isActive) cycle();
          }, 4000);
        }, 4000);
      }, 4000);
    };

    if (isActive) {
      cycle();
    } else {
      setPhase('inhale');
      setText('Ready?');
    }

    return () => clearTimeout(timeout);
  }, [isOpen, isActive]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-background/90 backdrop-blur-sm transition-opacity duration-300"
        onClick={onClose}
      />

      {/* Content */}
      <div className="relative z-10 w-full max-w-lg bg-card rounded-[3rem] shadow-2xl p-8 md:p-12 flex flex-col items-center justify-center border border-border/50">
        <button 
          onClick={onClose}
          className="absolute top-6 right-6 p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-full transition-colors"
        >
          <X size={24} />
        </button>

        <h3 className="font-serif text-3xl font-bold text-foreground mb-8 flex items-center gap-3">
          <Wind className="text-primary" />
          <span>Box Breathing</span>
        </h3>

        {/* Animation Circle */}
        <div className="relative w-64 h-64 flex items-center justify-center mb-12">
          {/* Outer ring */}
          <div className="absolute inset-0 rounded-full border-2 border-primary/10"></div>
          
          {/* Animated Circle */}
          <div 
            className={`
              rounded-full bg-primary/20 backdrop-blur-md flex items-center justify-center transition-all duration-[4000ms] ease-in-out
              ${phase === 'inhale' ? 'w-64 h-64 bg-primary/30' : ''}
              ${phase === 'hold' ? 'w-64 h-64 bg-primary/30 scale-105' : ''}
              ${phase === 'exhale' ? 'w-24 h-24 bg-primary/40' : ''}
              ${!isActive ? 'w-48 h-48' : ''}
            `}
          >
             <span className="font-serif text-2xl font-bold text-primary-foreground drop-shadow-md transition-all duration-300">
               {text}
             </span>
          </div>
          
          {/* Guiding Ring */}
          <div className={`absolute inset-0 rounded-full border-4 border-primary transition-all duration-[4000ms] ease-in-out opacity-20 ${phase === 'inhale' ? 'scale-100' : 'scale-50'}`} />
        </div>

        <p className="text-center text-muted-foreground mb-8 max-w-xs">
          This simple technique helps calm the nervous system and reduce stress.
        </p>

        <Button 
          onClick={() => setIsActive(!isActive)}
          variant={isActive ? ButtonVariant.OUTLINE : ButtonVariant.PRIMARY}
          className="w-48"
        >
          {isActive ? 'Pause' : 'Start'}
        </Button>
      </div>
    </div>
  );
};

export default BreathingExercise;