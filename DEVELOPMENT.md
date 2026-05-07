# Lumina Developer Documentation

This document provides a detailed breakdown of the codebase structure and specific guidance for future development and optimization.

---

## 📂 File Structure Analysis

### 1. Root Configuration
*   **`index.html`**: Entry point. Sets up Google Fonts (Fraunces/Nunito) and Tailwind CSS configuration (custom colors: Moss Green, Terracotta, etc.).
*   **`index.tsx`**: React entry point. Mounts the `App` component.
*   **`types.ts`**: **CRITICAL**. Defines the data contracts for the entire app.
    *   `Therapist`: Defines AI persona structure.
    *   `JournalEntry`: Defines the journal data model, including new AI metrics (`sentimentScore`, `energyLevel`) and `Distortion` types.
    *   If you change data structures, start here.

### 2. Services (`/services`)
*   **`geminiService.ts`**: The bridge between the frontend and Google's Gemini API.
    *   `generateTherapistResponse`: Handles chat logic.
    *   `analyzeJournalEntry`: JSON-mode prompt that extracts metadata (mood, tags, scores) from raw journal text.
    *   `analyzeDistortions`: **(The Prism)** A specialized prompt that asks Gemini to find CBT distortions and return a JSON array of reframes.

### 3. Core Components (`/components`)

#### A. Main Application Views
*   **`App.tsx`**: The main router and state container.
    *   Manages `currentView` ('landing' | 'dashboard' | 'chat').
    *   Holds global state like `isLoggedIn` and `activeTherapist`.
*   **`Dashboard.tsx`**: **The most complex component**.
    *   **Functions**: Journal list, Editor, Charts, Audio Recording, Prism Logic.
    *   **State**: Manages the list of entries (`entries`), editor state, and audio context for the visualizer.
    *   **Logic**: Contains the implementation of "The Prism" text highlighting and popover rendering.
*   **`FullChatInterface.tsx`**: The immersive, full-screen chat UI (post-login).
    *   **Live Assessment**: Maintains a state of psychological metrics (`metrics`: Wellness, Clarity, Calm, Energy).
    *   **Adaptive Prompting**: In `handleSend`, these metrics are injected into the prompt via a `[CURRENT USER METRICS]` block. This instructs the AI to modulate its tone based on the user's specific emotional state (e.g., "Low Energy (<40): Be gentle").
    *   **Functionality**: Also handles Gemini Live (audio/video) connections and chat transcript downloads (`handleSaveChat`).

#### B. Landing Page Components
*   **`Hero.tsx`**: First fold with Blob animations.
*   **`Navbar.tsx`**: Responsive navigation and login/logout triggers.
*   **`TherapistSelection.tsx`**: Grid of available AI companions. **Edit this file to add/modify AI personas and their system prompts.**
*   **`ChatSession.tsx`**: The "Preview" chat widget on the landing page.
*   **`DiscoverySection.tsx`**: Suggested conversation starters and content.
*   **`StatsSection.tsx`**: Marketing component showing impact charts.
*   **`SelfCareToolkit.tsx`**: Quick access cards (Breathing, Affirmations, Crisis).

#### C. Utilities & Visuals
*   **`Visualizer.tsx`**: A custom HTML5 Canvas particle engine.
    *   **Logic**: Samples pixels from an image, calculates "depth" based on luminance (brightness), and creates a 3D point cloud that reacts to audio frequency data.
*   **`BreathingExercise.tsx`**: A standalone modal with a CSS-animation based Box Breathing guide.
*   **`AuthModal.tsx`**: UI for Login/Signup (currently uses mock authentication).

---

## 🛠 Roadmap & Optimization Guide

If you are continuing development, here is the recommended path:

### Phase 1: Refactoring (Immediate)
1.  **Split `Dashboard.tsx`**: This file is getting too large (~600 lines).
    *   Extract the Chart logic into `components/dashboard/WellnessChart.tsx`.
    *   Extract the Editor logic into `components/dashboard/JournalEditor.tsx`.
    *   Extract the Prism logic into `components/dashboard/PrismOverlay.tsx`.
2.  **Centralize State**:
    *   Currently, `App.tsx` passes `activeTherapist` down via props.
    *   **Action**: Use `React Context` or `Zustand` to manage `userState`, `journalEntries`, and `activeTherapist` globally to avoid "Prop Drilling".

### Phase 2: Data Persistence (Backend)
1.  **Database Integration**:
    *   Currently, data is stored in `useState` (RAM only). Refreshing clears data.
    *   **Action**: Integrate Firebase (easiest) or Supabase (PostgreSQL).
    *   Save `JournalEntry` objects to a `journal` collection.
    *   Save chat history to a `conversations` collection.
2.  **Secure API Key**:
    *   **Critical**: Do not expose the Gemini API Key in the frontend in production.
    *   **Action**: Move `geminiService.ts` logic to a backend API route (e.g., Next.js API Routes or Express) and call that from the frontend.

### Phase 3: Enhanced AI Features
1.  **Real-time Metric Analysis**:
    *   Currently, chat metrics in `FullChatInterface` are simulated/randomized on send.
    *   **Action**: Implement a background call to `gemini-3-flash` after every 3-4 user messages to analyze the text and update the `metrics` state with real data derived from the conversation sentiment.
2.  **Long-term Memory (RAG)**:
    *   Currently, the AI only knows what is in the current chat window.
    *   **Action**: Use a Vector Database (like Pinecone) to store journal entries. When chatting, retrieve relevant past journal entries so the AI "remembers" your past struggles.
3.  **Audio Response (TTS)**:
    *   Use Gemini's multimodal capabilities or a separate TTS (Text-to-Speech) API to allow the AI to speak back to the user in the `FullChatInterface`.

### Phase 4: Performance
1.  **Visualizer Optimization**:
    *   The `Visualizer.tsx` uses a lot of CPU.
    *   **Action**: If performance drops on mobile, reduce `targetCount` (particle count) or implement a WebGL version using `react-three-fiber`.
2.  **Code Splitting**:
    *   Use `React.lazy` to load `Dashboard` and `FullChatInterface` only when needed to speed up the initial Landing Page load.

---

## 💡 "The Prism" Implementation Details

The Prism feature in `Dashboard.tsx` works in three steps:

1.  **Detection**:
    *   User clicks "The Prism".
    *   `analyzeDistortions` sends text to Gemini.
    *   Gemini returns JSON array: `[{ originalText: "I always fail", type: "All-or-Nothing", reframes: [...] }]`.

2.  **Rendering**:
    *   The `renderPrismContent` function manually parses the user's raw text.
    *   It finds the index of `originalText` and wraps it in a `<span className="bg-red-100 ...">`.

3.  **Interaction**:
    *   Clicking the span sets `activeDistortion`.
    *   A card pops up showing the 3 reframes.
    *   Clicking a reframe performs a Javascript string replacement: `content.replace(original, reframe)`.

**Optimization Tip**: The current string matching is simple (`indexOf`). It might fail if the user wrote the same phrase twice. Future improvement: Use character indices returned by the AI (if supported) or a more robust fuzzy matching library.