import React, { Suspense, lazy, useState, useMemo, useEffect } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import TherapistSelection, { therapists } from './components/TherapistSelection';
import { Therapist, JournalEntry } from './types';
import { useAuth } from './contexts/AuthContext';

const HowItWorks = lazy(() => import('./components/HowItWorks'));
const ChatSession = lazy(() => import('./components/ChatSession'));
const SelfCareToolkit = lazy(() => import('./components/SelfCareToolkit'));
const DiscoverySection = lazy(() => import('./components/DiscoverySection'));
const StatsSection = lazy(() => import('./components/StatsSection'));
const PhilosophySection = lazy(() => import('./components/PhilosophySection'));
const Footer = lazy(() => import('./components/Footer'));
const BreathingExercise = lazy(() => import('./components/BreathingExercise'));
const CrisisSupport = lazy(() => import('./components/CrisisSupport'));
const AuthModal = lazy(() => import('./components/AuthModal'));
const ProfileModal = lazy(() => import('./components/ProfileModal'));
const FullChatInterface = lazy(() => import('./components/FullChatInterface'));
const Dashboard = lazy(() => import('./components/Dashboard'));
const AdminPanel = lazy(() => import('./components/AdminPanel'));

// Initial Mock Data moved from Dashboard to App
const initialEntries: JournalEntry[] = [
  {
    id: '1',
    date: 'Oct 24',
    timestamp: 1729728000000,
    title: 'Afternoon Sunshine',
    content: 'The light hit the balcony in the most specific way today. It reminded me of childhood summers.',
    mood: 'calm',
    tags: ['Nostalgia', 'Light'],
    reflection: 'Light often serves as an anchor to past comforts.',
    actionItem: 'Spend 10 minutes in the sun tomorrow.',
    image: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=2070&auto=format&fit=crop',
    visualizerSettings: { particleSize: 2, intensity: 2, sensitivity: 90, density: 70, enabled: true },
    sentimentScore: 85,
    energyLevel: 60,
    anxietyLevel: 10
  },
  {
    id: '2',
    date: 'Oct 23',
    timestamp: 1729641600000,
    title: 'Finding calm in chaos',
    content: 'Today was overwhelming at work, but I took 5 minutes to practice breathing.',
    mood: 'anxious',
    tags: ['Work', 'Breathing'],
    reflection: 'Taking intentional pauses is a sign of self-regulation.',
    actionItem: 'Schedule one 5-minute breathing break.',
    sentimentScore: 45,
    energyLevel: 70,
    anxietyLevel: 80
  },
  {
    id: '3',
    date: 'Oct 21',
    timestamp: 1729468800000,
    title: 'Energy burst!',
    content: 'Finally finished the project. Felt a surge of dopamine.',
    mood: 'energetic',
    tags: ['Achievement', 'Art'],
    reflection: 'Acknowledging your wins fuels future creativity.',
    actionItem: 'Buy the new paint brushes.',
    sentimentScore: 92,
    energyLevel: 95,
    anxietyLevel: 5
  },
  {
    id: '4',
    date: 'Oct 19',
    timestamp: 1729296000000,
    title: 'A bit heavy today',
    content: 'Felt hard to get out of bed. Just one of those days.',
    mood: 'sad',
    tags: ['Rest', 'Slow'],
    reflection: 'It is okay to have slow days. Rest is productive.',
    actionItem: 'Go to bed 30 mins early.',
    sentimentScore: 30,
    energyLevel: 20,
    anxietyLevel: 30
  }
];

type AppView = 'landing' | 'dashboard' | 'chat' | 'admin';

const DEFAULT_AVATAR = "https://api.dicebear.com/7.x/notionists/svg?seed=John&backgroundColor=ffdfbf";

const AppLoadingState: React.FC<{ label?: string }> = ({ label = 'Loading Lumina' }) => (
  <div className="min-h-screen bg-background text-foreground flex items-center justify-center px-6">
    <div className="rounded-3xl border border-border/60 bg-card/80 px-6 py-5 shadow-sm">
      <div className="h-2 w-36 overflow-hidden rounded-full bg-muted">
        <div className="h-full w-1/2 animate-pulse rounded-full bg-primary/50" />
      </div>
      <p className="mt-4 text-sm font-medium text-muted-foreground">{label}</p>
    </div>
  </div>
);

