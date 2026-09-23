#!/bin/bash
# Piecemeal runner: does as much as fits in one sitting, stops by itself when the
# time is up, and picks up where it left off next time.
#
#   bash SAGE_Bewley/scripts/run_session.sh                 # a 2.5 hour session
#   SESSION_HOURS=2 bash SAGE_Bewley/scripts/run_session.sh # any length
#   bash SAGE_Bewley/scripts/run_session.sh status          # what is done, what is left
#
# Stop early at any time with Ctrl-C. At most the family build in progress is
# lost, about ten minutes: families, each country's fitted effort scale and
# discount spread, and every finished step are kept on disk, and a finished step
# is never run again. It runs at low priority on 10 workers so the laptop stays
# usable; SAGE_WORKERS=13 when you are away from it.
#
# The steps, most valuable first: France, Germany, the US and Italy at G+S+A;
# then each country's G+A and G; then each country's G+S; then the modularity
# suite. The doubled asset grid row needs 4 to 5 GB a worker and is left out
# unless INCLUDE_NA400=1. A memory guard stops Julia if swap GROWS by 4 GB over
# its lowest level this session. Not the absolute level: macOS leaves old pages
# in swap long after the pressure has gone (8.3 GB used with 72 percent of memory
# free, 2026-09-23), so an absolute threshold trips on nothing. The runaway it
# guards against took swap from 1.5 GB to 28 GB.
cd "$(dirname "$0")/.." || exit 1
SESSION_HOURS=${SESSION_HOURS:-2.5}
W=${SAGE_WORKERS:-10}
W400=${SAGE_WORKERS_NA400:-3}
INCLUDE_NA400=${INCLUDE_NA400:-0}
SWAP_GROWTH_MB=${SWAP_GROWTH_MB:-4000}
MIN_START_MIN=${MIN_START_MIN:-15}
LOG=scripts/run_session.log
say() { echo "$(date '+%d %b %H:%M') $*" | tee -a "$LOG"; }

# name | minutes on 13 workers | how to tell it is done | script and arguments
steps() {
  for c in FR DE US IT; do echo "calibrate_country_${c}|85|cal ${c} GSA|scripts/calibrate_country.jl ${c} GSA"; done
  for c in FR DE US IT; do for g in GA G; do echo "calibrate_country_${c}_${g}|10|cal ${c} ${g}|scripts/calibrate_country.jl ${c} ${g}"; done; done
  for c in FR DE US IT; do echo "calibrate_country_${c}_GS|55|cal ${c} GS|scripts/calibrate_country.jl ${c} GS"; done
  echo "test_modular|150|suite|scripts/test_modular.jl"
  if [ "$INCLUDE_NA400" = "1" ]; then echo "conv_na400|150|na400|scripts/conv_na400.jl"; fi
}

is_done() {  # prints the outcome and succeeds if the step needs no more work
  set -- $1
  case $1 in
    cal)
      local f="scripts/calibration_country_$2"
      [ "$3" != "GSA" ] && f="${f}_$3"
      if [ -f "$f.txt" ]; then echo "calibrated"; return 0; fi
      if [ -f "$f.not_calibrated.txt" ]; then echo "NOT calibrated (see its log)"; return 0; fi
      return 1 ;;
    suite)
      if grep -qE "MODULARITY SUITE (PASSES|FAILS)" scripts/test_modular.txt 2>/dev/null &&
         grep -q "France's footing" scripts/test_modular.txt; then
        grep -E "checks pass|MODULARITY SUITE (PASSES|FAILS)" scripts/test_modular.txt | tr '\n' ' '; echo; return 0
      fi
      return 1 ;;
    na400)
      if grep -q "^DONE" scripts/conv_na400.txt 2>/dev/null; then grep -E "SETTLED" scripts/conv_na400.txt | tail -1; return 0; fi
      return 1 ;;
  esac
  return 1
}

status() {
  local left=0
  echo "step                               state"
  echo "-------------------------------------------------------------------"
  while IFS='|' read -r name mins check cmd; do
    if out=$(is_done "$check"); then
      printf "%-34s %s\n" "$name" "$out"
    else
      [ "$name" = "conv_na400" ] && m=$mins || m=$(( mins * 13 / W ))
      printf "%-34s pending, about %d min\n" "$name" "$m"
      left=$(( left + m ))
    fi
  done < <(steps)
  echo "-------------------------------------------------------------------"
  if [ "$left" -eq 0 ]; then echo "nothing left to run"
  else
    local per; per=$(echo "$SESSION_HOURS * 60 - 5" | bc -l)   # each session loses about 5 minutes starting up
    printf "about %.1f hours left on %d workers, so roughly %d sessions of %s hours\n" \
      "$(echo "$left/60" | bc -l)" "$W" "$(echo "($left + $per - 1) / $per" | bc)" "$SESSION_HOURS"
  fi
  [ "$INCLUDE_NA400" = "1" ] || echo "(the doubled asset grid row is left out; INCLUDE_NA400=1 adds it)"
}

