# Firestore Mojibake Detection Plan

This is a non-destructive manual plan for staging or production data review.

## Collections To Inspect

- `dhikr_categories`
- `dhikr_categories/{categoryId}/items`
- `dua_categories`
- `dua_categories/{categoryId}/items`
- `store_items`
- `plans`
- `settings/app_config`
- `remote_app_config/draft`
- `remote_app_config/published`
- Dashboard-managed content collections that use category/item documents.

## Fields To Check

Check user-facing text fields such as:

- `title`
- `titleAr`
- `titleEn`
- `description`
- `descriptionAr`
- `descriptionEn`
- `subtitleAr`
- `subtitleEn`
- `text`
- `textAr`
- `textEn`
- `source`
- `translations.*.title`
- `translations.*.description`
- `translations.*.text`
- `translations.*.source`

## Suspicious Patterns

Search for text containing common mojibake code-point sequences such as:

- U+00C3 followed by currency or Arabic-looking Latin-1 spillover.
- U+00C2 non-breaking-space spillover.
- U+00D8 or U+00D9 Arabic UTF-8 bytes decoded as Latin-1.
- U+00E2 punctuation spillover.
- U+FFFD replacement characters.

These patterns usually mean UTF-8 Arabic was decoded as Windows-1252 or Latin-1 before being saved.

## Safe Manual Cleanup Workflow

1. Export a backup of the affected collection or document.
2. Inspect one document at a time in Firebase Console or a read-only export.
3. Decode the corrupted value offline and verify the intended Arabic phrase.
4. Update only the corrupted text fields.
5. Do not change ids, ownership fields, points, entitlements, rules, or timestamps unless the field itself is the corrupted text field.
6. Reopen the app and confirm the dynamic content no longer shows mojibake.

## Notes

This file is documentation only. It does not delete, overwrite, or migrate Firestore data.
