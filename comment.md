# Admin Login Bootstrap Config Fix

## Root Cause

The web startup coordinator loaded optional cloud settings before checking whether an admin user was signed in. When `/admin/login` opened with no user, startup tried to read protected Firestore documents such as:

- `settings/app_config`
- `settings/auth_config`
- `settings/prayer_provider`
- `settings/content_config`

Because the user was not signed in, Firestore returned `permission-denied`, bootstrap treated it as fatal, and the app showed startup failure before the admin login route could render.

## Files Changed

- `lib/app/bootstrap/startup_coordinator.dart`
- `lib/features/admin/data/firestore_app_config_repository.dart`
- `lib/core/utils/app_error_mapper.dart`
- `lib/app/bootstrap/firebase_bootstrap.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- `firestore.rules`
- Android/Kotlin/XML/widget files
- dashboard visual design

## Fallback Behavior

- On web, if there is no signed-in user, startup now clears the cached dashboard session and returns before reading protected config documents.
- `settings/app_config`, `settings/auth_config`, `settings/prayer_provider`, and `settings/content_config` reads now fall back to local `OperationalConfig.defaults()` data on:
  - `permission-denied`
  - `unavailable`
  - `deadline-exceeded`
  - `aborted`
  - `failed-precondition`
- Live config listeners also emit default config on those failures and report the friendly message:

```text
تعذر تحميل إعدادات السحابة مؤقتًا، سيتم استخدام الإعدادات الافتراضية.
```

- Optional config read failures are logged in debug through the existing Firestore debug logger.
- `/admin/login` no longer depends on reading `users/{uid}` or protected cloud config before rendering.
- Dashboard access still reads `users/{uid}` only after Firebase Auth has a signed-in user.

## App Check

App Check activation remains enabled for production. Activation failures are caught and logged only in debug mode, so debug web App Check issues cannot block `/admin/login`.

## Commands Run And Results

```powershell
dart format lib\app\bootstrap\startup_coordinator.dart lib\features\admin\data\firestore_app_config_repository.dart lib\core\utils\app_error_mapper.dart lib\app\bootstrap\firebase_bootstrap.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.

## Dashboard File Intake Modal Update

Implemented the next dashboard pass for real Firestore-backed admin data entry:

- Rebuilt Quran/Mushaf and Adhan add dialogs with the Figma-style language tabs, display-name field, points, subscription, file/link fields, active state, and supported-format notes.
- Added supported-format guidance for Quran manifests/images/ZIP/base URLs/fonts and Adhan audio/raw-resource/metadata inputs.
- Removed the accidental lesson action from the Adhan add tile.
- Updated lesson entry to be video-only in the dashboard UI and allow titles in Arabic, English, or French.
- Updated store/theme/widget entry to allow display names in Arabic, English, or French and show supported-format notes for themes and widgets.
- Updated `validateLessonMediaPayload` so lesson media can be saved when any one of `titleAr`, `titleEn`, or `titleFr` is present.
- Removed fallback/static dashboard cards from Hadith, Themes, Widgets, and Halaqat grids so empty Firestore collections now show only the add tile.
- Routed dashboard settings entries directly to the app customization editor and removed the extra shared-settings destination from the icon rail.
- Reworked the primary file add modal to match the provided Figma shape more closely: language tabs, display name, icon selector, points, subscription, file field, and Next action.

Validation:

