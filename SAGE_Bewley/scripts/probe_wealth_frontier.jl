# What one-asset households can deliver on the wealth moments (V3_START.md, section 47): G of version
# 5, a grid of top patience by patience gap, the permanent types and effort scale given. For each
# point the hand-to-mouth share in total and by education, median liquid wealth over median income,
# the MPC and effort, against the HFCS on the narrow and the broad definition. It answers whether a
# country's pair (hand-to-mouth share, median liquid wealth) lies on the surface the model spans.
#
#   julia --project=scripts/run_env scripts/probe_wealth_frontier.jl CODE PHI "f1 f2 f3 f4 f5" "w1 w2 w3 w4 w5"
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); phi = parse(Float64, ARGS[2]); pf = parse.(Float64, split(ARGS[3])); pw = parse.(Float64, split(ARGS[4])); pw ./= sum(pw); pf ./= sum(pf .* pw)
function hf(moment, grp = "all", sub = "all")
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == grp && f[5] == sub && return parse(Float64, f[6])
    end
    NaN
end
for (nm, h, l) in (("narrow", "htm_model_narrow_total", "liquid_kvw_to_disposable_income_ratio_of_medians"), ("broad", "htm_model_broad_total", "liquid_broad_to_disposable_income_ratio_of_medians"))
    @printf("%s, HFCS 2021, %s: hand-to-mouth %.3f (below tertiary %.3f, tertiary %.3f) | median liquid wealth over income %.3f\n", code, nm, hf(h), hf(h, "education", "below tertiary"), hf(h, "education", "tertiary"), hf(l))
end
@printf("survey MPC %.3f | effort scale %.3f | permanent types %s, weights %s\n", hf("mpc_mean"), phi, join([@sprintf("%.3f", v) for v in pf], " "), join([@sprintf("%.3f", v) for v in pw], " "))
@printf("%8s %6s | %7s %7s %7s | %9s | %6s | %7s | %8s\n", "top", "gap", "htm", "low", "high", "liq/inc", "MPC", "effort", "job loss")
for top in 0.90:0.01:0.97, gap in (0.0, 0.03, 0.06, 0.09, 0.12)
    c = country_config(code; config = "G", v3 = :v5, S = false, A = false, missing_ok = true, phi = phi, beta_bar = top, beta_spread = 0.0, beta_cell = (-gap, 0.0),
                       perm_sd = 0.0, perm_f = pf, perm_w = pw, cfloor = 0.0)
    try
        r = solve_economy(c; cache = false)
        hc = [sum(r.pooled[g].hmass) / sum(r.pooled[g].mass) for g in 1:2]
        @printf("%8.3f %6.2f | %7.3f %7.3f %7.3f | %9.3f | %6.3f | %7.4f | %8.3f\n", top, gap, r.hand_to_mouth_kvw, hc[1], hc[2], r.wealth_p50 / r.median_income, r.mpc, r.mean_effort_employed, r.consumption_drop)
    catch err
        @printf("%8.3f %6.2f | no solution: %s\n", top, gap, first(replace(sprint(showerror, err), "\n" => " "), 120))
    end
    flush(stdout)
end
println("DONE")
