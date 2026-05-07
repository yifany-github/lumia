import React, { useState, useEffect } from 'react';
import { Droplet, Book, Settings, Edit3, Heart, Target, Sparkles, Activity } from 'lucide-react';
import { Habit } from '../types';

interface Particle {
    id: number;
    x: number;
    y: number;
    type: 'water' | 'sparkle' | 'levelUp';
    delay: number;
    text?: string;
    tx?: number;
    ty?: number;
}

// Enchanted Palette for HD-2D / AC Vibe
const PALETTE: Record<string, string> = {
  ' ': 'transparent',
  'o': '#382b20', // Outline softer brown
  'B': '#64422e', // Dark Brown trunk
  'b': '#875d42', // Brown trunk
  'd': '#3a210f', // Dark dirt
  'D': '#4f3018', // Light dirt 
  'P': '#9e5a32', // Pot shade terracotta
  'p': '#c77e4e', // Pot mid
  'H': '#e3a176', // Pot Highlight
  'G': '#1b4f2c', // Dark Green
  'g': '#3a874b', // Mid Green
  'L': '#5db86f', // Light Green
  'h': '#8ef09e', // Leaves Highlight
  'l': '#4e9c5c', // Leaves mix
  'F': '#e05370', // Dark Pink flower
  'f': '#ff8cac', // Pink flower
  'w': '#ffffff', // White
  'W': '#ffcce1', // Flower Highlight
  'Y': '#fca103', // Yellow
  'y': '#d68700', // Dark Yellow
  'C': '#2ce8f4', // Can
  'c': '#0099db', // Can
  'e': '#ffffff', // Light Can
  'S': '#fcd29f', // Seed shell high
  's': '#c79152', // Seed shadow
};

const SPRITES: Record<string, string[]> = {
  seed: [
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "          oooo          ",
    "         oSSSso         ",
    "        oSssssso        ",
    "        oSssssso        ",
    "         oSSSso         ",
    "          oooo          ",
    "                        ",
    "                        ",
  ],
  sprout: [
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "         o    o         ",
    "        oho  oho        ",
    "       oLhloohLho       ",
    "        oggoooLgo       ",
    "         oogggo         ",
    "          oGgo          ",
    "          ogGo          ",
    "          oGgo          ",
    "          ogGo          ",
    "          oGgo          ",
    "          oooo          ",
  ],
  flower: [
    "                        ",
    "          oooo          ",
    "         oWWWWo         ",
    "        oWffWfWo        ",
    "       oWfowwoWfo       ",
    "       oFfowwoFfo       ",
    "        oFfffffo        ",
    "         offffo         ",
    "          oooo          ",
    "    oo     oGo     oo   ",
    "   oLho    ogL    ohLo  ",
    "  oLgLgo  ooGoo  ogLLLo ",
    "   oogLooogGggGooogLoo  ",
    "     oogLgGgggGhgLoo    ",
    "       oogLGGgLgoo      ",
    "         oGggGo         ",
    "         ogGgGo         ",
    "         oGggGo         ",
    "         oGgGGo         ",
    "         oooooo         ",
  ],
  tree: [
    "         oooooo         ",
    "       oohhhhLhoo       ",
    "      ohhLlllLGhho      ",
    "     ohLllLllLhLhlo     ",
    "    ohllllLllLlllhgho   ",
    "   ohLLllllLlLLllLghgo  ",
    "  oLLllLLhhlLLLLllGgGgo ",
    " oollllllhLLLllllLLLGGoo",
    "oGglLLllLhLLLlLLlllGgGho",
    "oGggLllLLLllLhLllLLLgLGo",
    " ooGLllllLLLhhhLLlgGGo  ",
    "   oogLllLLLLlLLlgGoo   ",
    "     oogLLLLLLlGo       ",
    "       ooobBboo         ",
    "         obBbo          ",
    "         oBBbo          ",
    "         obBbo          ",
    "        ooobBboo        ",
    "       oBbbBboBbo       ",
    "      oBbbBobobBbo      ",
    "      oooooooooooo      ",
  ],
  pot: [
    "  oooooooooooooooooooo  ",
    " oHHppppppppppppppppHPo ",
    " oPPppppppppppppppppPPo ",
    " oooooooooooooooooooooo ",
    "   oDDDDDDDDDDDDDDDDo   ",
    "   oPppppppppppppppPo   ",
    "   oPPppppppppppppPPo   ",
    "   oPPppppppppppppPPo   ",
    "   oPPPppppppppppPPPo   ",
    "   oPPPppppppppppPPPo   ",
    "   oPPPPPPPPPPPPPPPPo   ",
    "   oooooooooooooooooo   ",
  ],
  dirt: [
    "  DDDDDDDDDDDDDDDDDDDD  ",
    " dDDDDDDdDDDDDDDDdDDDDd ",
    " dddddddddddddddddddddd ",
  ]
};

