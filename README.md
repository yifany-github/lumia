# Lumina - AI Mental Health Sanctuary

Lumina is an AI-powered emotional support application designed to provide a safe, judgment-free space for users to explore their thoughts and feelings. It combines empathetic AI companions, intelligent journaling, and immersive visual relaxation techniques.

## 🌟 Key Features

### 1. Empathetic AI Companions
*   **Diverse Personas**: Choose from therapists with different specialties (e.g., CBT, Stoicism, Mindfulness, Shadow Work).
*   **Contextual Memory**: AI adapts its tone and advice based on the selected persona.
*   **Gemini Powered**: Utilizes Google's Gemini 3 Flash model for high-speed, nuanced, and safe conversations.

### 2. Intelligent Journaling & "The Prism"
*   **AI Analysis**: Automatically generates titles, tags, mood tracking, and psychological scores (Positivity, Energy, Anxiety) for every entry.
*   **The Prism (Cognitive Reframing)**: A specialized tool that detects negative thought patterns (cognitive distortions) in your writing and offers 3 distinct reframing perspectives (Rational, Compassionate, Stoic).
*   **Voice & Image Support**: Dictate entries or upload images to create "Visual Memories".

### 3. Real-time Emotional Adaptation
*   **Live Assessment**: The chat interface tracks dynamic psychological metrics (Wellness, Clarity, Calmness, Energy) during the session.
*   **Adaptive Prompting**: These metrics are injected into the AI's context window in real-time. The AI automatically adjusts its therapeutic approach—becoming more grounding when anxiety is high or more motivating when energy is low.

### 4. Immersive Visualizer
*   **Particle System**: Transforms uploaded memories (images) into living, breathing 3D particle clouds.
*   **Audio Reactivity**: The visualizer reacts to microphone input or music, creating a meditative flow state.

### 5. Self-Care Tools
*   **Box Breathing**: Guided animation for anxiety reduction.
*   **Crisis Support**: Immediate access to safety resources.
*   **Session Export**: Download your chat transcripts to reflect on your journey offline.

## 🛠 Tech Stack

*   **Frontend**: React 18, TypeScript
*   **Styling**: Tailwind CSS
*   **AI Integration**: Google GenAI SDK (`@google/genai`)
*   **Visualization**: HTML5 Canvas (Custom Particle Engine)
*   **Charts**: Recharts
*   **Icons**: Lucide React

## 🚀 Getting Started

1.  **Install Dependencies**:
    ```bash
    npm install
    ```

2.  **Environment Setup**:
    *   The app requires a Google Gemini API Key.
    *   The app is configured to look for `process.env.API_KEY`.
    *   *Note*: In the demo environment, there is also a UI picker to input the key manually if the environment variable is missing.

3.  **Run Development Server**:
    ```bash
    npm start
    # or
    npm run dev
    ```

## 🔐 Privacy & Safety
Lumina is designed as a tool for self-reflection, not a replacement for professional medical help. All AI interactions are prompted with safety guidelines, and a dedicated Crisis Support module is available globally.