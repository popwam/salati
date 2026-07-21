# Salati

Salati is an Arabic-first Flutter app with:

- Android-first end-user flows
- Web admin/subscription screens
- A shared single codebase
- Configured Firebase Auth and Firestore runtime

## Run

```bash
flutter pub get
flutter run -d android
```

```bash
flutter run -d chrome
```

## Firebase

- Runtime config files are present in `lib/firebase_options.dart` and `android/app/google-services.json`.
- Firebase bootstraps from `lib/app/bootstrap/firebase_bootstrap.dart`.

## Docs

- `docs/firebase_emulator_guide.md`
- `docs/firestore_seed_examples.md`
- `docs/firestore_structure.md`
- `NEXT_PROMPT_FOR_CODEX.md`
