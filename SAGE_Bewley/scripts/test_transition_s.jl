# The transition solver with the social dimension on (transition_s), France G+S+A.
#  1. A zero shock: one fixed-point iteration, participation flat at the
#     steady state the families give.
#  2. A recession: job-loss rates 50% higher for two years.
#
#   julia --project=scripts/run_env scripts/test_transition_s.jl [T]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
T = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 60
c = country_config("FR"; config = "GSA", S = true, A = true)
t = @elapsed z = transition_s(c; delta_scale = Float64[], T = T)
dev(v) = maximum(abs.(v .- v[1]))
@printf("1. zero shock (%.1f min, %d iterations, gap %.1e): participation %.8f against the families' %.8f; drift participation %.1e, consumption %.1e, assets %.1e; welfare %.1e\n",
        t / 60, z.iterations, z.gap, z.participation[1], z.steady_state_rate, dev(z.participation), dev(z.cons), dev(z.assets), z.welfare)
flush(stdout)
if length(ARGS) < 2 || ARGS[2] != "zero"
    t = @elapsed x = transition_s(c; delta_scale = [1.5, 1.5], T = T)
    @printf("2. recession, job-loss x1.5 for two years (%.1f min, %d iterations, gap %.1e)\n", t / 60, x.iterations, x.gap)
    @printf("   %4s %9s %8s %8s %8s %8s\n", "year", "particip.", "unempl.", "cons.", "effort", "assets")
    for tt in (1, 2, 3, 4, 5, 8, 12, 20)
        tt > T && continue
        @printf("   %4d %+8.3f%% %+7.2f%% %+7.2f%% %+7.2f%% %+7.2f%%\n", tt, 100 * (x.participation[tt] - z.participation[tt]),
                100 * (x.unemployment[tt] - z.unemployment[tt]), 100 * (x.cons[tt] / z.cons[tt] - 1),
                100 * (x.effort_employed[tt] / z.effort_employed[tt] - 1), 100 * (x.assets[tt] / z.assets[tt] - 1))
    end
    @printf("   welfare of living through it: %+.3f%% of consumption\n", 100 * x.welfare)
end
println("DONE")
