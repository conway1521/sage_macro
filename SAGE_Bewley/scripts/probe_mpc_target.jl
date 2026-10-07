# What targeting the MPC costs on the one-asset base (V3_START.md, section 35). A spread of patience
# does not move the MPC at a given hand-to-mouth share (probe_spread_frontier.jl), so on one asset the
# MPC and the hand-to-mouth share are one decision: patience. Here patience is fitted to the survey MPC
# in place of the hand-to-mouth share (as the calibrations that target the MPC on one asset do), the
# gap by education and everything else held, and the hand-to-mouth share and liquid wealth are read
# off. With a floor (Italy) the row is given at the calibrated floor and without it.
#
#   julia --project=scripts/run_env scripts/probe_mpc_target.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "IT"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
function hf(moment, grp = "all", sub = "all")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == grp && f[5] == sub && return parse(Float64, f[6])
    end
    NaN
end
c0 = country_config(code; config = cfg, v3 = :floor_edu_trans, S = false, A = occursin('A', cfg))
H = hf("htm_model_narrow_total"); L = hf("liquid_kvw_to_disposable_income_ratio_of_medians"); M = hf("mpc_mean")
@printf("%s %s | survey MPC %.3f | hand-to-mouth %.3f (broad liquid wealth: %.3f), liquid wealth over income %.3f (broad: %.3f)\n", code, cfg, M, H,
        hf("htm_model_broad_total"), L, hf("liquid_broad_to_disposable_income_ratio_of_medians"))
@printf("%-34s | %8s | %6s %6s %8s %9s\n", "", "patience", "MPC", "htm", "liq/inc", "job loss")
function row(tag, c, target)
    at(b) = solve_economy(SAGEConfig(c; beta_bar = b); cache = false)
    b = c.beta_bar
    if target !== nothing
        lo, hi = 0.80, 0.975
        for _ in 1:11
            mid = (lo + hi) / 2
            at(mid).mpc > target ? (lo = mid) : (hi = mid)          # the MPC falls with patience
        end
        b = (lo + hi) / 2
    end
    r = at(b)
    @printf("%-34s | %8.4f | %6.3f %6.3f %8.3f %9.3f\n", tag, b, r.mpc, r.hand_to_mouth_kvw, r.wealth_p50 / r.median_income, r.consumption_drop)
    flush(stdout)
end
row("the base (patience on hand-to-mouth)", c0, nothing)
row("patience on the survey MPC", c0, M)
c0.cfloor > 0 && row("the same, without the floor", SAGEConfig(c0; cfloor = 0.0), M)
println("DONE")
