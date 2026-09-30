# The transition solver (transition_core.jl), France G+A, one asset.
#  1. A zero shock stays at the steady state: every path flat, welfare zero.
#  2. A recession: job-loss rates 50% higher for two years, then back.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/test_transition.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
c = country_config("FR"; config = "GA", S = false, A = true)
r = solve_economy(c)
t = @elapsed z = transition(c; delta_scale = Float64[], T = 60)
dev(v) = maximum(abs.(v .- v[1]))
@printf("1. zero shock (%.1f s): largest drift over 60 years: unemployment %.1e, consumption %.1e, effort %.1e, assets %.1e, hand-to-mouth %.1e, tax %.1e; welfare %.1e\n",
        t, dev(z.unemployment), dev(z.cons), dev(z.effort_employed), dev(z.assets), dev(z.htm), dev(z.lumptax), z.welfare)
@printf("   against the steady-state economy: effort %.6f vs %.6f, hand-to-mouth %.6f vs %.6f, unemployment %.6f vs %.6f\n",
        z.effort_employed[1], r.mean_effort_employed, z.htm[1], r.hand_to_mouth_kvw, z.unemployment[1], r.unemployment)
t = @elapsed x = transition(c; delta_scale = [1.5, 1.5], T = 60)
println("2. recession: job-loss rates x1.5 in years 1 and 2 (", round(t; digits = 1), " s)")
@printf("   %4s %8s %8s %8s %8s %8s %8s\n", "year", "unempl.", "cons.", "effort", "assets", "htm", "cU/cE")
for tt in (1, 2, 3, 4, 5, 8, 12, 20)
    @printf("   %4d %+7.2f%% %+7.2f%% %+7.2f%% %+7.2f%% %+7.4f %8.3f\n", tt, 100 * (x.unemployment[tt] - z.unemployment[tt]),
            100 * (x.cons[tt] / z.cons[tt] - 1), 100 * (x.effort_employed[tt] / z.effort_employed[tt] - 1),
            100 * (x.assets[tt] / z.assets[tt] - 1), x.htm[tt] - z.htm[tt], x.cons_unemployed_rel[tt])
end
@printf("   welfare of living through it: %+.3f%% of consumption (lower-education %+.3f%%, higher %+.3f%%)\n",
        100 * x.welfare, 100 * x.welfare_cell[1], 100 * x.welfare_cell[2])
println("DONE")
