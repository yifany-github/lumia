import React, { createContext, useContext, useEffect, useState } from 'react';
import type { User } from 'firebase/auth';

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

type FirebaseAuthModule = typeof import('firebase/auth');
type FirebaseFirestoreModule = typeof import('firebase/firestore');
type FirebaseStorageModule = typeof import('firebase/storage');

interface FirebaseRuntime {
  auth: import('firebase/auth').Auth | null;
  db: import('firebase/firestore').Firestore | null;
  storage: import('firebase/storage').FirebaseStorage | null;
  authModule: FirebaseAuthModule;
  firestoreModule: FirebaseFirestoreModule;
  storageModule: FirebaseStorageModule;
}

const hasFirebaseConfig = Boolean(import.meta.env.VITE_FIREBASE_API_KEY);
let firebaseRuntimePromise: Promise<FirebaseRuntime> | null = null;

const loadFirebaseRuntime = async (): Promise<FirebaseRuntime> => {
  if (!hasFirebaseConfig) {
    throw new Error("Firebase not initialized");
  }

  firebaseRuntimePromise ||= Promise.all([
    import('../firebase'),
    import('firebase/auth'),
    import('firebase/firestore'),
    import('firebase/storage')
  ]).then(([firebase, authModule, firestoreModule, storageModule]) => ({
    auth: firebase.auth,
    db: firebase.db,
    storage: firebase.storage,
    authModule,
    firestoreModule,
    storageModule
  }));

  return firebaseRuntimePromise;
};

const syncUserProfile = async (
  runtime: FirebaseRuntime,
  user: User,
  displayName?: string
) => {
  const { db, firestoreModule } = runtime;
  if (!db) return;

  const userRef = firestoreModule.doc(db, 'users', user.uid);
  const now = firestoreModule.serverTimestamp();
  await firestoreModule.setDoc(userRef, {
    displayName: displayName || user.displayName || 'User',
    email: user.email || null,
    phoneNumber: user.phoneNumber || null,
    photoURL: user.photoURL || null,
    providerIds: user.providerData.map((provider) => provider.providerId),
    updatedAt: now,
    createdAt: now
  }, { merge: true });
};

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
    if (!hasFirebaseConfig) {
      setLoading(false);
      return;
    }

    let unsubscribe: (() => void) | undefined;
    let isMounted = true;

    loadFirebaseRuntime().then((runtime) => {
      if (!isMounted) return;
      const { auth, authModule } = runtime;
      if (!auth) {
        setLoading(false);
        return;
      }
      unsubscribe = authModule.onAuthStateChanged(auth, (user) => {
        setCurrentUser(user);
        setLoading(false);
        if (user) {
          syncUserProfile(runtime, user).catch((error) => {
            console.error("Failed to sync user profile", error);
          });
        }
      });
    }).catch(() => {
      if (isMounted) setLoading(false);
    });

    return () => {
      isMounted = false;
      unsubscribe?.();
    };
  }, []);

  const signInWithGoogle = async () => {
    const runtime = await loadFirebaseRuntime();
    const { auth, authModule } = runtime;
    if (!auth) throw new Error("Firebase not initialized");
    const provider = new authModule.GoogleAuthProvider();
    try {
      const result = await authModule.signInWithPopup(auth, provider);
      await syncUserProfile(runtime, result.user);
    } catch (error) {
      console.error("Google Sign In Error", error);
      throw error;
    }
  };

  const registerWithEmail = async (email: string, pass: string, name: string) => {
    const runtime = await loadFirebaseRuntime();
    const { auth, authModule } = runtime;
    if (!auth) throw new Error("Firebase not initialized");
    const result = await authModule.createUserWithEmailAndPassword(auth, email, pass);
    await authModule.updateProfile(result.user, { displayName: name });
    await syncUserProfile(runtime, result.user, name);
  };

  const loginWithEmail = async (email: string, pass: string) => {
    const runtime = await loadFirebaseRuntime();
    const { auth, authModule } = runtime;
    if (!auth) throw new Error("Firebase not initialized");
    const result = await authModule.signInWithEmailAndPassword(auth, email, pass);
    await syncUserProfile(runtime, result.user);
  };

  const logout = async () => {
    if (hasFirebaseConfig) {
      const { auth, authModule } = await loadFirebaseRuntime();
      if (auth) {
        await authModule.signOut(auth);
      }
    }
    setCurrentUser(null);
  };

  const updateUserProfile = async (name: string, photoURL?: string) => {
    if (hasFirebaseConfig) {
      const runtime = await loadFirebaseRuntime();
      const { auth, authModule } = runtime;
      if (auth && auth.currentUser) {
        await authModule.updateProfile(auth.currentUser, { displayName: name, photoURL: photoURL || auth.currentUser.photoURL });
        await syncUserProfile(runtime, auth.currentUser, name);
        setCurrentUser({ ...auth.currentUser });
        return;
      }
    }

    if (currentUser) {
      // Handle demo user update
      setCurrentUser({ ...currentUser, displayName: name, photoURL: photoURL || currentUser.photoURL } as User);
    }
  };

  const uploadAvatar = async (file: File): Promise<string> => {
    if (!hasFirebaseConfig) {
      return URL.createObjectURL(file);
    }
    const { auth, storage, storageModule } = await loadFirebaseRuntime();
    if (!storage || !auth?.currentUser) {
      // If demo user or no storage, return a fake URL or object URL
      return URL.createObjectURL(file);
    }
    const storageRef = storageModule.ref(storage, `avatars/${auth.currentUser.uid}/${file.name}`);
    await storageModule.uploadBytes(storageRef, file);
    return await storageModule.getDownloadURL(storageRef);
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
