import React, { useRef, useEffect } from 'react';
import { VisualizerSettings } from '../types';

interface VisualizerProps {
  imageSrc: string;
  audioAnalyser: AnalyserNode | null;
  settings: VisualizerSettings;
  className?: string;
}

class Particle {
  // Screen coordinates
  x: number = 0;
  y: number = 0;
  
  // 3D World coordinates (relative to center)
  baseX: number;
  baseY: number;
  baseZ: number;
  
  color: string;
  baseSize: number;
  
  // Physics & Animation
  floatOffset: number;
  
  // Projection
  scale: number = 1;
  alpha: number = 1;

  constructor(x: number, y: number, r: number, g: number, b: number, baseSize: number, width: number, height: number) {
    // 1. Center the coordinates
    this.baseX = x - width / 2;
    this.baseY = y - height / 2;
    
    // 2. LUMINANCE-BASED DEPTH (The Key Fix)
    // Calculate brightness (human perception formula)
    const luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255; 
    
    // Map brightness to Z depth. 
    // Brighter pixels are closer (positive Z), Darker pixels are deeper (negative Z).
    // This preserves the 3D structure of the image (like a 3D relief map).
    const depthRange = 250; 
    this.baseZ = (luminance * depthRange) - (depthRange / 2);
    
    // Add very slight noise to avoid "flat sheets" artifacts on solid colors
    this.baseZ += (Math.random() - 0.5) * 10;
    
    this.color = `rgb(${r},${g},${b})`;
    
    // Slight size variation based on depth to enhance 3D feel (closer = slightly bigger base)
    this.baseSize = baseSize * (0.8 + luminance * 0.4); 
    
    this.floatOffset = Math.random() * 100;
  }

  update(
    audioData: Uint8Array | null, 
    settings: VisualizerSettings, 
    width: number, 
    height: number, 
    time: number,
    rotationX: number,
    rotationY: number
  ) {
    // 1. Gentle Floating (Affected by Intensity)
    const floatSpeed = 0.0002;
    const intensityFactor = settings.intensity / 3; // Normalize around default 3
    
    const floatX = Math.sin(time * floatSpeed + this.floatOffset) * 2 * intensityFactor; 
    const floatY = Math.cos(time * floatSpeed * 0.8 + this.floatOffset) * 2 * intensityFactor;
    const floatZ = Math.sin(time * floatSpeed * 0.5 + this.floatOffset) * 5 * intensityFactor;

    let tx = this.baseX + floatX;
    let ty = this.baseY + floatY;
    let tz = (this.baseZ * intensityFactor) + floatZ;

    // 2. Audio Reaction (Z-axis displacement mostly)
    if (audioData) {
      // Map X position to frequency bin
      const pct = Math.abs(tx) / (width / 2); 
      const bin = Math.floor(pct * audioData.length * 0.5); 
      const val = audioData[bin] || 0;

      if (val > 10) {
        const sensitivity = settings.sensitivity / 50;
        const drive = (val / 255) * sensitivity;
        
        if (drive > 0.05) {
           // Push 'out' towards camera on beat
           tz += drive * settings.intensity * 20; 
        }
      }
    }

    // 3. 3D Rotation Math
    // Rotate around Y axis (Horizontal mouse movement)
    let cosY = Math.cos(rotationY);
    let sinY = Math.sin(rotationY);
    let x1 = tx * cosY - tz * sinY;
    let z1 = tz * cosY + tx * sinY;

    // Rotate around X axis (Vertical mouse movement)
    let cosX = Math.cos(rotationX);
    let sinX = Math.sin(rotationX);
    let y2 = ty * cosX - z1 * sinX;
    let z2 = z1 * cosX + ty * sinX;

    // 4. Perspective Projection
    const perspective = 800; 
    const depth = perspective + z2;
    
    if (depth < 10) {
        this.scale = 0; 
    } else {
        this.scale = perspective / depth;
    }

    this.x = x1 * this.scale + width / 2;
    this.y = y2 * this.scale + height / 2;
    
    // Depth Fog (Subtle)
    // Don't fade too much, or we lose the image
    this.alpha = Math.max(0.4, Math.min(1, 1 - (z2 / 1200))); 
  }

  draw(ctx: CanvasRenderingContext2D, settings: VisualizerSettings) {
    if (this.scale <= 0) return;

    // To make image look "solid" yet "particlized", we need slightly larger particles 
    // that overlap just enough.
    const size = this.baseSize * this.scale;
    
    if (size < 0.5) return;

    ctx.fillStyle = this.color;
    ctx.globalAlpha = this.alpha;
    
    // Using rects fills gaps better than circles for image reconstruction
    ctx.beginPath();
    ctx.fillRect(this.x - size/2, this.y - size/2, size, size);
    
    ctx.globalAlpha = 1.0;
  }
}