```powershell
dart format lib\features\admin_dashboard\presentation\admin_dashboard_figma_screen.dart
npm --prefix functions run lint
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `flutter analyze --no-pub`: passed.
- `npm --prefix functions run lint`: passed.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Note: `dart format functions\src\index.ts` was attempted accidentally and failed because Dart format does not parse TypeScript; TypeScript validation passed through `npm --prefix functions run lint`.

# Public App Reads / Dashboard Modal Fix

## Root Cause

- Firestore rules required `signedIn()` for public app reads such as `settings/app_config`, `remote_app_config/published`, active Store items, plans, Adhkar, Dua, Quran assets, Adhan sounds, Hadith packs, and lessons.
- This blocked non-registered users from entering/using public app areas.
- Dashboard content pages also read the `languages` collection, but that collection had no explicit rule, causing Adhkar/Dua language permission errors.
- The dashboard content screen tried to seed default languages from Flutter before loading content, adding another permission failure path.
- Shared/general settings pages were acting like navigation tiles to another editor instead of opening an in-place dashboard modal.

## Firestore Rule Behavior

Changed `firestore.rules` so:

- Public app config reads are allowed without sign-in:
  - `settings/app_config`
  - `settings/auth_config`
  - `settings/prayer_provider`
  - `remote_app_config/published`
- Public catalog/content reads are allowed only when the document is active:
  - `isActive == true`
  - or `active == true`
- Dashboard admins can still read dashboard data.
- `languages/{languageId}` can be read by dashboard admins.
- `languages/{languageId}` writes remain Super Admin only.
- User documents, audit logs, draft config, and admin-only data remain protected.
- Writes remain restricted to Super Admin or existing safe owner paths.

## Dashboard Content Behavior

- Adhkar and Dua pages no longer try to seed default languages from Flutter before rendering.
- If `languages` is empty or unavailable, the content form still falls back to:
  - Arabic
  - English
  - French
- Dua item entry now matches Adhkar entry:
  - text in Arabic, English, and French
  - benefit/source field
  - repeat count
  - no separate item title requirement

## Dashboard Modal Behavior

- Quran/Mushaf and Adhan add buttons open the existing dashboard modal.
- The asset modal now accepts title fields only:
  - Arabic
  - English
  - French
- Description fields were removed from the asset modal payload/UI.
- Shared/general settings pages now open an in-page settings draft modal and save through `saveAppConfigDraft`.
- The settings pages are no longer just transfer/navigation tiles.

## Files Changed

- `firestore.rules`
- `lib/app/navigation/app_router.dart`
- `lib/features/admin_dashboard/presentation/admin_content_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- Android/Kotlin/XML/widget files
- Firebase Functions source

## Commands Run And Results

```powershell
dart format lib\app\navigation\app_router.dart lib\features\admin_dashboard\presentation\admin_content_management_screen.dart lib\features\admin_dashboard\presentation\admin_dashboard_figma_screen.dart
firebase deploy --only firestore:rules --dry-run
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- `firebase deploy --only firestore:rules --dry-run`: passed; rules compiled successfully, no deploy.
- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: passed, 62 tests.
- First `flutter build web`: timed out in the command runner before Flutter returned a failure.
- Final `flutter build web`: passed.
- Web output: `build\web`.

# Dashboard Adhkar / Dua Real Data Card UI

## What Changed

- Rebuilt the Adhkar and Dua dashboard management screens into the new Figma-style card grid.
- Category cards now come from Firestore through the existing repository streams:
  - `content/adhkar/categories`
  - `content/dua/categories`
- Item chips under the selected category also come from Firestore through:
  - `content/adhkar/categories/{categoryId}/items`
  - `content/dua/categories/{categoryId}/items`
- Removed the old split-pane layout from the active render path.
- Kept the old panes in the file as fallback-only unused elements.

## New Page Behavior

- The page shows real category cards, not placeholder screenshots.
- The final card is the add card.
- Selecting a category shows its real items below the category grid.
- Item chips show:
  - delete action
  - display text
  - repeat count
  - active/inactive toggle
- Existing save/edit flows still use callable Functions through `FirestoreAdminContentRepository`.
- Quran/Mushaf and Adhan grid pages no longer show hardcoded default cards when Firestore is empty.
- Quran/Mushaf and Adhan pages now show only real Firestore documents plus the add card.

## New Modal Behavior

Category modal:

- Language tabs for Arabic, English, and French.
- Display name field.
- Icon selector.
- Points/order field.
- Subscription selector.
- Active toggle.

Adhkar/Dua item modal:

- Language tabs for Arabic, English, and French.
- Text/name field for the selected language.
- Benefit field:
  - `فضل الذكر`
  - `فضل الدعاء`
- Repeat count field.
- Active toggle.

Quran/Mushaf and Adhan asset modal:

- Language tabs for Arabic, English, and French.
- Only the selected language title field is shown at a time.
- The modal no longer requires the Arabic title specifically; any one title language is enough.
- Existing asset technical fields still save through the callable Functions.

## Files Changed

- `lib/features/admin_dashboard/presentation/admin_content_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- Firestore rules
- Android/Kotlin/XML/widget files
- Firebase Functions source

