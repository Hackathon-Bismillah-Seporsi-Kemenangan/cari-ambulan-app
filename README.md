# cari_ambulan_app

A new Flutter project.

## Configuration

Settings are passed at build time with `--dart-define`:

| Key | Default | |
| --- | --- | --- |
| `API_BASE_URL` | `http://10.0.2.2:8080` | Laravel server (the emulator's view of localhost) |
| `FIREBASE_API_KEY` | | Push notifications (optional) |
| `FIREBASE_APP_ID` | | e.g. `1:1234:android:abcd` |
| `FIREBASE_MESSAGING_SENDER_ID` | | |
| `FIREBASE_PROJECT_ID` | | |

Without the four Firebase keys push is off, and calls and orders arrive by
polling while the app is open. With them, the server can wake the app for an
incoming call or a new order. The values are in your Firebase project
settings (Android app); no `google-services.json` is needed.

```sh
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
