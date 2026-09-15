# Recalibration at seven productivity states.
#
# Everything in stages 6 and 7 was computed with two, at which the income
# distribution is two clusters with a gap and the median falls in the gap
# (MODULAR.md). Two parameters have to be found again:
#
#   the downward discount spread, against a hand-to-mouth share of 0.30
#   the social technology (kappa, sigma_m), against group participation of
#   0.25 and 0.45
#
# The first question is whether the discount spread is needed at all. Stage 7
# added it because unemployment risk drove hand-to-mouth from 0.32 down to
# 0.116; at seven states the baseline sits much higher, so some of that
# over-saving may have been the coarse income process rather than the model.
#
# Both quantities are read at the participation equilibrium, so the social
# technology is scanned inside each spread rather than after it. The scan is
# interpolation on the rate column, so it costs seconds; the families are the
# expensive part and there is one set per spread.
#
#   julia --project=. scripts/calibrate_nz7.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

const NZ = 11
const R_TARGET = (0.25, 0.45)
const HTM_TARGET = 0.30
const SPREADS = (0.036, 0.037, 0.038)
# The scan is a tabulation of the cell rate against the belonging scale, done
# once per sigma and reused across kappa. Its cost is the grid times the number
# of taste nodes, so a fine grid with the production quadrature is billions of
# interpolations and takes longer than the household solves it is scanning
# over. Coarse pass at 500 nodes, then a refinement at the production 2000.
const XG = collect(0.0:0.02:60.0)

"Families and the pieces the scan needs, for one discount spread."
function setup(spread)
    c = SAGEConfig(S = true, A = true, unemployment = true, nz = NZ, beta_spread = spread)
    cs = cells_of(c); bs, bw = betas_of(c)
    T = c.lumptax + ui_tax_of(c)
    cT = SAGEConfig(c; lumptax = T)
    fams = map(cs) do cell
        build_family_u(params_of(cT, cell), c.ugrid, c.theta; weights = bw)
    end
    (c = c, cT = cT, cs = cs, fams = fams, T = T,
     agrid = SAGEBewley.exponential_grid(1e-10, c.a_max, c.na, c.pexp))
end

xtab(u, col, σ, nq) = (ms = taste_nodes_ln(σ; n = nq); [mean(interp(u, col, x * m) for m in ms) for x in XG])

"Best (kappa, sigma_m) for one setup, by a global scan with kappa free at every sigma."
function scan(S, σs, κs, nq)
    rl = [n.rate for n in S.fams[1]]; rh = [n.rate for n in S.fams[2]]
    best = (L = Inf,)
    for σ in σs
        Rl = xtab(S.c.ugrid, rl, σ, nq); Rh = xtab(S.c.ugrid, rh, σ, nq)
        for κ in κs
            g = range(0.0, 1.0, length = 401)
            f(r) = (arg = S.c.omega + (1 - S.c.omega) * r;
                    lo = interp(XG, Rl, κ * S.cs[1].B * arg); hi = interp(XG, Rh, κ * S.cs[2].B * arg);
                    (S.cs[1].share * lo + S.cs[2].share * hi, lo, hi))
            o = [f(r)[1] for r in g]
            for i in 1:400
                d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
                (d1 == 0 || sign(d1) != sign(d2)) || continue
                sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
                rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
                L = (lo - R_TARGET[1])^2 + (hi - R_TARGET[2])^2
                L < best.L && (best = (L = L, κ = κ, σ = σ, r = rs, lo = lo, hi = hi, slope = sl))
            end
        end
    end
    best
end

"Coarse global scan, then a refinement on the production taste quadrature.
The coarse pass is global in both parameters, never a local window: a local
refinement around a coarse winner is what produced the stage-5b headline this
project had to retract."
function calibrate(S)
    c = scan(S, 0.20:0.02:1.00, 2.0:0.1:20.0, 500)
    scan(S, max(0.10, c.σ - 0.05):0.005:(c.σ + 0.05),
         max(1.0, c.κ - 0.6):0.02:(c.κ + 0.6), S.c.nq)
end

"Hand-to-mouth and the rest at a calibrated point, from the pooled families."
function at_point(S, e)
    arg = S.c.omega + (1 - S.c.omega) * e.r
    cc = SAGEConfig(S.c; kappa = e.κ, sigma_m = e.σ)
    pooled = [collapse(S.fams[g], node_weights(cc, S.cs[g].B, arg)) for g in 1:2]
    minc = sum(S.cs[g].share * pooled[g].minc for g in 1:2)
    Wtot = sum(S.cs[g].share .* vec(sum(pooled[g].W, dims = 1)) for g in 1:2)
    Y = sum(S.cs[g].share * pooled[g].Y for g in 1:2)
    (htm = share_below_interp(S.agrid, Wtot, (4 / 52) * minc),
     median = cdf_quantile(YGRID, Y, 0.5), minc = minc)
end

@printf("%d productivity states, unemployment on, replacement rate %.2f, UI tax %.5f\n\n",
        NZ, 0.68, ui_tax_of(SAGEConfig(unemployment = true, nz = NZ)))
@printf("%-8s | %-7s %-7s %-9s %-8s %-7s | %-9s %-9s %s\n",
        "spread", "kappa", "sigma", "rootloss", "rate", "slope", "hand-to-m", "median", "verdict")
println("-"^96)
rows = NamedTuple[]
for sp in SPREADS
    t0 = time()
    S = setup(sp); e = calibrate(S); v = at_point(S, e)
    push!(rows, (spread = sp, e = e, v = v))
    @printf("%-8.3f | %-7.2f %-7.3f %-9.4f %-8.4f %-7.4f | %-9.4f %-9.4f %s  (%.1f min)\n",
            sp, e.κ, e.σ, sqrt(e.L), e.r, e.slope, v.htm, v.median,
            abs(v.htm - HTM_TARGET) < 0.015 ? "ON TARGET" : "", (time() - t0) / 60)
    flush(stdout)
end
println("-"^96)
@printf("target hand-to-mouth %.2f, group participation %.2f / %.2f\n", HTM_TARGET, R_TARGET...)
best = rows[argmin([abs(r.v.htm - HTM_TARGET) for r in rows])]
@printf("\nclosest on hand-to-mouth: spread %.3f, kappa %.2f, sigma_m %.3f\n",
        best.spread, best.e.κ, best.e.σ)
@printf("  rate %.4f, groups %.4f / %.4f, root loss %.4f, slope %.4f, multiplier %.1f\n",
        best.e.r, best.e.lo, best.e.hi, sqrt(best.e.L), best.e.slope, 1 / (1 - best.e.slope))
if length(rows) > 1
    i = argmin([abs(r.v.htm - HTM_TARGET) for r in rows])
    lo = max(1, i - 1); hi = min(length(rows), i + 1)
    @printf("  hand-to-mouth spans %.4f to %.4f over spreads %.3f to %.3f, so the spread is\n",
            rows[lo].v.htm, rows[hi].v.htm, rows[lo].spread, rows[hi].spread)
    println("  identified to about a thousandth by this moment")
end
println("DONE")
