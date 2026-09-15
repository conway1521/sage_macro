# The modularity suite reports a baseline median disposable income of 0.530
# against mean labour income of 0.450, which cannot be right. The suspect is
# the income process: with two productivity states of equal mass the income
# distribution is two clusters with a gap between them, and the median sits IN
# the gap, so it jumps from one cluster to the other on any small change. The
# poverty line is half the median and the asset threshold is a quarter of that,
# so everything built on them inherits the jump.
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf, Statistics

c = SAGEConfig()
r = solve_economy(c)
Y = sum(0.5 * p.Y for p in r.pooled)
@printf("nz = %d, mean labour income %.4f, mean disposable %.4f\n\n",
        c.na > 0 ? 2 : 2, r.mean_labour_income, r.mean_income)
println("the pooled disposable-income distribution:")
for q in (0.05, 0.2, 0.4, 0.45, 0.48, 0.5, 0.52, 0.55, 0.6, 0.8, 0.95)
    @printf("  p%-4.1f  %.4f\n", 100q, cdf_quantile(YGRID, Y, q))
end
println()
println("mass in each 0.02-wide income band, to show the gap:")
edges = 0.24:0.02:0.62
prev = 0.0
for e in edges
    k = searchsortedlast(YGRID, e)
    cum = k < 1 ? 0.0 : Y[min(k, length(Y))]
    @printf("  up to %.2f : cumulative %.4f   in band %.4f\n", e, cum, cum - prev)
    prev = cum
end
println()
@printf("the median is %.4f; a band of width 0.02 around it holds %.4f of the mass\n",
        r.median_income, 0.0)
lo = cdf_quantile(YGRID, Y, 0.45); hi = cdf_quantile(YGRID, Y, 0.55)
@printf("the 45th to 55th percentile spans %.4f to %.4f, a width of %.4f\n", lo, hi, hi - lo)
println(hi - lo > 0.05 ? "  the median sits in a gap: it is not a stable statistic here" :
                         "  the median sits inside a dense region")
println("DONE")
