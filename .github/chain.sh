#!/bin/bash
# After a calibration job succeeds, start the calibrations that need it. Nothing
# is written to the repository: each new job fetches the calibration file it
# needs from this run's artifact (input `prereq`, "run id:artifact:file"), and
# the files are reviewed and committed by hand. Called by calibrate.yml (kind 1,
# one asset) and calibrate2.yml (kind 2, two assets). A calibration that misses
# its targets writes no file (exit 2), so it starts nothing.
#
#   .github/chain.sh KIND CODE CFG [CHI_FROM]
#
# The order:
#   one asset   GSA -> GS (sigma from GSA)      GSAE -> GSE
#   two assets  FR GA -> DE GA, IT GA (chi0 from France)
#               G -> GE      GA -> GSA, GAE (the fixed cost of GA)      GSA -> GS
set -euo pipefail
kind=$1; code=$2; cfg=$3; chi_from=${4:-}
v3=${SAGE_V3:-0}; floor=${SAGE_FLOOR:-0}; edu=${SAGE_EDU:-0}; trans=${SAGE_TRANS:-0}
if [ "$kind" = 1 ]; then
  file=calibration_country_${code}_${cfg}.txt; [ "$cfg" = GSA ] && file=calibration_country_${code}.txt
  [ "$v3" = 1 ] && file=calibration_v3_${code}_${cfg}.txt        # version 3 files, every configuration
  if [ "$v3" = 1 ]; then tag=v3; [ "$floor" = 1 ] && tag=${tag}f; [ "$edu" = 1 ] && tag=${tag}e; [ "$trans" = 1 ] && tag=${tag}t; file=calibration_${tag}_${code}_${cfg}.txt; fi        # the regime's files
  art=calibration-${code}-${cfg}
else
  file=calibration_country_${code}_${cfg}_I.txt; art=calibration2-${code}-${cfg}
fi
[ -f "SAGE_Bewley/scripts/$file" ] || { echo "no $file: nothing to chain"; exit 0; }
pre="$GITHUB_RUN_ID:$art:$file"
run1() { gh workflow run calibrate.yml --ref "$GITHUB_REF_NAME" -f countries="$1" -f configs="$2" -f prereq="$pre" -f v3="$v3" -f floor="$floor" -f edu="$edu" -f trans="$trans" -f floor_from="${SAGE_FLOOR_FROM:-G}"
         echo "started one-asset $1 $2, with $file from run $GITHUB_RUN_ID"; }
run2() { gh workflow run calibrate2.yml --ref "$GITHUB_REF_NAME" -f countries="$1" -f configs="$2" -f chi_from="${3:-}" -f prereq="$pre"
         echo "started two-asset $1 $2 ${3:+(chi0 from $3)}, with $file from run $GITHUB_RUN_ID"; }
if [ "$kind" = 1 ]; then
  case "$cfg" in
    GSA)  run1 "$code" GS ;;
    GSAE) run1 "$code" GSE ;;
  esac
else
  case "$cfg" in
    GA)
      [ "$code" = FR ] && [ -z "$chi_from" ] && run2 "DE IT" GA FR
      run2 "$code" "GSA GAE" ;;
    G) run2 "$code" GE ;;
    GSA) run2 "$code" GS ;;
  esac
fi
