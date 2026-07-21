# Salati Manual Actions Required

## Executive Summary

- Currently testable: Flutter analyzer passes, Firebase Functions TypeScript lint passes, and the web dashboard build completes into `build\web`.
- Not ready: the Flutter test suite still fails, Arabic mojibake remains in source strings, monetization setup is not proven, and several dashboard/mobile features are metadata-only or unverified.
- Revenue is blocked: Google Play/App Store setup, server credential configuration, purchase-to-plan activation, sandbox purchase proof, and paid unlock verification are still missing.
- Production is blocked: full tests do not pass, manual Firebase deployment/device QA is incomplete, exact design files are missing from this checkout, and Android/iOS release readiness is not proven.

## Already Fixed / Confirmed

- Admin login route exists at `/admin/login`.
- Web startup bootstrap skips protected config reads before admin login.
- Config repositories have fallback behavior for selected protected settings reads.
- Dashboard access model was simplified to `dashboard.view` with super admin support.
- Dashboard home, Users, Azkar, Dua, Mushaf/Quran, Hadith, Adhan, Themes, Widgets, Store, Plans, Settings, Halaqat metadata, and audit surfaces exist.
- Dashboard content create/update flows use callable Functions for major admin saves.
- User block/activate uses callable `updateDashboardUserStatus`.
- Firebase Functions lint currently passes: `npm --prefix functions run lint`.
- Flutter analyzer currently passes: `flutter analyze --no-pub`.
- Web build currently passes: `flutter build web`.
- Firestore rules and Storage rules files exist locally.
- Android widget providers, XML definitions, and Flutter method-channel bridge exist.
- Local assets exist for Quran JSON, Adhkar JSON, Dua JSON, Quran font, default adhan audio, Fajr adhan audio, and azkar audio.

## Still Missing In Code

### Failing Widget Test
- Problem: `flutter test --no-pub` fails in `test/widget_test.dart`; the test expects exactly one `الأذكار`, but the current UI renders two.
- Why it matters: production release should not proceed with a red test suite.
- Expected files: `test/widget_test.dart`, likely `lib/features/home/presentation/home_screen.dart` or navigation UI.
- Priority: P0.
- Acceptance criteria: full `flutter test --no-pub` passes with no failures.

### Arabic Mojibake
- Problem: many user-facing Arabic strings in source appear as mojibake, especially `Ø...` / `Ù...` sequences.
- Why it matters: Arabic UI quality is launch-critical for this product.
- Expected files: affected `lib/` screens, admin dashboard files, local fallback content if corrupted.
- Priority: P0.
- Acceptance criteria: Arabic, English, and French UI passes show no garbled text in critical flows.

### Dashboard Delete/Archive Functions
- Problem: content and store delete UI exists, but repository methods throw backend-not-implemented errors.
- Why it matters: admins cannot safely delete/archive mistaken content or products.
- Expected files: `functions/src/index.ts`, `lib/features/admin_dashboard/data/firestore_admin_content_repository.dart`, `lib/features/admin_dashboard/data/firestore_admin_store_repository.dart`.
- Priority: P1.
- Acceptance criteria: delete/archive works through trusted backend, writes audit logs, and respects Firestore rules.

### Purchase-To-Plan Activation
- Problem: `verifyPurchase` writes product entitlements, but plan/subscription activation mapping is not proven complete.
- Why it matters: paid subscriptions must activate the correct user plan and expire/cancel safely.
- Expected files: `functions/src/index.ts`, `lib/features/subscriptions/`, `lib/features/store/`.
- Priority: P0.
- Acceptance criteria: sandbox purchase activates the correct plan, restore works, expiry/cancellation removes access.

### Pro Trial Decision
- Problem: `grantProTrialByAds` currently returns failure: trusted backend grant is required.
- Why it matters: visible reward/pro trial UX cannot launch if it never grants access.
- Expected files: `lib/features/store/data/firestore_store_repository.dart`, Functions if implemented.
- Priority: P1.
- Acceptance criteria: Pro trial is either fully implemented server-side or hidden from launch UI.

### Hadith Mobile Screen
- Problem: dashboard and backend Hadith import exist, but no mobile Hadith route/screen was found in `AppRouter`.
- Why it matters: imported Hadith content is not user-facing.
- Expected files: `lib/app/navigation/app_router.dart`, new or existing `lib/features/hadith/`.
- Priority: P1.
- Acceptance criteria: active Hadith packs can be browsed/read in the mobile app, or Hadith is hidden from launch.

