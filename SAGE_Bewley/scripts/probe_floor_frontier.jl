# Italy's choice on one asset (V3_START.md, section 30): its liquid wealth target is met through the
# means-tested floor, which raises patience and holds the MPC down. The frontier: for each level of
# the floor, patience refitted to the hand-to-mouth share (the gap by education and everything else
# held at the calibration), and what liquid wealth, the MPC and the fall in consumption on job loss
# then are. The band of France and Germany for liquid wealth is 0.09; Italy's, with the floor, 0.03.
#
#   julia --project=scripts/run_env scripts/probe_floor_frontier.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "IT"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "G"
function hf(moment)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "all" && f[5] == "all" && return parse(Float64, f[6])
    end
    NaN
end
c0 = country_config(code; config = cfg, v3 = :floor_edu_trans, S = false, A = occursin('A', cfg))
H = hf("htm_model_narrow_total"); L = hf("liquid_kvw_to_disposable_income_ratio_of_medians"); M = hf("mpc_mean")
@printf("%s %s, the base: floor %.4f, top patience %.4f | targets: hand-to-mouth %.3f, liquid wealth over income %.3f | survey MPC %.3f\n", code, cfg, c0.cfloor, c0.beta_bar, H, L, M)
@printf("%-22s | %8s | %6s %8s %6s %9s | %s\n", "floor, share of the base's", "patience", "htm", "liq/inc", "MPC", "job loss", "liquid wealth off its target by")
for sh in (1.0, 0.8, 0.6, 0.4, 0.2, 0.0)
    t0 = time()
    at(b) = solve_economy(SAGEConfig(c0; cfloor = sh * c0.cfloor, beta_bar = b); cache = false)
    lo, hi = 0.84, 0.97
    for _ in 1:11
        mid = (lo + hi) / 2
        at(mid).hand_to_mouth_kvw > H ? (lo = mid) : (hi = mid)          # the share falls with patience
    end
    b = (lo + hi) / 2; r = at(b); lq = r.wealth_p50 / r.median_income
    @printf("%-22s | %8.4f | %6.3f %8.3f %6.3f %9.3f | %+.3f%s   [%.1f min]\n", @sprintf("%.1f (%.4f)", sh, sh * c0.cfloor), b, r.hand_to_mouth_kvw, lq, r.mpc, r.consumption_drop,
            lq - L, abs(lq - L) <= 0.03 ? "  inside 0.03" : abs(lq - L) <= 0.09 ? "  inside 0.09" : "  outside 0.09", (time() - t0) / 60)
    flush(stdout)
end
println("DONE")
