# Salati Required Work

## Critical Blockers

- Fix failing `flutter test --no-pub`: `test/widget_test.dart` expects exactly one `الأذكار`, but the current UI renders two.
- Resolve Arabic mojibake/encoding in source strings before any Arabic production release.
- Verify admin login and dashboard access manually against the deployed Firebase project.
- Confirm `firestore.rules`, `storage.rules`, and Functions are actually deployed, not only dry-run/build validated.
- Complete backend delete operations or remove delete UI affordances from dashboard.
- Validate Android notification, exact alarm, and widget behavior on real devices.
- Restore or provide inspectable project docs/Figma exports; the `docs` directory is empty in this checkout.

## Revenue Blockers

- Configure Google Play product IDs and Apple products to match the app's `salati_premium_monthly` and `salati_premium_yearly` or update the app to match store IDs.
- Configure `ANDROID_PACKAGE_NAME` and Google Play Developer API service account access for Functions.
- Configure Apple receipt validation secret/environment where required.
- Map verified purchases to user plan/subscription status, not only product entitlements.
- Verify subscription expiry/cancellation/downgrade server-side.
- Implement or remove Pro trial by rewarded ads; current backend grant returns failure.
- Prove paid content unlocks for Quran modes, themes, widgets, adhan sounds, and any premium content.
- Ensure users cannot self-award paid access or exploitable points through any client write path.

## Production Blockers

- Passing full test suite.
- Manual QA completion for web and Android critical paths.
- Release signing/versioning review.
- Firebase App Check enforcement decision and rollout.
- Production monitoring: Crashlytics, analytics, Function logs, alerting, and audit log visibility.
- Legal/policy review for subscriptions, account deletion, privacy, child safety, Islamic AI disclaimers, and ad usage.
- Content QA for Quran, Adhkar, Dua, Hadith, and translations.
- iOS readiness decision; current Firebase options throw unsupported for iOS.

## Web Dashboard Required Work

| Section | Task | Priority | Owner type | Expected files | Acceptance criteria |
|---|---|---|---|---|---|
| Login | Manual verify admin login/refresh/logout and non-admin denial | P0 | QA + Firebase engineer | Firebase console, `lib/features/auth/`, `lib/app/bootstrap/` | Super admin enters; non-admin denied; refresh does not crash. |
| Home | Replace/verify placeholder KPI values | P1 | Flutter engineer + Product | `lib/features/admin_dashboard/data/`, home screen | Metrics match Firestore or are clearly hidden when unavailable. |
| Users | Verify block/activate and permissions updates | P0 | Firebase engineer + QA | Functions, users repository/screens | Blocked user loses access where expected and audit log is created. |
| Azkar | Implement delete callable or remove delete UI | P1 | Backend engineer | `functions/src/index.ts`, content repository | Category/item delete works safely with audit log or UI no longer offers delete. |
| Dua | Implement delete callable or remove delete UI | P1 | Backend engineer | Same as Azkar | Same acceptance as Azkar. |
| Mushaf/Quran | Verify manifest import and mobile consumption | P1 | Backend + QA | Functions, Quran dashboard, mobile Quran | Imported pack appears and opens correctly in mobile. |
| Hadith | Add/verify mobile Hadith consumption | P1 | Flutter engineer | router, new/existing Hadith feature | User can browse imported active Hadith packs. |
| Adhan | Connect custom adhan assets to mobile playback if monetized | P1 | Flutter + Android engineer | Store, preferences, notification scheduler, Android raw resources | Purchased/selected sound actually plays. |
| Lessons | Build/verify mobile lessons screen or mark dashboard as admin-only metadata | P2 | Flutter engineer + Product | router, lessons feature | User can consume active lessons or feature is hidden. |
| Themes | Apply purchased theme unlocks | P1 | Flutter engineer | Store, theme/app config | Purchase unlocks and applies theme after relaunch. |
| Widgets | Verify widget store unlock behavior | P1 | Flutter + Android engineer | store, widget services/native files | Locked widgets require entitlement; owned widgets update reliably. |
| Store | Implement delete callable and remove fallback confusion | P1 | Backend + Flutter engineer | Functions, store repo/screen | Admin can archive/delete safely; empty Firestore does not imply production inventory. |
| Plans/Subscriptions | Complete plan/product mapping | P0 | Backend + mobile billing engineer | Functions, subscriptions, Firebase/Play/App Store | Sandbox purchase activates correct plan and expires correctly. |
| General Settings | Verify draft/publish production flow | P1 | Firebase engineer + QA | app customization repo/screen | Published config changes mobile behavior after relaunch. |
| Shared | Define ownership or merge with general settings | P2 | Product + Flutter engineer | dashboard routes/scaffold | Navigation is unambiguous. |
| Halaqat/Stream | Decide scope: metadata-only or real live streaming | P2 | Product + backend engineer | Functions/dashboard/mobile | UI no longer promises unsupported video/recording, or real room flow exists. |
| Audit Logs | Enable and verify production audit display | P1 | Firebase engineer | audit repository/home/audit screen | Recent admin actions appear with actor, action, target, timestamp. |

## Mobile App Required Work