### Lessons Mobile Screen
- Problem: dashboard lesson media metadata exists, but no mobile Lessons route/screen was found.
- Why it matters: admins can create lesson metadata that users cannot consume.
- Expected files: `lib/app/navigation/app_router.dart`, new or existing lessons/media feature.
- Priority: P2.
- Acceptance criteria: active lessons are playable/openable on mobile, or Lessons is hidden from launch.

### Custom Adhan Runtime
- Problem: notification scheduler maps only known bundled raw sound keys; custom paid/remote adhan playback is not proven.
- Why it matters: paid adhan sounds cannot be sold unless selected sounds actually play in notifications.
- Expected files: `lib/features/prayer/services/prayer_notification_scheduler.dart`, `lib/core/services/local_notification_service.dart`, Android raw resources, preferences/store integration.
- Priority: P1 if monetized, P2 if hidden.
- Acceptance criteria: selected paid adhan sound fires on a real Android device at prayer time.

### Widget Entitlement Connection
- Problem: Android widgets exist and store widget products exist, but entitlement gating for each widget type is not proven end-to-end.
- Why it matters: paid widgets must not be available without entitlement, and purchased widgets must unlock reliably.
- Expected files: `lib/features/store/`, `lib/core/services/salati_widgets_service.dart`, widget-related mobile UI.
- Priority: P1.
- Acceptance criteria: locked widgets require entitlement; owned widgets add/update/refresh on real devices.

### Old Direct Firestore Points Path
- Problem: `PrayerPointsService` still contains direct Firestore point writes, and `FirestoreStoreRepository.spendPoints` supports a client transaction path for non-store spending.
- Why it matters: points must not be forgeable or abusable.
- Expected files: `lib/features/prayer/services/prayer_points_service.dart`, `lib/features/store/data/firestore_store_repository.dart`, rules/tests.
- Priority: P0.
- Acceptance criteria: all earning and paid spending paths are either server-callable based or proven safe under rules with replay/race tests.

## Manual Actions I Must Do Outside Code

### Firebase Console

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Firebase project | Confirm the selected project is `salati-cf0db` or the intended production/staging project | Firebase Console project switcher | Prevent deploying/testing against the wrong backend | P0 |
| Project separation | Decide staging vs production Firebase projects | Firebase Console | Avoid testing purchases/admin changes directly in production | P0 |
| Authentication | Enable and verify providers used by the app: anonymous, Google, phone if in scope | Firebase Console > Authentication | Mobile startup/login depends on enabled providers | P0 |
| Admin account | Create or confirm a real super admin user document with `role: superAdmin` or `super_admin` and/or `dashboard.view` | Firestore `users/{uid}` | Dashboard access depends on Firestore user role/permissions | P0 |
| Firestore rules | Deploy current `firestore.rules` | Firebase Console or Firebase CLI | Local rules do not protect production until deployed | P0 |
| Storage rules | Deploy current `storage.rules` | Firebase Console or Firebase CLI | Content/profile upload protection depends on deployed rules | P0 |
| Functions | Deploy current Functions | Firebase Console/CLI | Purchase verification, admin saves, points, and audit logs need deployed callables | P0 |
| Hosting | Deploy `build\web` if using the web dashboard | Firebase Hosting | Dashboard must be served from current web build | P0 |
| App Check | Configure web reCAPTCHA, Android Play Integrity, debug tokens, and enforcement plan | Firebase Console > App Check | App currently activates App Check, but enforcement/config is external | P1 |
| Firestore indexes | Confirm required composite indexes after dashboard/mobile queries run | Firebase Console > Firestore indexes | Queries may fail in production without indexes | P1 |
| Secret Manager | Set `BOOTSTRAP_ADMIN_SECRET` if using bootstrap admin | Google Cloud/Firebase Functions secrets | Bootstrap callable requires this secret | P0 |
| Function env vars | Set `ANDROID_PACKAGE_NAME` and Apple-related values if iOS is in scope | Google Cloud/Firebase Functions environment/secrets | Purchase verification code reads these values | P0 |
| Logs/monitoring | Review Function logs, Crashlytics, Analytics, and alerts | Firebase/Google Cloud Console | Production operations need visibility | P1 |

