import React from 'react';

export interface NavItem {
  label: string;
  href: string;
}

export interface Feature {
  id: number;
  title: string;
  description: string;
  icon: React.ReactNode;
  shapeClass: string;
}

export interface Therapist {
  id: string;
  name: string;
  role: string;
  description: string;
  icon: React.ReactNode;
  avatarUrl: string;
  colorClass: string;
  bgClass: string;
  systemInstruction: string;
  greeting: string;
  voiceName: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'model';
  text: string;
  isThinking?: boolean;
}

export interface VisualizerSettings {
  particleSize: number; // 1-10
  intensity: number; // 0-5
  sensitivity: number; // 0-100
  density: number; // 10-100
  enabled: boolean;
}

// Cognitive Reframing Types
export interface ReframingOption {
  perspective: 'rational' | 'compassionate' | 'stoic';
  text: string;
}

export interface Distortion {
  originalText: string;
  type: string; // e.g., "Catastrophizing", "All-or-Nothing"
  explanation: string;
  reframes: ReframingOption[];
}

export interface JournalEntry {
  id: string;
  date: string; // ISO string or formatted date
  timestamp: number; // For sorting
  title: string;
  content: string;
  mood: 'happy' | 'calm' | 'anxious' | 'sad' | 'neutral' | 'energetic';
  tags: string[];
  image?: string; // URL or Base64
  visualizerSettings?: VisualizerSettings; // Saved settings for this entry
  
  // AI Enhanced Fields
  summary?: string;
  reflection?: string;
  actionItem?: string;
  
  // Quantitative Metrics (0-100)
  sentimentScore?: number; // 0 (Negative) - 100 (Positive)
  energyLevel?: number;    // 0 (Low) - 100 (High)
  anxietyLevel?: number;   // 0 (Low) - 100 (High)
}

export interface Habit {
  id: string;
  title: string;
  description: string;
  completedAt: number | null;
  createdAt: number;
  plantType: 'seed' | 'sprout' | 'flower' | 'tree';
  growth?: number; // 0 to 100
}

export enum ButtonVariant {
  PRIMARY = 'primary',
  OUTLINE = 'outline',
  GHOST = 'ghost',
}