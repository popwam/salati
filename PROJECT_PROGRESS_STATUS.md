# Salati Project Progress Status

## Executive Summary

Salati is internally testable as a Flutter/Firebase product with a working web build, a broad mobile feature surface, Firebase callable Functions, Firestore/Storage rules, Android widgets, local Quran/Adhkar/Dua assets, and a recently rebuilt admin dashboard. It is not revenue-ready yet. The main blockers are one failing Flutter widget test, unverified manual critical flows, purchase credentials/store products not proven configured, Pro trial backend grant intentionally missing, delete operations missing for several admin content/store flows, no inspectable Figma source/docs in this checkout, and clear mojibake/encoding risk in many Arabic UI strings.

## Overall Status

| Area | Status | Completion | Notes |
|---|---|---:|---|
| Web Dashboard | Partial / internally testable | 68% | Routes, login screen, dashboard shell, users, content, store, plans, settings, Halaqat metadata, and audit surfaces exist. Delete actions for content/store throw backend-not-implemented errors. Manual browser QA is still required. |
| Mobile App | Partial / internally testable | 62% | Core prayer, Quran, Adhkar, Dua, Store, Subscriptions, AI, notifications, and Android widgets exist. Several flows rely on fallback data, platform services, or unverified native/manual behavior. |
| Firebase Functions | Partial | 70% | Callable functions exist for admin saves, points awards, purchase verification, user status, audit logs, and point redemption. Purchase verification still has TODO credential setup and Pro trial grant is not implemented. |
| Firestore Rules | Partial | 72% | Rules protect most paid/admin state and allow public active content reads. Users can still spend limited client-side points for `quran_share_image`; deployment was previously dry-run only per `comment.md`. |
| Monetization | Not revenue-ready | 38% | Store and IAP scaffolding exist, but Google/Apple product setup and credentials are unproven, subscription entitlement mapping is incomplete, and Pro trial grant is intentionally blocked. |
| Design | Partial | 55% | Dashboard was rebuilt toward exported Figma direction in prior work, but `docs` is empty in this checkout and exact Figma sources/exports are not inspectable. Mobile design has usable screens but not proven against a design spec. |
| Production Readiness | Not ready | 45% | Analyze and web build pass. Tests fail 61/62. Manual QA, deployment verification, encoding cleanup, app store setup, security review, and production monitoring remain. |

## Web Dashboard Status

### Login
- Implemented: `/admin/login` route, Firebase Auth integration, bootstrap bypass for protected config reads before login.
- Partial: access depends on `users/{uid}` role/permissions and dashboard session cache.
- Missing: manual login/logout/browser refresh verification in production project.
- Risk: Arabic copy in source appears mojibake in multiple files.
- Manual test needed: sign in as non-admin, admin, and super admin; refresh `/admin/login` and `/admin/dashboard`.

### Home
- Implemented: KPI cards, user/status table, dashboard summary reads from `users`, recent audit section.
- Partial: audit log repository returns empty in debug mode.
- Missing: verified revenue metrics and real analytics/channel data.
- Risk: home can look complete while some metrics are placeholders/derived from sparse data.
- Manual test needed: confirm real counts, empty states, audit log visibility in production mode.

### Users
- Implemented: user list, search/filter UI, details modal, block/activate callable.
- Partial: some admin user/profile updates use client-side Firestore/audit helpers.
- Missing: end-to-end verification against deployed rules/functions.
- Risk: broad `dashboard.view` grants all dashboard sections once inside dashboard.
- Manual test needed: block/activate user and verify mobile access impact.

### Azkar
- Implemented: dashboard category/item grid backed by Firestore streams and callable saves.
- Partial: create/update active state exists.
- Missing: delete backend function; delete UI calls repository method that throws.
- Risk: content admins can create but not truly delete without backend work.
- Manual test needed: create category, create item, toggle active, confirm mobile reads active content.

### Dua
- Implemented: same broad structure as Azkar with Firestore/callable saves.
- Partial: mobile Dua uses remote content with local fallback.
- Missing: delete backend function.
- Risk: remote sync is basic and has TODO for versioned local cache.
- Manual test needed: create category/item and verify mobile localized display.