### Google Play Console

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Package name | Confirm Android package name matches Firebase and Function `ANDROID_PACKAGE_NAME` | Play Console + Android project/Firebase | Play purchase verification requires exact package name | P0 |
| App signing | Enable/verify Play App Signing | Google Play Console | Required for release distribution | P0 |
| Internal testing | Create internal testing track and upload a signed build when ready | Google Play Console | Required for real billing/device QA | P0 |
| Subscriptions | Create subscription product IDs matching code: `salati_premium_monthly`, `salati_premium_yearly` or update code later | Play Console > Monetize | Billing query uses those IDs | P0 |
| One-time products | Create any one-time products if you plan to sell non-subscription IAP | Play Console | Store currently uses points; IAP one-time products are not proven | P1 |
| License testers | Add tester Gmail accounts | Play Console > License testing | Sandbox purchases require testers | P0 |
| Tester accounts | Add testers to internal track | Play Console > Testing | Testers need install access | P0 |
| Developer API | Enable Google Play Developer API | Google Cloud/Play Console | Server verification uses Android Publisher API | P0 |
| Service account | Create/link service account with purchase/subscription read permissions | Google Cloud IAM + Play Console API access | Functions need credentials to verify purchase tokens | P0 |
| Verification credentials | Confirm deployed Functions can use the service account | Google Cloud/Firebase Functions | Without credentials, `verifyPurchase` fails | P0 |

### App Store Connect

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| iOS scope | Decide whether iOS is in scope for launch | Product/release planning | Current `firebase_options.dart` throws unsupported for iOS | P0 |
| Bundle ID | If iOS is in scope, create/confirm bundle ID | Apple Developer / App Store Connect | Required for Firebase iOS app and IAP | P0 |
| Firebase iOS config | If iOS is in scope, add Firebase iOS app and `GoogleService-Info.plist` | Firebase Console + iOS project | Current Firebase config is not ready for iOS | P0 |
| Subscriptions | If iOS is in scope, create matching subscription products | App Store Connect | iOS IAP needs products | P0 |
| Shared secret / API | Configure Apple shared secret or App Store Server API credentials | App Store Connect / Functions env | iOS receipt validation code expects Apple setup | P0 |
| Sandbox testers | Create sandbox tester accounts | App Store Connect | Needed for iOS purchase testing | P1 |

iOS is not launch-ready and should be out of scope for now unless you allocate a separate iOS setup/testing pass.

### Android Device Testing

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Fresh install | Install from internal test or local release build on a clean Android device | Physical Android device | Startup/onboarding/auth behavior differs from debug/web | P0 |
| Login | Test anonymous startup, Google login, phone login if enabled | Physical Android device | Auth providers must work outside emulator assumptions | P0 |
| Location permission | Grant/deny location and choose manual city | Physical Android device | Prayer times rely on location/settings | P0 |
| Prayer times | Compare times against expected city/method | Physical Android device | Core religious utility must be accurate | P0 |
| Notification permission | Grant/deny Android notification permission | Physical Android device | Notifications are retention-critical | P0 |
| Exact alarm permission | Test exact alarm permission flow | Android settings/device | Adhan timing depends on scheduling reliability | P0 |
| Adhan fires | Schedule near-time prayer reminder and wait | Physical Android device | Must prove notification fires at correct time | P0 |
| Selected sound | Test default and Fajr sounds | Physical Android device | Current scheduler supports bundled sound keys | P0 |
| Background/reboot | Reboot and verify notifications/widgets refresh | Physical Android device | Receivers and scheduling must survive device events | P1 |
| Widgets | Add every widget, update from app, refresh after time changes | Android launcher | Widget providers cannot be validated by web build | P1 |
| Points earn | Complete prayer/adhkar/dua actions and inspect points | Device + Firestore | Points economy must behave correctly | P0 |
| Points spend | Redeem store item with points | Device + Firestore | Must prove atomic spend and entitlement grant | P0 |
| Store unlock | Confirm purchased/owned state survives restart | Device | Revenue features depend on persistent unlocks | P0 |
| Quran reader | Test page, ayah, word modes and saved progress | Device | Core content feature must be stable | P0 |
| Share image | Share generated Quran image to common apps | Device | Platform share behavior needs real testing | P1 |
| Language switch | Test Arabic/English/French if exposed | Device | Mojibake/localization issues are launch blockers | P0 |
| Offline/slow network | Airplane mode and poor connection pass | Device | App uses caches/fallbacks and must degrade safely | P1 |