| Feature | Task | Priority | Owner type | Expected files | Acceptance criteria |
|---|---|---|---|---|---|
| Auth | Manual verify anonymous, Google, phone, session persistence | P0 | QA + Firebase engineer | auth service, startup | Fresh install and returning user work without crashes. |
| Prayer times | Device QA for location/manual city/calculation method | P0 | QA | prayer screens/services | Correct times for chosen city and date. |
| Prayer points | Audit old direct Firestore increment path | P0 | Backend engineer | `prayer_points_service.dart`, rules, callers | Only trusted/validated paths can earn points. |
| Adhkar | Verify remote/fallback content and point award | P1 | QA | Adhkar feature | Completion awards once per expected event. |
| Dua | Version/cache remote content | P2 | Flutter engineer | `dua_screen.dart`, assets | First-run offline content remains stable and remote updates are controlled. |
| Quran | Validate full 604-page/ayah/word behavior | P0 | QA + Flutter engineer | Quran service/readers/assets | No missing page/ayah crashes; limits and paid locks work. |
| Hadith | Implement mobile browsing | P1 | Flutter engineer | new Hadith feature/router | Active packs appear and are readable. |
| Store | Confirm point redemption and owned state | P0 | QA + backend engineer | Store repo/screen, Functions | Points decrease atomically and entitlement appears. |
| Subscriptions | Complete sandbox IAP | P0 | Mobile billing engineer | billing, purchase verification, Functions | Purchase/restore/cancel cases are verified. |
| Notifications | Real-device permission/exact alarm/sound QA | P0 | QA + Android engineer | notification scheduler/service, Android manifest | Scheduled adhan fires reliably with selected sound. |
| Widgets | Launcher/device testing for every widget provider | P1 | Android engineer + QA | Android widgets, method channel | Widgets add, update, survive reboot/update. |
| Sharing | Verify share intent and image quality | P1 | QA | Quran share image/file | Generated image shares successfully on Android/iOS targets. |
| AI assistant | Verify external worker availability, quota, safety copy | P1 | Backend/Product/QA | Islamic AI client/screen, usage repo | Daily limit, error states, and answer flow work. |
| Language support | Repair mojibake and test Arabic/English/French | P0 | Flutter engineer + QA | source strings, localization, content | No garbled Arabic in critical screens. |
| Offline/cache | Define offline expectations and test airplane mode | P1 | QA + Flutter engineer | Quran/Adhkar/Dua/store repositories | App degrades predictably without network. |

## Backend Required Work

### Functions
- Add delete/archive callables for content categories/items and store items, with audit logs.
- Finish verified purchase-to-plan activation.
- Implement subscription expiry/cancellation refresh job or webhook/polling strategy.
- Decide and implement Pro trial trusted grant, or remove UI.
- Add tests for Functions validation and transactions.

### Firestore Rules
- Deploy and verify current rules against emulator tests or Firebase Rules Unit Testing.
- Review broad `dashboard.view` model before giving access to non-super-admins.
- Review client-allowed `quran_share_image` point spend for replay/race behavior.

### Storage
- Verify custom token claims match `isAdmin()` in Storage rules.
- Define upload paths and size/content-type requirements for Quran, Adhan, lessons, themes, widgets.

### Purchase Verification
- Configure Android/Apple credentials.
- Store transaction IDs, expiry, platform, product mapping, and plan status.
- Add replay protection and restore behavior.

### App Check
- Confirm enforcement settings in Firebase console.
- Test debug/release tokens for web and Android.

### Audit Logs
- Ensure every admin mutation writes one log.
- Expose logs in production dashboard and keep debug behavior intentional.

## Manual QA Checklist

- [ ] Web dashboard login
- [ ] Super admin access
- [ ] Non-admin access denial
- [ ] User management block/activate/details
- [ ] Content creation: Azkar category/item
- [ ] Content creation: Dua category/item
- [ ] Quran manifest/asset import
- [ ] Hadith pack import
- [ ] Store product create/update/redeem
- [ ] Points earn for prayer
- [ ] Points earn for Adhkar/Dua
- [ ] Points spend in store
- [ ] Subscription activation via sandbox purchase
- [ ] Subscription restore
- [ ] Subscription expiry/cancellation
- [ ] Adhan notification scheduling and sound
- [ ] Morning/evening reminder scheduling
- [ ] Home widgets add/update/refresh
- [ ] Quran reading page/ayah/word modes
- [ ] Quran share image
- [ ] AI assistant chat/quota/error handling
- [ ] Halaqat room metadata creation
- [ ] Dashboard audit log visibility
- [ ] Arabic/English/French UI pass
- [ ] Offline/slow-network behavior

## Next 7-Day Plan

Day 1: Fix the failing widget test, rerun analyze/test/build, and document the exact baseline.

Day 2: Repair mojibake in user-visible Arabic strings or centralize affected strings into a verified localization source.

Day 3: Complete/de-scope admin delete operations for content and store; add audit logs.

Day 4: Configure and test Firebase deployment path for rules/functions/hosting in a staging project.

Day 5: Complete subscription product mapping and Android purchase credential configuration.

Day 6: Run Android manual QA for auth, prayer, adhan notifications, Quran readers, store points, and widgets.

Day 7: Product review: decide whether Hadith, lessons, Halaqat, Pro trial, custom adhan, and premium widgets are launch scope or hidden.

## Next 30-Day Plan

Week 1: Stabilize tests, encoding, admin CRUD, deployment baseline, and first manual QA pass.

Week 2: Finish monetization implementation: Play/App Store products, server verification, entitlement/plan activation, restore/expiry handling, and sandbox tests.

Week 3: Complete user-facing gaps: Hadith reader, lessons if in scope, paid unlock application for themes/widgets/adhan/Quran, and offline behavior.

Week 4: Production hardening: security/rules tests, App Check enforcement, analytics/Crashlytics review, legal/policy checks, content QA, release candidate build, and final go/no-go review.