## Commands Run And Results

```powershell
dart format lib\features\admin_dashboard\presentation\admin_content_management_screen.dart
dart format lib\features\admin_dashboard\presentation\admin_dashboard_figma_screen.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- First `flutter analyze --no-pub`: found one style issue after the modal title rewrite.
- Final `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.

# Firestore Super Admin Dashboard Access Fix

## Root Cause

The dashboard home summary and Users page both need to read the `users` collection. Firestore rules previously allowed reading only the signed-in user's own document:

```text
match /users/{userId} allow read: if isOwner(userId)
```

That meant dashboard pages could load, but user counts and user rows could fail or fall back to empty/zero depending on the screen.

## Rules Behavior

Added a strict `superAdmin()` helper that recognizes:

```text
superAdmin
super_admin
```

Updated Firestore rules so:

- Dashboard admins can read user documents for dashboard lists and summaries.
- Super Admin can create/update/delete protected dashboard data directly from rules if needed.
- Normal users still only manage their own safe profile/sync/settings data.
- Non-Super Admin dashboard users do not get broad Firestore writes from rules.

Protected dashboard collections now allow writes only for Super Admin at the rules layer. Callable Functions/Admin SDK remain the normal safe write path.

## Pages Fixed

The main dashboard can now read the same user data as the Users page, so:

- total users,
- subscribed users,
- blocked users,
- active users,
- user status rows

can come from the same `users` collection access path.

The Figma dashboard pages that read dashboard collections can also open for dashboard admins because read access remains available through `dashboardAdmin()`.

## Files Changed

- `firestore.rules`
- `comment.md`

No changes were made to:

- `ai.js`
- Android/Kotlin/XML/widget files
- `functions/src/index.ts`

## Commands Run And Results

```powershell
firebase deploy --only firestore:rules --dry-run
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `firebase deploy --only firestore:rules --dry-run`: passed; rules compiled successfully, no deploy.
- `flutter analyze --no-pub`: passed.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.

## Deployment Note

The rules change was verified with dry-run only. It still needs real deployment:

```powershell
firebase deploy --only firestore:rules
```

# Dashboard Remaining Figma Pages Rebuild

## What Changed

Reworked the remaining visible dashboard pages to follow the exported Figma direction more closely:

- Mushaf/Quran assets now use large square cards and a large `+` card, matching the Mushaf screenshot direction.
- Hadith packs now use the same large-card layout with Bukhari/Muslim/Tirmidhi style defaults and JSON import through the `+` card.
- Adhan sounds now use large cards and keep callable-backed save behavior.
- Theme page now uses large theme preview cards for Dark, Light, and Safe eye, with saved theme colors shown when available.
- Widget page now uses large widget cards instead of the generic product layout.
- Shared and General Settings now use Figma-style setting tiles with a dedicated editor tile.
- Stream/Halaqat now uses poster-style cards matching the richer card layout from the Stream export, while keeping metadata-only room creation.

## Functional Behavior

The visual rebuild did not change the backend architecture:

- Saves still go through callable Functions/Admin SDK.
- Quran assets still use `saveQuranAsset`; manifest import remains available.
- Hadith import still uses `importHadithPack`.
- Adhan sound metadata still uses `saveAdhanSound`.
- Theme and Widget products still use `saveStoreItem`.
- Halaqat room metadata still uses `saveHalaqaRoomMetadata`.

## Files Changed

- `lib/features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- `firestore.rules`
- Android/Kotlin/XML/widget files
- `functions/src/index.ts`

## Commands Run And Results

