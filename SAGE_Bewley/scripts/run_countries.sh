#!/bin/bash
# Overnight chain: wait for the modularity suite, then calibrate DE, US, IT, FR
# in turn with calibrate_country.jl. Exit 0 = calibrated, 2 = not calibrated
# (recorded, move on), 3 = preflight failed (stop everything). Any other exit is
# a crash: one retry, and a second crash stops the chain. The family cache means
# a retry resumes from finished builds. G+S is skipped for IT and FR to fit the
# night; everything else runs for every country.
cd "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley" || exit 1
clean() { for p in $(pgrep julia); do [ "$(ps -o ppid= -p $p | tr -d ' ')" = "1" ] && kill $p; done; }
SUITE_PID=$(pgrep -f "scripts/test_modular.jl" | head -1)
if [ -n "$SUITE_PID" ]; then
  echo "$(date '+%H:%M') waiting for the suite, pid $SUITE_PID"
  while kill -0 "$SUITE_PID" 2>/dev/null; do sleep 60; done
fi
echo "$(date '+%H:%M') suite finished"
sleep 20; clean
for CODE in DE US IT FR; do
  SKIP=0
  if [ "$CODE" = "IT" ] || [ "$CODE" = "FR" ]; then SKIP=1; fi
  for attempt in 1 2; do
    echo "$(date '+%H:%M') $CODE attempt $attempt"
    SKIP_GS=$SKIP julia --project=. scripts/calibrate_country.jl "$CODE" > "scripts/calibrate_country_${CODE}.txt" 2>&1
    rc=$?
    echo "$(date '+%H:%M') $CODE exit $rc"
    clean
    if [ $rc -eq 0 ] || [ $rc -eq 2 ]; then break; fi
    if [ $rc -eq 3 ]; then echo "preflight failed; stopping"; exit 3; fi
    if [ $attempt -eq 2 ]; then echo "$CODE crashed twice; stopping"; exit 4; fi
  done
done
echo "$(date '+%H:%M') ALL DONE"
