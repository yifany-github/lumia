import React from 'react';
import { Sparkles, Instagram, Twitter, Heart } from 'lucide-react';

const Footer: React.FC = () => {
  return (
    <footer id="footer" className="bg-foreground text-background dark:bg-card dark:text-foreground py-20 px-4 rounded-t-[3rem] mt-20 relative overflow-hidden">
      {/* Texture for footer */}
      <div className="absolute inset-0 opacity-10 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMDAlJyBoZWlnaHQ9JzEwMCUnPjxmaWx0ZXIgaWQ9J25vaXNlJz48ZmVUdXJidWxlbmNlIHR5cGU9J2ZyYWN0YWxOb2lzZScgYmFzZUZyZXF1ZW5jeT0nMC44JyBudW1PY3RhdmVzPSc0JyBzdGl0Y2hUaWxlcz0nc3RpdGNoJy8+PC9maWx0ZXI+PHJlY3Qgd2lkdGg9JzEwMCUnIGhlaWdodD0nMTAwJScgZmlsdGVyPSd1cmwoI25vaXNlKScgb3BhY2l0eT0nMC40Jy8+PC9zdmc+')] mix-blend-overlay pointer-events-none"></div>

      <div className="max-w-7xl mx-auto grid md:grid-cols-4 gap-12 relative z-10">
        <div className="space-y-6">
          <div className="flex items-center gap-3">
             <div className="h-10 w-10 bg-primary rounded-full flex items-center justify-center text-primary-foreground">
               <Sparkles size={20} />
             </div>
             <span className="font-serif font-bold text-xl">Lumia</span>
          </div>
          <p className="text-background/60 dark:text-muted-foreground text-sm leading-relaxed max-w-xs">
            Blending artificial intelligence with human-centric empathy to create a safe space for everyone.
          </p>
        </div>

        <div>
          <h4 className="font-serif font-bold text-lg mb-6 text-primary">Resources</h4>
          <ul className="space-y-3 text-sm text-background/60 dark:text-muted-foreground">
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">Crisis Hotlines</a></li>
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">Mindfulness Guides</a></li>
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">Find a Professional</a></li>
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">FAQ</a></li>
          </ul>
        </div>

        <div>
          <h4 className="font-serif font-bold text-lg mb-6 text-primary">Legal</h4>
          <ul className="space-y-3 text-sm text-background/60 dark:text-muted-foreground">
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">Privacy Policy</a></li>
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">Terms of Service</a></li>
            <li><a href="#" className="hover:text-background dark:hover:text-foreground transition-colors">AI Ethics</a></li>
          </ul>
        </div>

        <div>
           <h4 className="font-serif font-bold text-lg mb-6 text-primary">Connect</h4>
           <div className="flex gap-4 mb-6">
             <a href="#" className="h-10 w-10 rounded-full bg-background/10 dark:bg-muted flex items-center justify-center hover:bg-primary transition-colors">
               <Instagram size={18} />
             </a>
             <a href="#" className="h-10 w-10 rounded-full bg-background/10 dark:bg-muted flex items-center justify-center hover:bg-primary transition-colors">
               <Twitter size={18} />
             </a>
             <a href="#" className="h-10 w-10 rounded-full bg-background/10 dark:bg-muted flex items-center justify-center hover:bg-primary transition-colors">
               <Heart size={18} />
             </a>
           </div>
           <p className="text-xs text-background/40 dark:text-muted-foreground/60">
             © 2024 Lumia AI. Not a replacement for professional therapy.
           </p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;