if [ "$1" = "status" ]; then status; exit 0; fi

# ----------------------------------------------------------------- setup --
say "session starts: ${SESSION_HOURS} h, ${W} workers, $(julia --version 2>&1)"
PROJECT="."
if ! julia --project=. -e 'using Pkg; Pkg.instantiate()' >> "$LOG" 2>&1; then
  say "the full project did not instantiate; using the runtime-only environment"
  PROJECT="scripts/run_env"
  julia --project="$PROJECT" -e 'using Pkg; Pkg.instantiate()' >> "$LOG" 2>&1 || { say "environment setup failed; see $LOG"; exit 1; }
fi
julia --project="$PROJECT" -e 'include("scripts/modular_stack.jl"); println("the model stack loads")' >> "$LOG" 2>&1 \
  || { say "the model code does not load in this environment; see $LOG"; exit 1; }
if [ "${PROBE:-0}" = "1" ]; then
  probe() { SAGE_WORKERS=2 julia --project="$PROJECT" scripts/probe_memory.jl "$1" 16 2>&1 | tee -a "$LOG" | grep '^WORKERS=' | cut -d= -f2; }
  W=$(probe 200); W400=$(probe 400)
  { [ -n "$W" ] && [ -n "$W400" ]; } || { say "memory probe failed"; exit 1; }
  say "memory probe: $W workers on the production grid, $W400 on the doubled asset grid"
fi
caffeinate -i -w $$ &

DEADLINE=0
if [ "$(echo "$SESSION_HOURS > 0" | bc -l)" = "1" ]; then
  DEADLINE=$(( $(date +%s) + $(echo "$SESSION_HOURS * 3600 / 1" | bc) ))
fi
swap_used() { sysctl -n vm.swapusage | awk '{gsub("M","",$6); print int($6)}'; }
SWAP_BASE=$(swap_used)
say "swap in use at the start: ${SWAP_BASE} MB; the guard trips at ${SWAP_GROWTH_MB} MB above its lowest level"
CUR=""
stop_julia() {
  local jp=$1; [ -z "$jp" ] && return
  local kids; kids=$(pgrep -P "$jp")
  kill "$jp" $kids 2>/dev/null; sleep 5; kill -9 "$jp" $kids 2>/dev/null
}
trap 'say "stopped by hand; resumes here next session"; stop_julia "$CUR"; exit 130' INT TERM

RESULT=""
run_step() {  # run_step <name> <workers> <script and arguments>; sets RESULT
  local name=$1 w=$2; shift 2
  SAGE_WORKERS=$w nice -n 10 julia --project="$PROJECT" "$@" > "scripts/$name.txt" 2>&1 < /dev/null &
  CUR=$!
  local why=""
  while kill -0 "$CUR" 2>/dev/null; do
    sleep 15
    if [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]; then why=deadline; break; fi
    local used; used=$(swap_used)
    [ "$used" -lt "$SWAP_BASE" ] && SWAP_BASE=$used
    if [ $(( used - SWAP_BASE )) -gt "$SWAP_GROWTH_MB" ]; then why=memory; break; fi
  done
  if [ -n "$why" ]; then stop_julia "$CUR"; wait "$CUR" 2>/dev/null; RESULT=$why; CUR=""; return; fi
  wait "$CUR"; RESULT="exit $?"; CUR=""
}

# ------------------------------------------------------------------ steps --
while IFS='|' read -r name mins check cmd; do
  is_done "$check" > /dev/null && continue
  if [ "$DEADLINE" -gt 0 ] && [ $(( DEADLINE - $(date +%s) )) -lt $(( MIN_START_MIN * 60 )) ]; then
    say "under $MIN_START_MIN minutes left; stopping here, $name is next"
    status | tail -3; exit 0
  fi
  w=$W; [ "$name" = "conv_na400" ] && w=$W400
  [ "$name" = "test_modular" ] && export SUITE_SKIP_NA400=1
  ok=0
  for attempt in 1 2; do
    say "$name: starting (attempt $attempt, $w workers)"
    run_step "$name" "$w" $cmd
    case $RESULT in
      deadline) say "$name: time is up; stopped part-way, resumes here next session"; status | tail -3; exit 0 ;;
      memory)   say "$name: MEMORY GUARD, swap grew more than ${SWAP_GROWTH_MB} MB (lowest ${SWAP_BASE} MB); Julia stopped"; exit 5 ;;
      "exit 0") say "$name: done"; ok=1; break ;;
      "exit 2") say "$name: finished, NOT calibrated (recorded)"; ok=1; break ;;
      "exit 3") say "$name: preflight failed, this machine does not reproduce the reference numbers"; exit 3 ;;
      *)        say "$name: crashed ($RESULT); see scripts/$name.txt" ;;
    esac
  done
  unset SUITE_SKIP_NA400
  [ $ok -eq 1 ] || { say "$name crashed twice; stopping"; exit 4; }
done < <(steps)
say "ALL DONE"
status
