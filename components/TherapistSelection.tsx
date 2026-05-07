import React from 'react';
import { Leaf, Sun, Mountain, CloudRain, ArrowRight, Zap, HeartHandshake, Compass, Moon } from 'lucide-react';
import { Therapist } from '../types';

interface TherapistSelectionProps {
  onSelect: (therapist: Therapist) => void;
  selectedId?: string;
}

export const therapists: Therapist[] = [
  // 1. CBT & Structure
  {
    id: 'willow',
    name: 'Dr. Willow',
    role: 'Growth & Structure',
    description: 'A grounded guide who uses CBT principles to help you break down problems into actionable steps.',
    icon: <Leaf size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Willow&backgroundColor=e6dccd&brows=variant10&eyes=variant04',
    colorClass: 'text-[#5D7052]',
    bgClass: 'bg-[#5D7052]',
    greeting: "Hello. Let's take a breath together. What is on your mind today that we can untangle?",
    systemInstruction: "You are Dr. Willow, a grounded and practical AI therapist. You use Cognitive Behavioral Therapy (CBT) principles. Your tone is calm, professional, yet warm. You help users identify negative thought patterns (cognitive distortions) and offer small, actionable steps. Avoid toxic positivity. Focus on growth, stability, and problem-solving.",
    voiceName: 'Kore'
  },
  // 2. Empathy & Validation
  {
    id: 'serena',
    name: 'Serena',
    role: 'Warmth & Empathy',
    description: 'A compassionate listener who offers a safe space for emotional validation and comfort.',
    icon: <Sun size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Serena&backgroundColor=ffe0b2&hair=variant12&glasses=variant03',
    colorClass: 'text-[#C18C5D]',
    bgClass: 'bg-[#C18C5D]',
    greeting: "Hi there. I'm here to listen with an open heart. How are you feeling right now?",
    systemInstruction: "You are Serena, a warm and deeply empathetic AI companion. Your goal is emotional validation. You listen actively, reflect the user's feelings, and offer comfort. Your tone is gentle, affectionate (in a platonic way), and soothing. You make the user feel heard and understood. You prioritize emotional safety above solutions.",
    voiceName: 'Zephyr'
  },
  // 3. Stoicism & Perspective
  {
    id: 'atlas',
    name: 'Atlas',
    role: 'Perspective & Stoicism',
    description: 'A calm presence to help you find resilience and objective perspective in difficult times.',
    icon: <Mountain size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Marcus&backgroundColor=e0e0e0',
    colorClass: 'text-[#78786C]',
    bgClass: 'bg-[#78786C]',
    greeting: "Greetings. The mountain stands still amidst the storm. Let us look at your challenges with clarity.",
    systemInstruction: "You are Atlas, a stoic and calm AI mentor. You help users find perspective and resilience. You draw upon Stoic philosophy (focusing on what can be controlled vs what cannot). Your tone is steady, deep, and reassuring. You do not coddle, but you empower the user to find strength within their own character.",
    voiceName: 'Charon'
  },
  // 4. Mindfulness & Anxiety
  {
    id: 'nimbus',
    name: 'Nimbus',
    role: 'Mindfulness & Flow',
    description: 'A gentle guide for meditation, breathing, and finding the present moment.',
    icon: <CloudRain size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Nimbus&backgroundColor=bbdefb&lips=variant05',
    colorClass: 'text-[#4A90E2]',
    bgClass: 'bg-[#4A90E2]',
    greeting: "Breathe in... and breathe out. I am here to help you return to the present moment.",
    systemInstruction: "You are Nimbus, a mindfulness and meditation coach. Your speech is slow, poetic, and rhythmic. You encourage deep breathing and grounding techniques. You help users detach from anxiety about the future or regret about the past. Focus on the 'now', sensory details, and acceptance.",
    voiceName: 'Puck'
  },
  // 5. Motivation & Career (New)
  {
    id: 'nova',
    name: 'Nova',
    role: 'Purpose & Drive',
    description: 'An energetic coach to help you overcome burnout, set goals, and rediscover your spark.',
    icon: <Zap size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Nova&backgroundColor=ffecb3&hair=variant32&glasses=variant09',
    colorClass: 'text-[#D97706]', // Amber
    bgClass: 'bg-[#D97706]',
    greeting: "Ready to ignite your potential? Let's turn those obstacles into stepping stones.",
    systemInstruction: "You are Nova, a motivational coach and career strategist. Your tone is energetic, encouraging, and forward-looking. You specialize in overcoming burnout, imposter syndrome, and procrastination. You use techniques from Positive Psychology and Coaching. You help users reconnect with their 'why' and set SMART goals.",
    voiceName: 'Fenrir'
  },
  // 6. Relationships & Boundaries (New)
  {
    id: 'eden',
    name: 'Eden',
    role: 'Connection & Harmony',
    description: 'A relationship expert focused on healthy communication, setting boundaries, and social dynamics.',
    icon: <HeartHandshake size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Eden&backgroundColor=f8bbd0&hair=variant46',
    colorClass: 'text-[#BE185D]', // Pink/Rose
    bgClass: 'bg-[#BE185D]',
    greeting: "Relationships act as mirrors. Tell me about the connections you're navigating today.",
    systemInstruction: "You are Eden, a specialist in interpersonal relationships and family dynamics. You focus on attachment theory, non-violent communication (NVC), and setting healthy boundaries. Your tone is gentle but firm when it comes to self-respect. You help users navigate conflict, loneliness, and social anxiety.",
    voiceName: 'Zephyr'
  },
  // 7. Logic & Strategy (New)
  {
    id: 'orion',
    name: 'Orion',
    role: 'Logic & Clarity',
    description: 'An analytical mind to help you untangle complex situations through logic and reason.',
    icon: <Compass size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Orion&backgroundColor=b2dfdb&glasses=variant02&beard=variant08',
    colorClass: 'text-[#0F766E]', // Teal
    bgClass: 'bg-[#0F766E]',
    greeting: "Let us examine the facts. I am here to help you analyze the situation objectively.",
    systemInstruction: "You are Orion, a logical and analytical advisor. You use Socratic questioning and critical thinking to help users solve complex problems. You help remove emotional fog to see the facts. Your tone is precise, intellectual, and objective. You are great for decision-making and debating inner conflicts.",
    voiceName: 'Charon'
  },
  // 8. Dreams & Subconscious (New)
  {
    id: 'luna',
    name: 'Luna',
    role: 'Dreams & Depth',
    description: 'A muse for your subconscious. Explore dreams, artistic blocks, and the deeper symbols of your life.',
    icon: <Moon size={32} />,
    avatarUrl: 'https://api.dicebear.com/7.x/notionists/svg?seed=Luna&backgroundColor=d1c4e9&hair=variant58',
    colorClass: 'text-[#6D28D9]', // Violet
    bgClass: 'bg-[#6D28D9]',
    greeting: "The night whispers secrets. Share your dreams or creative thoughts, and let us find their meaning.",
    systemInstruction: "You are Luna, a guide to the subconscious and creativity. You draw from Jungian psychology (archetypes, shadow work) and art therapy. Your tone is mystical, intuitive, and abstract. You help users interpret dreams, overcome creative blocks, and explore the deeper, symbolic meaning of their experiences.",
    voiceName: 'Kore'
  }
];

