You are working inside the Salati Flutter/Firebase project.

Your task is to implement the following feature updates safely and incrementally.

IMPORTANT RULES:

* Do not rewrite the whole project.
* Do not delete existing working features.
* Do not break current tests.
* Do not change unrelated files.
* Before editing, inspect the relevant files and understand the existing architecture.
* Prefer small, focused changes.
* Keep the current Flutter/Firebase structure.
* If a feature requires Android native changes, isolate them clearly.
* After changes, run:

  * `flutter analyze --no-pub`
  * `flutter test --no-pub`
  * and any relevant Android/Functions checks if files are touched.
* Update or create documentation if needed.
* If something cannot be safely completed, write it clearly in the final summary.

---

# Main Goal

Implement the requested UX, points, prayer, adhkar, dua, subscription, store, profile, Quran, notification, and widget improvements.

The project already has a `PROJECT_AUDIT_STATUS.md` file. Read it first to understand current risks and structure.

---

# Phase 1 — Unified Points Engine

Create or improve a centralized points calculation system.

The points system must support:

## Prayer points

Default free plan values:

* Prayer completed on time: `+10`
* Prayer completed late but before the next prayer starts: `+5`
* Prayer missed/not completed: `-1`

The system must allow different point values per subscription plan.

Example:

* Plus/Pro may use different values such as:

  * on-time prayer: `20`
  * late prayer: `5`
  * adhkar completion: `15`
  * dua completion: `15`

Do not hardcode plan values directly inside UI screens. Put them in a config/model/service that can be changed later.

## Adhkar / Dua points

Default:

* Completing an adhkar category: `+10`
* Completing a dua category: `+10`

Plan-based values must be supported.

## Requirements

* Points must be added to the user's points balance automatically.
* Points must decrease when negative points apply.
* Avoid double-counting the same completed prayer/adhkar/dua section for the same day/session.
* The store balance must reflect these points.
* Add tests if possible for the point calculation logic.

---

# Phase 2 — Prayer Screen Updates

Review and update the prayer page, especially:

`lib/features/prayer/presentation/prayer_screen.dart`

Required changes:

1. Fix the "Update address/location" button so it actually refreshes the location/address.
2. The current prayer registration button must display the current prayer name.
3. Apply the new prayer points logic:

   * On-time completion gives full points.
   * Late completion before the next prayer gives reduced points.
   * Missing prayer gives `-1`.
4. Qiyam al-layl should be recordable.
5. Prayer recording and adhan flow should be connected logically.
6. Keep UI clean and avoid adding more complexity to the already large screen.
7. If possible, extract new logic/widgets instead of increasing `prayer_screen.dart` further.

---

# Phase 3 — Adhkar Page Updates

Review:

`lib/features/adhkar/`

Required changes:

1. Remove text blocks above the category sections.
2. Remove explanations/descriptions from the category list UI.
3. When the user completes reading an adhkar category:

   * Add points to the user balance.
   * Mark the category as completed.
   * Show the completed category in grey color.
4. Prevent duplicate points for the same completed category in the same day/session.
5. Persist completion state if the project already has local/Firebase persistence for this area.
6. Keep the UI simple and clean.

---

# Phase 4 — Dua Page Updates

Review:

`lib/features/dua/`

Apply the same interaction model as Adhkar:

1. Remove text blocks above the category sections.
2. Remove explanations/descriptions from the category list UI.
3. When the user completes reading a dua category:

   * Add points.
   * Mark it as completed.
   * Show it in grey color.
4. Prevent duplicate points for the same completed category in the same day/session.
5. Persist completion state where appropriate.

---

# Phase 5 — Bottom Bar / Side Menu / Profile Flow

Review app navigation and profile/menu files.

Required changes:

1. Rework the side menu so it opens from the bottom navigation bar.
2. The profile page should act as or open the side menu.
3. Reorder the menu items in a cleaner structure.
4. Subscription status should appear under the subscription button/item.
5. The subscription item should show the current plan/status without forcing immediate navigation.
6. Keep navigation consistent and avoid duplicate admin/profile/menu entries.

---

# Phase 6 — Subscription Page Updates

Review:

`lib/features/subscriptions/`

Required changes:

1. Show the current subscription plan clearly.
2. Show only two plan cards:

   * Plus
   * Pro
3. Each plan should support custom point rules:

   * prayer points
   * adhkar points
   * dua points
   * any other reward rules
4. Do not hardcode point values in the UI. Use a plan configuration/model.
5. Trial button behavior:

   * If the trial was already activated, do not show/enable it again until the trial period ends according to existing subscription logic.
   * If trial is active, show remaining state/status.
6. Hide plan features inside an expandable/collapsible section instead of showing all features directly.
7. Keep the UI clean and easy to understand.

---

# Phase 7 — Store Page Updates

Review:

`lib/features/store/`

