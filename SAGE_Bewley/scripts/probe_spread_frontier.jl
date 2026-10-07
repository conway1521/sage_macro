# Can the MPC be a target on the one-asset base? (V3_START.md, section 34.) The standard device is
# heterogeneity in patience within a group: a spread of discount factors (Krusell and Smith 1998;
# Carroll, Slacalek, Tokuoka and White 2017), which the engine has (`beta_spread`, `nbeta` equal-mass
# nodes below the top) and the base sets to zero. For each spread, top patience is refitted to the
# hand-to-mouth share and everything else is held at the calibration (the gap by education, the
# floor, the income process): what the MPC, median liquid wealth and the fall in consumption on job
# loss then are, against the survey MPC (HFCS 2021, mean self-reported share of a windfall of one
# month's income spent within a year).
#
#   julia --project=scripts/run_env scripts/probe_spread_frontier.jl [CODE] [CONFIG] [spreads, comma separated]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "IT"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
spreads = length(ARGS) >= 3 ? parse.(Float64, split(ARGS[3], ",")) : [0.0, 0.04, 0.08, 0.12, 0.16]
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
G = hf("htm_model_narrow_total", "education", "below tertiary") - hf("htm_model_narrow_total", "education", "tertiary")
@printf("%s %s, the base: top patience %.4f, gap %.4f, floor %.4f | targets: hand-to-mouth %.3f, its difference by education %.3f, liquid wealth over income %.3f | survey MPC %.3f\n",
        code, cfg, c0.beta_bar, -c0.beta_cell[1], c0.cfloor, H, G, L, M)
@printf("%-7s | %8s %9s | %6s %8s %8s %6s %9s | %s\n", "spread", "top", "lowest", "htm", "by educ.", "liq/inc", "MPC", "job loss", "MPC off the survey by")
for sp in spreads
    t0 = time()
    at(b) = solve_economy(SAGEConfig(c0; beta_spread = sp, nbeta = 5, beta_bar = b); cache = false)
    lo, hi = 0.86, 0.975
    for _ in 1:10
        mid = (lo + hi) / 2
        at(mid).hand_to_mouth_kvw > H ? (lo = mid) : (hi = mid)          # the share falls with patience
    end
    b = (lo + hi) / 2; r = at(b)
    hg = sum(r.pooled[1].hmass) / sum(r.pooled[1].mass) - sum(r.pooled[2].hmass) / sum(r.pooled[2].mass)
    @printf("%-7.3f | %8.4f %9.4f | %6.3f %8.3f %8.3f %6.3f %9.3f | %+.3f   [%.0f min]\n", sp, b, b - sp * 0.9 + c0.beta_cell[1], r.hand_to_mouth_kvw, hg,
            r.wealth_p50 / r.median_income, r.mpc, r.consumption_drop, r.mpc - M, (time() - t0) / 60)
    flush(stdout)
end
println("DONE")
