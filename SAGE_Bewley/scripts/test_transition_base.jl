# Transitions on the base (V3_START.md, section 27, row M8): the regime with the floor, patience by
# education, the transitory part and the proportional tax; G and G+A, one asset.
#  1. A zero shock stays at the steady state: every path flat, welfare zero, and the path's first
#     period is the steady-state economy.
#  2. A recession: job-loss rates 50% higher for two years, then back. Unemployment, consumption,
#     assets, the hand-to-mouth share, the tax rate, and the welfare of living through it.
#
#   julia --project=scripts/run_env scripts/test_transition_base.jl [CONFIG] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))
dev(v) = maximum(abs.(v .- v[1]))
for code in codes
    try
        c = country_config(code; config = cfg, v3 = :floor_edu_trans, S = false, A = occursin('A', cfg))
        r = solve_economy(c; cache = false)
        t = @elapsed z = transition(c; delta_scale = Float64[], T = 60)
        @printf("%s %s | 1. zero shock (%.1f min): largest drift over 60 years: unemployment %.1e, consumption %.1e, assets %.1e, hand-to-mouth %.1e, tax rate %.1e; welfare %.1e\n",
                code, cfg, t / 60, dev(z.unemployment), dev(z.cons), dev(z.assets), dev(z.htm), dev(z.taxrate), z.welfare)
        @printf("   against the steady-state economy: effort %.6f vs %.6f, hand-to-mouth %.6f vs %.6f, unemployment %.6f vs %.6f\n",
                z.effort_employed[1], r.mean_effort_employed, z.htm[1], r.hand_to_mouth_kvw, z.unemployment[1], r.unemployment)
        # with a floor the steady state itself is accepted at a stall of the household iteration (egm_core.jl),
        # so its path is flat to that tolerance and not to rounding
        ztol = c.cfloor > 0 ? 1e-3 : 1e-6
        check("$code zero shock: paths flat and welfare zero to $(ztol)",
              max(dev(z.unemployment), dev(z.cons), dev(z.assets), dev(z.htm), dev(z.taxrate), abs(z.welfare)) < ztol)
        check("$code zero shock: the first period is the steady-state economy (hand-to-mouth, unemployment to 1e-5)",
              abs(z.htm[1] - r.hand_to_mouth_kvw) < 1e-5 && abs(z.unemployment[1] - r.unemployment) < 1e-5)
        t = @elapsed x = transition(c; delta_scale = [1.5, 1.5], T = 60)
        @printf("   2. recession: job-loss rates x1.5 in years 1 and 2 (%.1f min)\n", t / 60)
        @printf("   %4s %8s %8s %8s %8s %9s %8s\n", "year", "unempl.", "cons.", "assets", "htm", "tax rate", "cU/cE")
        for tt in (1, 2, 3, 4, 5, 8, 12, 20)
            @printf("   %4d %+7.2f%% %+7.2f%% %+7.2f%% %+8.4f %+8.4f%% %8.3f\n", tt, 100 * (x.unemployment[tt] - z.unemployment[tt]),
                    100 * (x.cons[tt] / z.cons[tt] - 1), 100 * (x.assets[tt] / z.assets[tt] - 1), x.htm[tt] - z.htm[tt],
                    100 * (x.taxrate[tt] - z.taxrate[tt]), x.cons_unemployed_rel[tt])
        end
        @printf("   welfare of living through it: %+.3f%% of consumption (below tertiary %+.3f%%, tertiary %+.3f%%)\n",
                100 * x.welfare, 100 * x.welfare_cell[1], 100 * x.welfare_cell[2])
        check("$code recession: unemployment rises, consumption falls, welfare falls, and the path returns (consumption within 0.1% by year 40)",
              maximum(x.unemployment .- z.unemployment) > 0.005 && minimum(x.cons ./ z.cons) < 1 && x.welfare < 0 && abs(x.cons[40] / z.cons[40] - 1) < 1e-3)
    catch err
        println("   ", first(replace(sprint(showerror, err), "\n" => " "), 400)); check("$code $cfg: runs", false)
    end
    flush(stdout)
end
np = count(last, results)
println(np, " of ", length(results), " checks pass", np == length(results) ? "" : "; FAILED: " * join([n for (n, ok) in results if !ok], "; "))
println("DONE")
