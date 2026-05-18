# Lumina Firebase Backend Runbook

Lumina uses Firebase as the shared backend for Web, iOS, and Android. Clients should not call AI vendors directly for production text features.

## Backend Pieces

```text
Firebase Auth
  - email/password, phone, Google, Apple
  - gives each client a Firebase ID token

Cloud Firestore
  - users/{uid}/...
  - journal, therapy, garden, settings, health summaries

Cloud Functions
  - aiGateway
  - verifies Firebase ID token
  - owns prompt versions, model choice, and vendor API keys

Firebase Hosting
  - serves the Web app from dist/
```

## AI Flow

```text
Web / iOS / Android
  -> Firebase Auth current user
  -> ID token
  -> POST /aiGateway
  -> prompt registry + safety policy
  -> Gemini
  -> response to client
```

The current gateway supports:

```text
healthCheck
therapyChat
analyzeJournal
analyzeDistortions
analyzeSentiment
generateDeepInsights
```

## First-Time Setup

Install Firebase CLI if needed:

```bash
npm install -g firebase-tools
firebase login
```

Select the project:

```bash
firebase use lumia-cd3d2
```

Set the server-side AI key:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

Build and deploy:

```bash
npm run build
npm --prefix functions run build
firebase deploy --only firestore,functions,hosting
```

If the Firebase CLI is not installed globally, use the repo script:

```bash
npm run backend:deploy
```

If this fails with `Failed to authenticate`, run:

```bash
npx firebase-tools login
npm run backend:deploy
```

## Client Requirements

Every client must:

```text
1. Sign in with Firebase Auth.
2. Read/write private data under users/{uid}.
3. Call aiGateway with Authorization: Bearer <Firebase ID token>.
4. Never store Gemini/OpenAI/Claude API keys locally.
5. Never hard-code production prompts in the client.
```

## Firestore Security

Rules are in:

```text
firestore.rules
```

Current policy:

```text
users/{uid}/... is private to that uid.
aiRequests is server-only.
all other paths are denied.
```

## Release Checks

Before release:

```bash
npm --prefix functions run build
npm run build
xcodebuild -project iOS/Lumina/Lumina.xcodeproj -scheme Lumina -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

After deploy, test:

```text
1. Web email login.
2. iOS email login.
3. Therapy message returns real AI reply.
4. Journal analysis returns structured fields.
5. Firestore data appears under the signed-in user's uid.
6. Another account cannot read that user's data.
```
