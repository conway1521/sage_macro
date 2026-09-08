#!/usr/bin/env bash
# Set the effort grid of the participation core in every stage-5 script.
#   bash scripts/set_ne.sh 80
set -euo pipefail
NE="$1"; HERE="$(cd "$(dirname "$0")" && pwd)"
sed -i '' -E "s/const NA, NE = 200, [0-9]+/const NA, NE = 200, $NE/" "$HERE/sa_level4.jl"
for f in sa_countries_l4.jl audit_sa.jl wise_participation_logit.jl sa_figures_l4.jl sa_recalibrate_l5b.jl sa_valley.jl; do
  sed -i '' -E "s/ne *= *40([,;) ])/ne = $NE\1/g; s/na = 200, ne = [0-9]+/na = 200, ne = $NE/g; s/na=200, ne=[0-9]+/na=200, ne=$NE/g" "$HERE/$f"
  echo "$f: $(grep -oE 'ne *= *[0-9]+' "$HERE/$f" | sort -u | tr '\n' ' ')"
done
sed -i "" -E "s/^const NE = [0-9]+/const NE = $NE/" "$HERE/sa_recalibrate_l5b.jl"
sed -i "" -E "s/const NE_DEFAULT = [0-9]+/const NE_DEFAULT = $NE/" "$HERE/audit_sa.jl"
sed -i "" -E "s/const NE_FIG = [0-9]+/const NE_FIG = $NE/" "$HERE/sa_figures_l4.jl" "$HERE/sa_omega_l4.jl"
echo "sa_level4.jl: $(grep -oE 'const NA, NE = 200, [0-9]+' "$HERE/sa_level4.jl")"
