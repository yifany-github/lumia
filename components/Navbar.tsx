import React, { useState } from 'react';
import { Menu, X, Sparkles, LogIn, LogOut, LayoutDashboard, Sun, Moon } from 'lucide-react';
import { NavItem, ButtonVariant } from '../types';
import Button from './Button';

interface NavbarProps {
  isLoggedIn: boolean;
  onLoginClick: () => void;
  onLogoutClick: () => void;
  onEnterApp: () => void;
  userAvatar?: string;
  userName?: string;
  onOpenProfile?: () => void;
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const navItems: NavItem[] = [
  { label: 'Sanctuary', href: '#hero' },
  { label: 'Companions', href: '#companions' },
  { label: 'Discover', href: '#discovery' },
  { label: 'Impact', href: '#impact' },
  { label: 'Philosophy', href: '#philosophy' },
];

const Navbar: React.FC<NavbarProps> = ({ 
  isLoggedIn, onLoginClick, onLogoutClick, onEnterApp, 
  userAvatar, userName, onOpenProfile, theme, toggleTheme
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const defaultAvatar = "https://api.dicebear.com/7.x/notionists/svg?seed=John&backgroundColor=ffdfbf";

  const handleScroll = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
    e.preventDefault();
    const targetId = href.replace(/^#/, '');
    const element = document.getElementById(targetId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
    setIsOpen(false);
  };

  return (
    <nav className="fixed top-4 left-0 right-0 z-40 flex justify-center px-4">
      <div className="relative w-full max-w-5xl bg-background/70 backdrop-blur-md border border-border/50 shadow-sm rounded-full px-6 py-3 flex items-center justify-between transition-all duration-300">
        
        {/* Logo */}
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 bg-primary rounded-full flex items-center justify-center text-primary-foreground shadow-sm">
            <Sparkles size={20} strokeWidth={2.5} />
          </div>
          <span className="font-serif font-bold text-xl tracking-tight text-foreground hidden sm:block">
            Lumina
          </span>
        </div>

        {/* Desktop Nav */}
        <div className="hidden md:flex items-center gap-6">
          {navItems.map((item) => (
            <a 
              key={item.label} 
              href={item.href} 
              onClick={(e) => handleScroll(e, item.href)}
              className="text-sm font-bold text-muted-foreground hover:text-primary transition-colors duration-200"
            >
              {item.label}
            </a>
          ))}
        </div>

        {/* CTA Area */}
        <div className="hidden md:flex items-center gap-4">
          <button
            onClick={toggleTheme}
            className="p-2 rounded-full text-muted-foreground hover:text-primary hover:bg-muted/20 transition-colors"
            title={theme === 'light' ? 'Switch to Dark Mode' : 'Switch to Light Mode'}
          >
            {theme === 'light' ? <Moon size={20} /> : <Sun size={20} />}
          </button>

          {isLoggedIn ? (
            <>
              <Button variant={ButtonVariant.PRIMARY} className="h-10 px-6 text-sm shadow-sm" onClick={onEnterApp}>
                <LayoutDashboard size={16} className="mr-2" />
                Dashboard
              </Button>
              
              <div className="pl-2 flex items-center gap-2">
                 <button 
                    className="flex items-center gap-2 hover:bg-muted/50 p-1.5 pr-3 rounded-full transition-colors group"
                    onClick={onOpenProfile}
                    title="View Profile"
                 >
                   <div className="w-8 h-8 rounded-full bg-muted/20 border border-border shadow-sm overflow-hidden group-hover:border-primary transition-colors">
                     <img src={userAvatar || defaultAvatar} alt="User" className="w-full h-full object-cover" />
                   </div>
                   <span className="text-sm font-bold text-foreground group-hover:text-primary transition-colors max-w-[100px] truncate hidden lg:block">
                     {userName || "User"}
                   </span>
                 </button>
                 <button 
                  onClick={onLogoutClick}
                  className="text-muted-foreground hover:text-red-500 transition-colors p-2 hover:bg-red-50/10 rounded-full"
                  title="Log Out"
                >
                  <LogOut size={18} />
                </button>
              </div>
            </>
          ) : (
            <>
              <button 
                onClick={onLoginClick}
                className="text-sm font-bold text-muted-foreground hover:text-foreground transition-colors px-2"
              >
                Log In
              </button>
              <Button variant={ButtonVariant.PRIMARY} className="h-10 px-6 text-sm" onClick={() => document.getElementById('companions')?.scrollIntoView({ behavior: 'smooth' })}>
                Begin Journey
              </Button>
            </>
          )}
        </div>

        {/* Mobile Menu Toggle */}
        <div className="flex items-center gap-2 md:hidden">
          <button
              onClick={toggleTheme}
              className="p-2 rounded-full text-muted-foreground hover:text-primary hover:bg-muted/20 transition-colors"
            >
              {theme === 'light' ? <Moon size={20} /> : <Sun size={20} />}
          </button>
          <button 
            className="text-foreground p-2"
            onClick={() => setIsOpen(!isOpen)}
          >
            {isOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </div>

      {/* Mobile Menu Dropdown */}
      {isOpen && (
        <div className="absolute top-20 left-4 right-4 bg-background border border-border rounded-[2rem] p-6 shadow-xl flex flex-col gap-4 md:hidden animate-in slide-in-from-top-4 fade-in duration-300">
          {navItems.map((item) => (
            <a 
              key={item.label}
              href={item.href}
              onClick={(e) => handleScroll(e, item.href)}
              className="text-lg font-serif font-medium text-foreground py-2 border-b border-border/30 last:border-0"
            >
              {item.label}
            </a>
          ))}
          <div className="pt-2 flex flex-col gap-3">
             {isLoggedIn ? (
                <>
                  <div 
                    className="flex items-center gap-3 px-2 py-2 mb-2 border-b border-border/30 cursor-pointer"
                    onClick={() => {
                        setIsOpen(false);
                        onOpenProfile?.();
                    }}
                  >
                      <div className="w-10 h-10 rounded-full bg-secondary/10 overflow-hidden border border-border">
                        <img src={userAvatar || defaultAvatar} alt="User" className="w-full h-full object-cover" />
                      </div>
                      <div>
                        <div className="font-bold text-foreground">{userName || "User"}</div>
                        <div className="text-xs text-muted-foreground">Tap to view profile</div>
                      </div>
                   </div>

                  <Button className="w-full" onClick={() => {
                    setIsOpen(false);
                    onEnterApp();
                  }}>
                    <LayoutDashboard size={18} className="mr-2" />
                    Dashboard
                  </Button>
                  <Button 
                    variant={ButtonVariant.OUTLINE} 
                    className="w-full justify-center border-border text-muted-foreground hover:text-red-600 hover:border-red-200"
                    onClick={() => {
                      setIsOpen(false);
                      onLogoutClick();
                    }}
                  >
                    <LogOut size={18} className="mr-2" />
                    Log Out
                  </Button>
                </>
             ) : (
                <>
                  <Button 
                      variant={ButtonVariant.OUTLINE} 
                      className="w-full justify-center border-border text-muted-foreground"
                      onClick={() => {
                        setIsOpen(false);
                        onLoginClick();
                      }}
                  >
                      <LogIn size={18} className="mr-2" />
                      Log In
                  </Button>
                  <Button className="w-full" onClick={() => {
                      setIsOpen(false);
                      document.getElementById('companions')?.scrollIntoView({ behavior: 'smooth' });
                    }}>
                      Begin Journey
                  </Button>
                </>
             )}
          </div>
        </div>
      )}
    </nav>
  );
};

export default Navbar;