Required changes:

1. The user's points balance must increase/decrease automatically based on prayer/adhkar/dua actions.
2. The store must display the real points balance.
3. Remove/hide extra text blocks.
4. Remove the calendar from the store.
5. The store should show gifts/rewards only.
6. Remove paid features from the store UI.
7. Purchased sounds/items should still be available to other settings screens if already supported.
8. Make sure spending points reduces the balance correctly.

---

# Phase 8 — Prayer Settings Page Updates

Review:

`lib/features/prayer/presentation/prayer_settings_screen.dart`

Required changes:

1. Location and prayer time calculation should work automatically in the background.
2. Qiyam al-layl should be supported in recording/settings.
3. Prayer registration should be connected to adhan behavior where appropriate.
4. Permissions UI:

   * Remove long explanatory text.
   * Display permissions as checkboxes/status rows.
   * Check permissions when the page opens for the first time.
   * Required permissions/statuses:

     * Notifications permission
     * Battery optimization/background work permission
     * Lock screen permission/status if supported
     * Auto-start permission/status if supported
5. Sounds:

   * Add a test/play button for each sound.
   * Show sounds purchased from the store.
6. Adhkar and surah automation:

   * Allow automatic adhkar/surah behavior.
   * Let the user choose whether adhkar or surah plays/reads first.
   * Allow adhkar to be either heard or read.
   * Default behavior: read.
7. Widgets:

   * The widget refresh button should always work.
   * Add a widget test/check button to verify whether widgets are working.

If Android-native work is needed, implement it carefully in the Android module and document limitations.

---

# Phase 9 — Profile Page Updates

Review:

`lib/features/account/`

Required changes:

1. Backup/sync section:

   * Show the last backup date/time.
   * Restore should happen automatically only the first time.
   * Do not show a manual restore button unless there is already a clear existing reason.
2. Appearance and reading settings:

   * Font settings must actually apply.
   * Quran font settings must actually apply.
   * Downloaded fonts should be stored on the device.
   * If encryption already exists in the project, use it for downloaded fonts.
   * If encryption does not exist, do not fake encryption. Add a clear TODO/documentation note and implement safe local storage first.

---

# Phase 10 — Quran Page Updates

Review:

`lib/features/quran/`

Required changes:

1. Wird selection:

   * When the user selects a specific wird, update the current reading position across all reading modes:

     * ayah reading
     * word reading
     * page reading
2. The Quran index/fahras should apply to all reading modes, not only ayah mode.
3. Ayah reading session time:

   * Limit new ayah reading sessions to 60 minutes.
   * If the time expires while the user is already reading, do not interrupt the active session.
   * When the user closes and tries to open a new session, check remaining time before allowing it.
4. Word reading session time:

   * Limit to 30 minutes.
5. Page reading:

   * When changing mushaf, update normally.
   * If mushaf page rendering/loading fails, fall back to text-based reading.
6. Ayah image generation:

   * Fix image generation from selected ayahs.
   * Use the correct Flutter rendering/export tools.
   * Ensure the generated image is valid and shareable.

---

# Phase 11 — Android App Icon / Notifications / Adhan / Widgets

Review:

* Android native module
* Flutter notification services
* Android widget providers
* Existing widget files
* Existing adhan/notification code

Required changes:

## App icon by points level

Implement safely if possible:

* Default icon for normal points.
* Different icon/color when points are above a threshold such as `>= 30`.
* Different icon/color when points are below `0`.

Important:

* Android launcher icon dynamic changes may require activity aliases in `AndroidManifest.xml`.
* Do not implement a fake solution.
* If true launcher icon switching is risky, document it and implement only safe widget/notification icon changes.

## Adhan stop behavior

* The adhan should not stop from a button or notification dismissal.
* The preferred stop action is shaking the phone.
* Implement only if it can be done safely.
* Consider Android background/sensor limitations.
* Do not break notification/audio behavior.

## Persistent notification

* Add or fix a persistent notification that cannot be easily dismissed.
* It should show the next prayer.
* It should update when prayer time changes.
* It should respect Android notification/channel requirements.

## Widgets

Fix/update the Android widgets:

1. Next prayer widget currently does not work correctly. Fix it.
2. Reading screen widget currently does not work correctly. Fix it.
3. Replace quick control widget layout from `1x4` to `4x1`.
4. Points widget should be `1x1` and remove extra text.
5. Widget refresh must work reliably.
6. Add a widget test/check action if feasible.

---

# Phase 12 — Dashboard / Admin Panel Updates

Review:

* `lib/features/admin/`
* `lib/features/admin_dashboard/`
* existing Firestore repositories, rules, models, settings collections, and remote config paths

Required changes:

The dashboard/admin dashboard must support the new app behavior and must not create duplicate settings if compatible settings, repositories, or collections already exist.

## Unified points system management

