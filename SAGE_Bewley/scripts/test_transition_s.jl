# The transition solver with the social dimension on (transition_s), France G+S+A.
#  1. A zero shock: one fixed-point iteration, participation flat at the
#     steady state the families give.
#  2. A recession: job-loss rates 50% higher for two years.
#
# Third and fourth arguments: the country, and "base" for the base regime (the floor, patience by
# education, the transitory part and the proportional tax) in place of version 2.
#
#   julia --project=scripts/run_env scripts/test_transition_s.jl [T] [zero | full] [CODE] [base]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
T = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 60
code = length(ARGS) >= 3 ? uppercase(ARGS[3]) : "FR"
c = (length(ARGS) >= 4 && ARGS[4] == "base") ? country_config(code; config = "GSA", v3 = :floor_edu_trans, S = true, A = true) :
                                               country_config(code; config = "GSA", S = true, A = true)
println(code, " G+S+A", (length(ARGS) >= 4 && ARGS[4] == "base") ? ", base regime" : ", version 2")
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
