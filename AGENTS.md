# AGENTS.md — CariAmbulan App (Flutter)

Instructions for any AI coding agent (Claude Code, Codex, Cursor, Gemini, Copilot, opencode, …) working in this repo. Read it fully before changing code. Humans: `README.md` has the same facts in longer form.

## 1. What this is

One Flutter app (brand name in UI: **SigapMed**) for two roles of the CariAmbulan ambulance dispatch service:

- **driver** → `DriverShell`: go online, receive emergency offers, drive to patient, then to hospital IGD.
- **user** (patient / reporter) → `UserShell`: call an ambulance, watch the search, track the ambulance, Medical ID, history.

Any other role sees "Akun ini belum didukung aplikasi".

The backend is the Laravel repo **`../CariAmbulan-server`** (it has its own `AGENTS.md`). The app does nothing useful without it.

| Piece | Where |
|---|---|
| REST API | `{API_BASE_URL}/api/v1/…`, Sanctum bearer token. Default `https://103-150-60-58.sslip.io` (shared team VPS behind Caddy/HTTPS) |
| Call audio | **LiveKit** room per call (`livekit_client`), `LIVEKIT_URL` default `wss://lk.103-150-60-58.sslip.io`; the server issues the room token |
| Push | Firebase Cloud Messaging (`FcmService.init()` in `main.dart`); Android applies google-services only when `android/app/google-services.json` exists (not in git) |
| Map | **Offline** vector tiles `assets/map/jatim.pmtiles` (East Java only, zoom ≥ 8) + bundled liberty style |
| Routing | OSRM public server (internet needed) |

Overrides: `--dart-define=API_BASE_URL=… LIVEKIT_URL=… LOG_LEVEL=debug LOG_COLOR=false`. (`REVERB_*` defines still exist in `api_config.dart` but calls no longer use them.)

## 2. Code map

```
lib/
├── main.dart                     ProviderScope → AuthGate (auth flow / DriverShell / UserShell)
├── core/
│   ├── network/                  api_config.dart (URLs, keys), api_client.dart (JSON, 401→logout, ApiException)
│   ├── logging/app_log.dart      AppLog.info/warn/error('Tag', msg) — use it, never print()
│   ├── map/                      map_tiles.dart (offline PMTiles), pmtiles_archive.dart, route_trim.dart
│   ├── location/ alerts/ permissions/ theme/ constants/ widgets/
└── features/
    ├── auth/        login/register, token in flutter_secure_storage (auth_token)
    ├── onboarding/  role selection, permission pages
    ├── driver/      data/ (DriverRepository interface, Api*, Mock*, routing) · domain/ · presentation/
    ├── user/        data/ (UserRepository interface, Api*) · domain/ · presentation/
    ├── call/        voice calls: livekit_voice_service, voice_call_provider, active_call_sheet
    └── dashboard/
test/                widget + repository tests (no server needed)
tool/run.sh          flutter run with a filtered, readable log
scripts/live/adb.sh  drive the running app from the shell (see §5)
```

Key state: `driverHomeProvider` (online toggle, location reporting 10 s / 3 s on trip, offer polling, trip steps), `tripCallProvider`, `voiceCallProvider`, `authProvider`.

## 3. How things flow

**Order (driver):** online → poll `driver/offers/current` (3 s) → offer screen, 30 s countdown from server `seconds_remaining` → `accept` → `arrive` → `start-to-hospital` (server picks hospital) → `complete`. Trip resumes after restart via `GET driver/trip`. Back button disabled during a trip.

**Order (user):** `POST emergency-requests` → poll `emergency-requests/{id}`; server widens radius 3→5→10→15→25 km every 90 s → driver assigned → tracking.

