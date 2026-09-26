#!/bin/zsh
# usage: simshot.sh <outprefix> "<delays e.g. 18 30>" [ENV=VAL ...]   (launches the simulator build with SIMCTL_CHILD_ env, screenshots at each delay from launch)
out=$1; delays=($=2); shift 2
UD=CC7815D7-8D0B-43FE-A4E1-EA4CBED5E83A
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl terminate $UD com.markbailey.speeder.ios 2>/dev/null
envs=()
for kv in "$@"; do envs+=("SIMCTL_CHILD_$kv"); done
env "${envs[@]}" xcrun simctl launch $UD com.markbailey.speeder.ios >/dev/null
t0=$(date +%s); last=0
for d in $delays; do sleep $((d - last)); last=$d; xcrun simctl io $UD screenshot "$out-$d.png" >/dev/null 2>&1; done
xcrun simctl terminate $UD com.markbailey.speeder.ios 2>/dev/null
ls $out-*.png | tr '\n' ' '; echo
