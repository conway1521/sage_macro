# The reporting layer (reporting_core.jl, welfare_ce): checks on France G+A.
#  1. the propensities add up: MPC + saving - earnings = 1 (no participation credit);
#  2. the value splits into its parts with a small remainder (the choice value);
#  3. a baseline against itself is worth exactly zero;
#  4. a real policy: unemployment benefits 10% higher, financed by the UI tax.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/test_reporting.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
c = country_config("FR"; config = "GA", S = false, A = true)
t = @elapsed rB = solve_economy(c; cache = false)
w = rB.welfare
@printf("solved in %.1f min\n", t / 60)
@printf("1. propensities: MPC %.4f + saving %.4f - earnings %.4f = %.6f (should be 1); participation per windfall %.5f\n",
        rB.mpc, rB.mps, rB.mpe, rB.mpc + rB.mps - rB.mpe, rB.mpp)
@printf("2. value per head %.4f = consumption %.4f + effort %.4f + belonging %.4f + remainder %.4f\n",
        w.V, w.Vc, w.Ve, w.Vb, w.V - w.Vc - w.Ve - w.Vb)
z = welfare_ce(rB, rB)
@printf("3. baseline against itself: %.2e\n", z.total)
rP = solve_economy(SAGEConfig(c; rr = c.rr * 1.1); cache = false)
ce = welfare_ce(rB, rP)
@printf("4. benefits +10%%: welfare %+.3f%% of consumption (consumption %+.3f, effort %+.3f, belonging %+.3f, rest %+.3f); lower-education %+.3f%%, higher %+.3f%% | agency %+.4f, hardship %+.4f\n",
        100 * ce.total, 100 * ce.parts.consumption, 100 * ce.parts.effort, 100 * ce.parts.belonging, 100 * ce.parts.choice_and_rest,
        100 * ce.cells[1], 100 * ce.cells[2], rP.A - rB.A, rP.hardship - rB.hardship)
@printf("   by status today: employed %+.3f%%, unemployed %+.3f%%\n", 100 * ce.employed, 100 * ce.unemployed)
println("DONE")
