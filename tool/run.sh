#!/usr/bin/env bash
# `flutter run` with a readable log: the app's own AppLog lines, Flutter
# errors and real crashes, without Android's system chatter (Surface,
# FlutterJNI, BLASTBufferQueue, Davey!, ...). Hot reload (r / R) still works.
#
#   tool/run.sh                          # like `flutter run`
#   tool/run.sh -d emulator-5554         # any `flutter run` option
#   LOG_ALL=1 tool/run.sh                # everything, unfiltered
#   tool/run.sh --dart-define=LOG_LEVEL=debug   # also unchanged polls and
#                                               # request bodies
set -o pipefail
cd "$(dirname "$0")/.."

if [[ -n "$LOG_ALL" ]]; then
  exec flutter run "$@"
fi

# Error lines from Android that are noise, not app problems.
NOISE='BLASTBufferQueue|FlutterGeolocator|libEGL|eglCodecCommon|gralloc|OpenGLRenderer|EGL_emulation|Parcel|ziparchive'

flutter run "$@" 2>&1 | while IFS= read -r line; do
  case "$line" in
    # The app's own logs: drop the "I/flutter (12345): " prefix.
    [VDIWEF]/flutter*) printf '%s\n' "${line#*): }" ;;
    # Crashes and other Android errors, minus the known noise.
    E/*|F/*|*AndroidRuntime*)
      [[ "$line" =~ $NOISE ]] || printf '%s\n' "$line" ;;
    # Everything else Android prints: hide.
    [VDIW]/*) ;;
    # flutter tool output (Launching, hot reload, "Lost connection", ...).
    *) printf '%s\n' "$line" ;;
  esac
done
