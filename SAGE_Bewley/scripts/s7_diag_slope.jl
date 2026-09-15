# Is the map slope of 0.9908 a property of the economy or of the exact
# minimiser? The stage-7 calibration sits at a root loss of 0.0184 against
# 0.0257 one sigma-step away, so the difference in FIT between those points is
# small; if the difference in SLOPE is large, the multiplier is not a quantity
# the moments identify, and the linearisation failure (ratio 0.269) is the
# symptom rather than the disease.
#
# Also checks the equilibrium grid: near tangency a 401-point crossing search
# can misplace the fixed point and so the slope read off it.
#
#   julia --project=. scripts/s7_diag_slope.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.030
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results()

fl = family_u(CELLS[1].α, CELLS[1].δ; lumptax = res["T_UI"])
fh = family_u(CELLS[2].α, CELLS[2].δ; lumptax = res["T_UI"])
const XG = collect(0.0:0.02:60.0)
xtab(f, σ) = (ms = taste_nodes_ln(σ; n = NQ); [mean(interp(f.u, f.r, x * m) for m in ms) for x in XG])
phi2(z) = exp(-z^2 / 2) / sqrt(2pi)

"All stable crossings on a grid of `ng` points, with their slopes."
function eqs(Rl, Rh, κ; ng = 401)
    g = range(0.0, 1.0, length = ng)
    f(r) = (arg = OMEGA + (1 - OMEGA) * r;
            lo = interp(XG, Rl, κ * CELLS[1].B * arg); hi = interp(XG, Rh, κ * CELLS[2].B * arg);
            (CELLS[1].share * lo + CELLS[2].share * hi, lo, hi))
    o = [f(r)[1] for r in g]; out = NamedTuple[]
    for i in 1:ng-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (g[i+1] - g[i])
        rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
        push!(out, (r = rs, lo = lo, hi = hi, slope = sl, stable = sl < 1,
                    L = (lo - 0.25)^2 + (hi - 0.45)^2))
    end
    out
end
best(Rl, Rh, κ; ng = 401) = (e = [x for x in eqs(Rl, Rh, κ; ng = ng) if x.stable];
                             isempty(e) ? nothing : e[argmin([x.L for x in e])])

println("A. along the calibration valley: best kappa at each sigma, and the slope there")
@printf("%-7s %-7s %-9s %-8s %-8s %-8s %-8s %s\n", "sigma", "kappa", "rootloss", "rate", "slope", "mult", "ratio", "nstable")
println("-"^76)
for σ in 0.33:0.01:0.50
    Rl = xtab(fl, σ); Rh = xtab(fh, σ)
    kb = nothing
    for κ in 8.0:0.02:12.0
        e = best(Rl, Rh, κ); e === nothing && continue
        (kb === nothing || e.L < kb.e.L) && (kb = (κ = κ, e = e))
    end
    kb === nothing && continue
    e = kb.e
    comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * e.r)
    dens = 0.5 * phi2(quantile_normal(1 - e.lo)) + 0.5 * phi2(quantile_normal(1 - e.hi))
    ns = count(x -> x.stable, eqs(Rl, Rh, kb.κ))
    @printf("%-7.3f %-7.2f %-9.4f %-8.4f %-8.4f %-8.1f %-8.3f %d\n",
            σ, kb.κ, sqrt(e.L), e.r, e.slope, 1 / (1 - e.slope), σ / (comp * dens), ns)
    flush(stdout)
end

println()
println("B. the equilibrium grid at the calibrated point (kappa 9.92, sigma 0.375)")
Rl = xtab(fl, 0.375); Rh = xtab(fh, 0.375)
@printf("%-8s | %-9s %-9s %s\n", "ngrid", "rate", "slope", "stable crossings")
println("-"^48)
for ng in (401, 1601, 6401, 25601)
    e = best(Rl, Rh, 9.92; ng = ng)
    @printf("%-8d | %.6f  %.6f  %d\n", ng, e.r, e.slope, count(x -> x.stable, eqs(Rl, Rh, 9.92; ng = ng)))
end

println()
println("C. the linearisation identity at shocks of decreasing size, calibrated point")
e0 = best(Rl, Rh, 9.92; ng = 25601)
@printf("%-8s | %-11s %-11s %-11s %s\n", "shock", "map shift", "predicted", "measured", "ratio")
println("-"^60)
for pct in (0.01, 0.003, 0.001, 0.0003, 0.0001)
    κ1 = 9.92 * (1 + pct)
    Rl1 = xtab(fl, 0.375); Rh1 = xtab(fh, 0.375)
    f0(r) = (arg = OMEGA + (1 - OMEGA) * r;
             CELLS[1].share * interp(XG, Rl, 9.92 * CELLS[1].B * arg) +
             CELLS[2].share * interp(XG, Rh, 9.92 * CELLS[2].B * arg))
    f1(r) = (arg = OMEGA + (1 - OMEGA) * r;
             CELLS[1].share * interp(XG, Rl1, κ1 * CELLS[1].B * arg) +
             CELLS[2].share * interp(XG, Rh1, κ1 * CELLS[2].B * arg))
    shift = f1(e0.r) - f0(e0.r)
    e1 = best(Rl1, Rh1, κ1; ng = 25601)
    pred = shift / (1 - e0.slope)
    @printf("%-8.4f | %+.8f %+.8f %+.8f %s\n", pct, shift, pred, e1.r - e0.r,
            abs(pred) > 1e-12 ? @sprintf("%.3f", (e1.r - e0.r) / pred) : "n/a")
    flush(stdout)
end
println("DONE")
