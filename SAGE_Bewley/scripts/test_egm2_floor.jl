# The two-asset solver with the means-tested floor (V3_START.md section 141): the reduction test on version 2's
# calibrated quarterly G (the labour chain, the floor, the job's hours), one cell and one patience type. With the
# fixed cost so large that no adjustment is affordable, no illiquid wealth and no deaths, the slice k = 0 of the
# two-asset problem is the one-asset problem, so its distribution, consumption and participation must agree with
# the one-asset solver's to the solvers' tolerance. Also reports the share on the floor in both.
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_floor.jl CODE [H]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); H = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 0
say(x...) = (println(x...); flush(stdout))
c = floor_effort(quarterly_calibrated(code, "G"))        # the job's hours, as the economy uses them
p = params_of(c, cells_of(c)[1])[1]
say(@sprintf("%s G: %d states, %d liquid points, floor %.4f, R %.5f, beta %.5f, social strength %.2f", code, p.nz, p.na, p.cfloor, p.R, p.β, p.social_strength))
t1 = @elapsed s1 = solve_participation_egm(p, 1.0; full = true)
p2 = update(p; illiquid = true, chi0 = 1e6, nk = 2, k_max = 1.0, k_mid = 0.0, k_sub = 1, Rk = 1.0, death = 0.0, solver = :egm)
t2 = @elapsed s2 = solve_two_asset_egm(p2, 1.0; full = true, howard = H)
λ1 = s1.lambda; λ2 = dropdims(sum(s2.lambda; dims = 2); dims = 2)
say(@sprintf("one asset %.1f min, two assets %.1f min (%d full steps, Howard %d); mass at k > 0: %.2e, adjusting %.2e",
             t1 / 60, t2 / 60, s2.iters, s2.timing.howard_steps, sum(s2.lambda[:, 2, :]), sum(s2.lambda .* s2.Padj)))
say(@sprintf("distribution: largest difference %.2e (total variation %.2e); participation %.2e; value at k = 0 %.2e (relative)",
             maximum(abs.(λ1 .- λ2)), sum(abs.(λ1 .- λ2)), maximum(abs.(s1.P1 .- s2.P1[:, 1, :])),
             maximum(abs.(s1.V .- s2.V[:, 1, :])) / maximum(abs.(s1.V))))
a = s1.a
m1 = sum(λ1 .* reshape(a, :, 1)); m2 = sum(λ2 .* reshape(a, :, 1))
say(@sprintf("mean liquid wealth %.8f against %.8f", m1, m2))
if hasproperty(s1, :floor_d) && p.cfloor > 0
    f1 = sum(λ1 .* ((1 .- s1.P1) .* s1.floor_d[1] .+ s1.P1 .* s1.floor_d[2]))
    f2 = sum(s2.lambda[:, 1, :] .* ((1 .- s2.inner.P1[:, 1, :]) .* s2.floor[1][:, 1, :] .+ s2.inner.P1[:, 1, :] .* s2.floor[2][:, 1, :]))
    say(@sprintf("share on the floor %.6f against %.6f", f1, f2))
end
# the summaries (agency_summary, both solvers): every field summed over states, and the fall and time out of work
g1 = agency_summary(p, s1); g2 = agency_summary(p2, s2)
for k in (:hmass, :whmass, :rmass, :cmass, :mpcmass, :mpc12mass, :pmass, :pinc, :dmass, :kolmass, :nonempmass, :lumpmass, :vmass)
    x = sum(getfield(g1, k)); y = sum(getfield(g2, k))
    say(@sprintf("  %-11s one asset %.10f  two assets %.10f  difference %.1e", k, x, y, abs(x - y)))
end
kz1 = g1.kolmass; kz2 = g2.kolmass
say(@sprintf("fall (Kolsrud): %.6f against %.6f", 1 - (kz1[5] / kz1[4]) / (kz1[2] / kz1[1]), 1 - (kz2[5] / kz2[4]) / (kz2[2] / kz2[1])))
println("DONE")