**Voice call (both directions, LiveKit):**
1. Caller `POST emergency-requests/{id}/calls` → server creates the call + LiveKit room and returns a token (`token` / `livekit_token` / `connection.token`) and URL.
2. Callee finds the ringing call by polling (`driver/calls/current` or `calls/incoming`; FCM push when configured) → `calls/{id}/accept` (LiveKit `Call`) or `calls/{id}/answer` (legacy `TripCall`).
3. Each side without a token fetches `GET calls/{id}/token`, then joins the room at the returned URL or `ApiConfig.livekitUrl`.
4. `calls/{id}` is polled for status; `…/decline`, `…/end` close it. Participant left / room disconnected ends the call.

"connected" (other side picked up) ≠ `audioConnected` (joined the LiveKit room / peer joined). If the call rings and answers but has no audio, check the LiveKit server is reachable from both phones (`wss://lk.103-150-60-58.sslip.io` + its RTC/TURN ports) before blaming the app.

## 4. Commands

```bash
flutter pub get
tool/run.sh                                   # run with readable log (any flutter run flags)
tool/run.sh -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080   # local server
flutter analyze                               # must say "No issues found!"
flutter test                                  # all tests
flutter test test/trip_call_test.dart         # one file
dart format lib test
```

`flutter test` / `pub get` may rewrite `pubspec.lock`. Don't commit lock changes you didn't intend; never `git checkout`/stash over the user's own uncommitted `pubspec.lock` changes.

## 5. Testing — the ladder

Unit tests alone are **not** proof a feature works. Climb as far as the change needs, and report which levels you ran.

| Level | When | How |
|---|---|---|
| **L0 static** | every change | `flutter analyze`, `dart format --set-exit-if-changed lib test` |
| **L1 tests** | every change | `flutter test`. New repo method → test with `MockDriverRepository` / fake client |
| **L2 live API** | touched an endpoint, model parsing, or server contract | Use the server's `scripts/live/api.sh` (see server `AGENTS.md`) to see the real JSON the app will parse |
| **L3 live app** | any UI or flow change | Run the app (below), drive it with `scripts/live/adb.sh`, confirm with screenshot + log lines |
| **L4 two-party** | orders, tracking, **calls** | Driver on one device/emulator, user on another; watch both logs |
| **L5 VPS smoke** | before saying "works on the shared server" | server `scripts/live/smoke.sh` with `BASE_URL=https://103-150-60-58.sslip.io` (read-only) |

### Running live (L3)

```bash
emulator -list-avds && emulator -avd <name> &          # or a USB phone with debugging on
flutter devices
mkdir -p build/live && tool/run.sh -d <device> > build/live/run.log 2>&1 &   # log to a file you can read
scripts/live/adb.sh geo -7.2575 112.7521               # Surabaya: inside the offline map
scripts/live/adb.sh screenshot                         # → build/live/screen.png, then LOOK at it
scripts/live/adb.sh ui                                 # visible labels + tap coordinates
scripts/live/adb.sh tap "Masuk"                        # tap by text / accessibility label
scripts/live/adb.sh type "driver@cariambulan.id"
scripts/live/adb.sh logs 15                            # app log for the next 15 s
```

Hot reload: send `r` to the `flutter run` process (or restart it). Two devices: prefix with `ANDROID_SERIAL=emulator-5556`.

### Test accounts

Exist on a local seeded server **and** on the shared VPS (it seeds demo data on every deploy):

| Role | Email | Password |
|---|---|---|
| driver | `driver@cariambulan.id` | `Driver@123` |
| user | `pasien@cariambulan.id` | `Pasien@123` |

Driver offers on a **local** server: `php artisan demo:emergency` (creates an order ~1.5 km from the driver), reporter call: `php artisan demo:call`. Run those via the server repo (`docker compose exec app php artisan …`).

### Feature checklists (what "verified" means)

- **Order flow:** offer appears ≤ 3 s after `demo:emergency`; each button moves status (`API … status=…` log); after `complete` the driver is online and "Trip selesai" +1.
- **Map/route:** GPS inside East Java; `Route │ … km · … min` log; screenshot shows tiles + route line.
- **Calls:** both phones log `VoiceCall │ LiveKit connection state: …connected` and `Participant … joined LiveKit room`, UI shows the timer **without** "menyambungkan suara…", and a person confirms they hear audio both ways. Test once on the same Wi-Fi **and** once with one phone on mobile data — only the second proves the relay path. Emulators can't prove audio. Quick reachability: `nc -z -w3 lk.103-150-60-58.sslip.io 443`.
- **Auth:** 401 anywhere logs out; wrong password shows the server's message.

