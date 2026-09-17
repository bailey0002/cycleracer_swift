#!/bin/zsh
# usage: record.sh <outdir> <start> <end> [ENV=VAL ...]
# Runs the Mac app in demo mode and records scene seconds <start>..<end> (60 fps, every frame)
# into <outdir>/clip.mov (SPEEDER_RECORD_NAME=<name> renames it). Waits for the app's
# "video saved" line instead of a fixed sleep: the per-frame readback slows rendering, but the
# demo's fixed 1/60 s step keeps the clip itself at exact speed. Also saves the usual PNG stills.
# Example: record.sh grid-ramp 4 12 SPEEDER_VARIANT=grid-snap SPEEDER_DEMO_SCRIPT=ramp SPEEDER_WINDOW=1920x1080
out=$1; start=$2; end=$3; shift 3
mkdir -p "$out"
APP="$(dirname "$0")/../../build/Build/Products/Debug/SpeederProto.app/Contents/MacOS/SpeederProto"
env SPEEDER_DEMO=1 SPEEDER_CAPTURE_DIR="$out" SPEEDER_RECORD="$start,$end" "$@" "$APP" > "$out/log.txt" 2>&1 &
pid=$!
limit=$(( 40 + ${end%.*} * 6 ))
for (( i = 0; i < limit; i++ )); do
  sleep 1
  grep -q "video saved\|video FAILED" "$out/log.txt" 2>/dev/null && break
done
kill $pid 2>/dev/null
wait $pid 2>/dev/null
grep "video " "$out/log.txt"
ls -la "$out"/*.mov 2>/dev/null
