#!/usr/bin/env bash
# Drive the running app on an Android emulator/phone from the command line,
# so an agent (or a person) can test live: see the screen, tap, type, move GPS.
#
#   scripts/live/adb.sh devices                 # list targets
#   scripts/live/adb.sh screenshot [file.png]   # default: build/live/screen.png
#   scripts/live/adb.sh ui                      # visible texts/labels + centers
#   scripts/live/adb.sh tap "Terima"            # tap the element with that text/label
#   scripts/live/adb.sh tapxy 540 1800          # tap a coordinate
#   scripts/live/adb.sh type "driver@cariambulan.id"   # into the focused field
#   scripts/live/adb.sh back
#   scripts/live/adb.sh geo -7.2575 112.7521    # fake GPS (emulator only), lat lon
#   scripts/live/adb.sh logs [seconds]          # app log (AppLog lines), default 20 s
#
# Several devices: ANDROID_SERIAL=emulator-5556 scripts/live/adb.sh ...
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT=build/live
mkdir -p "$OUT"

# Matches every node with text/content-desc and prints "x y<TAB>label".
nodes() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null
  adb exec-out cat /sdcard/ui.xml | tr '>' '\n' | grep -E 'text="[^"]+"|content-desc="[^"]+"' |
    sed -E 's/.*text="([^"]*)".*content-desc="([^"]*)".*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\3 \4 \5 \6\t\1 \2/' |
    awk -F'\t' '{ split($1, b, " "); printf "%d %d\t%s\n", (b[1]+b[3])/2, (b[2]+b[4])/2, $2 }' |
    sed -E 's/\t +/\t/; s/ +$//'
}

cmd=${1:-help}
shift || true

case "$cmd" in
  devices) adb devices -l ;;
  screenshot)
    file=${1:-$OUT/screen.png}
    adb exec-out screencap -p >"$file"
    echo "$file"
    ;;
  ui) nodes ;;
  tap)
    [[ $# -ge 1 ]] || { echo "usage: tap <text>" >&2; exit 2; }
    match=$(nodes | grep -F -- "$1" | head -1 || true)
    [[ -n "$match" ]] || { echo "No element with \"$1\" on screen. Visible:" >&2; nodes >&2; exit 1; }
    read -r x y _ <<<"$match"
    adb shell input tap "$x" "$y"
    echo "tapped \"$1\" at $x,$y"
    ;;
  tapxy) adb shell input tap "$1" "$2" ;;
  type)
    # adb input needs spaces as %s.
    adb shell input text "${1// /%s}"
    ;;
  back) adb shell input keyevent KEYCODE_BACK ;;
  geo)
    [[ $# -eq 2 ]] || { echo "usage: geo <lat> <lon>" >&2; exit 2; }
    adb emu geo fix "$2" "$1" # emulator wants longitude first
    echo "GPS set to $1,$2"
    ;;
  logs)
    secs=${1:-20}
    # Clear, wait, then dump what the app logged meanwhile.
    adb logcat -c
    sleep "$secs"
    adb logcat -d -s flutter:V | sed -E 's/^.*flutter *\( *[0-9]+\): //'
    ;;
  *) sed -n '2,17p' "$0" ;;
esac