### Web Dashboard Manual Testing

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Direct login URL | Open `/admin/login` directly | Browser/deployed hosting | Confirms bootstrap/login route works | P0 |
| Super admin | Login as super admin | Browser | Confirms dashboard access | P0 |
| Non-admin | Login as normal user | Browser | Confirms access denial | P0 |
| Refresh | Refresh `/admin/dashboard` | Browser | Confirms session routing survives reload | P0 |
| Adhkar | Create category and item | Dashboard | Confirms callable save + rules + mobile content path | P0 |
| Dua | Create category and item | Dashboard | Same as Adhkar | P0 |
| Quran | Import Quran manifest | Dashboard + Firestore | Confirms manifest/page map flow | P1 |
| Hadith | Import Hadith JSON | Dashboard + Firestore | Confirms pack import | P1 |
| Store | Create Store item | Dashboard + mobile app | Required for point redemption/premium unlock QA | P0 |
| Plan | Create/update Plan | Dashboard + mobile app | Subscriptions and limits depend on plan docs | P0 |
| User status | Block and activate user | Dashboard + mobile app | Confirms callable and user access behavior | P0 |
| Config | Publish app config | Dashboard + mobile app restart | Confirms remote config propagation | P1 |
| Audit logs | Check audit logs after actions | Dashboard + Firestore | Confirms traceability | P1 |

### Design / Figma / Assets

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Figma source | Add or provide the approved Figma source/exported PNGs | `docs/design/` or shared design system | Current checkout has no inspectable Figma exports | P1 |
| Dashboard match | Compare dashboard pages to approved design | Browser + Figma | Pixel/UX match is not proven by code inspection | P1 |
| Mobile Arabic UI | Review Arabic screens on device | Android device + design review | Mojibake and RTL issues must be caught visually | P0 |
| Empty/loading/error states | Approve each major state | Browser/device | Launch UX needs non-happy-path design | P1 |
| Icons/images | Prepare final app/store/product icons/images | Assets/design folder + consoles | Store/dashboard/mobile need final visuals | P1 |
| Quran page images | Decide if Quran images are needed and prepare them | Content storage or ZIP | Dashboard supports Mushaf metadata/manifest | P1 |
| Adhan audio | Prepare final licensed adhan audio files | Assets/storage/Android raw if used in notification | Monetized/custom sounds need valid files | P1 |
| Lesson media | Prepare lesson videos or YouTube links | Content source/dashboard | Dashboard metadata needs actual content | P2 |
| Hadith content | Prepare verified Hadith JSON packs | Content source/dashboard | Hadith import requires JSON | P1 |
| Adhkar/Dua content | Prepare final reviewed JSON/Firestore content | Assets/dashboard | Existing fallback content may not be final | P1 |

### Content Preparation

| Area | Manual action required | Where to do it | Why required | Priority |
|---|---|---|---|---|
| Adhkar JSON | Prepare reviewed Adhkar categories/items with Arabic/English/French if needed | `assets/data/adhkar.json` or dashboard import process | Launch content must be authentic and clean | P1 |
| Dua JSON | Prepare reviewed Dua categories/items | `assets/data/duaa.json` or dashboard | Same as Adhkar | P1 |
| Hadith packs JSON | Prepare pack JSON with IDs, titles, sources, items | Dashboard import | Mobile/admin Hadith depends on this content | P1 |
| Quran manifest | Prepare manifest with page map, URLs, page range, titles | Dashboard import | Mushaf pack import depends on it | P1 |
| Mushaf images | Prepare ZIP or remote image URL structure | Storage/CDN | Runtime image Mushaf support needs actual images if used | P1 |
| Adhan audio | Prepare final default/Fajr/custom sound files | Android raw/resources or storage | Notification playback depends on packaged/known sounds | P1 |
| Lesson videos | Prepare MP4/MOV/WebM or YouTube links | Dashboard/content source | Lesson metadata is useless without media | P2 |
| Store images | Prepare product previews | Dashboard/assets | Store products need visual confidence | P1 |
| Theme previews | Prepare palette/screenshots | Dashboard/store | Users need to preview paid themes | P1 |
| Widget previews | Prepare screenshots/previews for each widget | Dashboard/store/Play assets | Paid widgets need clear previews | P1 |
| Terms/privacy | Review final legal text | `web/`, `public/`, Play/App Store listings | Required for production and subscriptions | P0 |

## Revenue Readiness Checklist

- [ ] Google Play products created.
- [ ] Product IDs match code: `salati_premium_monthly`, `salati_premium_yearly`, or code is updated later.
- [ ] Google Play license testers configured.
- [ ] Google Play Developer API enabled.
- [ ] Service account permissions configured for purchase verification.
- [ ] `ANDROID_PACKAGE_NAME` configured for deployed Functions.
- [ ] Apple subscription/shared secret/API configured if iOS is in scope.
- [ ] Purchase token verified server-side.
- [ ] Subscription activates the correct plan, not only a raw product entitlement.
- [ ] Restore purchase works.
- [ ] Cancellation/expiry handled.
- [ ] Paid content unlocks in mobile app.
- [ ] Points cannot be forged.
- [ ] Entitlements cannot be self-written by users.
- [ ] Firebase Functions deployed.
- [ ] Firestore rules deployed.
- [ ] Manual sandbox purchase completed.

