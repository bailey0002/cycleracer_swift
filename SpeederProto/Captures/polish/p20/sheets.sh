#!/bin/zsh
# Step 2 simulator sheets: every rule card over its job's briefing, the notebook and goal-card pages, the pause,
# settings, the briefing strip, a run (cue lane, toast) and the success card. Usage: sheets.sh [name ...]
cd "$(dirname "$0")/../../.."
S=Captures/polish/simshot.sh; O=Captures/polish/p20/sim
base=(SPEEDER_DEMO=1 SPEEDER_RESET_PROGRESS=1 SPEEDER_CHAPTER_CARDS=0)
card() { $S $O/card-$1 "24" $base SPEEDER_MISSION=$2 SPEEDER_HOLD_BRIEFING=1 SPEEDER_GUIDE_CARD=$1 SPEEDER_HOLD_CARD=1; }
want() { [[ $# -eq 0 || ${ARGS[(ie)$1]} -le ${#ARGS} ]]; }
ARGS=($@)
for spec in briefing:0 relay:0 sweep:1 run:3 salvage:8 dive:10 duel:5 respawn:4 derez:5 goals:0 notebook:0 offer:2 garage:0; do
  id=${spec%%:*}; job=${spec##*:}
  if (( ${#ARGS} == 0 )) || (( ${ARGS[(Ie)$id]} )); then card $id $job; fi
done
pick() { (( ${#ARGS} == 0 )) || (( ${ARGS[(Ie)$1]} )); }
pick page-notebook && $S $O/page-notebook "24" $base SPEEDER_MISSION=0 SPEEDER_SCREEN=notebook SPEEDER_NOTE=clean_disc,first_goal SPEEDER_HINT=2 SPEEDER_GOALS=city:kills
pick page-goals && $S $O/page-goals "24" $base SPEEDER_MISSION=0 SPEEDER_SCREEN=goals SPEEDER_GOALS=city:kills,city:clean,city:tunnel,city:streak
pick page-goals-grid && $S $O/page-goals-grid "26" $base SPEEDER_MISSION=5 SPEEDER_SCREEN=goals SPEEDER_GOALS=grid:round,grid:pads
pick page-paused && $S $O/page-paused "24" $base SPEEDER_MISSION=2 SPEEDER_SCREEN=paused SPEEDER_NOTE=clean_disc
pick page-settings && $S $O/page-settings "24" $base SPEEDER_MISSION=0 SPEEDER_SCREEN=settings
pick briefing && $S $O/briefing-relay02 "24" $base SPEEDER_MISSION=2 SPEEDER_HOLD_BRIEFING=1 SPEEDER_NOTE=clean_disc,first_goal SPEEDER_GOALS=city:kills,city:clean,city:streak
pick run && $S $O/run-relay01 "40 48 56 64 72 80" $base SPEEDER_MISSION=0 SPEEDER_GUIDANCE=1
pick result && $S $O/result-relay01 "150 165" $base SPEEDER_MISSION=0 SPEEDER_GUIDANCE=1 SPEEDER_HOLD_RESULT=1