### Mushaf/Quran
- Implemented: dashboard metadata and manifest save callables, page map import, mobile Quran readers, local asset + network/cache fallback, share image generation.
- Partial: dashboard asset import is metadata/page-map oriented; runtime support status is `metadata_ready`.
- Missing: full production content import pipeline and manual validation of every reader mode with paid locks.
- Risk: Quran asset completeness and remote fallback behavior may vary offline.
- Manual test needed: page reader, ayah reader, word reader, share image, paid lock/unlock.

### Hadith
- Implemented: dashboard pack import callable and Firestore rules for active pack/items.
- Partial: dashboard pack metadata/import exists.
- Missing: mobile Hadith screen/route was not found in router.
- Risk: backend/dashboard can store Hadith, but user-facing consumption appears missing.
- Manual test needed: import pack, inspect Firestore, confirm whether app has a Hadith entry point.

### Adhan
- Implemented: dashboard adhan sound metadata save, local notification scheduling with raw sound keys, bundled default/Fajr adhan audio.
- Partial: dashboard supports metadata for adhan assets; mobile scheduler maps only known raw sounds.
- Missing: verified custom remote audio usage in notifications.
- Risk: paid adhan sounds may appear in store but not play as notification sounds unless packaged as raw resources.
- Manual test needed: Android notification permission, exact alarm permission, Fajr/default sound playback.

### Lessons
- Implemented: dashboard lesson media metadata save.
- Partial: supports video/audio metadata in Functions; recent notes say UI was video-focused.
- Missing: mobile lessons/media screen not found in router.
- Risk: admin can create metadata that users cannot consume.
- Manual test needed: save lesson and confirm any mobile surface exists.

### Themes
- Implemented: dashboard theme/store item management and mobile store preview for theme palettes.
- Partial: products can be purchased with points as entitlements.
- Missing: verified runtime theme application after purchase.
- Risk: monetized theme product may unlock metadata only.
- Manual test needed: buy theme with points, restart app, confirm applied/available.

### Widgets
- Implemented: dashboard widget store items; Android widget providers and Flutter method-channel service exist.
- Partial: widgets are Android-only and need manual launcher testing.
- Missing: iOS widgets.
- Risk: store unlock and widget availability are not proven connected for all widget types.
- Manual test needed: add each Android widget, update from app, reboot/refresh.

### Store
- Implemented: dashboard store item create/update/seed, mobile store reads active items, point redemption callable, entitlement write.
- Partial: delete action throws backend-not-implemented error.
- Missing: full paid currency/IAP product mapping.
- Risk: fallback default store items make the store look populated even when Firestore is empty.
- Manual test needed: create item, redeem with points, verify ledger and entitlement.

### Plans/Subscriptions
- Implemented: dashboard plan defaults/update callable; mobile subscription screen; IAP product query/purchase/restore stream; server verification callable.
- Partial: default product IDs are hardcoded; real store setup unverified.
- Missing: product IDs/plan IDs/entitlements mapping and credentials confirmation.
- Risk: subscriptions can show "Needs setup" and verification can fail due missing environment config.
- Manual test needed: sandbox purchase, restore, entitlement refresh, expiry.

### General Settings
- Implemented: remote app config draft/publish callables and dashboard editor.
- Partial: settings are mixed between `settings/app_config` and `remote_app_config`.
- Missing: production publish workflow verification.
- Risk: public reads are allowed for config; sensitive fields must stay out of config docs.
- Manual test needed: edit draft, publish, relaunch mobile app.

### Shared
- Implemented: routes to app customization editor.
- Partial: not a distinct content domain.
- Missing: clear product definition for what "Shared" owns.
- Risk: duplicate navigation to general settings creates product ambiguity.
- Manual test needed: verify expected shared settings behavior.

### Halaqat/Stream
- Implemented: dashboard room metadata save and list.
- Partial: functions reject recording/video enabled; metadata only.
- Missing: live room creation/join/streaming implementation.
- Risk: not a real streaming product yet.
- Manual test needed: create scheduled room metadata and verify no false promise of live streaming.

### Audit Logs
- Implemented: Functions write audit logs for many admin actions; callable list exists.
- Partial: dashboard repository returns empty logs in debug mode.
- Missing: full audit page workflow and production read verification.
- Risk: direct client-side admin repositories may not log consistently with callable writes.
- Manual test needed: perform admin action, confirm audit log row.

## Mobile App Status