const Visualizer: React.FC<VisualizerProps> = ({ imageSrc, audioAnalyser, settings, className }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const particlesRef = useRef<Particle[]>([]);
  const animationFrameRef = useRef<number | null>(null);
  const timeRef = useRef<number>(0);
  
  // Rotation State
  const targetRotation = useRef({ x: 0, y: 0 });
  const currentRotation = useRef({ x: 0, y: 0 });

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    // Normalize to -1 to 1 range
    const nx = (x / rect.width) * 2 - 1;
    const ny = (y / rect.height) * 2 - 1;

    targetRotation.current.y = nx * 0.6; // Limit rotation to ~35 degrees to keep image visible
    targetRotation.current.x = -ny * 0.6; 
  };

  const handleMouseLeave = () => {
    targetRotation.current = { x: 0, y: 0 };
  };

  // Initialize Particles
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !imageSrc) return;
    
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) return;

    const img = new Image();
    img.crossOrigin = "Anonymous";

    img.onload = () => {
      const rect = canvas.getBoundingClientRect();
      let cw = rect.width || canvas.offsetWidth || canvas.clientWidth;
      let ch = rect.height || canvas.offsetHeight || canvas.clientHeight;
      
      // Fallback if canvas has no layout size yet (e.g. during modal animation)
      if (cw === 0 || ch === 0) {
        cw = window.innerWidth;
        ch = window.innerHeight;
      }
      
      canvas.width = cw;
      canvas.height = ch;
      
      // Draw image to canvas to read pixel data
      // We want to cover the canvas
      const scale = Math.max(canvas.width / img.width, canvas.height / img.height);
      const drawW = img.width * scale;
      const drawH = img.height * scale;
      const offsetX = (canvas.width - drawW) / 2;
      const offsetY = (canvas.height - drawH) / 2;

      ctx.drawImage(img, offsetX, offsetY, drawW, drawH);
      
      if (!settings.enabled) {
        // If disabled, we just leave the image on the canvas and don't create particles
        particlesRef.current = [];
        return;
      }

      // HIGH DENSITY SAMPLING
      // Base target count on the density setting (10-100)
      // 50 density -> ~9000 particles. 100 density -> ~18000 particles.
      const targetCount = settings.density * 180;
      const totalPixels = canvas.width * canvas.height;
      let calculatedStep = Math.floor(Math.sqrt(totalPixels / targetCount));
      const step = Math.max(1, calculatedStep); // Ensure at least 1
      
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const data = imageData.data;
      const newParticles: Particle[] = [];
      
      for (let y = 0; y < canvas.height; y += step) {
        for (let x = 0; x < canvas.width; x += step) {
          const i = (y * canvas.width + x) * 4;
          const a = data[i + 3];
          
          if (a > 128) { // Only take non-transparent pixels
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];
            
            // Push EVERY sampled pixel (no random dropping) to ensure density
            newParticles.push(new Particle(x, y, r, g, b, settings.particleSize, canvas.width, canvas.height));
          }
        }
      }
      
      particlesRef.current = newParticles;
      ctx.clearRect(0,0, canvas.width, canvas.height);
    };
    
    img.src = imageSrc;

  }, [imageSrc, settings.particleSize, settings.density, settings.enabled]); 

  // Animation Loop
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    if (!settings.enabled) {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      return;
    }

    let audioData: Uint8Array | null = null;
    if (audioAnalyser) {
       audioData = new Uint8Array(audioAnalyser.frequencyBinCount);
    }

    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      timeRef.current += 16; 

      if (audioAnalyser && audioData) {
        audioAnalyser.getByteFrequencyData(audioData);
      }

      // Smooth Rotation
      const lerpFactor = 0.05;
      currentRotation.current.x += (targetRotation.current.x - currentRotation.current.x) * lerpFactor;
      currentRotation.current.y += (targetRotation.current.y - currentRotation.current.y) * lerpFactor;

      const parts = particlesRef.current;
      const w = canvas.width;
      const h = canvas.height;
      const t = timeRef.current;
      const rx = currentRotation.current.x;
      const ry = currentRotation.current.y;

      for (let i = 0; i < parts.length; i++) {
          parts[i].update(audioData, settings, w, h, t, rx, ry);
      }

      // Sort by Scale (Approximation of Z-sort for painter's algorithm)
      // This ensures correct occlusion so foreground objects block background ones
      parts.sort((a, b) => a.scale - b.scale); 

      for (let i = 0; i < parts.length; i++) {
          parts[i].draw(ctx, settings);
      }

      animationFrameRef.current = requestAnimationFrame(animate);
    };

    animate();

    return () => {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    };
  }, [audioAnalyser, settings]);

  return (
    <canvas 
      ref={canvasRef} 
      className={`w-full h-full block cursor-move ${className}`}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    />
  );
};

export default Visualizer;