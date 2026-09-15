#!/bin/zsh
# Post-run sequence for stage 6, run once sa_stage6.jl at omega 0.30 has
# written sa_stage6_results.txt. Sequential on purpose: the parallel scripts
# each take the machine's cores.
set -u
cd "$(dirname "$0")/.."
run() { echo "=== $1"; julia --project=. "scripts/$1" > "scripts/${1%.jl}.txt" 2>&1; echo "    exit $? at $(date +%H:%M)"; }
run s6_check_identity.jl
run s6_check_theta.jl
run s6_second_path.jl
run s6_check_na.jl
echo "=== sa_stage6.jl 0.15"; julia --project=. scripts/sa_stage6.jl 0.15 > scripts/sa_stage6_om015.txt 2>&1; echo "    exit $? at $(date +%H:%M)"
echo "=== sa_stage6.jl 0.50"; julia --project=. scripts/sa_stage6.jl 0.50 > scripts/sa_stage6_om050.txt 2>&1; echo "    exit $? at $(date +%H:%M)"
run s6_omega_table.jl
echo "ALL DONE"