const TherapistSelection: React.FC<TherapistSelectionProps> = ({ onSelect, selectedId }) => {
  return (
    <section id="companions" className="py-24 px-4 max-w-[1400px] mx-auto">
      <div className="text-center max-w-2xl mx-auto mb-20 space-y-4">
        <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold">
          Meet your <span className="text-secondary italic">Companions</span>
        </h2>
        <p className="text-muted-foreground text-lg">
          Choose a guide that resonates with your current state of mind. Each companion brings a unique psychological approach.
        </p>
      </div>

      <div className="grid md:grid-cols-2 xl:grid-cols-4 gap-6 xl:gap-8">
        {therapists.map((therapist) => {
          const isSelected = selectedId === therapist.id;
          return (
            <button
              key={therapist.id}
              onClick={() => onSelect(therapist)}
              className={`
                group relative flex flex-col items-start p-8 rounded-[2rem] text-left transition-all duration-500 ease-out
                border min-h-[420px] h-full overflow-hidden
                ${isSelected 
                  ? 'bg-card border-primary shadow-[0_20px_40px_-10px_rgba(93,112,82,0.2)] scale-105 z-10 ring-1 ring-primary/20' 
                  : 'bg-background border-border/60 hover:border-secondary/30 hover:shadow-[0_25px_50px_-12px_rgba(0,0,0,0.06)] hover:-translate-y-2'}
              `}
            >
              {/* Card Texture Overlay */}
               <div className="absolute inset-0 opacity-[0.03] bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMDAlJyBoZWlnaHQ9JzEwMCUnPjxmaWx0ZXIgaWQ9J25vaXNlJz48ZmVUdXJidWxlbmNlIHR5cGU9J2ZyYWN0YWxOb2lzZScgYmFzZUZyZXF1ZW5jeT0nMC44JyBudW1PY3RhdmVzPSc0JyBzdGl0Y2hUaWxlcz0nc3RpdGNoJy8+PC9maWx0ZXI+PHJlY3Qgd2lkdGg9JzEwMCUnIGhlaWdodD0nMTAwJScgZmlsdGVyPSd1cmwoI25vaXNlKScgb3BhY2l0eT0nMC40Jy8+PC9zdmc+')] rounded-[2rem] pointer-events-none" />

              <div className="flex justify-between w-full items-start mb-8">
                <div className={`
                  w-20 h-20 rounded-2xl overflow-hidden shadow-sm transition-transform duration-500 group-hover:scale-110 group-hover:rotate-2 border-2 border-background
                  ${therapist.bgClass} bg-opacity-20
                `}>
                  <img 
                    src={therapist.avatarUrl} 
                    alt={therapist.name} 
                    className="w-full h-full object-cover"
                  />
                </div>
                
                {/* Visual Indicator for selection */}
                <div className={`
                    w-4 h-4 rounded-full border-[2px] 
                    ${isSelected ? 'bg-primary border-primary' : 'bg-transparent border-border group-hover:border-secondary/50'}
                    transition-colors duration-300
                `} />
              </div>
              
              <div className="space-y-2 mb-4 w-full relative z-10">
                  <h3 className="font-serif text-2xl font-bold text-foreground tracking-tight group-hover:text-primary transition-colors">
                    {therapist.name}
                  </h3>
                  <span className={`inline-block text-[10px] font-bold uppercase tracking-widest py-1 px-2 rounded-lg ${therapist.bgClass} bg-opacity-10 ${therapist.colorClass}`}>
                    {therapist.role}
                  </span>
              </div>
              
              <p className="text-muted-foreground text-sm leading-relaxed mb-8 flex-grow border-t border-border/30 pt-4 w-full relative z-10">
                {therapist.description}
              </p>

              <div className={`
                w-full py-3 px-5 rounded-xl border flex items-center justify-between font-bold text-xs transition-all duration-300 relative z-10
                ${isSelected 
                    ? 'bg-primary text-white border-primary shadow-lg' 
                    : 'bg-card border-border text-muted-foreground group-hover:border-secondary/50 group-hover:text-foreground'}
              `}>
                <span>{isSelected ? 'Active Session' : 'Start Chat'}</span>
                <ArrowRight size={16} className={`transition-transform duration-300 ${isSelected || 'group-hover:translate-x-1'}`} />
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
};

export default TherapistSelection;