const SectionLoadingState: React.FC = () => (
  <div className="mx-auto my-14 h-24 max-w-5xl rounded-[2rem] border border-border/50 bg-card/55" />
);

const App: React.FC = () => {
  const [currentView, setCurrentView] = useState<AppView>('landing');
  const [activeTherapist, setActiveTherapist] = useState<Therapist | null>(null);
  const [initialChatPrompt, setInitialChatPrompt] = useState<string | undefined>(undefined);
  const [isBreathingOpen, setIsBreathingOpen] = useState(false);
  const [isCrisisOpen, setIsCrisisOpen] = useState(false);
  
  // Theme State
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  // Auth State from Context
  const { currentUser, logout } = useAuth();
  const isLoggedIn = !!currentUser;
  
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);

  useEffect(() => {
    const openAuth = () => setIsAuthModalOpen(true);
    window.addEventListener("lumina:show-auth", openAuth);
    return () => window.removeEventListener("lumina:show-auth", openAuth);
  }, []);
  
  // Profile Modal State
  const [isProfileOpen, setIsProfileOpen] = useState(false);

  // Journal Data (Lifted State)
  const [entries, setEntries] = useState<JournalEntry[]>(initialEntries);

  // Derived Stats
  const stats = useMemo(() => {
    const totalSentiment = entries.reduce((acc, curr) => acc + (curr.sentimentScore || 50), 0);
    const avgSentiment = entries.length > 0 ? Math.round(totalSentiment / entries.length) : 0;
    return {
        entriesCount: entries.length,
        avgSentiment,
        memberSince: 'Oct 2024'
    };
  }, [entries]);

  // Theme Effect
  useEffect(() => {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev === 'light' ? 'dark' : 'light');
  };

  // --- Handlers for Landing Page Interaction ---
  const handleTherapistSelect = (therapist: Therapist) => {
    setActiveTherapist(therapist);
    setInitialChatPrompt(undefined);
    setTimeout(() => {
      document.getElementById('chat-session')?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  const handleStartSession = (therapistId: string, context: string) => {
    const therapist = therapists.find(t => t.id === therapistId);
    if (therapist) {
      setActiveTherapist(therapist);
      setInitialChatPrompt(context);
      setTimeout(() => {
        document.getElementById('chat-session')?.scrollIntoView({ behavior: 'smooth' });
      }, 100);
    }
  };

  // --- Auth & Navigation Handlers ---

  const handleLoginSuccess = () => {
    setIsAuthModalOpen(false);
    setCurrentView('dashboard'); // Redirect to dashboard on login
  };
  
  const handleLogout = async () => {
    await logout();
    setActiveTherapist(null);
    setCurrentView('landing');
    setIsProfileOpen(false);
  };

  const handleNavigateToChat = (therapist?: Therapist) => {
     if (therapist) {
         setActiveTherapist(therapist);
     } else if (!activeTherapist) {
         setActiveTherapist(therapists[0]); // Default to first if none selected
     }
     setCurrentView('chat');
  };

  const handleBackFromChat = () => {
      // If user is logged in, they go back to Dashboard. 
      // If they were just exploring, default to dashboard if logged in.
      if (isLoggedIn) {
          setCurrentView('dashboard');
      } else {
          setCurrentView('landing');
      }
  };

  // --- Profile Handlers ---
  const { updateUserProfile, uploadAvatar } = useAuth();
  
  const handleUpdateUser = async (name: string, avatar: string, avatarFile?: File) => {
      try {
        let photoURL = avatar;
        if (avatarFile) {
           photoURL = await uploadAvatar(avatarFile);
        }
        await updateUserProfile(name, photoURL);
      } catch (e) {
        console.error("Failed to update profile", e);
      }
  };

  const handleExportData = () => {
      const data = {
          user: { name: currentUser?.displayName || 'User', memberSince: stats.memberSince },
          journalEntries: entries,
          exportedAt: new Date().toISOString()
      };
      
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `lumina-export-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
  };

  const handleDeleteAccount = () => {
      if(confirm("Are you sure you want to delete your account? This action cannot be undone.")) {
          setEntries([]);
          handleLogout();
      }
  };

  // --- View Rendering ---

  if (currentView === 'chat') {
    return (
      <Suspense fallback={<AppLoadingState label="Opening therapy room" />}>
        <FullChatInterface
          initialTherapist={activeTherapist}
          onLogout={handleLogout}
          onBack={handleBackFromChat}
          userAvatar={currentUser?.photoURL || DEFAULT_AVATAR}
          userName={currentUser?.displayName || "User"}
        />
      </Suspense>
    );
  }

  if (currentView === 'dashboard' && isLoggedIn) {
      return (
        <Suspense fallback={<AppLoadingState label="Opening dashboard" />}>
          <Dashboard
            userAvatar={currentUser?.photoURL || DEFAULT_AVATAR}
            userName={currentUser?.displayName || "User"}
            entries={entries}
            setEntries={setEntries}
            onNavigateToChat={handleNavigateToChat}
            onLogout={handleLogout}
            onOpenProfile={() => setIsProfileOpen(true)}
          />
          {isProfileOpen && (
            <ProfileModal
              isOpen={isProfileOpen}
              onClose={() => setIsProfileOpen(false)}
              userAvatar={currentUser?.photoURL || DEFAULT_AVATAR}
              userName={currentUser?.displayName || "User"}
              onUpdateUser={handleUpdateUser}
              stats={stats}
              onExportData={handleExportData}
              onLogout={handleLogout}
              onDeleteAccount={handleDeleteAccount}
              onOpenAdmin={() => setCurrentView('admin')}
            />
          )}
        </Suspense>
      );
  }

  if (currentView === 'admin' && isLoggedIn) {
    return (
      <Suspense fallback={<AppLoadingState label="Opening admin" />}>
        <AdminPanel onBack={() => setCurrentView('dashboard')} />
      </Suspense>
    );
  }

  // Default: Landing Page
  return (
    <div className="font-sans text-foreground bg-background antialiased selection:bg-secondary/30 selection:text-foreground">
      <Navbar 
        isLoggedIn={isLoggedIn}
        onLoginClick={() => setIsAuthModalOpen(true)}
        onLogoutClick={handleLogout}
        onEnterApp={() => setCurrentView('dashboard')}
        userAvatar={currentUser?.photoURL || DEFAULT_AVATAR}
        userName={currentUser?.displayName || "User"}
        onOpenProfile={() => setIsProfileOpen(true)}
        theme={theme}
        toggleTheme={toggleTheme}
      />
      <main>
        <Hero />
        <Suspense fallback={<SectionLoadingState />}>
          <HowItWorks />
          <TherapistSelection
            onSelect={handleTherapistSelect}
            selectedId={activeTherapist?.id}
          />
          <ChatSession
            therapist={activeTherapist}
            initialPrompt={initialChatPrompt}
            isLoggedIn={isLoggedIn}
            onShowAuth={() => setIsAuthModalOpen(true)}
          />
          <SelfCareToolkit
            onOpenBreathing={() => setIsBreathingOpen(true)}
            onOpenCrisis={() => setIsCrisisOpen(true)}
          />
          <DiscoverySection onStartSession={handleStartSession} />
          <StatsSection />
          <PhilosophySection />
        </Suspense>
      </main>
      <Suspense fallback={null}>
        <Footer />
      </Suspense>

      <Suspense fallback={null}>
        {isBreathingOpen && (
          <BreathingExercise
            isOpen={isBreathingOpen}
            onClose={() => setIsBreathingOpen(false)}
          />
        )}
        {isCrisisOpen && (
          <CrisisSupport
            isOpen={isCrisisOpen}
            onClose={() => setIsCrisisOpen(false)}
          />
        )}
        {isAuthModalOpen && (
          <AuthModal
            isOpen={isAuthModalOpen}
            onClose={() => setIsAuthModalOpen(false)}
            onLogin={handleLoginSuccess}
          />
        )}
        {isProfileOpen && (
          <ProfileModal
            isOpen={isProfileOpen}
            onClose={() => setIsProfileOpen(false)}
            userAvatar={currentUser?.photoURL || DEFAULT_AVATAR}
            userName={currentUser?.displayName || "User"}
            onUpdateUser={handleUpdateUser}
            stats={stats}
            onExportData={handleExportData}
            onLogout={handleLogout}
            onDeleteAccount={handleDeleteAccount}
            onOpenAdmin={() => setCurrentView('admin')}
          />
        )}
      </Suspense>
    </div>
  );
};

export default App;