### Reading logs

`tool/run.sh` prints `HH:MM:SS LEVEL Tag │ message`. Useful tags: `API`, `VoiceCall`, `Route`, `Lokasi`, `Sync`, `Map`. Identical polls are hidden; `--dart-define=LOG_LEVEL=debug` shows them plus request bodies (passwords redacted). Server side: `docker compose logs -f app` (plus the LiveKit/coturn services) in the server repo.

## 6. Conventions

- Riverpod 3 (`Notifier`/`AsyncNotifier`, providers next to the feature). No other state library.
- Data access only through the repository interface. **New backend call = interface + `Api*Repository` + `MockDriverRepository`** (and a test).
- Feature-first folders: `data/ domain/ presentation/{pages,providers,widgets}`.
- All user-visible strings in **Bahasa Indonesia**; code, comments, logs in English.
- Show `ApiException.message` to the user as-is (server messages are already Indonesian). 5xx shows a generic message.
- Log with `AppLog`, tag = short area name. No `print`.
- Match surrounding style: comment density, naming, small widgets. `dart format`.
- Ask before adding a package to `pubspec.yaml`.

## 7. Cross-repo contract (change both sides together)

- Endpoint paths/fields: server `routes/api.php` + `app/Http/Resources/V1/*` ⇄ app `features/*/data/api_*_repository.dart` + domain `fromJson`.
- Calls: the token/URL field names the app accepts (`token`, `livekit_token`, `connection.token`, `url`, `livekit_url`, `connection.server_url`) must match what the server's call endpoints return. LiveKit API key/secret on the server must belong to the LiveKit server at `LIVEKIT_URL`.
- Status strings (`searching_driver`, `en_route_to_pickup`, `ringing`, `answered`, …) come from server enums in `app/Enums/`.

## 8. Safety — ask before, never do

**Never:** print or commit secrets/tokens/`.env` values; push to the server's `main` without being asked (it auto-deploys to the VPS); delete user data on the VPS.

**Ask first:** anything that writes on the shared VPS (creating orders or calls rings real teammates' phones; going online makes a driver dispatchable); adding dependencies; changing Android/iOS permissions, signing, or `applicationId`; replacing `jatim.pmtiles` (77 MB, bump `_tilesVersion`).

**Free:** anything against a local server/emulator; read-only requests to the VPS; demo accounts.

## 9. Known pitfalls

- Map covers **East Java only**, but the server's demo hospitals and seeded orders are in **Jakarta**. Put test GPS in East Java (Surabaya `-7.2575, 112.7521`) and expect "nearest hospital" to be far until East Java hospitals are seeded.
- Release builds can't use `http://` (cleartext only in debug/profile); use the HTTPS default or a local server in debug.
- `php artisan serve` without `PHP_CLI_SERVER_WORKERS=4` serializes the app's 3 s polls → laggy UI.
- `Unhandled Exception: Cancelled` from the map when leaving a screen is harmless.
- A declined/timed-out offer is never re-offered to the same driver: make a new `demo:emergency`.
- Emulator GPS needs `adb.sh geo`; without a fix the app uses its fallback location.

## 10. Definition of done

1. L0 + L1 pass (paste the summary line). Pre-existing failures named as such.
2. The live levels the change needs (§5) were run, with evidence: log lines, screenshot path, or API output. If you could not run them (no device, needs two people), **say so explicitly** — don't claim "works".
3. Cross-repo changes made on both sides, or the missing side called out.
4. `README.md` updated if behaviour/setup changed.
5. Not committed unless asked. Commit style: Conventional Commits (`fix(call): …`, `feat(map): …`).
