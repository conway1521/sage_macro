#!/bin/bash
# Everything, unattended, on a fresh clone of this branch. See RUNBOOK_SECOND_MACHINE.md.
#
#   bash SAGE_Bewley/scripts/run_all.sh
#
# Order: environment, memory probe, France then Germany, the US and Italy at
# G+S+A, then each country's G+A, G and G+S on their own, then the modularity
# suite, then the doubled asset grid row on fewer workers. A memory guard stops
# Julia if swap passes SWAP_LIMIT_MB (default 8000), because running out of swap
# restarted the first machine. Exit codes: 3 this machine does not reproduce
# the reference numbers, 4 a step crashed twice, 5 the memory guard tripped.
cd "$(dirname "$0")/.." || exit 1
LOG=scripts/run_all.log
FLAG=scripts/MEMORY_GUARD_TRIPPED
SWAP_LIMIT_MB=${SWAP_LIMIT_MB:-8000}
say() { echo "$(date '+%d %b %H:%M') $*" | tee -a "$LOG"; }
rm -f "$FLAG"

say "Julia: $(julia --version 2>&1)"
PROJECT="."
if julia --project=. -e 'using Pkg; Pkg.instantiate()' >> "$LOG" 2>&1; then
  say "full project environment ready"
else
  say "the full project did not instantiate (it carries Plots, GR, IJulia and Pluto, which the run does not need); trying the runtime-only environment"
  PROJECT="scripts/run_env"
  julia --project="$PROJECT" -e 'using Pkg; Pkg.instantiate()' >> "$LOG" 2>&1 || { say "environment setup failed; see $LOG"; exit 1; }
fi
# Prove the model code loads before spending hours on it.
julia --project="$PROJECT" -e 'include("scripts/modular_stack.jl"); println("the model stack loads")' >> "$LOG" 2>&1 \
  || { say "the model code does not load in this environment; see $LOG"; exit 1; }
say "environment ready, using $PROJECT"

( while true; do
    used=$(sysctl -n vm.swapusage | awk '{gsub("M","",$6); print int($6)}')
    if [ "$used" -gt "$SWAP_LIMIT_MB" ]; then
      touch "$FLAG"; pkill julia
      echo "$(date '+%d %b %H:%M') MEMORY GUARD: swap ${used} MB, Julia stopped" >> "$LOG"
    fi
    sleep 30
  done ) &
GUARD=$!
trap 'kill $GUARD 2>/dev/null' EXIT
caffeinate -dimsu -w $$ &

probe() { SAGE_WORKERS=2 julia --project="$PROJECT" scripts/probe_memory.jl "$1" 16 2>&1 | tee -a "$LOG" | grep '^WORKERS=' | cut -d= -f2; }
W200=${SAGE_WORKERS:-$(probe 200)}
W400=${SAGE_WORKERS_NA400:-$(probe 400)}
if [ -z "$W200" ] || [ -z "$W400" ]; then say "memory probe failed"; exit 1; fi
say "workers: $W200 on the production grid, $W400 on the doubled asset grid"

clean() { for p in $(pgrep julia); do [ "$(ps -o ppid= -p $p | tr -d ' ')" = "1" ] && kill $p; done; }
step() {  # step <log name> <workers> <script and arguments>
  local name=$1 w=$2; shift 2
  for attempt in 1 2; do
    if [ -f "$FLAG" ]; then say "memory guard tripped earlier; stopping"; exit 5; fi
    say "$name, attempt $attempt, $w workers"
    SAGE_WORKERS=$w julia --project="$PROJECT" "$@" > "scripts/$name.txt" 2>&1
    rc=$?
    say "$name exit $rc"
    clean
    if [ -f "$FLAG" ]; then say "memory guard tripped during $name; stopping"; exit 5; fi
    case $rc in
      0|2) return 0 ;;
      3) say "preflight failed: this machine does not reproduce the reference numbers; stopping"; exit 3 ;;
    esac
  done
  say "$name crashed twice; stopping"; exit 4
}

for CODE in FR DE US IT; do
  step "calibrate_country_${CODE}" "$W200" scripts/calibrate_country.jl "$CODE" GSA
done
for CODE in FR DE US IT; do
  for CFG in GA G GS; do
    step "calibrate_country_${CODE}_${CFG}" "$W200" scripts/calibrate_country.jl "$CODE" "$CFG"
  done
done
export SUITE_SKIP_NA400=1
step test_modular "$W200" scripts/test_modular.jl
unset SUITE_SKIP_NA400
step conv_na400 "$W400" scripts/conv_na400.jl
say "ALL DONE"
