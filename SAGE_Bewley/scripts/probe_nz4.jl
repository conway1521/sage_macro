# Where does the agency column actually settle in the state space?
#
# Anchoring the poverty line on mean income removed the line's drift entirely
# (0.1967 to 0.1970 across five to thirteen states) but agency still moved,
# so what is left is the WEALTH distribution. That is not a numerical artefact
# of the threshold: Rouwenhorst matches the mean, variance and autocorrelation
# of the AR(1) exactly at every state count, but its stationary distribution is
# binomial, and a binomial approaches a normal only as the state count grows.
# A threshold on wealth depends on the shape of the income distribution, not
# only its variance, so it converges at the rate the binomial approaches the
# normal rather than at the rate the moments are matched.
#
# This runs it out far enough to see where it stops, on the cheap configuration
# (no participation fixed point) so the sweep is affordable, and then confirms
# the answer on the configuration that will actually be used.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

println("G+A, poverty line anchored on mean income")
@printf("%-5s %-10s %-10s %-10s %-10s %s\n", "nz", "mean", "line", "asset pov", "agency", "move")
println("-"^62)
prev = NaN
for nz in (7, 9, 11, 13, 15, 17, 19, 23)
    r = solve_economy(SAGEConfig(A = true, nz = nz))
    @printf("%-5d %-10.5f %-10.5f %-10.5f %-10.6f %s\n", nz, r.mean_income, r.ypov,
            r.asset_poor, r.A, isnan(prev) ? "" : @sprintf("%+.5f", r.A - prev))
    global prev = r.A
    flush(stdout)
end
println()
println("and with unemployment on, which is the configuration stage 7 uses:")
@printf("%-5s %-10s %-10s %-10s %-10s %s\n", "nz", "mean", "line", "asset pov", "agency", "move")
println("-"^62)
prev = NaN
for nz in (7, 9, 11, 13, 15)
    r = solve_economy(SAGEConfig(A = true, unemployment = true, nz = nz))
    @printf("%-5d %-10.5f %-10.5f %-10.5f %-10.6f %s\n", nz, r.mean_income, r.ypov,
            r.asset_poor, r.A, isnan(prev) ? "" : @sprintf("%+.5f", r.A - prev))
    global prev = r.A
    flush(stdout)
end
println("DONE")
