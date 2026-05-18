import type { ChatMessage } from '../types';

export interface TherapySessionRecord {
  id: string;
  therapistID: string;
  messages: ChatMessage[];
  metrics: {
    wellness: number;
    clarity: number;
    calm: number;
    energy: number;
  };
  conversationState: string;
  lastRiskLevel: number;
  turnMetadata: unknown[];
  lastUpdated: number;
}

const DEFAULT_METRICS = {
  wellness: 72,
  clarity: 65,
  calm: 58,
  energy: 60
};

const normalizeMessage = (message: ChatMessage): ChatMessage => ({
  id: message.id,
  role: message.role,
  text: message.text,
  isThinking: Boolean(message.isThinking)
});

const loadFirestore = async () => {
  const [{ db }, firestore] = await Promise.all([
    import('../firebase'),
    import('firebase/firestore')
  ]);

  if (!db) {
    throw new Error('Firebase is not configured.');
  }

  return { db, firestore };
};

export const createTherapySessionRecord = (
  id: string,
  therapistID: string,
  messages: ChatMessage[],
  metrics = DEFAULT_METRICS
): TherapySessionRecord => ({
  id,
  therapistID,
  messages: messages.map(normalizeMessage),
  metrics,
  conversationState: 'listen',
  lastRiskLevel: 0,
  turnMetadata: [],
  lastUpdated: Date.now() / 1000
});

export const fetchLatestTherapySession = async (
  uid: string,
  therapistID: string
): Promise<TherapySessionRecord | null> => {
  const { db, firestore } = await loadFirestore();
  const sessionsRef = firestore.collection(db, 'users', uid, 'therapySessions');
  const queryRef = firestore.query(
    sessionsRef,
    firestore.where('therapistID', '==', therapistID)
  );
  const snapshot = await firestore.getDocs(queryRef);
  const doc = snapshot.docs.sort((a, b) => {
    const left = Number(a.data().lastUpdated || 0);
    const right = Number(b.data().lastUpdated || 0);
    return right - left;
  })[0];
  if (!doc) return null;

  const session = doc.data().session as Partial<TherapySessionRecord> | undefined;
  if (!session?.id || !Array.isArray(session.messages)) return null;

  return {
    id: session.id,
    therapistID: session.therapistID || therapistID,
    messages: session.messages.map(normalizeMessage),
    metrics: session.metrics || DEFAULT_METRICS,
    conversationState: session.conversationState || 'listen',
    lastRiskLevel: session.lastRiskLevel || 0,
    turnMetadata: session.turnMetadata || [],
    lastUpdated: session.lastUpdated || Date.now() / 1000
  };
};

export const saveTherapySession = async (
  uid: string,
  session: TherapySessionRecord
): Promise<void> => {
  const { db, firestore } = await loadFirestore();
  const sessionRef = firestore.doc(db, 'users', uid, 'therapySessions', session.id);
  await firestore.setDoc(sessionRef, {
    session,
    therapistID: session.therapistID,
    lastUpdated: session.lastUpdated,
    messageCount: session.messages.filter((message) => !message.isThinking).length,
    updatedAt: firestore.serverTimestamp()
  }, { merge: true });
};

export const deleteTherapySession = async (
  uid: string,
  sessionID: string
): Promise<void> => {
  const { db, firestore } = await loadFirestore();
  await firestore.deleteDoc(firestore.doc(db, 'users', uid, 'therapySessions', sessionID));
};
