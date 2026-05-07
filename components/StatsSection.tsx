import React from 'react';
import { AreaChart, Area, ResponsiveContainer, XAxis, Tooltip, CartesianGrid } from 'recharts';
import { Activity, TrendingDown, Clock, Shield } from 'lucide-react';

const data = [
  { name: 'Mon', anxiety: 85 },
  { name: 'Tue', anxiety: 78 },
  { name: 'Wed', anxiety: 65 },
  { name: 'Thu', anxiety: 60 },
  { name: 'Fri', anxiety: 55 },
  { name: 'Sat', anxiety: 40 },
  { name: 'Sun', anxiety: 35 },
];

const StatsSection: React.FC = () => {
  return (
    <section id="impact" className="py-24 px-4 bg-background relative overflow-hidden">
      <div className="max-w-6xl mx-auto grid lg:grid-cols-12 gap-12 items-center">
        
        {/* Text Content */}
        <div className="lg:col-span-5 space-y-8">
          <span className="inline-block px-3 py-1 rounded-full border border-secondary/20 bg-secondary/5 text-secondary text-xs font-bold tracking-widest uppercase">
              Impact Tracking
          </span>
          <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold leading-tight">
            Growth happens in <br/>
            <span className="italic text-primary">silence.</span>
          </h2>
          <p className="text-muted-foreground text-lg leading-relaxed">
            Mental health is a journey, not a destination. Tracking your emotional state over time can reveal patterns and progress that are often invisible in the moment.
          </p>
          
          <div className="grid grid-cols-2 gap-6 pt-4">
            <div className="flex flex-col gap-2 p-4 rounded-2xl bg-muted/20 border border-border/50">
              <Clock className="text-primary mb-2" size={24} />
              <div className="text-3xl font-serif font-bold text-foreground">24/7</div>
              <div className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Availability</div>
            </div>
            <div className="flex flex-col gap-2 p-4 rounded-2xl bg-muted/20 border border-border/50">
              <Shield className="text-secondary mb-2" size={24} />
              <div className="text-3xl font-serif font-bold text-foreground">100%</div>
              <div className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Private & Secure</div>
            </div>
          </div>
        </div>

        {/* Chart Card */}
        <div className="lg:col-span-7">
          <div className="bg-card rounded-[3rem] p-8 md:p-10 shadow-2xl shadow-primary/5 border border-border/60 relative overflow-hidden group hover:border-secondary/20 transition-colors duration-500">
             {/* Decorative background blob for chart */}
             <div className="absolute -top-20 -right-20 w-80 h-80 bg-gradient-to-br from-primary/10 to-secondary/10 rounded-full blur-3xl opacity-50 pointer-events-none" />
             
             <div className="flex items-center justify-between mb-8 relative z-10">
               <div>
                 <h3 className="font-serif text-2xl font-bold text-foreground">Stress Reduction</h3>
                 <p className="text-muted-foreground text-sm">Weekly progress report</p>
               </div>
               <div className="flex items-center gap-2 text-green-600 bg-green-50 px-3 py-1 rounded-full text-sm font-bold">
                 <TrendingDown size={16} />
                 <span>-42%</span>
               </div>
             </div>

             <div className="h-[320px] w-full relative z-10">
               <ResponsiveContainer width="100%" height="100%">
                 <AreaChart data={data} margin={{ top: 10, right: 0, left: 0, bottom: 0 }}>
                   <defs>
                     <linearGradient id="colorAnxiety" x1="0" y1="0" x2="0" y2="1">
                       <stop offset="5%" stopColor="#C18C5D" stopOpacity={0.2}/>
                       <stop offset="95%" stopColor="#C18C5D" stopOpacity={0}/>
                     </linearGradient>
                   </defs>
                   <CartesianGrid vertical={false} strokeDasharray="3 3" stroke="#f0f0f0" />
                   <XAxis 
                      dataKey="name" 
                      axisLine={false} 
                      tickLine={false} 
                      tick={{ fill: '#78786C', fontSize: 12, fontWeight: 500 }} 
                      dy={10}
                   />
                   <Tooltip 
                      contentStyle={{ 
                        borderRadius: '16px', 
                        border: 'none', 
                        boxShadow: '0 10px 40px -10px rgba(0,0,0,0.1)',
                        padding: '12px 20px',
                        fontFamily: 'Fraunces, serif'
                      }}
                      itemStyle={{ color: '#C18C5D', fontWeight: 'bold' }}
                      cursor={{ stroke: '#C18C5D', strokeWidth: 1, strokeDasharray: '5 5' }}
                   />
                   <Area 
                      type="monotone" 
                      dataKey="anxiety" 
                      stroke="#C18C5D" 
                      strokeWidth={4}
                      fillOpacity={1} 
                      fill="url(#colorAnxiety)" 
                      animationDuration={2000}
                   />
                 </AreaChart>
               </ResponsiveContainer>
             </div>
             
             <div className="mt-8 pt-6 border-t border-border/40 flex items-center justify-between text-sm text-muted-foreground relative z-10">
                <div className="flex items-center gap-2">
                   <Activity size={16} className="text-primary" />
                   <span>Based on self-reported check-ins</span>
                </div>
                <span className="italic opacity-60">Last updated: Today</span>
             </div>
          </div>
        </div>

      </div>
    </section>
  );
};

export default StatsSection;