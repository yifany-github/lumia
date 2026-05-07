import React, { useState } from 'react';
import { Search, Play, BookOpen, Headphones, Sparkles, ArrowRight, Compass, Clock, Heart, Leaf } from 'lucide-react';

interface DiscoveryItem {
  id: string;
  title: string;
  subtitle: string;
  type: 'article' | 'audio' | 'session';
  duration: string;
  category: string;
  therapistId: string; // The therapist to handle this
  initialContext: string; // The context to send to the chat
  color: string;
  bgColor: string;
  icon: React.ReactNode;
}

const contentItems: DiscoveryItem[] = [
  {
    id: 'uncertainty',
    title: "Embracing Uncertainty",
    subtitle: "Why not knowing is often the beginning of true wisdom.",
    type: 'article',
    duration: "5 min read",
    category: "Growth",
    therapistId: 'atlas',
    initialContext: "I'd like to explore the concept of uncertainty and how to find peace within it.",
    color: "text-[#C18C5D] dark:text-secondary",
    bgColor: "bg-[#E6DCCD] dark:bg-accent/20",
    icon: <BookOpen size={18} />
  },
  {
    id: 'rain',
    title: "Rain & Reflection",
    subtitle: "Ambient soundscapes to help you drift into a deep, restorative sleep.",
    type: 'audio',
    duration: "20 min",
    category: "Sleep",
    therapistId: 'nimbus',
    initialContext: "I'm having trouble sleeping. Can you guide me through a relaxation aimed at rest?",
    color: "text-[#4A90E2] dark:text-blue-400",
    bgColor: "bg-[#E3F2FD] dark:bg-blue-900/20",
    icon: <Headphones size={18} />
  },
  {
    id: 'anxiety-sos',
    title: "Anxiety SOS",
    subtitle: "Immediate grounding techniques.",
    type: 'session',
    duration: "3 min",
    category: "Anxiety",
    therapistId: 'willow',
    initialContext: "I'm feeling anxious right now and need help grounding myself immediately.",
    color: "text-[#5D7052] dark:text-primary",
    bgColor: "bg-[#F3F6F1] dark:bg-primary/20",
    icon: <Clock size={18} />
  },
  {
    id: 'grief',
    title: "Understanding Grief",
    subtitle: "Navigating loss with compassion.",
    type: 'article',
    duration: "8 min read",
    category: "Relationships",
    therapistId: 'serena',
    initialContext: "I'm carrying some grief and would like to talk about it.",
    color: "text-[#78786C] dark:text-muted-foreground",
    bgColor: "bg-[#F5F5F4] dark:bg-muted/30",
    icon: <Heart size={18} />
  },
   {
    id: 'morning',
    title: "Morning Gratitude",
    subtitle: "Start your day with intention.",
    type: 'session',
    duration: "5 min",
    category: "Mindfulness",
    therapistId: 'willow',
    initialContext: "I want to start my day with gratitude. Can you guide me?",
    color: "text-[#C18C5D] dark:text-secondary",
    bgColor: "bg-[#FFF8F0] dark:bg-secondary/10",
    icon: <Sparkles size={18} />
  }
];

const categories = ["All", "Mindfulness", "Anxiety", "Sleep", "Growth", "Relationships"];

interface DiscoverySectionProps {
  onStartSession: (therapistId: string, context: string) => void;
}

