#!/bin/bash
# Start the next session when the current one ends, but only if it ended cleanly
# (deadline reached, or too little time left to start a step). A crash, a memory
# guard stop or a failed preflight is left for a person to look at.
#   bash chain_next.sh <pid of the running session's caffeinate wrapper>
cd "$(dirname "$0")/../.." || exit 1
LOG=SAGE_Bewley/scripts/run_session.log
while kill -0 "$1" 2>/dev/null; do sleep 30; done
sleep 10
last=$(tail -1 "$LOG")
if echo "$last" | grep -qE "time is up|minutes left; stopping here"; then
  echo "$(date '+%d %b %H:%M') chain: previous session ended cleanly, starting the next" >> "$LOG"
  nohup caffeinate -is bash SAGE_Bewley/scripts/run_session.sh > SAGE_Bewley/scripts/run_session.out 2>&1 < /dev/null &
else
  echo "$(date '+%d %b %H:%M') chain: NOT starting another session; the last line was: $last" >> "$LOG"
fi
