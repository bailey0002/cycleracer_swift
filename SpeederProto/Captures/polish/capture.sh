#!/bin/zsh
# usage: capture.sh <outdir> <seconds> [ENV=VAL ...]   (runs the Mac app headless-ish, kills it after <seconds>)
out=$1; secs=$2; shift 2
mkdir -p "$out"
APP="$(dirname "$0")/../../build/Build/Products/Debug/SpeederProto.app/Contents/MacOS/SpeederProto"
env SPEEDER_DEMO=1 SPEEDER_CAPTURE_DIR="$out" "$@" "$APP" > "$out/log.txt" 2>&1 &
pid=$!
sleep $secs
kill $pid 2>/dev/null
wait $pid 2>/dev/null
ls "$out" | tr '\n' ' '; echo
