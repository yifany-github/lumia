import React, { useState } from 'react';
import { X, Mail, Lock, ArrowRight, Sparkles, UserCheck } from 'lucide-react';
import Button from './Button';
import { ButtonVariant } from '../types';
import { useAuth } from '../contexts/AuthContext';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onLogin: () => void;
}

const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose, onLogin }) => {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const { signInWithGoogle, loginWithEmail, registerWithEmail, loading, loginAsDemoUser } = useAuth();

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      if (isLogin) {
        await loginWithEmail(email, password);
      } else {
        await registerWithEmail(email, password, name);
      }
      onLogin();
    } catch (err: any) {
      setError(err.message || 'Failed to authenticate');
    }
  };

  const handleGoogleLogin = async () => {
    try {
      await signInWithGoogle();
      onLogin();
    } catch (err: any) {
      setError(err.message || 'Failed to sign in with Google');
    }
  };

  const handleDemoLogin = async () => {
    try {
      await loginAsDemoUser();
      onLogin();
    } catch (err: any) {
      setError(err.message || 'Failed to sign in as demo user');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-md transition-opacity duration-300"
        onClick={onClose}
      />

      {/* Modal Content */}
      <div className="relative z-10 w-full max-w-md bg-background rounded-[2.5rem] shadow-2xl overflow-hidden border border-border/50 animate-in zoom-in-95 duration-300 max-h-[90vh] flex flex-col">
        
        {/* Decorative Header */}
        <div className="bg-primary p-8 text-center relative overflow-hidden shrink-0">
          <div className="absolute top-0 left-0 w-full h-full opacity-10 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMDAlJyBoZWlnaHQ9JzEwMCUnPjxmaWx0ZXIgaWQ9J25vaXNlJz48ZmVUdXJidWxlbmNlIHR5cGU9J2ZyYWN0YWxOb2lzZScgYmFzZUZyZXF1ZW5jeT0nMC44JyBudW1PY3RhdmVzPSc0JyBzdGl0Y2hUaWxlcz0nc3RpdGNoJy8+PC9maWx0ZXI+PHJlY3Qgd2lkdGg9JzEwMCUnIGhlaWdodD0nMTAwJScgZmlsdGVyPSd1cmwoI25vaXNlKScgb3BhY2l0eT0nMC40Jy8+PC9zdmc+')] mix-blend-overlay"></div>
          <div className="w-16 h-16 bg-white/10 rounded-full flex items-center justify-center mx-auto mb-4 backdrop-blur-sm border border-white/20">
            <Sparkles className="text-primary-foreground" size={28} />
          </div>
          <h3 className="font-serif text-3xl font-bold text-primary-foreground mb-2">
            {isLogin ? 'Welcome Back' : 'Begin Your Journey'}
          </h3>
          <p className="text-primary-foreground/80 text-sm">
            {isLogin ? 'Reconnect with your inner sanctuary.' : 'Create a safe space for your mind.'}
          </p>
          
          <button 
            onClick={onClose}
            className="absolute top-4 right-4 p-2 text-primary-foreground/60 hover:text-primary-foreground hover:bg-white/10 rounded-full transition-colors z-20"
          >
            <X size={20} />
          </button>
        </div>

        {/* Form */}
        <div className="p-8 overflow-y-auto no-scrollbar">
          {error && <div className="mb-4 p-3 bg-red-100 text-red-600 rounded-lg text-sm">{error}</div>}
          
          <div className="mb-6 space-y-3">
            <button 
                onClick={handleDemoLogin}
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 p-3 rounded-xl bg-secondary/10 text-secondary hover:bg-secondary/20 font-bold text-sm transition-all border border-secondary/20"
            >
                <UserCheck size={18} />
                <span>One-Click Demo Login</span>
            </button>

            <button 
                onClick={handleGoogleLogin}
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 p-3 rounded-xl bg-white text-gray-700 hover:bg-gray-50 font-bold text-sm transition-all border border-gray-300 shadow-sm"
            >
                <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" className="w-5 h-5" />
                <span>Continue with Google</span>
            </button>
            <div className="relative flex items-center py-2">
                <div className="flex-grow border-t border-border"></div>
                <span className="flex-shrink-0 mx-4 text-xs text-muted-foreground uppercase tracking-widest">Or continue with email</span>
                <div className="flex-grow border-t border-border"></div>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {!isLogin && (
              <div className="space-y-2">
                <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground ml-2">Name</label>
                <div className="relative">
                  <UserCheck className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
                  <input 
                    type="text" 
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="w-full h-12 pl-12 pr-4 rounded-xl border border-border bg-card focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-muted-foreground/50"
                    placeholder="Your Name"
                  />
                </div>
              </div>
            )}
            
            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground ml-2">Email</label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
                <input 
                  type="email" 
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full h-12 pl-12 pr-4 rounded-xl border border-border bg-card focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-muted-foreground/50"
                  placeholder="you@example.com"
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground ml-2">Password</label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
                <input 
                  type="password" 
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full h-12 pl-12 pr-4 rounded-xl border border-border bg-card focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-muted-foreground/50"
                  placeholder="••••••••"
                />
              </div>
            </div>

            <Button 
              type="submit" 
              variant={ButtonVariant.PRIMARY} 
              className="w-full h-14 mt-4"
              disabled={loading}
            >
              {loading ? 'Processing...' : (isLogin ? 'Sign In' : 'Create Account')}
              {!loading && <ArrowRight size={18} className="ml-2" />}
            </Button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-muted-foreground text-sm">
              {isLogin ? "Don't have an account? " : "Already have a sanctuary? "}
              <button 
                onClick={() => setIsLogin(!isLogin)}
                className="font-bold text-primary hover:underline decoration-2 underline-offset-4"
              >
                {isLogin ? 'Sign Up' : 'Log In'}
              </button>
            </p>
          </div>
          
          <div className="mt-8 pt-6 border-t border-border/40 text-center">
             <p className="text-[10px] text-muted-foreground uppercase tracking-widest mb-1">Trusted & Secure</p>
             <div className="flex justify-center gap-1">
               {[1,2,3,4,5].map(i => (
                 <div key={i} className="w-1.5 h-1.5 rounded-full bg-primary/20"></div>
               ))}
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AuthModal;