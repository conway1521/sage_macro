# Agency as a dimension of experienced wellbeing: the hardship half of the
# SAGE agency object, computed inside the Bewley economy.
#
# THE OBJECT. Snower and Lima de Miranda (2020, IZA DP 12998, section 3.3)
# write agency utility as
#
#     U^a = C * alpha * (1 - p),
#
# with two complementary components: alpha, the ability to influence one's
# economic fortunes through one's own efforts, and (1 - p), freedom from
# economic hardship, where p is the probability that income falls below a
# critical level. The S+A model as it stood implemented alpha and dropped
# (1 - p). This file adds the missing half. The 2020 thesis (Conway 2020,
# concluding section) proposed the same closure and did not implement it.
#
# THE HARDSHIP EVENT. Their p is static: one period, uniform luck, no wealth.
# The point of putting it in a Bewley economy is that wealth is a buffer, so
# hardship becomes the failure of that buffer rather than a draw. We use the
# OECD's own criterion, unmodified:
#
#   Balestra and Tonkin (2018), OECD Statistics Working Paper 2018/01,
#   paragraph 68: an individual is asset-poor if they belong to a household
#   with "liquid financial wealth insufficient to support them at the level of
#   the income poverty line for at least three months", the income poverty
#   line being 50 percent of the national median equivalised disposable
#   income. OECD (2025), Household financial fragility and asset poverty in
#   OECD regions, states the same test as financial assets below 25 percent of
#   the national income poverty line.
#
# So, with the model period a year and abar the wealth threshold,
#
#     abar = (months / 12) * 0.5 * median(disposable income),   months = 3.
#
# WHY THE AGGREGATE IS EXACT AND CHEAP. Define the hardship indicator
# h(a) = 1{a < abar} and the forward-looking probability
# p(a, z) = E[h(a') | a, z] under the household's own next-asset policy. Then
# for any stationary distribution lambda,
#
#     sum_lambda p = E_lambda[h(a')] = E_lambda'[h] = E_lambda[h],
#
# because lambda' = lambda. And alpha is constant within an education cell, so
#
#     A_g = alpha_g * (1 - h_g)      exactly,
#
# with h_g the cell's asset-poverty rate. The forward-looking construction is
# therefore what defines the household-level object, while the AGGREGATE is
# the OECD's published statistic computed inside the model. That is a feature:
# it makes the agency index directly comparable to a number someone else
# measured. It also means the one-period horizon buys nothing at the aggregate;
# a horizon that takes the union over several years would be a different object
# and is the natural next refinement, not implemented here.
#
# WHAT THIS FILE STORES. Everything downstream is a threshold evaluation on a
# distribution, so each solved cell is summarised by two cumulative
# distributions: wealth on the model's own asset grid (exact, the stationary
# distribution puts mass on nodes) and disposable income on a fixed grid.
# Both are linear in lambda, so interpolating across the belonging scale and
# mixing across taste nodes and cells is exact, and the hardship threshold
# stays a post-processing choice rather than a solve-time parameter.
#
# Requires: SAGEBewley, proto_participation_core.jl, sa_core.jl.

using Printf, Statistics

# income grid for the CDF: mean labour income sits near 0.44, so this spans
# the support with 2e-3 spacing, enough to place the median to about 1e-3.
const YGRID = collect(0.0:0.002:1.5)

"""
    cell_distributions(p, sol)

Summarise one solved cell as cumulative distributions. Returns a named tuple:

  `wcdf`  cumulative stationary mass at or below each node of the asset grid
  `ycdf`  cumulative stationary mass at or below each node of `YGRID`, for
          DISPOSABLE income: labour income gross of the subsidy, plus the
          participation credit when the household participates, less the
          lump-sum tax, plus capital income
  `ymean` mean disposable income
  `rate`  participation rate (carried through so the family is self-contained)

Both cumulative vectors are computed by mixing over the participation branch,
so a household that participates with probability P1 contributes P1 of its
mass at its participating income and the rest at its non-participating income.
"""
function cell_distributions(p::SAGEParams, sol)
    a = sol.a; λ = sol.lambda; P1 = sol.P1; z = sol.z_vals
    na, nz = p.na, p.nz
    wcdf = zeros(na)
    ycdf = zeros(length(YGRID))
    ymean = 0.0
    @inbounds for i_z in 1:nz, i_a in 1:na
        w = λ[i_a, i_z]
        w <= 0 && continue
        wcdf[i_a] += w
        α = p.α[i_z]; zz = z[i_z]
        cap = (p.R - 1) * a[i_a]
        credit = p.partcredit * α * zz * p.Z * QBAR
        p1 = P1[i_a, i_z]
        for d in (0, 1)
            wd = d == 1 ? w * p1 : w * (1 - p1)
            wd <= 0 && continue
            y = (1 + p.subsidy) * α * zz * p.Z * sol.e_d[d+1][i_a, i_z] +
                cap - p.lumptax + (d == 1 ? credit : 0.0)
            ymean += wd * y
            k = searchsortedfirst(YGRID, y)
            k <= length(YGRID) && (ycdf[k] += wd)
        end
    end
    cumsum!(wcdf, wcdf)
    cumsum!(ycdf, ycdf)
    (wcdf = wcdf, ycdf = ycdf, ymean = ymean, rate = sol.rate)
end

"Share of mass strictly below `x` under a cumulative vector on `grid`.
The stationary distribution puts mass on grid nodes, so this is exact."
function share_below(grid, cdf, x)
    k = searchsortedlast(grid, x - eps(x) * 8)     # last node strictly below x
    k < 1 && return 0.0
    k >= length(cdf) && return cdf[end]
    cdf[k]
end

"""
Share of mass below `x`, treating the lottery's node masses as a discretised
continuous distribution: the cumulative vector is interpolated linearly
between grid nodes. `share_below` is the same quantity read as a pure step
function. The two bracket the truth, and their gap is the discretisation band
on any threshold statistic, which is why both are reported.
"""
function share_below_interp(grid, cdf, x)
    x <= grid[1] && return 0.0
    x >= grid[end] && return cdf[end]
    k = searchsortedlast(grid, x)
    k < 1 && return 0.0
    k >= length(grid) && return cdf[end]
    c0 = cdf[k]; c1 = cdf[k+1]
    c0 + (c1 - c0) * (x - grid[k]) / (grid[k+1] - grid[k])
end

"Quantile of a cumulative vector, linearly interpolated between grid nodes."
function cdf_quantile(grid, cdf, q)
    tot = cdf[end]
    tot <= 0 && return NaN
    t = q * tot
    k = searchsortedfirst(cdf, t)
    k <= 1 && return grid[1]
    k > length(grid) && return grid[end]
    c0, c1 = cdf[k-1], cdf[k]
    c1 <= c0 && return grid[k]
    grid[k-1] + (t - c0) / (c1 - c0) * (grid[k] - grid[k-1])
end

"""
    hardship_threshold(median_income; months = 3.0)

The OECD asset-poverty threshold in model units: the liquid wealth needed to
hold a household at the income poverty line, 50 percent of median disposable
income, for `months` months. Balestra and Tonkin (2018), paragraph 68.
"""
hardship_threshold(median_income; months = 3.0) =
    (months / 12) * 0.5 * median_income