```powershell
dart format lib\features\admin_dashboard\presentation\admin_dashboard_figma_screen.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- First `flutter analyze --no-pub`: timed out before returning a result.
- Second `flutter analyze --no-pub`: found missing constructor parameters and legacy unused-widget warnings after swapping the page bodies.
- Final `flutter analyze --no-pub`: passed.
- `flutter test --no-pub`: passed, 62 tests.
- First `flutter build web`: timed out before returning a result.
- Final `flutter build web`: passed.
- Web output: `build\web`.

# Dashboard Users and Content Entry Fix

## What Changed

Fixed the dashboard data visibility and user-status workflow:

- Dashboard summary now reads `users` instead of returning fixed zero values.
- Home users/status card now shows real user rows with name/UID, last login/update, and active/blocked status.
- Users page table now includes direct buttons for:
  - block user,
  - activate user,
  - open user details modal.
- User details modal shows UID, name, email, phone, plan, role, points, status, last login, updated date, created date, permissions, and AI limit.
- User block/activate action now uses a callable Function/Admin SDK:
  - `updateDashboardUserStatus`
- Direct Flutter admin writes were not restored.

## Adhkar / Dua Entry

Simplified the existing Adhkar and Dua entry modals:

- Category modal focuses on category name with language switch.
- Item modal focuses on:
  - Arabic text,
  - English text,
  - French text,
  - virtue/fadl text,
  - repeat count.
- The same simplified entry behavior applies to both Adhkar and Dua pages.

## Permission Behavior

Dashboard access remains based on the single dashboard-entry permission:

```text
dashboard.view
```

Super Admin remains the strongest role and bypasses section-level permissions through either:

```text
superAdmin
super_admin
```

No page-level permission such as `users.manage`, `content.manage`, or `store.manage` is required for Super Admin.

## Files Changed

- `functions/src/index.ts`
- `lib/features/admin_dashboard/data/firestore_admin_dashboard_summary_repository.dart`
- `lib/features/admin_dashboard/data/firestore_admin_users_repository.dart`
- `lib/features/admin_dashboard/models/admin_user_summary.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_home_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_users_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_content_management_screen.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- `firestore.rules`
- Android/Kotlin/XML/widget files

## Commands Run And Results

```powershell
dart format lib\features\admin_dashboard\data\firestore_admin_dashboard_summary_repository.dart lib\features\admin_dashboard\data\firestore_admin_users_repository.dart lib\features\admin_dashboard\models\admin_user_summary.dart lib\features\admin_dashboard\presentation\admin_dashboard_home_screen.dart lib\features\admin_dashboard\presentation\admin_users_management_screen.dart lib\features\admin_dashboard\presentation\admin_content_management_screen.dart
npm --prefix functions run lint
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- `npm --prefix functions run lint`: passed.
- First `flutter analyze --no-pub`: found one style info issue.
- Final `flutter analyze --no-pub`: passed.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.

# Dashboard Home 7-Card Layout Follow-up

## Root Cause

The sidebar still needed to be constrained to the requested dashboard set, and the home screen content was still too generic. It showed summary, audit, maintenance, and page cards instead of the requested KPI layout based on the dashboard mockups.

## Sidebar Behavior

The visible sidebar destinations remain limited to 12 dashboard pages:

- Home
- Azkar
- Dua
- Mushaf
- Hadith
- Adhan
- Themes
- Widgets
- Shared
- General Settings
- Users
- Stream / Halaqat

Older router constants can remain for compatibility, but they are not shown as sidebar icons.

## Home Page Layout

Rebuilt the dashboard home body into the requested 7-card structure:

- Total revenue card.
- Subscribed users card.
- Users breakdown card with total, banned, and active-now counts.
- Total channels card.
- Available tokens card.
- Large user-interaction chart card.
- Full-width users/status table card.

The layout is responsive for web: desktop uses the Figma-style grid, and narrower widths stack the cards without overflow.

## Permission Behavior

Dashboard access is now based on a single dashboard-entry permission:

```text
dashboard.view
```

Super Admin still bypasses all dashboard restrictions through either:

```text
superAdmin
super_admin
```

Normal admin/editor users no longer need section permissions like `content.manage`, `store.manage`, `plans.manage`, `app_config.manage`, `halaqat.manage`, or `users.manage` to use the dashboard once they have dashboard entry access.

## Files Changed

- `functions/src/index.ts`
- `lib/features/auth/presentation/admin_login_screen.dart`
- `lib/features/admin_dashboard/models/admin_dashboard_access.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_home_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_scaffold.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_ui.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_permissions_management_screen.dart`
- `test/admin_dashboard_access_test.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- `firestore.rules`
- Android/Kotlin/XML/widget files