Revenue blocked.

## Production Readiness Checklist

- [ ] Tests all pass. Current status: blocked, 61 pass / 1 fails.
- [x] Web build passes.
- [x] Flutter analyzer passes.
- [x] Functions lint passes.
- [ ] Android release build tested.
- [ ] Firebase production rules/functions/hosting deployed and verified.
- [ ] Arabic mojibake fixed.
- [ ] Privacy policy and terms reviewed for production.
- [ ] Crash reporting ready and verified.
- [ ] Manual QA passed on Android device.
- [ ] App store assets ready.
- [ ] Monitoring/logs ready.
- [ ] Figma/design review completed.
- [ ] Content QA completed.

Production blocked.

## Features To Hide If Not Ready

| Feature | Hide / Keep / Keep as beta | Reason |
|---|---|---|
| Hadith | Hide | Dashboard/backend import exists, but mobile reading screen/route is missing. |
| Lessons | Hide | Dashboard metadata exists, but mobile consumption screen/route is missing. |
| Halaqat/Stream | Hide | Current implementation is metadata-only; Functions reject recording/video enabled. |
| Pro trial | Hide | Backend grant intentionally returns failure. |
| Custom paid Adhan sounds | Hide unless manually proven | Scheduler maps bundled raw sounds; paid custom runtime is not proven. |
| Paid widgets | Keep as beta only after device QA | Android widgets exist, but entitlement gating and launcher behavior need real-device proof. |
| iOS | Hide / out of scope | Firebase iOS config is unsupported in current options and iOS purchase setup is unverified. |
| AI Quran assistant | Keep as beta or rename | `QuranAiPlaceholderScreen` is a gated wrapper around Islamic chat, not a dedicated Quran AI implementation. |
| Web dashboard | Keep internal only until QA | Build passes, but manual login/content/admin checks are not complete. |
| Subscriptions | Hide until sandbox verified | IAP flow exists, but product setup and purchase-to-plan activation are not proven. |

## Exact Next Manual Steps For Me

1. Open Firebase Console and confirm the active project ID is the intended staging/production project, likely `salati-cf0db`.
2. Confirm Authentication providers are enabled: anonymous for mobile startup, Google if used, and phone if you plan to support phone login.
3. Create or verify your super admin user document in Firestore with `role: superAdmin` or `super_admin`.
4. Deploy Firestore rules, Storage rules, Functions, and Hosting to a staging project first.
5. Open the deployed `/admin/login` URL and manually test super admin login, non-admin denial, and dashboard refresh.
6. In Google Play Console, create an internal testing track for the Android package.
7. Create Google Play subscription products matching `salati_premium_monthly` and `salati_premium_yearly`, or decide new IDs before code changes.
8. Add license testers and internal test users in Google Play Console.
9. Enable Google Play Developer API and link a service account with purchase verification permissions.
10. Configure deployed Functions with `ANDROID_PACKAGE_NAME` and required Google credentials/secrets.
11. Run one Android sandbox purchase and verify the Firestore user plan/entitlements after purchase and restore.
12. On a real Android device, test adhan notification permission, exact alarm permission, selected sound playback, background, and reboot behavior.
13. Add every Android widget to the launcher and verify add/update/refresh behavior.
14. Upload or restore Figma exports/source into `docs/design/` so dashboard/mobile design can be compared.
15. Prepare final content files: Adhkar JSON, Dua JSON, Hadith packs JSON, Quran manifest, Mushaf image source, Adhan audio, lesson links/videos, store/theme/widget previews.
16. Decide launch scope: hide Hadith, Lessons, Halaqat, Pro trial, subscriptions, iOS, and custom paid Adhan unless each passes its checklist.
17. After code fixes are done, rerun `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build web`, and `npm --prefix functions run lint`.

## Final Verdict

- Current status: internally testable only. Web build and Functions lint pass, but full tests fail and launch-critical manual setup is incomplete.
- What blocks revenue: Google Play/App Store product setup, Function purchase credentials, purchase-to-plan activation, sandbox purchase proof, subscription expiry/cancellation handling, paid unlock validation, and points abuse review.
- What blocks production: failing test suite, Arabic mojibake, unverified Firebase deployment, missing/manual Android device QA, missing Figma exports, incomplete content preparation, and unreleased/metadata-only features.
- What you must do manually before giving this app to users: configure Firebase/Google Play, deploy to staging, complete dashboard/device QA, prepare final content/design assets, verify monetization with sandbox purchases, and hide any feature that is not fully implemented and tested.

