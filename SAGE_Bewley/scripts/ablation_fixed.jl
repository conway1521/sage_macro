# The fixed-parameter comparison asked for by the methods review of 18 October (V3_START.md section 111): every
# module switched on and off at one common set of parameters, G+S+A's (with dread in choices and search), so that
# what a module does by itself is separated from what refitting does. Beside it, each configuration at its own
# calibration, and the parameters that move between them.
#
#   julia --project=scripts/run_env scripts/ablation_fixed.jl CODE [1]     (1: the first table only, which fits a job)
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); ONLY1 = length(ARGS) >= 2 && ARGS[2] == "1"
say(x...) = (println(x...); flush(stdout))
row(lab, r) = say(@sprintf("  %-14s %7.4f %7.4f %7.4f %7.4f %7.4f %7.4f %7.4f %7.4f", lab, r.rate, r.hand_to_mouth_kvw,
                           r.wealth_p50 / r.median_income, r.mpc, r.consumption_drop, r.unemployment,
                           isnan(r.search_UL[1]) ? NaN : r.search_UL[1], r.mean_effort_employed))
hdr() = say(@sprintf("  %-14s %7s %7s %7s %7s %7s %7s %7s %7s", "", "partic", "htm", "median", "MPC", "fall", "out", "chanceU", "hours"))

cG = country_config(code; config = "GSA", v3 = :v5m, S = true, A = true)
say(code, " | 1. one set of parameters, G+S+A's: the modules switched one at a time")
hdr()
for (lab, S_, A_) in (("G", false, false), ("G+A", false, true), ("G+S", true, false), ("G+S+A", true, true))
    c = country_config(code; config = "GSA", v3 = :v5m, S = S_, A = A_, search = A_ && cG.search)
    row(lab, solve_economy(c; cache = false))
end
ONLY1 && (println("DONE"); exit(0))
say("\n", code, " | 2. each configuration at its own calibration")
hdr()
for (lab, cfg, S_, A_) in (("G", "G", false, false), ("G+A", "GA", false, true), ("G+S", "GS", true, false), ("G+S+A", "GSA", true, true))
    c = country_config(code; config = cfg, v3 = :v5m, S = S_, A = A_)
    row(lab, solve_economy(c; cache = false))
    say(@sprintf("  %-14s phi %.2f, beta %.4f, gap %.4f%s%s", "", c.phi, c.beta_bar, -c.beta_cell[1],
                 S_ ? @sprintf(", kappa %.2f, sigma %.2f", c.kappa, c.sigma_m) : "", c.search ? @sprintf(", search %s %s", string(c.search_kU), string(c.search_kL)) : ""))
end
println("DONE")