1. Manage prayer points.
2. Manage late prayer points.
3. Manage missed prayer penalty.
4. Manage adhkar completion points.
5. Manage dua completion points.
6. Manage plan-based point rules for Free, Plus, and Pro.
7. Point values must come from config/database, not hardcoded UI.

## Subscription plans management

1. Manage Plus and Pro plans.
2. Show current active plans.
3. Manage plan features.
4. Manage plan reward rules.
5. Manage trial rules.
6. Trial should not be reactivated while already active.

## Store management

1. Manage gifts/rewards only.
2. Remove paid features from store management if they are no longer used.
3. Manage purchased sounds/items if supported.
4. Ensure point spending updates the user balance correctly.

## Adhkar and Dua management

1. Manage categories.
2. Manage completion rewards.
3. Manage visibility/status.
4. Ensure dashboard data matches the simplified app UI.

## Prayer settings management

1. Manage adhan sounds.
2. Manage qiyam al-layl settings if stored remotely.
3. Manage prayer-related configuration if already supported.
4. Do not create duplicate settings if existing settings collections already exist.

## Quran settings management

1. Manage wird/session configuration if already supported.
2. Manage reading time limits:

   * Ayah reading: `60` minutes.
   * Word reading: `30` minutes.

3. These values should be configurable if a remote config/settings system already exists.

## Widgets and notification configuration

1. Manage widget settings if already stored remotely.
2. Manage persistent notification configuration if already supported.
3. Do not fake native Android capabilities in the dashboard.

---

# Phase 13 — Development Database Reset & Seed Tool

Add this as a development-only admin dashboard requirement.

Do not implement this tool until the dashboard, backend, Firestore rules, and schema have been inspected carefully.

## Purpose

The tool is for development/testing only.

It should allow a super admin to:

1. Delete/reset selected development database collections.
2. Recreate compatible Firestore database structure.
3. Seed protected default configuration documents.
4. Seed plans, points rules, store gifts, adhkar/dua settings, Quran/session settings, and app remote config.
5. Keep the new database structure compatible with the updated app behavior.

## Very Important Safety Rules

1. This tool must NEVER run in production.
2. This tool must be hidden unless the app is in development/debug mode.
3. This tool must be accessible only by `superAdmin`.
4. This tool must require a strong confirmation phrase before running.
5. The confirmation phrase should be something like:

   `RESET SALATI DEV DATABASE`

6. It must show exactly what collections/documents will be deleted before execution.
7. It must not delete user auth accounts.
8. It must not delete production payment/subscription history.
9. It must not delete production purchase verification records.
10. It must not delete production user data unless explicitly running against an emulator/dev project.
11. It must support dry-run mode before actual deletion.
12. It must log every reset action in an audit log.
13. It must be disabled by default.
14. It must require a remote/config flag or environment flag to enable.
15. If the current Firebase project cannot be confirmed as development/emulator, the tool must refuse to run.

## Security Requirements

1. Firestore rules must protect reset/seed operations.
2. The reset action should preferably be done through a secure backend/Firebase Function, not directly from Flutter client.
3. The Flutter dashboard should only trigger the backend operation.
4. Backend must verify:

   * Firebase Auth user.
   * Admin/superAdmin claim.
   * Development environment flag.
   * Confirmation phrase.

5. All reset/seed actions must be written to audit logs.
6. No secret keys should be stored in the Flutter client.
7. Do not expose encryption keys in source code.

## Encryption / Protection Requirement

If the project already has an encryption/security service, use it for sensitive local/cache data.

If encryption does not already exist, do not fake encryption.

Instead:

1. Add a clear TODO in the prompt requiring a proper encryption design.
2. Sensitive values must not be hardcoded.
3. Secret keys must be stored in secure backend environment variables or platform secure storage, depending on the use case.
4. Firestore data must be protected primarily through security rules, server validation, and proper access control.

## Seed Data Requirements

The seed tool should create/update safe default documents for:

1. App configuration.
2. Points rules:

   * Free
   * Plus
   * Pro

3. Subscription plan definitions:

   * Plus
   * Pro

4. Store gifts/rewards.
5. Adhkar category configuration if remote settings exist.
6. Dua category configuration if remote settings exist.
7. Quran session limits:

   * Ayah: `60` minutes.
   * Word: `30` minutes.

8. Widget/notification configuration if remote settings exist.
9. Admin dashboard configuration.

Before proposing or implementing any schema, inspect existing Firestore paths, repositories, rules, and models.

Do not invent a new database structure if a compatible one already exists.

---

# Required Final Response

After implementation, provide:

1. Files changed.
2. Features implemented.
3. Features partially implemented.
4. Features not implemented and why.
5. Commands run and results.
6. Any manual Android/Firebase steps required.
7. Any risks or limitations.
8. Recommended next step.

Do not claim something works unless you tested it or can prove it from code.
