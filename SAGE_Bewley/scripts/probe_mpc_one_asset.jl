# What the one-asset model's MPC does as the hand-to-mouth share rises (France G
# by default). Two routes: a wider uniform patience spread, and an impatient
# group (share at effective patience beta_low). Effort is not refitted here.
#
#   julia --project=scripts/run_env scripts/probe_mpc_one_asset.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
c = country_config(code; config = cfg, S = false, A = occursin('A', cfg))
line(tag, r) = (@printf("%-28s htm %.3f | MPC %.3f (of the htm %.3f) | saving %.3f | earnings %+.3f | median liquid wealth / median income %.3f | effort %.4f\n",
                        tag, r.hand_to_mouth_kvw, r.mpc, r.mpc_htm, r.mps, r.mpe, r.wealth_p50 / r.median_income, r.mean_effort_employed); flush(stdout))
line("calibrated", solve_economy(c; cache = false))
for sp in (0.02, 0.04, 0.06, 0.08, 0.10)
    line(@sprintf("uniform spread %.2f", sp), solve_economy(SAGEConfig(c; beta_spread = sp); cache = false))
end
for sh in (0.05, 0.10, 0.20, 0.30, 0.40), bl in (0.85, 0.70)
    line(@sprintf("impatient %.2f at %.2f", sh, bl), solve_economy(SAGEConfig(c; beta_spread = 0.0, impatient_share = sh, beta_low = bl); cache = false))
end
println("DONE")
