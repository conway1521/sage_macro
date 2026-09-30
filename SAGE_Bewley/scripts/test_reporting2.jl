# The reporting layer on two assets (two_asset_welfare_parts, egm2_core.jl).
#  1. the illiquid asset inert: welfare parts and propensities equal the one-asset ones;
#  2. France G+A on two assets: the propensities add up (saving includes the net
#     illiquid outlay) and the value splits with a small remainder;
#  3. a real policy: unemployment benefits 10% higher, on two assets.
#
#   julia --project=scripts/run_env scripts/test_reporting2.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
c1 = country_config(code; config = "GA", S = false, A = true)
inert(c) = SAGEConfig(c; illiquid = true, chi0 = 1e10, death = 0.0, b_max = c.a_max, nb = c.na, nk = 4, k_max = 5.0)
r1 = solve_economy(c1; cache = false); ri = solve_economy(inert(c1); cache = false)
gap = maximum(abs.([r1.welfare.V - ri.welfare.V, r1.welfare.Vc - ri.welfare.Vc, r1.welfare.Ve - ri.welfare.Ve,
                    r1.welfare.Vb - ri.welfare.Vb, r1.mps - ri.mps, r1.mpe - ri.mpe, r1.mpp - ri.mpp]))
@printf("1. inert illiquid asset against one asset: largest gap in welfare parts and propensities %.1e\n", gap)
flush(stdout)
c = country_config(code; config = "GA", S = false, A = true, illiquid = true)
t = @elapsed rB = solve_economy(c; cache = false)
w = rB.welfare
@printf("2. %s G+A two assets (%.1f min): MPC %.4f + saving %.4f - earnings %.4f = %.6f; participation per windfall %.5f\n",
        code, t / 60, rB.mpc, rB.mps, rB.mpe, rB.mpc + rB.mps - rB.mpe, rB.mpp)
@printf("   value %.4f = consumption %.4f + effort %.4f + belonging %.4f + remainder %.4f\n",
        w.V, w.Vc, w.Ve, w.Vb, w.V - w.Vc - w.Ve - w.Vb)
@printf("   poor hand-to-mouth %.4f, wealthy %.4f; MPC of the wealthy hand-to-mouth %.3f\n", rB.hand_to_mouth_kvw, rB.wealthy_htm, rB.mpc_wealthy)
flush(stdout)
rP = solve_economy(SAGEConfig(c; rr = c.rr * 1.1); cache = false)
ce = welfare_ce(rB, rP)
@printf("3. benefits +10%%: welfare %+.3f%% (consumption %+.3f, effort %+.3f, belonging %+.3f, rest %+.3f); lower-education %+.3f%%, higher %+.3f%%; employed %+.3f%%, unemployed %+.3f%%\n",
        100 * ce.total, 100 * ce.parts.consumption, 100 * ce.parts.effort, 100 * ce.parts.belonging, 100 * ce.parts.choice_and_rest,
        100 * ce.cells[1], 100 * ce.cells[2], 100 * ce.employed, 100 * ce.unemployed)
println("DONE")
