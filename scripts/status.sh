#!/usr/bin/env bash
# What is running, and where.
#
#   bash scripts/status.sh
#
# ON THIS MACHINE: Julia jobs (do not close the laptop while any is listed, or
# it stops; nothing else here needs the laptop). ON GITHUB: runs that carry on
# whatever the laptop does; their results wait there until collected.
cd "$(dirname "$0")/.."
echo "=== ON THIS MACHINE (closing the laptop stops these) ==="
jobs=$(ps -eo pid,etime,command | grep -E "[j]ulia .*scripts/[a-z_0-9]+\.jl" | grep -v -- "--worker" |
       sed -E 's/^ *([0-9]+) +([0-9:-]+) .*scripts\/([a-z_0-9]+\.jl)( [A-Z ]*)?.*/  \3\4  (running \2, pid \1)/')
if [ -z "$jobs" ]; then echo "  nothing: the laptop can be closed"; else echo "$jobs"; fi
echo
echo "=== ON GITHUB (runs regardless of the laptop) ==="
gh run list --limit 30 --json databaseId,workflowName,status,conclusion,createdAt,displayTitle \
  -q '.[] | select(.workflowName != "ci" and .workflowName != "pages-build-deployment") | select(.status != "completed") | "  " + .workflowName + "  " + .status + "  (started " + .createdAt + ", run " + (.databaseId|tostring) + ")"' 2>/dev/null |
  { out=$(cat); [ -z "$out" ] && echo "  nothing running" || echo "$out"; }
echo
echo "--- finished on GitHub in the last 24 hours (results to collect) ---"
gh run list --limit 30 --json databaseId,workflowName,status,conclusion,updatedAt \
  -q '.[] | select(.workflowName != "ci" and .workflowName != "pages-build-deployment") | select(.status == "completed") | "  " + .workflowName + "  " + (.conclusion // "") + "  (" + .updatedAt + ", run " + (.databaseId|tostring) + ")"' 2>/dev/null | head -8
