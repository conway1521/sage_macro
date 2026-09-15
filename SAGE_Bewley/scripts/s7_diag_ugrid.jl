# Is the jagged slope an economy or a grid?
#
# `s7_diag_slope.txt` panel A shows the map slope jumping 0.926, 0.990, 0.960,
# 0.984 across sigma steps of 0.01, and panel C shows the linearisation
# identity failing non-monotonically at every shock size. Both are signatures
# of a map with kinks rather than a map near a fold. The suspect is the
# belonging grid: the response family is sampled at spacing 0.2 across the
# transition and interpolated linearly, which was enough when a cell had ONE
# transition, and five permanent discount types give it five, each narrower
# than the composite.
#
# This rebuilds the two baseline families at spacing 0.05 and repeats the two
# diagnostics. Two families of about 330 nodes, so it costs minutes.
#
#   julia --project=. scripts/s7_diag_ugrid.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.030
const UFINE = vcat(collect(0.0:0.5:2.0), collect(2.05:0.05:12.0),
                   collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results()
@printf("coarse grid %d nodes, fine grid %d nodes\n\n", length(UGRID), length(UFINE))

"Build a baseline family on an arbitrary belonging grid."
function fam_on(α, δ, ug)
    bs, w = beta_types(NABLA)
    p0s = [cell_params_u(α; δ = δ, f = F_FIND, rr = RR, na = NA, ne = NE, a_max = GRID.a_max,
                         pexp = GRID.pexp, lumptax = res["T_UI"], β = b) for b in bs]
    nodes = build_family_u(p0s, ug, THETA; weights = w)
    (u = collect(ug), r = [n.rate for n in nodes])
end
t0 = time()
FL = fam_on(CELLS[1].α, CELLS[1].δ, UFINE); FH = fam_on(CELLS[2].α, CELLS[2].δ, UFINE)
@printf("fine families built in %.1f min\n\n", (time() - t0) / 60)
CL = family_u(CELLS[1].α, CELLS[1].δ; lumptax = res["T_UI"])
CH = family_u(CELLS[2].α, CELLS[2].δ; lumptax = res["T_UI"])

const XG = collect(0.0:0.01:60.0)
xtab(u, r, σ) = (ms = taste_nodes_ln(σ; n = NQ); [mean(interp(u, r, x * m) for m in ms) for x in XG])
phi2(z) = exp(-z^2 / 2) / sqrt(2pi)
function best(Rl, Rh, κ; ng = 6401)
    g = range(0.0, 1.0, length = ng)
    f(r) = (arg = OMEGA + (1 - OMEGA) * r;
            lo = interp(XG, Rl, κ * CELLS[1].B * arg); hi = interp(XG, Rh, κ * CELLS[2].B * arg);
            (CELLS[1].share * lo + CELLS[2].share * hi, lo, hi))
    o = [f(r)[1] for r in g]; out = nothing; ns = 0
    for i in 1:ng-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
        ns += 1
        rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
        L = (lo - 0.25)^2 + (hi - 0.45)^2
        (out === nothing || L < out.L) && (out = (r = rs, lo = lo, hi = hi, slope = sl, L = L))
    end
    out === nothing ? nothing : (out..., nstable = ns)
end
function row(u, r_l, u2, r_h, σ)
    Rl = xtab(u, r_l, σ); Rh = xtab(u2, r_h, σ)
    kb = nothing
    for κ in 8.0:0.02:12.0
        e = best(Rl, Rh, κ); e === nothing && continue
        (kb === nothing || e.L < kb.e.L) && (kb = (κ = κ, e = e))
    end
    kb
end

println("the valley on each grid: best kappa at each sigma, and the slope there")
@printf("%-7s | %-24s | %-24s\n", "sigma", "coarse, spacing 0.2", "fine, spacing 0.05")
@printf("%-7s | %-7s %-8s %-7s | %-7s %-8s %-7s\n", "", "kappa", "rootloss", "slope", "kappa", "rootloss", "slope")
println("-"^62)
for σ in 0.33:0.01:0.50
    a = row(CL.u, CL.r, CH.u, CH.r, σ); b = row(FL.u, FL.r, FH.u, FH.r, σ)
    @printf("%-7.3f | %-7.2f %-8.4f %-7.4f | %-7.2f %-8.4f %-7.4f\n",
            σ, a.κ, sqrt(a.e.L), a.e.slope, b.κ, sqrt(b.e.L), b.e.slope)
    flush(stdout)
end
println()
println("linearisation identity on the FINE grid at the best fine point")
bb = nothing
for σ in 0.33:0.005:0.55
    b = row(FL.u, FL.r, FH.u, FH.r, σ)
    (bb === nothing || b.e.L < bb.b.e.L) && (bb = (σ = σ, b = b))
end
σs = bb.σ; κs = bb.b.κ; e0 = bb.b.e
comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * e0.r)
dens = 0.5 * phi2(quantile_normal(1 - e0.lo)) + 0.5 * phi2(quantile_normal(1 - e0.hi))
@printf("fine-grid calibration: kappa %.2f sigma %.3f rootloss %.4f rate %.4f groups %.3f/%.3f\n",
        κs, σs, sqrt(e0.L), e0.r, e0.lo, e0.hi)
@printf("slope %.4f multiplier %.1f sigbar %.4f ratio %.3f stable %d\n",
        e0.slope, 1 / (1 - e0.slope), comp * dens, σs / (comp * dens), e0.nstable)
Rl = xtab(FL.u, FL.r, σs); Rh = xtab(FH.u, FH.r, σs)
@printf("\n%-8s | %-12s %-12s %-12s %s\n", "shock", "map shift", "predicted", "measured", "ratio")
println("-"^62)
for pct in (0.01, 0.003, 0.001)
    κ1 = κs * (1 + pct)
    f0(r) = (arg = OMEGA + (1 - OMEGA) * r;
             CELLS[1].share * interp(XG, Rl, κs * CELLS[1].B * arg) + CELLS[2].share * interp(XG, Rh, κs * CELLS[2].B * arg))
    f1(r) = (arg = OMEGA + (1 - OMEGA) * r;
             CELLS[1].share * interp(XG, Rl, κ1 * CELLS[1].B * arg) + CELLS[2].share * interp(XG, Rh, κ1 * CELLS[2].B * arg))
    shift = f1(e0.r) - f0(e0.r); e1 = best(Rl, Rh, κ1; ng = 25601)
    pred = shift / (1 - e0.slope)
    @printf("%-8.4f | %+.9f %+.9f %+.9f %.3f\n", pct, shift, pred, e1.r - e0.r, (e1.r - e0.r) / pred)
end
println("DONE")
