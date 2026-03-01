# omni_smsnew

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline resilience 🛡️

This application now caches contacts and conversation messages locally using
`shared_preferences`. When the backend is unreachable (for example, if the
Scaleway server is down) users can still open the app, browse previously
loaded conversations and contacts, and the UI will not crash. Sending new
messages will fail gracefully and display an error; unsent messages are
removed from the chat for now but the history remains available.

## Building release artifacts

A convenience script `build_release.sh` is provided to generate a release
APK and Android App Bundle (AAB). Run it on a machine with Flutter installed:

```bash
./build_release.sh
```

Alternatively, run the following commands manually:

```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Artifacts are written under `build/app/outputs/` after a successful build.

Build triggered at Sat Feb 21 16:55:04 UTC 2026
