import { useCallback, useEffect, useRef, useState } from 'react';

type SpeechRecognitionConstructor = new () => SpeechRecognitionLike;

type SpeechRecognitionLike = {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: ((event: { error?: string }) => void) | null;
  onend: (() => void) | null;
};

type SpeechRecognitionEventLike = {
  resultIndex: number;
  results: ArrayLike<{
    isFinal: boolean;
    0: { transcript: string };
  }>;
};

type UseSpeechInputOptions = {
  lang?: string;
  onTranscript: (text: string) => void;
};

export function useSpeechInput({ lang, onTranscript }: UseSpeechInputOptions) {
  const [isSupported, setIsSupported] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [interimTranscript, setInterimTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);

  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const onTranscriptRef = useRef(onTranscript);

  useEffect(() => {
    onTranscriptRef.current = onTranscript;
  }, [onTranscript]);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const SpeechRecognition = ((window as any).SpeechRecognition ||
      (window as any).webkitSpeechRecognition) as SpeechRecognitionConstructor | undefined;

    if (!SpeechRecognition) {
      setIsSupported(false);
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = lang || navigator.language || 'en-US';

    recognition.onresult = (event) => {
      let finalTranscript = '';
      let interim = '';

      for (let i = event.resultIndex; i < event.results.length; i += 1) {
        const transcript = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          finalTranscript += transcript;
        } else {
          interim += transcript;
        }
      }

      if (finalTranscript.trim()) {
        onTranscriptRef.current(finalTranscript.trim());
      }
      setInterimTranscript(interim.trim());
    };

    recognition.onerror = (event) => {
      setError(readableSpeechError(event.error));
      setIsListening(false);
      setInterimTranscript('');
    };

    recognition.onend = () => {
      setIsListening(false);
      setInterimTranscript('');
    };

    recognitionRef.current = recognition;
    setIsSupported(true);

    return () => {
      try {
        recognition.abort();
      } catch {
        // No-op: some browsers throw when aborting an inactive recognizer.
      }
      recognitionRef.current = null;
    };
  }, [lang]);

  const start = useCallback(() => {
    if (!recognitionRef.current) {
      setError('Voice input is not supported in this browser.');
      return;
    }

    try {
      setError(null);
      setInterimTranscript('');
      recognitionRef.current.start();
      setIsListening(true);
    } catch {
      setError('Voice input is already listening.');
    }
  }, []);

  const stop = useCallback(() => {
    if (!recognitionRef.current) return;
    try {
      recognitionRef.current.stop();
    } catch {
      // No-op: stop can throw if the recognizer has already ended.
    }
    setIsListening(false);
    setInterimTranscript('');
  }, []);

  const toggle = useCallback(() => {
    if (isListening) {
      stop();
    } else {
      start();
    }
  }, [isListening, start, stop]);

  return {
    error,
    interimTranscript,
    isListening,
    isSupported,
    start,
    stop,
    toggle,
  };
}

function readableSpeechError(error?: string) {
  switch (error) {
    case 'not-allowed':
    case 'service-not-allowed':
      return 'Microphone permission is blocked.';
    case 'no-speech':
      return 'No speech detected.';
    case 'audio-capture':
      return 'No microphone was found.';
    case 'network':
      return 'Voice recognition needs a network connection.';
    default:
      return 'Voice input stopped. Try again.';
  }
}
