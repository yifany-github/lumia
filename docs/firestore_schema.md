# Lumia Firestore Schema

This is the shared database contract for Web, iOS, and Android. Firestore does not require pre-created tables. Collections and documents are created automatically when a client writes to these paths.

## Root Collections

```text
users/{uid}
```

All private user data must live under the authenticated user's `users/{uid}` document. Do not store journal, therapy, garden, check-in, or health data in public root collections.

## User Profile

Path:

```text
users/{uid}
```

Fields:

```text
displayName: string
email: string | null
phoneNumber: string | null
photoURL: string | null
providerIds: string[]
createdAt: timestamp
updatedAt: timestamp
```

## Settings

Path:

```text
users/{uid}/settings/app
```

Fields:

```text
theme: "system" | "light" | "dark"
largeText: boolean
hapticsEnabled: boolean
privacyLockEnabled: boolean
notificationsEnabled: boolean
updatedAt: timestamp
```

## Subscription Entitlement

Path:

```text
users/{uid}/entitlements/subscription
```

Fields:

```text
tier: "free" | "premium"
status: "unknown" | "active" | "trialing" | "grace_period" | "expired" | "cancelled" | "billing_issue"
provider: "none" | "revenuecat" | "manual"
revenueCatAppUserID: string | null
productID: string | null
entitlementID: "premium" | null
currentPeriodEnd: timestamp | null
willRenew: boolean
updatedAt: timestamp
```

## Journal Entries

Path:

```text
users/{uid}/journalEntries/{entryId}
```

Fields:

```text
title: string
body: string
mood: "happy" | "calm" | "anxious" | "sad" | "neutral"
tags: string[]
aiReflection: string | null
createdAt: timestamp
updatedAt: timestamp
deletedAt: timestamp | null
```

## Therapy Sessions

Path:

```text
users/{uid}/chatSessions/{sessionId}
```

Fields:

```text
therapistId: string
title: string
summary: string | null
status: "active" | "closed"
createdAt: timestamp
updatedAt: timestamp
closedAt: timestamp | null
```

Messages:

```text
users/{uid}/chatSessions/{sessionId}/messages/{messageId}
```

Fields:

```text
role: "user" | "assistant" | "system"
content: string
createdAt: timestamp
```

## Check-Ins

Path:

```text
users/{uid}/checkIns/{checkInId}
```

Fields:

```text
mood: string
stress: number
energy: number | null
note: string | null
createdAt: timestamp
```

## Garden

State path:

```text
users/{uid}/garden/state
```

Fields:

```text
dew: number
growth: number
lastTendedAt: timestamp | null
updatedAt: timestamp
```

Habit path:

```text
users/{uid}/gardenHabits/{habitId}
```

Fields:

```text
title: string
kind: "reflection" | "movement" | "breathing" | "rest" | "custom"
stage: "seed" | "sprout" | "bloom" | "rooted"
progress: number
createdAt: timestamp
updatedAt: timestamp
```

## Health Summaries

Path:

```text
users/{uid}/healthSummaries/{yyyyMMdd}
```

Fields:

```text
date: string
steps: number | null
sleepMinutes: number | null
mindfulMinutes: number | null
heartRateResting: number | null
source: "apple_health" | "google_fit" | "manual"
updatedAt: timestamp
```

## Security Rule Shape

The first production rule should keep all user-owned documents private:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;

      match /{document=**} {
        allow read, write: if request.auth != null
          && request.auth.uid == userId;
      }
    }
  }
}
```

## Notes

- Real document IDs should use Firebase Auth `uid`, not `test_user_001`.
- AI calls should go through Cloud Functions, not directly from clients.
- `deletedAt` supports soft delete and future account recovery/export flows.
