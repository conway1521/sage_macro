#!/bin/zsh
# Post-run sequence for stage 7. Sequential: each script takes the machine.
set -u
cd "$(dirname "$0")/.."
run() { echo "=== $1"; julia --project=. "scripts/$1" > "scripts/${1%.jl}.txt" 2>&1; echo "    exit $? at $(date +%H:%M)"; }
run s7_check_identity.jl
run s7_check_theta.jl
run s7_second_path.jl
run s7_check_na.jl
echo "=== sa_stage7.jl 0.15"; julia --project=. scripts/sa_stage7.jl 0.15 > scripts/sa_stage7_om015.txt 2>&1; echo "    exit $? at $(date +%H:%M)"
echo "=== sa_stage7.jl 0.50"; julia --project=. scripts/sa_stage7.jl 0.50 > scripts/sa_stage7_om050.txt 2>&1; echo "    exit $? at $(date +%H:%M)"
run s7_omega_table.jl
echo "ALL DONE"
