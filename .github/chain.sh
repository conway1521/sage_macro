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
#               GA -> GSA (the fixed cost of GA)      GSA -> GS
set -euo pipefail
kind=$1; code=$2; cfg=$3; chi_from=${4:-}
if [ "$kind" = 1 ]; then
  file=calibration_country_${code}_${cfg}.txt; [ "$cfg" = GSA ] && file=calibration_country_${code}.txt
  art=calibration-${code}-${cfg}
else
  file=calibration_country_${code}_${cfg}_I.txt; art=calibration2-${code}-${cfg}
fi
[ -f "SAGE_Bewley/scripts/$file" ] || { echo "no $file: nothing to chain"; exit 0; }
pre="$GITHUB_RUN_ID:$art:$file"
run1() { gh workflow run calibrate.yml --ref "$GITHUB_REF_NAME" -f countries="$1" -f configs="$2" -f prereq="$pre"
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
      run2 "$code" GSA ;;
    GSA) run2 "$code" GS ;;
  esac
fi
