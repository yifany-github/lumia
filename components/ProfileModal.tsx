import React, { useState, useRef } from 'react';
import { X, Upload, Download, LogOut, Trash2, User, Sparkles, Volume2, VolumeX, Zap, ZapOff, Camera, PenLine, Shield } from 'lucide-react';
import Button from './Button';
import { ButtonVariant } from '../types';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  userAvatar: string;
  userName: string;
  onUpdateUser: (name: string, avatar: string, avatarFile?: File) => Promise<void>;
  stats: {
    entriesCount: number;
    avgSentiment: number;
    memberSince: string;
  };
  onExportData: () => void;
  onLogout: () => void;
  onDeleteAccount: () => void;
  onOpenAdmin?: () => void;
}

const ProfileModal: React.FC<ProfileModalProps> = ({ 
  isOpen, onClose, userAvatar, userName, onUpdateUser, 
  stats, onExportData, onLogout, onDeleteAccount, onOpenAdmin
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [tempName, setTempName] = useState(userName);
  const [tempAvatarFile, setTempAvatarFile] = useState<File | null>(null);
  const [tempAvatarUrl, setTempAvatarUrl] = useState<string | null>(null);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [motionEnabled, setMotionEnabled] = useState(true);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleSaveName = async () => {
    setIsUploading(true);
    await onUpdateUser(tempName, tempAvatarUrl || userAvatar, tempAvatarFile || undefined);
    setIsUploading(false);
    setIsEditing(false);
  };

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setTempAvatarFile(file);
      setTempAvatarUrl(url);
      setIsUploading(true);
      await onUpdateUser(tempName, url, file); // Use tempName to preserve edits
      setIsUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-md animate-in fade-in duration-300"
        onClick={onClose}
      />

      {/* Modal Content */}
      <div className="relative z-10 w-full max-w-lg bg-background rounded-[2.5rem] shadow-2xl overflow-hidden border border-border/50 animate-in zoom-in-95 slide-in-from-bottom-4 duration-300">
        
        {/* Header / Identity Section */}
        <div className="relative pt-12 pb-8 px-8 flex flex-col items-center bg-gradient-to-b from-primary/10 to-transparent">
            <button 
                onClick={onClose} 
                className="absolute top-4 right-4 p-2 text-muted-foreground hover:text-foreground rounded-full hover:bg-muted transition-colors"
            >
                <X size={24} />
            </button>

            {/* Avatar */}
            <div className="relative group mb-4">
                <div className="w-28 h-28 rounded-full overflow-hidden border-4 border-background shadow-lg">
                    <img src={userAvatar} alt="Profile" className="w-full h-full object-cover" />
                </div>
                <button 
                    onClick={() => fileInputRef.current?.click()}
                    className="absolute inset-0 bg-black/40 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer"
                >
                    <Camera className="text-white" size={32} />
                </button>
                <input 
                    type="file" 
                    ref={fileInputRef} 
                    className="hidden" 
                    accept="image/*" 
                    onChange={handleAvatarChange}
                />
            </div>

            {/* Name */}
            {isEditing ? (
                <div className="flex items-center gap-2 mb-1">
                    <input 
                        type="text" 
                        value={tempName}
                        onChange={(e) => setTempName(e.target.value)}
                        className="text-2xl font-serif font-bold text-center bg-transparent border-b-2 border-primary focus:outline-none text-foreground w-48"
                        autoFocus
                    />
                    <button onClick={handleSaveName} className="p-1.5 bg-primary text-white rounded-full"><Sparkles size={14} /></button>
                </div>
            ) : (
                <div className="flex items-center gap-2 mb-1 group cursor-pointer" onClick={() => setIsEditing(true)}>
                    <h2 className="text-2xl font-serif font-bold text-foreground">{userName}</h2>
                    <PenLine size={16} className="text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity" />
                </div>
            )}
            <p className="text-sm text-muted-foreground">Sanctuary Member since {stats.memberSince}</p>

            {/* Stats Row */}
            <div className="flex w-full justify-center gap-8 mt-6">
                <div className="text-center">
                    <div className="text-2xl font-bold text-primary">{stats.entriesCount}</div>
                    <div className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">Reflections</div>
                </div>
                <div className="w-px bg-border/50 h-10"></div>
                <div className="text-center">
                    <div className="text-2xl font-bold text-secondary">{stats.avgSentiment}%</div>
                    <div className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">Avg Wellness</div>
                </div>
            </div>
        </div>

        {/* Settings Section */}
        <div className="px-8 py-6 space-y-6">
            <div>
                <h3 className="text-xs font-bold text-muted-foreground uppercase tracking-widest mb-4 ml-1">Preferences</h3>
                <div className="space-y-3">
                    <div className="flex items-center justify-between p-4 bg-card border border-border/50 rounded-2xl">
                        <div className="flex items-center gap-3">
                            <div className={`p-2 rounded-xl ${soundEnabled ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'}`}>
                                {soundEnabled ? <Volume2 size={20} /> : <VolumeX size={20} />}
                            </div>
                            <span className="font-bold text-foreground text-sm">Ambient Sounds</span>
                        </div>
                        <button 
                            onClick={() => setSoundEnabled(!soundEnabled)}
                            className={`w-12 h-6 rounded-full p-1 transition-colors ${soundEnabled ? 'bg-primary' : 'bg-muted'}`}
                        >
                            <div className={`w-4 h-4 bg-background rounded-full shadow-sm transition-transform ${soundEnabled ? 'translate-x-6' : 'translate-x-0'}`} />
                        </button>
                    </div>

                    <div className="flex items-center justify-between p-4 bg-card border border-border/50 rounded-2xl">
                        <div className="flex items-center gap-3">
                            <div className={`p-2 rounded-xl ${motionEnabled ? 'bg-secondary/10 text-secondary' : 'bg-muted text-muted-foreground'}`}>
                                {motionEnabled ? <Zap size={20} /> : <ZapOff size={20} />}
                            </div>
                            <span className="font-bold text-foreground text-sm">Motion Effects</span>
                        </div>
                        <button 
                            onClick={() => setMotionEnabled(!motionEnabled)}
                            className={`w-12 h-6 rounded-full p-1 transition-colors ${motionEnabled ? 'bg-secondary' : 'bg-muted'}`}
                        >
                            <div className={`w-4 h-4 bg-background rounded-full shadow-sm transition-transform ${motionEnabled ? 'translate-x-6' : 'translate-x-0'}`} />
                        </button>
                    </div>
                </div>
            </div>

            {/* Data & Account */}
            <div>
                <h3 className="text-xs font-bold text-muted-foreground uppercase tracking-widest mb-4 ml-1">Data & Privacy</h3>
                <div className="space-y-3">
                    <button 
                        onClick={onExportData}
                        className="w-full flex items-center justify-between p-4 bg-card border border-border/50 rounded-2xl hover:border-primary/30 hover:shadow-sm transition-all group"
                    >
                        <div className="flex items-center gap-3">
                            <div className="p-2 rounded-xl bg-blue-50 dark:bg-blue-900/20 text-blue-500 group-hover:bg-blue-100 dark:group-hover:bg-blue-900/40 transition-colors">
                                <Download size={20} />
                            </div>
                            <span className="font-bold text-foreground text-sm">Export My Data</span>
                        </div>
                        <span className="text-xs text-muted-foreground">JSON</span>
                    </button>

                    <div className="grid grid-cols-2 gap-3">
                        <button 
                            onClick={onLogout}
                            className="flex items-center justify-center gap-2 p-4 bg-card border border-border/50 rounded-2xl hover:bg-muted hover:text-red-500 transition-colors"
                        >
                            <LogOut size={18} />
                            <span className="font-bold text-sm">Log Out</span>
                        </button>
                        <button 
                            onClick={onDeleteAccount}
                            className="flex items-center justify-center gap-2 p-4 bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-900/30 text-red-500 rounded-2xl hover:bg-red-100 dark:hover:bg-red-900/40 transition-colors"
                        >
                            <Trash2 size={18} />
                            <span className="font-bold text-sm">Delete</span>
                        </button>
                    </div>

                    {onOpenAdmin && (
                        <button 
                            onClick={() => {
                                onClose();
                                onOpenAdmin();
                            }}
                            className="w-full flex items-center justify-center gap-2 p-4 mt-3 bg-primary/10 text-primary border border-primary/20 rounded-2xl hover:bg-primary/20 transition-colors"
                        >
                            <Shield size={18} />
                            <span className="font-bold text-sm">Admin Panel</span>
                        </button>
                    )}
                </div>
            </div>
        </div>

      </div>
    </div>
  );
};

export default ProfileModal;