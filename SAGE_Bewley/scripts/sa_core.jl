# Computational core of the S+A paper: agency meets the participation margin.
#
# Structure. Two permanent education cells (the clean education-income
# separation): agency alpha and belonging taste B are constant within a cell,
# income risk runs through the within-cell z process. Within each cell a
# lognormal distribution of belonging taste m (persistent traits). Each
# (cell, taste) agent solves the discrete-participation problem of
# proto_participation_core.jl.
#
# The key reduction: in the core, the belonging payoff is
#     belong = strength * Lambda * B * arg * QBAR,
# so a cell's behaviour depends on the product s = strength * m * arg only
# (B and alpha live inside the cell's parameters). We precompute each cell's
# participation rate r_g(s) ONCE on a fine s grid at production resolution,
# then every map evaluation, equilibrium search, calibration loop and policy
# counterfactual is interpolation on r_g. This removes the near-fold grid
# noise of the first prototype at its source: the expensive solves happen
# far from any fixed-point logic, on a smooth one-dimensional family.
#
# Requires: include SAGEBewley, then proto_participation_core.jl.

using Printf, Statistics

# ---------- taste distribution (persistent traits) ---------------------------
"N equal-probability lognormal nodes, E[m] = 1, log sd sigma."
function taste_nodes_ln(σ; n = 15)
    qs = [(i - 0.5) / n for i in 1:n]
    m = exp.(σ .* quantile_normal.(qs))
    m ./ mean(m)
end
# standard normal quantile (Beasley-Springer-Moro, ample for node placement)
function quantile_normal(p)
    a = [-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
         1.383577518672690e2, -3.066479806614716e1, 2.506628277459239e0]
    b = [-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
         6.680131188771972e1, -1.328068155288572e1]
    c = [-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838e0,
         -2.549732539343734e0, 4.374664141464968e0, 2.938163982698783e0]
    d = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996e0,
         3.754408661907416e0]
    plow, phigh = 0.02425, 1 - 0.02425
    if p < plow
        q = sqrt(-2 * log(p))
        return (((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) /
               ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)
    elseif p <= phigh
        q = p - 0.5; r = q * q
        return (((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q /
               (((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)
    else
        q = sqrt(-2 * log(1 - p))
        return -(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) /
                ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)
    end
end

# ---------- the education cells ----------------------------------------------
# B is folded into the belonging scale at interpolation time (the payoff
# depends only on the product), so the solve-relevant cell parameter is alpha.
"Cell parameter set: alpha constant within cell, z is income risk only."
function cell_params(αg; na = 200, ne = 40, subsidy = 0.0, lumptax = 0.0)
    SAGEParams(na = na, ne = ne, α = fill(αg, 2), B = fill(1.0, 2),
               subsidy = subsidy, lumptax = lumptax)
end

const CELL_LOW  = (name = "low edu",  share = 0.5, α = 0.765, B = 0.80)
const CELL_HIGH = (name = "high edu", share = 0.5, α = 0.911, B = 0.94)

# ---------- the response family r(u; alpha) ----------------------------------
"""
Precompute the participation rate and mean labour income as functions of the
belonging scale u, where the core's payoff is belong = u * Lambda * QBAR
(social_strength = u, B = 1, arg = 1; the cell's B and the taste m multiply
into u at interpolation time). Keyed by alpha and the policy pair.
Returns (u_grid, rates, mean_incomes).
"""
function response_family(α; u_max = 60.0, nu = 41, na = 200, ne = 40,
                          subsidy = 0.0, lumptax = 0.0, verbose = true)
    u_grid = collect(range(0.0, u_max, length = nu))
    r = Float64[]; minc = Float64[]
    for u in u_grid
        p = update(cell_params(α; na = na, ne = ne,
                               subsidy = subsidy, lumptax = lumptax);
                   social_strength = u)
        _, rate, mi = solve_participation(p, 1.0)
        push!(r, rate); push!(minc, mi)
        verbose && @printf("    family alpha=%.3f u=%6.2f rate=%.3f minc=%.3f\n",
                           α, u, rate, mi)
        flush(stdout)
    end
    return u_grid, r, minc
end

"Linear interpolation, clamped at the ends."
function interp(x, y, xq)
    xq <= x[1] && return y[1]
    xq >= x[end] && return y[end]
    k = searchsortedlast(x, xq)
    t = (xq - x[k]) / (x[k+1] - x[k])
    (1 - t) * y[k] + t * y[k+1]
end

# ---------- population objects ----------------------------------------------
"""
Population participation rates given the aggregate rate guess, via the
response families (one per cell, keyed by that cell's alpha). kappa is the
interaction strength, omega the private share, sigma the taste dispersion.
B values multiply into the interpolation scale. Returns (agg, r_low, r_high).
"""
function population_rate(fam_low, fam_high, Blow, Bhigh, κ, ω, σ, rate_in;
                          n_nodes = 15)
    ms = taste_nodes_ln(σ; n = n_nodes)
    arg = ω + (1 - ω) * clamp(rate_in, 0.0, 1.0)
    rlo = mean(interp(fam_low[1], fam_low[2], κ * m * Blow * arg) for m in ms)
    rhi = mean(interp(fam_high[1], fam_high[2], κ * m * Bhigh * arg) for m in ms)
    agg = CELL_LOW.share * rlo + CELL_HIGH.share * rhi
    return agg, rlo, rhi
end

"Trace the aggregate map rate_out(rate_in); return the curve and all
equilibrium crossings with stability (map slope below one at the crossing)."
function trace_map(fam_low, fam_high, Blow, Bhigh, κ, ω, σ;
                   ngrid = 401, n_nodes = 15)
    grid = range(0.0, 1.0, length = ngrid)
    out = [population_rate(fam_low, fam_high, Blow, Bhigh, κ, ω, σ, r;
                           n_nodes = n_nodes)[1] for r in grid]
    eqs = Tuple{Float64,Bool}[]                  # (rate, stable?)
    for i in 1:ngrid-1
        d1 = out[i] - grid[i]; d2 = out[i+1] - grid[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1 / (d1 - d2)
            r_star = grid[i] + t * (grid[i+1] - grid[i])
            slope = (out[i+1] - out[i]) / (grid[i+1] - grid[i])
            push!(eqs, (r_star, slope < 1))
        end
    end
    return collect(grid), out, eqs
end

"Population mean labour income at a given equilibrium rate (for budget loops)."
function population_meaninc(fam_low, fam_high, Blow, Bhigh, κ, ω, σ, rate;
                             n_nodes = 15)
    ms = taste_nodes_ln(σ; n = n_nodes)
    arg = ω + (1 - ω) * clamp(rate, 0.0, 1.0)
    milo = mean(interp(fam_low[1], fam_low[3], κ * m * Blow * arg) for m in ms)
    mihi = mean(interp(fam_high[1], fam_high[3], κ * m * Bhigh * arg) for m in ms)
    CELL_LOW.share * milo + CELL_HIGH.share * mihi
end
