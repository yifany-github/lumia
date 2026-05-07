import React, { useState } from 'react';
import { X, ArrowRight, BrainCircuit, CheckCircle2, Loader2, RefreshCw } from 'lucide-react';
import { analyzeDistortions } from '../services/geminiService';
import { Distortion } from '../types';

interface ThoughtReframerProps {
  initialThought?: string;
  onClose: () => void;
  onComplete: (reframedThought: string) => void;
}

const ThoughtReframer: React.FC<ThoughtReframerProps> = ({ initialThought = '', onClose, onComplete }) => {
  const [step, setStep] = useState(1);
  const [thought, setThought] = useState(initialThought);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [distortions, setDistortions] = useState<Distortion[]>([]);
  const [selectedDistortion, setSelectedDistortion] = useState<Distortion | null>(null);
  const [evidenceFor, setEvidenceFor] = useState('');
  const [evidenceAgainst, setEvidenceAgainst] = useState('');
  const [finalReframe, setFinalReframe] = useState('');

  const handleAnalyze = async () => {
    if (!thought.trim()) return;
    setIsAnalyzing(true);
    try {
      const results = await analyzeDistortions(thought);
      setDistortions(results);
      if (results.length > 0) {
        setSelectedDistortion(results[0]);
      }
      setStep(2);
    } catch (error) {
      console.error("Failed to analyze thought:", error);
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleNextStep = () => {
    if (step === 2) {
      setStep(3);
    } else if (step === 3) {
      // Auto-generate a reframe based on evidence
      if (selectedDistortion && selectedDistortion.reframes.length > 0) {
          setFinalReframe(selectedDistortion.reframes[0].text);
      }
      setStep(4);
    } else if (step === 4) {
      onComplete(finalReframe);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className="relative z-10 w-full max-w-2xl bg-background rounded-[2rem] shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        
        {/* Header */}
        <div className="p-6 border-b border-border/50 flex justify-between items-center bg-muted/30">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-primary/10 text-primary rounded-xl flex items-center justify-center">
              <BrainCircuit size={20} />
            </div>
            <div>
              <h2 className="font-serif text-xl font-bold">Thought Reframer</h2>
              <p className="text-xs text-muted-foreground uppercase tracking-widest font-bold">CBT Interactive Tool</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-muted rounded-full transition-colors">
            <X size={20} />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 sm:p-8 overflow-y-auto flex-1">
          {/* Progress Bar */}
          <div className="flex gap-2 mb-8">
            {[1, 2, 3, 4].map(s => (
              <div key={s} className={`h-1.5 flex-1 rounded-full transition-colors ${s <= step ? 'bg-primary' : 'bg-muted'}`} />
            ))}
          </div>

          {step === 1 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <h3 className="font-serif text-2xl font-bold">What's on your mind?</h3>
              <p className="text-muted-foreground">Write down the negative thought that is bothering you right now.</p>
              <textarea
                value={thought}
                onChange={(e) => setThought(e.target.value)}
                placeholder="e.g., I messed up the presentation, I'm a total failure..."
                className="w-full h-32 p-4 bg-muted/30 border border-border rounded-2xl focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none"
              />
              <div className="flex justify-end">
                <button 
                  onClick={handleAnalyze}
                  disabled={!thought.trim() || isAnalyzing}
                  className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-full font-bold hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {isAnalyzing ? <Loader2 size={18} className="animate-spin" /> : <RefreshCw size={18} />}
                  Analyze Thought
                </button>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <h3 className="font-serif text-2xl font-bold">Identify the Trap</h3>
              <p className="text-muted-foreground">We found some common cognitive distortions in your thought.</p>
              
              {distortions.length > 0 ? (
                <div className="space-y-4">
                  {distortions.map((d, i) => (
                    <div 
                      key={i} 
                      onClick={() => setSelectedDistortion(d)}
                      className={`p-5 rounded-2xl border cursor-pointer transition-all ${selectedDistortion === d ? 'border-primary bg-primary/5 shadow-md' : 'border-border hover:border-primary/30 bg-card'}`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-bold uppercase tracking-widest text-primary">{d.type}</span>
                        {selectedDistortion === d && <CheckCircle2 size={18} className="text-primary" />}
                      </div>
                      <p className="font-medium text-foreground mb-2">"{d.originalText}"</p>
                      <p className="text-sm text-muted-foreground">{d.explanation}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="p-6 bg-muted/30 rounded-2xl border border-border text-center">
                  <p className="text-muted-foreground">We couldn't identify specific distortions, but we can still reframe it.</p>
                </div>
              )}

              <div className="flex justify-end pt-4">
                <button 
                  onClick={handleNextStep}
                  className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-full font-bold hover:bg-primary/90 transition-colors"
                >
                  Challenge It <ArrowRight size={18} />
                </button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <h3 className="font-serif text-2xl font-bold">Examine the Evidence</h3>
              <p className="text-muted-foreground">Let's look at the facts objectively, like a scientist.</p>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-bold text-foreground mb-2">Evidence FOR this thought:</label>
                  <textarea
                    value={evidenceFor}
                    onChange={(e) => setEvidenceFor(e.target.value)}
                    placeholder="What actual facts support this? (e.g., I did stumble on one slide)"
                    className="w-full h-24 p-4 bg-muted/30 border border-border rounded-2xl focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none"
                  />
                </div>
                <div>
                  <label className="block text-sm font-bold text-foreground mb-2">Evidence AGAINST this thought:</label>
                  <textarea
                    value={evidenceAgainst}
                    onChange={(e) => setEvidenceAgainst(e.target.value)}
                    placeholder="What facts contradict this? (e.g., The rest of the presentation went well, my boss smiled)"
                    className="w-full h-24 p-4 bg-muted/30 border border-border rounded-2xl focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none"
                  />
                </div>
              </div>

              <div className="flex justify-end pt-4">
                <button 
                  onClick={handleNextStep}
                  className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-full font-bold hover:bg-primary/90 transition-colors"
                >
                  Generate Reframe <ArrowRight size={18} />
                </button>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="space-y-6 animate-in fade-in slide-in-from-right-4">
              <h3 className="font-serif text-2xl font-bold">A New Perspective</h3>
              <p className="text-muted-foreground">Based on the evidence, here is a more balanced way to look at it.</p>
              
              <textarea
                value={finalReframe}
                onChange={(e) => setFinalReframe(e.target.value)}
                className="w-full h-32 p-6 bg-primary/5 border border-primary/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none text-lg font-serif leading-relaxed text-foreground"
              />

              <div className="flex justify-end pt-4">
                <button 
                  onClick={handleNextStep}
                  className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-full font-bold hover:bg-primary/90 transition-colors shadow-lg shadow-primary/20"
                >
                  <CheckCircle2 size={18} /> Save & Complete
                </button>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
};

export default ThoughtReframer;
