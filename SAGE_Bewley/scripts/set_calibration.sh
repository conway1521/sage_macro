#!/usr/bin/env bash
# Set the S+A calibration point in every stage-5 script at once.
#   bash scripts/set_calibration.sh 10.00 0.510
set -euo pipefail
K="$1"; S="$2"; HERE="$(cd "$(dirname "$0")" && pwd)"
for f in sa_level4.jl sa_countries_l4.jl audit_sa.jl wise_participation_logit.jl; do
  sed -i '' -E "s/const KAPPA *= *[0-9.]+/const KAPPA = $K/; s/const SIGMA *= *[0-9.]+/const SIGMA = $S/; s/const K=[0-9.]+/const K=$K/; s/const S=[0-9.]+/const S=$S/" "$HERE/$f"
  echo "$f: $(grep -oE 'const (KAPPA|K) *= *[0-9.]+' "$HERE/$f" | head -1), $(grep -oE 'const (SIGMA|S) *= *[0-9.]+' "$HERE/$f" | head -1)"
done
# the figures script reads kappa/sigma from the results file, nothing to set
echo "sa_figures_l4.jl reads the point from sa_level4_results.txt"