const SPRITE_URLS: Record<string, string> = {};

export function PixelSprite({ spriteName, size = 96, className = '' }: { spriteName: string, size?: number, className?: string }) {
  const [url, setUrl] = useState<string>('');
  
  useEffect(() => {
      if (!SPRITE_URLS[spriteName] && SPRITES[spriteName]) {
          const canvas = document.createElement('canvas');
          const sprite = SPRITES[spriteName];
          const cols = sprite[0].length;
          const rows = sprite.length;
          const scale = 4;
          canvas.width = cols * scale;
          canvas.height = rows * scale;
          const ctx = canvas.getContext('2d');
          
          if (ctx) {
              ctx.imageSmoothingEnabled = false;
              for (let y = 0; y < rows; y++) {
                  for (let x = 0; x < cols; x++) {
                      const char = sprite[y] ? sprite[y][x] : ' ';
                      if (char && char !== ' ') {
                          ctx.fillStyle = PALETTE[char] || 'transparent';
                          ctx.fillRect(x * scale, y * scale, scale, scale);
                      }
                  }
              }
              SPRITE_URLS[spriteName] = canvas.toDataURL('image/png');
          }
      }
      setUrl(SPRITE_URLS[spriteName]);
  }, [spriteName]);
  
  if (!url) return null;
  
  return (
      <img 
          src={url} 
          width={size}
          height={size}
          className={className}
          style={{ imageRendering: 'pixelated' }}
          alt={spriteName}
          draggable="false"
      />
  );
}

interface PixelGardenProps {
    habits: Habit[];
    waterDrops: number;
    onWaterPlant: (id: string) => void;
    onAddDrop?: () => void;
}

