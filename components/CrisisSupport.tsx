import React from 'react';
import { X, Phone, HeartHandshake, ShieldAlert } from 'lucide-react';

interface CrisisSupportProps {
  isOpen: boolean;
  onClose: () => void;
}

const CrisisSupport: React.FC<CrisisSupportProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div 
        className="absolute inset-0 bg-black/80 backdrop-blur-md transition-opacity"
        onClick={onClose}
      />
      
      <div className="relative z-10 w-full max-w-2xl bg-background rounded-[2rem] shadow-2xl overflow-hidden border-2 border-secondary/20">
        {/* Header */}
        <div className="bg-secondary/10 p-8 text-center border-b border-secondary/10">
          <ShieldAlert className="w-12 h-12 text-secondary mx-auto mb-4" />
          <h3 className="font-serif text-3xl font-bold text-foreground">You Are Not Alone</h3>
          <p className="text-muted-foreground mt-2">
            If you are in immediate danger or need urgent help, please reach out to these resources immediately.
          </p>
        </div>

        {/* Resources List */}
        <div className="p-8 space-y-4">
          <a href="tel:988" className="flex items-center gap-6 p-6 rounded-2xl bg-card border border-border hover:border-secondary hover:shadow-lg transition-all group">
            <div className="w-12 h-12 rounded-full bg-secondary/10 text-secondary flex items-center justify-center group-hover:bg-secondary group-hover:text-white transition-colors">
              <Phone size={24} />
            </div>
            <div>
              <h4 className="font-serif text-xl font-bold text-foreground">988 Suicide & Crisis Lifeline</h4>
              <p className="text-sm text-muted-foreground">Available 24/7. Free and confidential.</p>
            </div>
            <span className="ml-auto font-bold text-secondary text-sm">Call Now</span>
          </a>

          <a href="sms:741741" className="flex items-center gap-6 p-6 rounded-2xl bg-card border border-border hover:border-[#4A90E2] hover:shadow-lg transition-all group">
            <div className="w-12 h-12 rounded-full bg-[#4A90E2]/10 text-[#4A90E2] flex items-center justify-center group-hover:bg-[#4A90E2] group-hover:text-white transition-colors">
              <HeartHandshake size={24} />
            </div>
            <div>
              <h4 className="font-serif text-xl font-bold text-foreground">Crisis Text Line</h4>
              <p className="text-sm text-muted-foreground">Text "HOME" to 741741.</p>
            </div>
            <span className="ml-auto font-bold text-[#4A90E2] text-sm">Text Now</span>
          </a>
        </div>

        <div className="p-6 bg-muted/20 text-center">
          <button 
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground font-bold text-sm underline decoration-2 underline-offset-4"
          >
            I am safe, return to Lumina
          </button>
        </div>
        
        <button 
          onClick={onClose}
          className="absolute top-4 right-4 p-2 text-muted-foreground hover:text-foreground"
        >
          <X size={24} />
        </button>
      </div>
    </div>
  );
};

export default CrisisSupport;