const DiscoverySection: React.FC<DiscoverySectionProps> = ({ onStartSession }) => {
  const [activeCategory, setActiveCategory] = useState("All");

  const filteredItems = activeCategory === "All" 
    ? contentItems 
    : contentItems.filter(item => item.category === activeCategory);

  // Separate main grid items (first 2 relevant ones) from bottom row for layout
  const gridItems = filteredItems.filter(i => ['uncertainty', 'rain'].includes(i.id) || !['anxiety-sos', 'grief', 'morning'].includes(i.id)).slice(0, 2);
  const quickItems = filteredItems.filter(i => ['anxiety-sos', 'grief', 'morning'].includes(i.id));

  return (
    <section id="discovery" className="py-24 px-4 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row items-end justify-between mb-12 gap-6">
        <div className="max-w-xl">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-primary/20 bg-primary/5 text-primary text-xs font-bold tracking-widest uppercase mb-6">
            <Compass size={14} />
            <span>Explore</span>
          </div>
          <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold mb-4">
            Discover your <span className="italic text-secondary">Path</span>
          </h2>
          <p className="text-muted-foreground text-lg">
            Curated journeys, meditations, and wisdom to support your emotional landscape.
          </p>
        </div>
        
        {/* Search Bar */}
        <div className="w-full md:w-auto relative group">
          <input 
            type="text" 
            placeholder="Search for peace..." 
            className="w-full md:w-80 h-12 pl-12 pr-4 rounded-full border border-border bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-muted-foreground"
          />
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground group-focus-within:text-primary transition-colors" size={20} />
        </div>
      </div>

      {/* Categories */}
      <div className="flex gap-3 overflow-x-auto pb-8 mb-4 scrollbar-hide">
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`
              px-6 py-2.5 rounded-full text-sm font-bold whitespace-nowrap transition-all duration-300
              ${activeCategory === cat 
                ? 'bg-foreground text-background shadow-lg' 
                : 'bg-card border border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground'}
            `}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="grid lg:grid-cols-12 gap-8">
        {/* Featured Card */}
        <div 
          onClick={() => onStartSession('willow', "I'm ready to learn about the Architecture of Resilience. How can I build inner strength?")}
          className="lg:col-span-7 group cursor-pointer"
        >
          <div className="h-full bg-primary rounded-[2.5rem] p-10 md:p-14 relative overflow-hidden flex flex-col justify-between text-primary-foreground shadow-xl transition-transform duration-500 hover:-translate-y-1">
             {/* Background Pattern */}
             <div className="absolute inset-0 opacity-10 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMDAlJyBoZWlnaHQ9JzEwMCUnPjxmaWx0ZXIgaWQ9J25vaXNlJz48ZmVUdXJidWxlbmNlIHR5cGU9J2ZyYWN0YWxOb2lzZScgYmFzZUZyZXF1ZW5jeT0nMC44JyBudW1PY3RhdmVzPSc0JyBzdGl0Y2hUaWxlcz0nc3RpdGNoJy8+PC9maWx0ZXI+PHJlY3Qgd2lkdGg9JzEwMCUnIGhlaWdodD0nMTAwJScgZmlsdGVyPSd1cmwoI25vaXNlKScgb3BhY2l0eT0nMC40Jy8+PC9zdmc+')] mix-blend-overlay" />
             <div className="absolute top-0 right-0 w-[400px] h-[400px] bg-white rounded-full mix-blend-overlay filter blur-[80px] opacity-20 -translate-y-1/2 translate-x-1/3" />

             <div className="relative z-10">
               <span className="inline-block px-3 py-1 rounded-lg bg-white/20 backdrop-blur-md text-xs font-bold tracking-widest uppercase mb-6 border border-white/10">
                 Featured Journey
               </span>
               <h3 className="font-serif text-3xl md:text-5xl font-bold leading-tight mb-6">
                 The Architecture <br/> of <span className="italic opacity-80">Resilience</span>
               </h3>
               <p className="text-primary-foreground/80 text-lg max-w-md leading-relaxed mb-8">
                 A guided exploration of your inner strength. Learn how to build a foundation that withstands the storms of life.
               </p>
             </div>

             <div className="relative z-10 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-white text-primary flex items-center justify-center group-hover:scale-110 transition-transform">
                  <Play size={20} fill="currentColor" />
                </div>
                <div className="flex flex-col">
                  <span className="font-bold text-sm">Start Session</span>
                  <span className="text-xs opacity-70">15 min • Dr. Willow</span>
                </div>
             </div>
          </div>
        </div>

        {/* Grid Items (Filtered) */}
        <div className="lg:col-span-5 flex flex-col gap-8">
           {gridItems.length > 0 ? gridItems.map((item) => (
             <div 
               key={item.id}
               onClick={() => onStartSession(item.therapistId, item.initialContext)}
               className="bg-card rounded-[2.5rem] p-8 border border-border/60 hover:border-secondary/30 hover:shadow-lg transition-all duration-300 group cursor-pointer relative overflow-hidden flex-1"
             >
                <div className="flex justify-between items-start mb-4">
                   <div className={`w-10 h-10 rounded-full ${item.bgColor} ${item.color} flex items-center justify-center`}>
                     {item.icon}
                   </div>
                   <span className="text-xs font-bold text-muted-foreground bg-muted/30 px-2 py-1 rounded-md">{item.duration}</span>
                </div>
                <h4 className={`font-serif text-2xl font-bold text-foreground mb-2 group-hover:text-primary transition-colors`}>{item.title}</h4>
                <p className="text-muted-foreground text-sm line-clamp-2">{item.subtitle}</p>
                <ArrowRight className="absolute bottom-8 right-8 text-border group-hover:text-primary transition-colors" size={24} />
             </div>
           )) : (
             <div className="h-full bg-muted/10 rounded-[2.5rem] flex items-center justify-center text-muted-foreground border border-border border-dashed p-8 text-center">
               No featured articles in this category.
             </div>
           )}
        </div>
      </div>

      {/* Bottom Row (Quick Items) */}
      {quickItems.length > 0 && (
        <div className="grid md:grid-cols-3 gap-8 mt-8">
           {quickItems.map((item) => (
             <div 
               key={item.id} 
               onClick={() => onStartSession(item.therapistId, item.initialContext)}
               className="flex items-center gap-4 p-5 rounded-[2rem] border border-border/50 bg-card hover:border-border hover:shadow-md transition-all cursor-pointer group"
             >
                <div className={`w-12 h-12 rounded-2xl ${item.bgColor} ${item.color} flex items-center justify-center group-hover:scale-110 transition-transform`}>
                  {item.icon}
                </div>
                <div>
                  <h5 className="font-serif font-bold text-lg text-foreground">{item.title}</h5>
                  <span className="text-xs text-muted-foreground font-bold uppercase tracking-wider">Start Now</span>
                </div>
                <ArrowRight className="ml-auto text-border group-hover:text-foreground transition-colors" size={18} />
             </div>
           ))}
        </div>
      )}
    </section>
  );
};

export default DiscoverySection;