- Auth: Implemented with Firebase Auth, anonymous mobile startup, Google/phone support paths. Needs manual verification on Android/iOS/web; iOS Firebase options are unsupported in current `firebase_options.dart`.
- Prayer times: Implemented with `adhan_dart`, location services, saved settings, local calculation, and tests for core calculation.
- Prayer points: Server callable `awardPoints` exists and client payload tests pass; old `PrayerPointsService` can still increment Firestore directly and should be reviewed.
- Adhkar: Implemented with local asset fallback, Firestore active content loader, progress, completion points.
- Dua: Implemented with local asset fallback, Firestore active content loader, completion points; remote cache versioning TODO remains.
- Quran: Implemented readers, progress sync/cache, session limits, share image, local quran asset, network fallback. Full content completeness/manual paid flow unverified.
- Hadith: Backend/dashboard exists, but mobile route/screen was not found.
- Store: Implemented points store, active item loading, point redemption callable, fallback defaults. Pro trial grant is blocked.
- Subscriptions: IAP scaffolding exists but product setup, credentials, entitlement mapping, sandbox/manual validation are missing.
- Purchase verification: Callable exists for Android/iOS but Android package env/service account and Apple shared secret are TODO/unverified.
- Points spending: Store redemption is server-side. `quran_share_image` spending is permitted through Firestore rules with transaction checks. Needs abuse/race review.
- Notifications: Local notification service and scheduler exist; web returns false. Android exact alarm and sound behavior need real device tests.
- Adhan audio: Bundled audio exists; notification raw sound mapping supports known raw names only. Custom downloaded audio is not proven.
- Home widgets: Android native widgets and method channels exist. Web/iOS unsupported. Needs device/manual QA.
- Sharing images/widgets: Quran share image implemented and tested at helper level; widget visual share flows need manual QA.
- Background tasks: Notification scheduling and midnight widget refresh receiver exist. No broad background sync worker found.
- AI assistant: Islamic chat screen/client exists against external worker URL; quota repository exists. Quran AI route is a gated wrapper/placeholder that opens IslamicChat for Plus.
- Language support: Arabic/English/French content fields and fallback helper exist. Many source strings display mojibake, so localization quality is not launch-ready.
- Offline/cache behavior: Quran uses Hive and bundled asset/network cache; Adhkar/Dua use local JSON fallback. Store/plans/admin content rely on Firestore/fallbacks.

## Backend And Firebase Status

- Callable Functions: Implemented for admin save flows, plans, app config publish, Quran manifest, Hadith import, Halaqat metadata, users, audit list, purchase verification, point award, and point redemption.
- Purchase verification: Real implementation structure exists, but Android and Apple credential TODOs remain. Not production proven.
- Points award/spend: `awardPoints` server transaction exists. Store point redemption is server transaction. One client Firestore spend path remains for Quran share images.
- Admin content functions: Create/update/import exist. Delete functions are missing for categories/items/store items.
- User status functions: `updateDashboardUserStatus` exists.
- Firestore rules: Protect admin writes to superAdmin, public active content reads, owner-only user data, entitlements locked from client writes. Normal users cannot give themselves paid entitlements.
- Storage rules: Present for user profile images and public content images/audio. Admin detection relies on custom auth token claims, not Firestore role lookup.
- App Check: Activated in app bootstrap; enforcement status in Firebase console is not inspectable here.
- Security risks: broad `dashboard.view` access model, delete gaps, direct client admin repositories in some places, external AI backend trust boundary, missing purchase credentials, and possible stale deployed rules/functions.

## Revenue Readiness

- Can this app make money now? Not revenue-ready yet.
- If not, why? Critical payment, entitlement, product, and manual QA proof is missing. Tests currently fail. Store products may fall back to defaults. Subscription products and platform credentials are not verified.
- What must be finished before charging users? Fix failing test, configure store products, configure Android/Apple verification credentials, map purchases to user plan/entitlements, verify paid unlocks, remove/complete Pro trial grant placeholder, finish delete/admin workflows, deploy rules/functions/hosting, and complete manual QA.
- Which monetization paths are ready? Server-side points redemption for active store items is structurally implemented. IAP purchase flow and verification are structurally implemented but not operationally proven.
- Which are only metadata/placeholders? Halaqat streaming, lessons user-facing consumption, Hadith user-facing consumption, custom Adhan notification audio, Pro trial grant, and some store/theme/widget unlock effects are metadata or unverified.

## Final Verdict

Internally testable only.

Not revenue-ready yet.

