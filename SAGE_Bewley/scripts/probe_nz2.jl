# The one convergence row the modularity suite fails.
#
# Without the social dimension the agency column is settled by seven
# productivity states: nine moves it by 0.0001. With the social dimension on it
# moves by 0.0076, and the sequence is not monotone, 0.3706 at five, 0.3713 at
# seven, 0.3637 at nine. Two candidate explanations, and they are told apart by
# the map slope: either the income process genuinely needs more states once the
# participation margin is present, or the economy is sitting somewhere steep
# and a small change in the households is being amplified into the aggregate.
#
# The defaults are NOT a calibrated economy: kappa and sigma_m are inherited
# from the stage-7 calibration, which was done at two productivity states, so
# the participation rate here is 0.64 against a target of 0.35. If the slope is
# high that is the reason, and the fix is to recalibrate rather than to add
# states.
#
#   julia --project=. scripts/probe_nz2.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

@printf("%-5s %-9s %-9s %-9s %-9s %-9s %s\n",
        "nz", "rate", "slope", "mult", "agency", "asset pov", "median")
println("-"^72)
for nz in (5, 7, 9, 11, 13)
    r = solve_economy(SAGEConfig(S = true, A = true, nz = nz))
    @printf("%-5d %-9.4f %-9.4f %-9.1f %-9.6f %-9.6f %.6f\n",
            nz, r.rate, r.slope, 1 / (1 - r.slope), r.A, r.asset_poor, r.median_income)
    flush(stdout)
end
println()
println("the same at a social technology that puts the rate near the French target,")
println("so the economy is not sitting on a steep part of the map:")
@printf("%-5s %-9s %-9s %-9s %-9s %-9s %s\n",
        "nz", "rate", "slope", "mult", "agency", "asset pov", "median")
println("-"^72)
for nz in (5, 7, 9, 11, 13)
    r = solve_economy(SAGEConfig(S = true, A = true, nz = nz, kappa = 7.0, sigma_m = 0.55))
    @printf("%-5d %-9.4f %-9.4f %-9.1f %-9.6f %-9.6f %.6f\n",
            nz, r.rate, r.slope, 1 / (1 - r.slope), r.A, r.asset_poor, r.median_income)
    flush(stdout)
end
println()
println("and with the social dimension off, for reference:")
@printf("%-5s %-9s %-9s %s\n", "nz", "agency", "asset pov", "median")
println("-"^44)
for nz in (5, 7, 9, 11, 13)
    r = solve_economy(SAGEConfig(A = true, nz = nz))
    @printf("%-5d %-9.6f %-9.6f %.6f\n", nz, r.A, r.asset_poor, r.median_income)
    flush(stdout)
end
println("DONE")