## Commands Run And Results

```powershell
dart format lib\features\admin_dashboard\presentation\admin_dashboard_home_screen.dart lib\features\admin_dashboard\presentation\admin_dashboard_scaffold.dart lib\features\admin_dashboard\models\admin_dashboard_access.dart test\admin_dashboard_access_test.dart
npm --prefix functions run lint
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- `npm --prefix functions run lint`: passed.
- `flutter analyze --no-pub`: passed.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.

# Dashboard Modern Rebuild And Single Access Permission

## Summary

Updated the admin dashboard shell toward the exported Figma dashboard direction and simplified dashboard authorization to a single access permission.

Used visual references from:

- `docs/design/dashboard_figma_exports/dashboard_home_desktop.png`
- `docs/design/dashboard_figma_exports/dashboard_azkar_desktop.png`
- Other exported dashboard PNGs in `docs/design/dashboard_figma_exports/`

The large `.fig` source file was not parsed directly; the already-exported PNGs were used as the practical visual reference.

## Permission Behavior

Dashboard access is now based on one entry permission:

```text
dashboard.view
```

After a user is allowed into the dashboard, the Flutter dashboard treats that user as able to open all dashboard sections and use dashboard actions.

Supported admin entry conditions:

- `role == "superAdmin"`
- `role == "super_admin"`
- `role == "admin"`
- `permissions` contains `dashboard.view`

Legacy section permission constants remain in code only for compatibility with older data/tests, but they are no longer used as dashboard gates.

## Backend Callable Behavior

`requireAdminContext` in `functions/src/index.ts` now allows admin callable access when the user has dashboard entry access.

Callable Functions now pass `dashboard.view` as the required permission marker instead of section-specific permissions such as:

- `content.manage`
- `store.manage`
- `plans.manage`
- `app_config.manage`
- `halaqat.manage`

`bootstrapFirstAdmin` now writes only:

```json
["dashboard.view"]
```

## Dashboard UI Changes

Updated desktop dashboard shell:

- Replaced the wide text sidebar with a compact icon rail similar to the exported Figma screens.
- Added tooltip navigation for icon-only destinations.
- Kept the text drawer for smaller/mobile widths.
- Updated the main content panel with cleaner white surface, softer border, and lighter shadow.
- Updated dashboard header cards and preview cards with larger blue icon treatment, cleaner spacing, and more modern card styling.

No direct Firestore admin writes were added.

## Files Changed

- `functions/src/index.ts`
- `lib/app/navigation/app_router.dart`
- `lib/features/auth/presentation/admin_login_screen.dart`
- `lib/features/admin_dashboard/models/admin_dashboard_access.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_scaffold.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_dashboard_ui.dart`
- `lib/features/admin_dashboard/presentation/admin_permissions_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_users_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_store_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_subscriptions_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_languages_management_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_app_customization_screen.dart`
- `lib/features/admin_dashboard/presentation/admin_ai_usage_management_screen.dart`
- `test/admin_dashboard_access_test.dart`
- `comment.md`

No changes were made to:

- `ai.js`
- Firestore rules
- Android/Kotlin/XML/widget files

## Commands Run And Results

```powershell
dart format lib\features\admin_dashboard\models\admin_dashboard_access.dart lib\features\admin_dashboard\presentation\admin_dashboard_scaffold.dart lib\features\admin_dashboard\presentation\admin_dashboard_figma_screen.dart lib\features\admin_dashboard\presentation\admin_dashboard_ui.dart lib\features\admin_dashboard\presentation\admin_permissions_management_screen.dart lib\features\admin_dashboard\presentation\admin_users_management_screen.dart lib\features\auth\presentation\admin_login_screen.dart lib\app\navigation\app_router.dart test\admin_dashboard_access_test.dart
npm --prefix functions run lint
flutter analyze --no-pub
flutter test --no-pub
flutter build web
```

Results:

- `dart format`: passed.
- `npm --prefix functions run lint`: passed.
- First `flutter analyze --no-pub`: found one unused local variable after the shell redesign.
- Final `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: passed, 62 tests.
- `flutter build web`: passed.
- Web output: `build\web`.
