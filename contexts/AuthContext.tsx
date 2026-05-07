import React, { createContext, useContext, useEffect, useState } from 'react';
import { 
  User, 
  onAuthStateChanged, 
  signInWithPopup, 
  GoogleAuthProvider, 
  signOut,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  updateProfile
} from 'firebase/auth';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { auth, storage } from '../firebase';

interface AuthContextType {
  currentUser: User | null;
  loading: boolean;
  signInWithGoogle: () => Promise<void>;
  logout: () => Promise<void>;
  registerWithEmail: (email: string, pass: string, name: string) => Promise<void>;
  loginWithEmail: (email: string, pass: string) => Promise<void>;
  updateUserProfile: (name: string, photoURL?: string) => Promise<void>;
  uploadAvatar: (file: File) => Promise<string>;
  loginAsDemoUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!auth) {
      setLoading(false);
      return;
    }
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  const signInWithGoogle = async () => {
    if (!auth) throw new Error("Firebase not initialized");
    const provider = new GoogleAuthProvider();
    try {
      await signInWithPopup(auth, provider);
    } catch (error) {
      console.error("Google Sign In Error", error);
      throw error;
    }
  };

  const registerWithEmail = async (email: string, pass: string, name: string) => {
    if (!auth) throw new Error("Firebase not initialized");
    const result = await createUserWithEmailAndPassword(auth, email, pass);
    await updateProfile(result.user, { displayName: name });
  };

  const loginWithEmail = async (email: string, pass: string) => {
    if (!auth) throw new Error("Firebase not initialized");
    await signInWithEmailAndPassword(auth, email, pass);
  };

  const logout = async () => {
    if (auth) {
      await signOut(auth);
    }
    setCurrentUser(null);
  };

  const updateUserProfile = async (name: string, photoURL?: string) => {
    if (auth && auth.currentUser) {
      await updateProfile(auth.currentUser, { displayName: name, photoURL: photoURL || auth.currentUser.photoURL });
      setCurrentUser({ ...auth.currentUser });
    } else if (currentUser) {
      // Handle demo user update
      setCurrentUser({ ...currentUser, displayName: name, photoURL: photoURL || currentUser.photoURL } as User);
    }
  };

  const uploadAvatar = async (file: File): Promise<string> => {
    if (!storage || !auth?.currentUser) {
        // If demo user or no storage, return a fake URL or object URL
        return URL.createObjectURL(file);
    }
    const storageRef = ref(storage, `avatars/${auth.currentUser.uid}/${file.name}`);
    await uploadBytes(storageRef, file);
    return await getDownloadURL(storageRef);
  };

  const loginAsDemoUser = async () => {
    const demoUser = {
      uid: 'demo-user',
      displayName: 'Guest Traveler',
      email: 'guest@lumina.ai',
      photoURL: 'https://api.dicebear.com/7.x/notionists/svg?seed=Guest&backgroundColor=e0e0e0',
      emailVerified: true,
    } as unknown as User;
    setCurrentUser(demoUser);
  };

  const value = {
    currentUser,
    loading,
    signInWithGoogle,
    logout,
    registerWithEmail,
    loginWithEmail,
    updateUserProfile,
    uploadAvatar,
    loginAsDemoUser
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
};
