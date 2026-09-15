# Does anchoring the poverty line on mean income settle the state-space
# sensitivity? probe_nz2 showed the model's own median drifting monotonically,
# 0.4160 at five and seven states, then 0.4220, 0.4280, 0.4338 at nine, eleven
# and thirteen, carrying agency from 0.384 down to 0.369. Mean income over the
# same range moves by 0.001. If the drift is the median's discreteness rather
# than the economy, anchoring removes it.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
@printf("%-4s | %-9s %-9s %-9s %-9s | %-9s %-9s %-9s %s\n", "nz",
        "own median", "line", "asset pov", "agency", "mean", "line", "asset pov", "agency")
@printf("%-4s | %-38s | %s\n", "", "poverty line from the model's own median",
        "poverty line anchored on mean income")
println("-"^104)
for nz in (5, 7, 9, 11, 13)
    a = solve_economy(SAGEConfig(A = true, nz = nz, poverty_line = :model))
    b = solve_economy(SAGEConfig(A = true, nz = nz))
    @printf("%-4d | %-9.4f %-9.4f %-9.4f %-9.6f | %-9.4f %-9.4f %-9.4f %.6f\n",
            nz, a.median_income, a.ypov, a.asset_poor, a.A,
            b.mean_income, b.ypov, b.asset_poor, b.A)
    flush(stdout)
end
println("-"^104)
println("the model's own median-to-mean ratio, against 0.8693 for France (Eurostat ilc_di03):")
for nz in (5, 7, 9, 11, 13)
    r = solve_economy(SAGEConfig(A = true, nz = nz))
    @printf("  nz %2d : %.4f\n", nz, r.median_model / r.mean_income)
end
println("DONE")
