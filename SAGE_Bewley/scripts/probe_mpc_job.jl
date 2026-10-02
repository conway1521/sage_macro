# The MPC with effort set by the job, as the hand-to-mouth share rises (France G
# by default): the (hand-to-mouth, MPC) pairs the calibration can choose from
# under decision D1(a), against the same pairs under free effort
# (probe_mpc_one_asset.jl). Effort is not refitted. Last line: S on, to check
# the switch runs through the families.
#
#   julia --project=scripts/run_env scripts/probe_mpc_job.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
c = SAGEConfig(country_config(code; config = "G", S = false, A = false); effort_mode = :job)
line(tag, r, t) = (@printf("%-26s htm %.3f | MPC %.3f (of the htm %.3f) | earnings %+.4f | drop on job loss %.3f | median liquid wealth / median income %.3f | effort %.4f  [%.1f min]\n",
                           tag, r.hand_to_mouth_kvw, r.mpc, r.mpc_htm, r.mpe, r.consumption_drop, r.wealth_p50 / r.median_income, r.mean_effort_employed, t / 60); flush(stdout))
t = @elapsed r = solve_economy(c; cache = false); line("calibrated spread", r, t)
for sh in (0.10, 0.20, 0.30, 0.40), bl in (0.85, 0.70)
    local t = @elapsed rr = solve_economy(SAGEConfig(c; beta_spread = 0.0, impatient_share = sh, beta_low = bl); cache = false)
    line(@sprintf("impatient %.2f at %.2f", sh, bl), rr, t)
end
cs = SAGEConfig(country_config(code; config = "GSA", S = true, A = true); effort_mode = :job)
t = @elapsed r = solve_economy(cs; cache = false)
@printf("G+S+A, job effort: participation %.4f (employed %.4f, unemployed %.4f), multiplier %.2f, MPC %.3f, earnings %+.4f, effort %.4f  [%.1f min]\n",
        r.rate, r.rate_E, r.rate_U, 1 / (1 - r.slope), r.mpc, r.mpe, r.mean_effort_employed, t / 60)
println("DONE")