export function PixelGarden({ habits, waterDrops, onWaterPlant, onAddDrop }: PixelGardenProps) {
    const [wateringId, setWateringId] = useState<string | null>(null);
    const [particles, setParticles] = useState<Particle[]>([]);

    const handleWaterClick = (habit: Habit) => {
        if (waterDrops <= 0) return;
        setWateringId(habit.id);
        
        let newParticles: Particle[] = [];
        let pId = Date.now();

        // Simulate drops
        for (let i = 0; i < 8; i++) {
            newParticles.push({
                id: pId++,
                x: 80 + Math.random() * 40 - 20,
                y: -30 + Math.random() * 20,
                type: 'water',
                delay: i * 60
            });
        }

        setParticles(prev => [...prev, ...newParticles]);

        setTimeout(() => {
            onWaterPlant(habit.id);
            setWateringId(null);
            
            let sparkleParticles: Particle[] = [];
            for (let i = 0; i < 8; i++) {
                sparkleParticles.push({
                    id: pId++,
                    x: 80,
                    y: 60,
                    type: 'sparkle',
                    delay: i * 40,
                    tx: (Math.random() - 0.5) * 80,
                    ty: (Math.random() - 0.5) * 80
                });
            }
            if (habit.plantType !== 'tree') {
                sparkleParticles.push({
                    id: pId++,
                    x: 80,
                    y: 20,
                    type: 'levelUp',
                    delay: 0,
                    text: '+20%'
                });
            }
            
            setParticles(prev => [...prev, ...sparkleParticles]);

            setTimeout(() => {
                setParticles(prev => prev.filter(p => !newParticles.includes(p) && !sparkleParticles.includes(p)));
            }, 2000);

        }, 800);
    };

    // Pad habits to 4 layout slots
    const paddedHabits = [...habits];
    while(paddedHabits.length < 4) {
        paddedHabits.push({
            id: `empty-${paddedHabits.length}`,
            title: '-',
            description: 'Empty plot. Add a habit in Timeline.',
            completedAt: null,
            createdAt: Date.now(),
            plantType: 'seed',
            growth: 0
        });
    }

    const displayHabits = paddedHabits.slice(0, 4);

    return (
        <div className="w-full min-h-[750px] md:min-h-[850px] rounded-[3rem] shadow-[0_20px_40px_rgba(0,0,0,0.15)] relative overflow-hidden flex flex-col font-sans bg-gradient-to-b from-[#62C4E9] to-[#A3E5F9] border-[12px] border-[#FFF9EB] mb-10 text-[#786c5e]">
            
            {/* --- SKY BACKGROUND --- */}
            <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
                {/* Sun */}
                <div className="absolute top-20 right-24 w-24 h-24 rounded-full bg-[#FFF281] shadow-[0_0_40px_rgba(255,242,129,0.8)] opacity-90"></div>
                
                {/* Clouds */}
                <div className="absolute top-32 left-[15%] w-32 h-10 bg-white/90 rounded-full blur-[0.5px]">
                    <div className="absolute -top-6 left-4 w-16 h-16 bg-white/90 rounded-full"></div>
                    <div className="absolute -top-4 right-6 w-12 h-12 bg-white/90 rounded-full"></div>
                </div>
                
                <div className="absolute top-16 right-[40%] w-24 h-8 bg-white/80 rounded-full blur-[0.5px]">
                    <div className="absolute -top-4 left-4 w-12 h-12 bg-white/80 rounded-full"></div>
                </div>

                <div className="absolute top-40 right-[15%] w-28 h-9 bg-white/80 rounded-full blur-[0.5px]">
                    <div className="absolute -top-5 left-6 w-14 h-14 bg-white/80 rounded-full"></div>
                </div>
            </div>

            {/* --- TOP HUD --- */}
            <div className="relative z-20 flex flex-col sm:flex-row justify-between items-start p-8 gap-4">
                {/* Title */}
                <div className="bg-[#FFF9EB] rounded-[2rem] py-3 px-8 flex items-center gap-4 shadow-[0_8px_0_rgba(120,108,94,0.15)] transition-transform active:translate-y-[4px] active:shadow-[0_4px_0_rgba(120,108,94,0.15)] cursor-default">
                    <div className="scale-125 origin-center pb-1">
                        <PixelSprite spriteName="sprout" size={32} />
                    </div>
                    <div className="pb-1 pr-2">
                        <h2 className="text-[#6bb570] font-black text-[26px] tracking-tight leading-tight" style={{textShadow: '0px 2px 0px rgba(107,181,112,0.3)'}}>My Garden</h2>
                        <p className="text-[#a5998a] text-[12px] font-black uppercase tracking-[0.15em] mt-1">Nurture tiny habits</p>
                    </div>
                </div>

                <div className="flex gap-4 items-center">
                    {/* Drops */}
                    <div className="bg-[#FFF9EB] rounded-[2rem] h-[64px] px-5 flex items-center gap-3 shadow-[0_8px_0_rgba(120,108,94,0.15)] cursor-default">
                        <div className="bg-[#E4F4FF] p-2.5 rounded-[1.2rem] flex items-center justify-center -ml-1">
                            <Droplet className="fill-[#5AC8FA] text-[#5AC8FA]" size={20} />
                        </div>
                        <span className="text-[#786c5e] font-black text-[20px] pb-1 tracking-wide">{waterDrops} Drops</span>
                        
                        {onAddDrop && (
                            <button onClick={onAddDrop} className="ml-1 w-10 h-10 rounded-[1.2rem] bg-[#E8DECE] text-[#786c5e] font-black flex items-center justify-center text-xl hover:bg-[#DED2C0] active:scale-95 transition-all pb-1 shadow-inner">
                                +
                            </button>
                        )}
                    </div>
                    <button className="bg-[#FFF9EB] w-[64px] h-[64px] rounded-[2rem] shadow-[0_8px_0_rgba(120,108,94,0.15)] text-[#c2b5a3] flex items-center justify-center hover:text-[#786c5e] active:translate-y-[4px] active:shadow-[0_4px_0_rgba(120,108,94,0.15)] transition-all">
                        <Book size={26} className="stroke-[3]" />
                    </button>
                    <button className="bg-[#FFF9EB] w-[64px] h-[64px] rounded-[2rem] shadow-[0_8px_0_rgba(120,108,94,0.15)] text-[#c2b5a3] flex items-center justify-center hover:text-[#786c5e] active:translate-y-[4px] active:shadow-[0_4px_0_rgba(120,108,94,0.15)] transition-all">
                        <Settings size={26} className="stroke-[3]" />
                    </button>
                </div>
            </div>

            {/* --- PLAY AREA & SHELF --- */}
            <div className="relative flex-1 mt-auto z-10 flex flex-col justify-end">
                
                {/* Objects on shelf */}
                <div className="relative z-20 flex justify-around items-end px-4 sm:px-12 pb-0">
                    {displayHabits.map((habit, index) => {
                        const isWatering = wateringId === habit.id;
                        const isEmpty = habit.id.startsWith('empty');
                        return (
                            <div key={habit.id} className="relative flex flex-col items-center group w-1/4 h-[160px] justify-end">
                                
                                {/* Water Animation particles */}
                                {isWatering && (
                                    <div className="absolute top-0 right-0 z-30 pointer-events-none w-full h-full"> 
                                        {particles.map(p => (
                                            <div 
                                                key={p.id}
                                                className={`absolute ${
                                                    p.type === 'water' ? 'w-2.5 h-4 bg-[#60A5FA] rounded-full shadow-[0_0_8px_#3B82F6] animate-water-drop' : 
                                                    p.type === 'sparkle' ? 'text-[#FFF281] text-3xl animate-sparkle filter drop-shadow-[0_0_10px_#FFF281]' : 
                                                    'font-black text-[#58c973] animate-float-up text-3xl filter drop-shadow-[0_4px_0_rgba(0,0,0,0.1)]'
                                                }`}
                                                style={{
                                                    left: p.x,
                                                    top: p.y,
                                                    animationDelay: `${p.delay}ms`,
                                                    '--tx': p.tx,
                                                    '--ty': p.ty,
                                                } as React.CSSProperties}
                                            >
                                                {p.type === 'sparkle' ? '✨' : p.type === 'levelUp' ? p.text : ''}
                                            </div>
                                        ))}
                                    </div>
                                )}

                                {!isEmpty ? (
                                    <div className={`relative flex flex-col items-center transition-transform duration-[400ms] origin-bottom hover:scale-[1.05] cursor-pointer ${isWatering ? 'scale-[1.15] brightness-110' : ''}`} onClick={() => handleWaterClick(habit)}>
                                        <div className={`relative z-10 -mb-[22px] pointer-events-none ${habit.plantType === 'tree' ? 'mb-[-28px]' : ''}`}>
                                            <PixelSprite spriteName={habit.plantType} size={habit.plantType === 'tree' ? 140 : habit.plantType === 'flower' ? 100 : habit.plantType === 'sprout' ? 70 : 50} />
                                        </div>
                                        <div className="relative z-0">
                                            <PixelSprite spriteName="pot" size={90} className="relative z-[1] filter drop-shadow-[0_12px_8px_rgba(0,0,0,0.15)]" />
                                        </div>
                                    </div>
                                ) : (
                                    <div className="w-[85px] h-[85px] mb-2 border-[6px] border-dashed border-[#ffffff] opacity-40 rounded-[2rem]" />
                                )}
                            </div>
                        );
                    })}
                </div>

                {/* 3D GRASS SHELF */}
                <div className="relative z-10 w-full flex flex-col">
                    {/* Top Highlight Edge */}
                    <div className="h-[12px] bg-[#C1F085] w-full"></div>
                    {/* Main Grass Surface */}
                    <div className="h-[36px] bg-[#9CE05A] w-full relative overflow-hidden shadow-[inset_0_-4px_10px_rgba(0,0,0,0.05)]">
                        {/* AC Triangle pattern overlay using CSS SVG */}
                        <div className="absolute inset-0 opacity-[0.15]" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'24\' height=\'24\' viewBox=\'0 0 24 24\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cpath d=\'M12 4L20 18H4L12 4Z\' fill=\'%235C9A31\'/%3E%3C/svg%3E")', backgroundSize: '32px 32px', backgroundPosition: 'center' }}></div>
                    </div>
                    {/* Dirt soil edge below grass */}
                    <div className="h-[48px] bg-[#D6AD7A] w-full border-t-[8px] border-[#89C748] shadow-[0_15px_30px_rgba(0,0,0,0.15)] z-20 relative">
                        {/* Dot texture for dirt */}
                        <div className="absolute inset-0 opacity-[0.15]" style={{ backgroundImage: 'radial-gradient(#5C4033 2px, transparent 2px)', backgroundSize: '16px 16px', backgroundPosition: '0 0, 8px 8px' }}></div>
                    </div>
                </div>

                {/* --- CHUNKY UI CARDS AREA (NookPhone Style) --- */}
                <div className="relative z-0 w-full px-4 sm:px-10 pt-24 pb-[100px] flex gap-4 sm:gap-6 justify-center bg-[#FFF9EB] shadow-[inset_0_20px_30px_rgba(0,0,0,0.03)] min-h-[480px]">
                    {/* Subtle dot pattern for background */}
                    <div className="absolute inset-0 opacity-40 pointer-events-none" style={{ backgroundImage: 'radial-gradient(#DED2C0 2px, transparent 2px)', backgroundSize: '24px 24px' }}></div>
                    
                    {displayHabits.map((habit, i) => {
                        const isEmpty = habit.id.startsWith('empty');
                        
                        const bgClass = isEmpty ? 'bg-transparent border-[4px] border-dashed border-[#DED2C0]' : 'bg-white shadow-[0_12px_0_rgba(120,108,94,0.08)] border-[3px] border-[#FAF5E6]';
                        
                        let tagBg = '#DED2C0';
                        let tagShadow = '#cabda9';
                        let tagText = '#fff';
                        
                        if (!isEmpty) {
                            if (habit.plantType === 'seed') {
                                tagBg = '#FFB26B'; tagShadow = '#E6974D'; 
                            } else if (habit.plantType === 'sprout') {
                                tagBg = '#7CD699'; tagShadow = '#5FBA7D'; 
                            } else if (habit.plantType === 'flower') {
                                tagBg = '#F299B3'; tagShadow = '#DE7B97'; 
                            } else {
                                tagBg = '#5AC8FA'; tagShadow = '#42AFD6'; 
                            }
                        }

                        return (
                            <div key={i} className={`relative flex flex-col items-center rounded-[3rem] px-4 xl:px-6 pt-12 pb-8 w-1/4 ${bgClass} transition-shadow duration-300 z-10`}>
                                
                                {/* Top Badge */}
                                <div className="absolute -top-[24px] left-1/2 -translate-x-1/2 z-10 w-[90%] flex justify-center">
                                    <div 
                                        className="px-6 py-3 rounded-full font-black text-[14px] tracking-[0.12em] leading-none border-[4px] border-white w-full text-center whitespace-nowrap overflow-hidden text-ellipsis"
                                        style={{ 
                                            backgroundColor: tagBg, 
                                            color: tagText,
                                            boxShadow: `0 6px 0 ${tagShadow}`
                                        }}
                                    >
                                        {(isEmpty ? 'EMPTY' : habit.plantType).toUpperCase()}
                                    </div>
                                </div>

                                {/* Content Details */}
                                <div className="flex flex-col items-center text-center mt-3 mb-6 flex-1 w-full relative">
                                    <div className={`mb-6 w-[80px] h-[80px] rounded-[2rem] flex items-center justify-center
                                        ${isEmpty ? 'bg-[#F2ECE1] text-[#c2b5a3]' : 'bg-[#F9F4E8] text-[#786c5e]'}`}
                                    >
                                        {isEmpty ? <Edit3 size={32} /> : 
                                         i === 0 ? <Edit3 size={32} className="text-[#FFB26B]" /> : 
                                         i === 1 ? <Droplet size={32} className="fill-[#5AC8FA] text-[#5AC8FA]" /> : 
                                         <Activity size={32} className="text-[#F299B3]" />}
                                    </div>
                                    <h3 className={`font-black text-[22px] leading-tight mb-3 px-1 w-full break-words
                                        ${isEmpty ? 'text-[#b8ad9e]' : 'text-[#6b584d]'}`}>
                                        {isEmpty ? 'Available Plot' : habit.title}
                                    </h3>
                                    <p className={`text-[14px] font-bold leading-snug tracking-wide line-clamp-3
                                        ${isEmpty ? 'text-[#c7bcb0]' : 'text-[#a5998a]'}`}>
                                        {habit.description}
                                    </p>
                                </div>

                                {/* Bottom Progress Action Pill */}
                                {!isEmpty && (
                                    <div className="mt-auto w-full">
                                        <button 
                                            onClick={() => handleWaterClick(habit)}
                                            disabled={waterDrops <= 0}
                                            className={`group w-full h-[60px] rounded-[2rem] relative overflow-hidden bg-[#F2ECE1] border-[3px] border-white shadow-[0_6px_0_rgba(120,108,94,0.1)] active:translate-y-[4px] active:shadow-none transition-all flex items-center justify-center cursor-pointer ${waterDrops <= 0 ? 'opacity-70 cursor-not-allowed' : ''}`}
                                        >
                                            {/* Growth fill base */}
                                            <div className="absolute left-0 top-0 h-full bg-[#82E0AA] transition-all duration-1000" style={{ width: `${habit.growth || 0}%` }}>
                                                {/* Soft diagonal striped pattern overlapping progress for that AC look */}
                                                <div className="absolute inset-0 opacity-20" style={{ backgroundImage: 'repeating-linear-gradient(45deg, transparent, transparent 10px, #ffffff 10px, #ffffff 20px)' }}></div>
                                                {/* Liquid top reflection */}
                                                <div className="absolute top-1.5 left-2 right-2 h-2.5 bg-white/50 rounded-full blur-[0.5px]"></div>
                                            </div>
                                            
                                            {/* Text layered on top */}
                                            <div className="relative z-10 flex items-center gap-1.5 font-black text-[#6b584d] text-[13px] md:text-[14px] xl:text-[16px] xl:tracking-wide whitespace-nowrap group-hover:scale-105 transition-transform" style={{textShadow: '0 2px 0 rgba(255,255,255,0.6)'}}>
                                                <Droplet size={18} className="fill-[#5AC8FA] text-[#2299c9] stroke-2 shrink-0" /> <span className="pt-0.5">WATER ({habit.growth || 0}%)</span>
                                            </div>
                                        </button>
                                    </div>
                                )}
                            </div>
                        )
                    })}
                </div>
            </div>
        </div>
    );
}
