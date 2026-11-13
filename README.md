# CariAmbulan Driver App

Flutter app for **ambulance drivers** (Pengemudi Ambulans) of the CariAmbulan dispatch service. Drivers go online, receive emergency calls, navigate to the patient and deliver them to the nearest hospital's IGD.

It talks to the Laravel backend in [`CariAmbulan-server`](../CariAmbulan-server). **The backend must be running for the app to work.**

| | |
|---|---|
| Framework | Flutter 3.47+ / Dart 3.13+ |
| State management | Riverpod 3 |
| Map | flutter_map + vector_map_tiles with the [OpenFreeMap](https://openfreemap.org) "liberty" style (free, **no API key**) |
| Routing | [OSRM](https://project-osrm.org) public server (free, no API key) |
| GPS | geolocator |
| Token storage | flutter_secure_storage |
| Design | `Driver App.png` in the repo root |

---

## Table of contents

1. [Quick start](#quick-start)
2. [Pointing the app at the server](#pointing-the-app-at-the-server)
3. [Testing a full emergency](#testing-a-full-emergency)
4. [Screens and flow](#screens-and-flow)
5. [Project structure](#project-structure)
6. [How the app talks to the backend](#how-the-app-talks-to-the-backend)
7. [Tests and code quality](#tests-and-code-quality)
8. [Troubleshooting](#troubleshooting)
9. [Status and roadmap](#status-and-roadmap)

---

## Quick start

### Requirements

- Flutter SDK 3.47+ (`flutter --version`)
- Android Studio with an emulator, or Xcode for iOS, or a real phone
- Internet access to the shared server, or a local backend (see [Pointing the app at the server](#pointing-the-app-at-the-server) and the [server README](../CariAmbulan-server/README.md)).

### Steps

```bash
flutter pub get
flutter run          # uses the shared server http://103.150.60.58:8080
```

### Reading the log

`tool/run.sh` runs `flutter run` (same options) but shows only the app's own log, Flutter errors and crashes, without Android's system lines:

```
12:55:32 ✓ INFO  API      │ GET driver/trip → 200 · 204 ms · status=en_route_to_pickup
12:55:33 ✓ INFO  Route    │ router.project-osrm.org: 3.1 km · 4 min · 130 points
12:55:50 ! WARN  API      │ GET driver/calls/current → timeout after 15006 ms
```

- A poll that returns the same thing again (every 3 s) is not repeated; add `--dart-define=LOG_LEVEL=debug` to see those and request bodies (passwords hidden).
- `LOG_ALL=1 tool/run.sh` shows everything; `--dart-define=LOG_COLOR=false` if the terminal shows codes like `[32m`.
- In code, log with `AppLog.info / warn / error('Tag', 'message', error)` from `lib/core/logging/app_log.dart`.

### Log in

- **Shared server:** ask the backend maintainer for an account. The demo accounts below are only created on a **local** server (`APP_ENV=local`).
- **Local server** (`php artisan migrate --seed`):

  | Email | Password |
  |---|---|
  | `driver@cariambulan.id` | `Driver@123` |
  | `pasien@cariambulan.id` | `Pasien@123` |

One app serves both roles: a **driver** account opens the driver screens, a **user** (patient / caller) account opens the user screens. Other roles see "Akun ini belum didukung aplikasi".

---

## Pointing the app at the server

By default the app uses the **shared team server** `http://103.150.60.58:8080`, set in `lib/core/network/api_config.dart`. A plain `flutter run` needs no local backend.

To use a **local** backend instead, pass its URL:

| Where the app runs | Command |
|---|---|
| Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080` (`10.0.2.2` = your computer, seen from the emulator) |
| iOS simulator, macOS, web | `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080` |
| Real phone on the same Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<your-LAN-IP>:8080` |

To find your computer's LAN IP: `ipconfig getifaddr en0` on macOS, `ipconfig` on Windows. The local server must be started with `--host=0.0.0.0`.

> Plain `http://` is only allowed in **debug/profile** builds (Android `usesCleartextTraffic`). A **release** APK can't reach the shared server until it has a domain with **HTTPS**. On iOS only local `http://` is allowed (`NSAllowsLocalNetworking`), so iOS builds also need HTTPS or a local server.

---|---|
| Android emulator | `http://10.0.2.2:8080` (`10.0.2.2` = your computer, seen from the emulator) |
| iOS simulator, macOS, web | `http://127.0.0.1:8080` |

For anything else, such as a **real phone** or a different port, pass the URL when running:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

To find your computer's LAN IP: `ipconfig getifaddr en0` on macOS, `ipconfig` on Windows. The phone and computer must be on the **same Wi-Fi**, and the server must be started with `--host=0.0.0.0`.

> Plain `http://` is only allowed in **debug/profile** builds (Android `usesCleartextTraffic`, iOS `NSAllowsLocalNetworking`). A release build needs an `https://` server.

---

## Testing a full emergency

There is no patient app yet, so the backend has a command that plays the patient:

1. In the app, log in and switch **Online** (top card). Allow location access.
2. On the server:
   ```bash
   php artisan demo:emergency
   ```
3. Within about 3 seconds the **Panggilan Darurat** screen opens with a 30-second countdown.
4. Tap **Terima**, then **Saya Sudah Tiba**, then **Mulai ke Rumah Sakit**, then **Serahkan Pasien ke IGD** and **Ya, Serahkan**.
5. You're back on the home screen, online, and "Trip selesai" has gone up by 1.

You can also test **Tolak**, or let the countdown run out.

**Reporter calling during the order:** while on Menuju pasien or Menuju rumah sakit, run `php artisan demo:call` on the server. The dark **Panggilan masuk · order aktif** panel appears over the map. **Jawab** shows a call bar with a timer at the top of the trip sheet (tap the red button to hang up), and **Tolak** declines. The call closes and the order goes to the next available driver.

**Emulator GPS:** the emulator has no real location. Set one, e.g. central Jakarta:

```bash
adb emu geo fix 106.8222 -6.2088    # longitude first, then latitude
```

Or use the emulator's **⋯ → Location** panel. If location is unavailable, the app falls back to Jakarta (-6.2088, 106.8222).

---

## Screens and flow

```
Login ──► Beranda (Offline) ──switch──► Beranda (Online, waiting)
                                              │  offer arrives (poll every 3 s)
                                              ▼
                                     Panggilan Darurat (30 s)
                                   Tolak ◄──┤──► Terima
                                              ▼
                                       Menuju pasien
                                   (route, Telepon, Saya Sudah Tiba)
                                              ▼
                                   Tiba di lokasi → Mulai ke Rumah Sakit
                                              ▼
                                     Menuju rumah sakit
                         (IGD notified notice, timeline, Serahkan Pasien ke IGD)
                                              ▼
                                   Beranda (Online again)
```

- **Reporter calls** can arrive on both trip screens (checked every 3 s while the screen is open). Ringing dims the screen until the driver answers or declines. After answering, navigation and the trip buttons stay usable.
- **Back button is disabled** during a trip so an accepted order can't be abandoned by accident.
- **Resuming:** if the app is closed mid-trip, it reopens the right trip screen after the next login or launch (`GET /driver/trip`).
- **Profil tab → Keluar** sets the driver offline, then logs out. Logout is blocked during a trip.

---

## Project structure

```
lib/
├── main.dart                         App entry + auth gate (login / driver app / error)
├── core/
│   ├── network/
│   │   ├── api_config.dart           Server URL (API_BASE_URL)
│   │   ├── api_client.dart           HTTP client, ApiException, 401 → logout
│   │   └── api_providers.dart
│   ├── alerts/emergency_alert.dart   Siren, vibration, notification for new orders
│   ├── location/location_service.dart GPS + permissions (driver and user)
│   ├── map/map_tiles.dart            Shared OpenFreeMap base layer
│   ├── widgets/pill_bottom_nav.dart  Floating tab bar (driver and user)
│   └── theme/                        Colors and theme
└── features/
    ├── auth/
    │   ├── data/auth_repository.dart Login/logout, token in secure storage
    │   ├── domain/auth_models.dart
    │   └── presentation/             LoginPage, authProvider
    └── driver/
        ├── data/
        │   ├── driver_repository.dart       Interface used by the UI
        │   ├── api_driver_repository.dart   Real implementation (Laravel API)
        │   ├── mock_driver_repository.dart  Fake data, used by tests
        │   └── routing_repository.dart      OSRM routes
        ├── domain/                   Models (EmergencyRequest, ActiveTrip, ...)
        └── presentation/
            ├── providers/driver_home_provider.dart   Main driver state
            ├── providers/trip_call_provider.dart     Reporter's call during a trip
            ├── pages/                Shell (tabs), Home, IncomingCall,
            │                         ToPatient, ToHospital
            └── widgets/              Map, banners, sheets, timeline,
                                      trip call overlay + call bar
    └── user/                         Patient / caller app (`User App.png`)
        ├── data/                     UserRepository + API implementation
        ├── domain/user_models.dart   NearestAmbulance
        └── presentation/             UserShell (tabs), UserHomePage, map,
                                      call button with 5 s cancel
test/                                 Widget + repository tests
```

**Architecture in one sentence:** pages watch Riverpod providers → providers call a `DriverRepository` → `ApiDriverRepository` calls the backend through `ApiClient`. Tests replace the repository with `MockDriverRepository`, so they run without a server.

---

## How the app talks to the backend

| App action | API call |
|---|---|
| Login / restore session | `POST /auth/login`, `GET /auth/me` |
| Home screen load | `GET /driver/profile`, `GET /hospitals/nearest`, `GET /driver/trip` |
| Online / Offline switch | `PUT /driver/availability` |
| GPS updates (max every 10 s, while online) | `POST /driver/location` |
| Waiting for calls (every 3 s, while online) | `GET /driver/offers/current` |
| Terima / Tolak | `POST /driver/requests/{id}/accept` / `decline` |
| Saya Sudah Tiba | `POST .../arrive` |
| Mulai ke Rumah Sakit | `POST .../start-to-hospital` |
| Serahkan Pasien ke IGD | `POST .../complete` |
| Reporter call (every 3 s on trip screens) | `GET /driver/calls/current` |
| Jawab / Tolak / hang up | `POST /driver/calls/{id}/answer` / `decline` / `end` |
| Logout | `PUT /driver/availability` (offline, only if online), `POST /auth/logout` |

- The token is stored in **secure storage** under `auth_token`. Any `401` response logs the driver out automatically.
- Server error messages, such as validation or "wrong step" (409), are shown as-is in a snackbar.
- The call countdown uses `seconds_remaining` from the server, so it stays correct even if the phone's clock is off.
- Map tiles and routes come from **public free services** (OpenFreeMap, OSRM). They need internet but no key. For production, consider self-hosting OSRM because the public server has fair-use limits.

Full API details are in the [server README](../CariAmbulan-server/README.md#api-reference).

---

## Tests and code quality

```bash
flutter analyze      # must report "No issues found!"
flutter test         # widget + repository tests, no server needed
```

Before committing:

- `flutter analyze` and `flutter test` pass,
- `dart format lib test`,
- new backend calls go in `ApiDriverRepository` **and** the `DriverRepository` interface, plus the mock.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Tidak dapat terhubung ke server. Periksa koneksi Anda." | Shared server: check the device has internet and `http://103.150.60.58:8080/up` opens in a browser. Local server: check `php artisan serve --host=0.0.0.0 --port=8080` is running and you passed the right `--dart-define=API_BASE_URL`. Release builds can't use `http://` at all. |
| Login says email or password is wrong | On the shared server, use the account you were given (demo accounts don't exist there). On a local server, seed the demo data: `php artisan migrate --seed` (local env). Note that the emulator keyboard sometimes adds stray characters; tap the 👁 icon to check. |
| "Akun ini bukan akun driver" | You logged in with a non-driver account. Use `driver@cariambulan.id`. |
| Map is grey/blank | No internet on the device/emulator (tiles come from openfreemap.org). Cold-boot the emulator if its network is broken. |
| Route never appears ("Menghitung rute…") | OSRM public server unreachable or slow. Wait, or check internet. |
| Location stuck / wrong place on emulator | `adb emu geo fix <lon> <lat>` or the emulator Location panel. Allow the permission when asked. |
| No emergency call arrives | The driver must be **Online** with a recent location. Create a **new** call with `php artisan demo:emergency`, because a request isn't re-offered to a driver who declined or ignored it. The app must be open (no push yet). |
| Emulator error "Service mount: not found" / won't boot | Cold boot: `emulator -avd <name> -no-snapshot-load`, or **Cold Boot Now** in Android Studio's Device Manager. |
| Buttons react slowly / screens lag behind the server | The dev server handles one request at a time. Start it with `PHP_CLI_SERVER_WORKERS=4 php artisan serve --host=0.0.0.0 --port=8080`. |
| `Unhandled Exception: Cancelled` in logs | Harmless. It comes from the map library cancelling tile loads when you change screens. |
| Cleartext HTTP error on release build | Release builds require `https://`. Use debug builds for local testing. |

---

## Status and roadmap

Compared to the design (`Driver App.png`):

| Screen | Status |
|---|---|
| Beranda – Offline | ✅ |
| Beranda – Online | ✅ (Rating shows "–" because the backend has no ratings yet) |
| Panggilan Darurat | ✅ Looping siren at full alarm volume, rush vibration and a heads-up notification until answered |
| Menuju pasien | ✅ (Chat button is a placeholder; Telepon opens the phone dialer) |
| Incoming call during an order (Tolak / Jawab) | ✅ Screen, ringing, answer/decline/hang-up and missed calls work with the backend. ⚠️ **No voice audio yet**: needs a calling service (Agora / Twilio / WebRTC). See the TODO in `api_driver_repository.dart`. |
| Menuju rumah sakit | ✅ |
| Riwayat tab | ❌ Placeholder |
| Profil tab | ⚠️ Basic version (no design yet) |

Known limitations:

User app, compared to `User App.png`:

| Screen | Status |
|---|---|
| Beranda (Panggil Ambulans) | ✅ Location + GPS accuracy, address, nearest ambulance with ETA, 5 s cancel countdown sends the emergency, Telepon 119. ⚠️ "Ubah" lokasi is a placeholder; no emergency type picker yet (sent as "Lainnya"). |
| Mencari ambulans terdekat (screen 3) | ✅ Search rings, nearby ambulances, drivers contacted, pickup / keluhan / nearest hospital, Batalkan Pencarian. Reopens after an app restart. When a driver accepts it shows "Ambulans ditemukan!" until the tracking screen exists. |
| Radius search, no ambulance found (screens 4–5) | ❌ Not started |
| Ambulans dalam perjalanan … telah tiba (screens 6–9) | ❌ Not started |
| Riwayat, Medical ID | ❌ Placeholders |
| Profil | ⚠️ Basic version (name, email, Keluar) |

- Calls only arrive **while the app is open** (polling). Push notifications (FCM / Laravel Reverb) are planned.
- Public OpenFreeMap/OSRM servers are fine for development but not guaranteed for production.
- The `spec/` folder is local-only (git-ignored).
