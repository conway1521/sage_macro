# How many productivity states does the poverty line need?
#
# With nz = 2 the income distribution is two clusters of roughly equal mass
# with a gap between them, and the median falls in the gap: at the baseline the
# 48th percentile is 0.378 and the 50th is 0.530. The poverty line is half the
# median and the asset threshold a quarter of that, so the agency column
# inherits a forty percent jump from a statistic that is not identified.
#
# The participation results never showed this because they are not threshold
# statistics; `audit_nz_l5.txt` found them stable from nz = 2. A threshold
# statistic is a different question and this is it.
#
#   julia --project=. scripts/probe_nz.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

@printf("%-4s %-9s %-9s %-9s | %-9s %-9s %-9s %-9s | %s\n",
        "nz", "median", "mean", "med/mean", "line", "abar", "asset pov", "agency", "gap at the median")
println("-"^104)
for nz in (2, 3, 5, 7, 9)
    c = SAGEConfig(nz = nz)
    r = solve_economy(c)
    Y = sum(0.5 * p.Y for p in r.pooled)
    lo = cdf_quantile(YGRID, Y, 0.45); hi = cdf_quantile(YGRID, Y, 0.55)
    @printf("%-4d %-9.4f %-9.4f %-9.4f | %-9.4f %-9.4f %-9.4f %-9.4f | %.4f %s\n",
            nz, r.median_income, r.mean_income, r.median_income / r.mean_income,
            r.ypov, r.abar, r.asset_poor, r.A, hi - lo,
            hi - lo > 0.05 ? "  <- the median is in a gap" : "")
    flush(stdout)
end
println()
println("the same, with the social dimension on, since that is where it will be used:")
@printf("%-4s %-9s %-9s %-9s | %-9s %-9s %-9s | %s\n",
        "nz", "median", "med/mean", "rate", "asset pov", "agency", "htm", "gap at the median")
println("-"^92)
for nz in (2, 3, 5, 7)
    c = SAGEConfig(S = true, A = true, nz = nz)
    r = solve_economy(c)
    Y = sum(0.5 * p.Y for p in r.pooled)
    lo = cdf_quantile(YGRID, Y, 0.45); hi = cdf_quantile(YGRID, Y, 0.55)
    @printf("%-4d %-9.4f %-9.4f %-9.4f | %-9.4f %-9.4f %-9.4f | %.4f %s\n",
            nz, r.median_income, r.median_income / r.mean_income, r.rate,
            r.asset_poor, r.A, r.hand_to_mouth, hi - lo,
            hi - lo > 0.05 ? "  <- the median is in a gap" : "")
    flush(stdout)
end
println()
println("France for comparison: median over mean equivalised disposable income 0.87 (Eurostat ilc_di03)")
println("DONE")
