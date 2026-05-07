import React from 'react';
import { Sprout, Sun, Droplets, Wind, Heart, Recycle } from 'lucide-react';
import { Feature } from '../types';

const features: Feature[] = [
  {
    id: 1,
    title: "Living Materials",
    description: "We work exclusively with clay, untreated wood, and organic fibers that breathe with your home.",
    icon: <Sprout className="text-primary" size={28} />,
    shapeClass: "rounded-[2rem] rounded-tr-[4rem]"
  },
  {
    id: 2,
    title: "Sun-Dried Process",
    description: "Our ceramics are dried naturally under the sun, reducing energy consumption by 40%.",
    icon: <Sun className="text-secondary" size={28} />,
    shapeClass: "rounded-[2rem] rounded-tl-[4rem]"
  },
  {
    id: 3,
    title: "Water Conscious",
    description: "Every drop used in our dye process is recycled through a natural reed bed filtration system.",
    icon: <Droplets className="text-[#4A90E2]" size={28} />, // Custom blue for water
    shapeClass: "rounded-[2rem] rounded-bl-[4rem]"
  },
  {
    id: 4,
    title: "Air Purification",
    description: "Our living wall installations are designed to naturally filter toxins from your indoor air.",
    icon: <Wind className="text-muted-foreground" size={28} />,
    shapeClass: "rounded-[2rem] rounded-br-[4rem]"
  },
  {
    id: 5,
    title: "Handcrafted Soul",
    description: "Imperfections are celebrated. No two pieces are alike, bearing the mark of the maker.",
    icon: <Heart className="text-destructive" size={28} />,
    shapeClass: "rounded-[2rem] rounded-tr-[5rem] rounded-bl-[3rem]"
  },
  {
    id: 6,
    title: "Full Circle",
    description: "Return any item at the end of its life, and we will compost or recycle it into new art.",
    icon: <Recycle className="text-primary" size={28} />,
    shapeClass: "rounded-[3rem] rounded-tl-[2rem] rounded-br-[4rem]"
  }
];

const Features: React.FC = () => {
  return (
    <section id="features" className="py-32 px-4 bg-muted/30 relative overflow-hidden">
      <div className="max-w-7xl mx-auto">
        <div className="text-center max-w-2xl mx-auto mb-20 space-y-4">
          <h2 className="font-serif text-4xl md:text-5xl text-foreground font-semibold">
            Rooted in <span className="text-secondary italic">Earth</span>
          </h2>
          <p className="text-muted-foreground text-lg">
            Our principles are simple: take only what is needed, and leave the soil richer than we found it.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, idx) => (
            <div 
              key={feature.id}
              className={`
                group bg-card border border-border/50 p-8 
                shadow-[0_4px_20px_-2px_rgba(93,112,82,0.15)] 
                hover:shadow-[0_20px_40px_-10px_rgba(93,112,82,0.15)]
                hover:-translate-y-2 transition-all duration-500 ease-out
                ${feature.shapeClass}
              `}
            >
              <div className="h-14 w-14 rounded-2xl bg-primary/10 flex items-center justify-center mb-6 group-hover:bg-primary transition-colors duration-500">
                <div className="group-hover:text-white transition-colors duration-500">
                  {feature.icon}
                </div>
              </div>
              <h3 className="font-serif text-2xl font-semibold mb-3 text-foreground">{feature.title}</h3>
              <p className="text-muted-foreground leading-relaxed">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Features;