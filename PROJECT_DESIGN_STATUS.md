# Salati Design Status

## Design Summary

The product has substantial UI built for both web dashboard and mobile, and recent work in `comment.md` says the dashboard was rebuilt toward exported Figma screenshots. However, this checkout has an empty `docs` directory and no inspectable `docs/design/dashboard_figma_exports` assets, so exact Figma matching cannot be verified here. Design is partial, not launch-approved.

## Figma Matching Status

Exact Figma source is not inspectable in this workspace. The `docs` directory exists but contains no files, and `docs/design/dashboard_figma_exports` is not present. Prior notes in `comment.md` reference exported dashboard PNGs and state that the `.fig` source was not parsed directly. Therefore, dashboard matching can only be judged from implemented UI structure and prior notes, not from a pixel comparison.

## Web Dashboard Design

| Area | Good | Partial | Missing | Required fix |
|---|---|---|---|---|
| Sidebar | Compact icon rail and responsive drawer exist. | Section list has been constrained in recent work. | Exact Figma spacing/icon verification unavailable. | Compare against actual Figma exports and adjust spacing, active states, and labels. |
| Home cards | KPI/card layout exists. | Some metrics are placeholders or derived from limited data. | Verified real-data states. | Add real empty/loading/error states for every metric. |
| Charts | User interaction chart card exists. | Real analytics/data source is unclear. | Production chart data validation. | Define metric source and show empty state when unavailable. |
| Users table | Table/cards/details modal exist. | Needs responsive/manual QA. | Verified row overflow/loading/error states. | Test at desktop/tablet/mobile widths. |
| Azkar page | Figma-style card grid and modals exist. | Delete UI exists but backend missing. | Pixel match proof. | Align modal fields/states with final content workflow. |
| Dua page | Same design pattern as Azkar. | Remote/mobile content relation needs QA. | Pixel match proof. | Verify long Dua text and RTL wrapping. |
| Mushaf page | Large card/add-card layout exists. | Metadata/import focus may not match final product flow. | Exact Figma comparison. | Verify asset cards, import modal, empty/error states. |
| Hadith page | Pack cards/import surface exist. | Mobile consumption absent. | Final reader/design flow. | Decide if dashboard-only or add user-facing design. |
| Adhan page | Large cards and add modal exist. | Custom audio runtime unclear. | Sound preview/playback UX proof. | Add verified preview/error state. |
| Themes page | Theme preview cards exist. | Runtime apply flow unverified. | Purchased/applied state design. | Show applied/owned/locked states consistently. |
| Widgets page | Widget cards exist. | Android-only reality may not be clear. | Device-specific guidance and entitlement states. | Make web dashboard copy/status clear without overpromising iOS. |
| Settings pages | App customization editor exists. | Shared/general settings overlap. | Clear IA. | Merge or clearly separate settings responsibilities. |
| Forms/modals | Many modals exist with language tabs and validation. | Some actions lead to unimplemented backend errors. | Complete disabled/loading/error states. | Disable unsupported actions until backend exists. |
| Responsiveness | Dashboard uses responsive shell/grid patterns. | Not manually verified in this audit. | Browser screenshot QA. | Test common desktop, laptop, tablet widths. |
| RTL Arabic | UI intends Arabic/RTL support. | Many source strings appear mojibake. | Clean Arabic rendering proof. | Repair encoding and run Arabic visual QA. |
| Empty states | Several empty states exist. | Some screens fall back to default data, hiding empty production state. | Consistent empty-state policy. | Avoid default content masking missing Firestore setup. |
| Loading states | Loading widgets/indicators exist. | Not audited per screen manually. | Skeleton/latency review. | Test slow network/loading paths. |
| Error states | Error widgets and snackbar flows exist. | Error copy has mojibake risk. | Complete actionable messages. | Validate every admin mutation failure path. |

## Mobile App Design

| Area | Good | Partial | Missing | Required fix |
|---|---|---|---|---|
| Home | Main navigation and feature entry exist. | Current widget test fails due duplicated `الأذكار` text expectation. | Manual responsive/mobile visual QA. | Fix test or UI semantics and verify bottom navigation. |
| Prayer screen | Large feature screen with settings, score, notifications, and visual states. | Very large file; complexity risk. | Device QA and accessibility pass. | Validate location permission, time display, reflection flow, and no overflow. |
| Adhkar | Category grid/details/progress exists. | Uses local and remote sources. | Full Arabic typography QA. | Verify long text, counters, completion state. |
| Dua | Category/detail flow exists. | Remote cache TODO remains. | Design parity with Adhkar. | Verify long Dua cards and completion feedback. |
| Quran | Hub, page/ayah/word readers, lock views, share card exist. | Quran AI is a gated wrapper/placeholder. | Full Mushaf/reader design QA. | Validate typography, page layout, paid locks, share image. |
| Store | Tabs, cards, previews, point balance, owned/action states exist. | Fallback products can mask missing setup. | Applied/unlocked state proof. | Verify locked/owned/loading/error and empty states. |
| Profile | User/profile repository exists, but a dedicated profile route/screen was not identified in router. | Account/settings may be distributed. | Clear account/profile design. | Add or document profile entry point if needed. |
| Drawer/menu | Main navigation exists. | Exact mobile IA not fully audited. | User journey review. | Confirm all launch features are reachable and non-launch features hidden. |
| Subscription views | Screen exists with IAP card and plan cards. | Copy indicates setup still pending in some states. | Production purchase design states. | Design pending, failed, restored, active, expired states. |
| Widgets visuals | Android widget XML/previews/providers exist. | Android-only and manual QA required. | iOS widget design. | Test actual launcher previews and sizes. |
| Sharing image design | Quran share image card is implemented and helper-tested. | Only Quran share image audited. | Broader share templates if desired. | Verify output on real share targets. |
| Arabic typography | Quran font bundled and used for Quran text. | General Arabic strings have mojibake risk. | Typography QA across app. | Repair strings and test Arabic/French/English. |
| Dark/light mode | Theme system and previews exist. | Runtime design behavior unverified. | Full dark/light design matrix. | Verify every core screen in both modes. |

## Design Risks

- Exact Figma matching cannot be verified because design exports/source are missing from the checkout.
- Arabic mojibake in source strings is a severe product/design quality issue.
- Dashboard can display unsupported delete actions, which is a UX and trust issue.
- Mobile Store/Subscriptions can show setup/fallback states that are not production commerce UX.
- Some admin-managed content has no obvious user-facing mobile screen, especially Hadith and lessons.
- Halaqat/Stream design may imply live/recorded capability while backend supports metadata only.
- Android widgets are rich but unverified on real launchers and sizes.
- Loading, empty, and error states are uneven and need a systematic QA pass.

## Design Acceptance Criteria

- Figma source or exported PNGs are present in the repo or design handoff and reviewed screen-by-screen.
- Dashboard matches approved Figma within agreed tolerance for sidebar, home, cards, tables, forms, modals, RTL, and responsive breakpoints.
- No user-facing mojibake remains in Arabic, English, or French flows.
- Every primary dashboard section has verified empty, loading, error, success, create, update, and unsupported-action states.
- Every mobile launch feature has verified small-screen, large-screen, dark/light, Arabic RTL, and long-text behavior.
- Paid/locked/owned states are visually clear and match backend reality.
- Unsupported or metadata-only features are hidden or explicitly scoped before launch.
- Android widget previews and real launcher widgets are approved for all declared sizes.
- Subscription and purchase screens have approved pending, failed, restored, active, expired, and unavailable states.
- A final design QA checklist is signed off before release candidate.

