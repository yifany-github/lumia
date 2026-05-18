# Lumia Subscription Architecture

This document defines the first production-ready shape for Lumia memberships across iOS, Android, and Web.

## Decision

Use RevenueCat as the subscription entitlement source of truth.

- iOS: App Store auto-renewable subscriptions through StoreKit and RevenueCat SDK.
- Android: Google Play Billing through RevenueCat SDK.
- Web: Stripe checkout through RevenueCat Web Billing when available.
- Firebase: stores a mirrored entitlement snapshot for fast reads, AI gating, support, and cross-client UI.

Clients must not decide premium access from local purchase receipts alone. They should read the RevenueCat SDK customer info and the Firebase entitlement snapshot. Server-side AI features must check Firebase entitlement before serving premium-only work.

## Entitlements

Initial entitlement:

```text
premium
```

Future entitlements can be added without changing the core architecture:

```text
live_plus
advanced_memory
family
```

## Products

Recommended first products:

```text
lumia_plus_monthly
lumia_plus_yearly
```

Offerings:

```text
default
  monthly -> lumia_plus_monthly
  yearly  -> lumia_plus_yearly
```

## Feature Matrix

```text
Feature                         Free              Premium
Journal entries                 Unlimited         Unlimited
Basic therapy text chat          Limited/day       Higher limit/day
Deep journal insights            Limited/manual    Daily auto + manual
Therapy journal context          Basic             Doctor-specific memory
Gemini Live voice/video          Trial/limited     Included by quota
Garden premium quests            Basic             Premium quests
Cloud sync                       Basic             Full cross-device sync
Export data                      Included          Included
```

The exact quota numbers should live in backend config, not in the app bundle.

## Firestore Mirror

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

The document is safe for clients to read. Writes should eventually be server-only through a RevenueCat webhook function, with optional admin/manual override tooling.

## RevenueCat Identity

Use Firebase Auth `uid` as RevenueCat `appUserID`.

```text
Firebase Auth uid == RevenueCat appUserID
```

This keeps iOS, Android, and Web purchases attached to the same Lumia account.

## Client Flow

1. User signs in with Firebase Auth.
2. Client configures RevenueCat with `appUserID = uid`.
3. Client fetches RevenueCat customer info.
4. Client reads `users/{uid}/entitlements/subscription`.
5. UI uses a single local `SubscriptionState`.
6. Premium-only buttons check `appState.canUse(.feature)`.

## Backend Flow

1. RevenueCat webhook receives purchase/renew/cancel/expire events.
2. Function verifies RevenueCat webhook authorization.
3. Function maps customer `app_user_id` to Firebase `uid`.
4. Function writes the Firestore entitlement snapshot.
5. `aiGateway` reads entitlement and applies quota/feature gates.

## AI Gateway Rules

The server should gate:

```text
runtimeConfig              allowed for signed-in users
healthCheck                allowed for signed-in users
therapyChat                free quota, then premium
analyzeJournal             free quota, then premium
analyzeDistortions         premium candidate
generateDeepInsights       premium candidate
Gemini Live runtime access premium or trial quota
```

The current implementation adds the entitlement lookup and feature-classification entry point. Quotas can be added next.

## Implementation Order

1. Add shared entitlement models in iOS.
2. Mirror entitlement in Firestore.
3. Add backend entitlement lookup in `aiGateway`.
4. Add RevenueCat iOS SDK and paywall.
5. Add RevenueCat webhook function.
6. Add Web checkout.
7. Add Android SDK integration.
