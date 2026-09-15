# Diagnostic: how much of the recalibration shift is the unemployed block?
#
# At stage 6 the unemployed participate at a rate of one at every belonging
# scale, because participation costs only time and they have no return to
# effort. They are then a fixed, non-responsive share of the aggregate. To hit
# the same population moments the EMPLOYED gradient must widen, which needs
# less taste dispersion, which steepens the map. This asks how much of the
# move from (10.00, 0.510) to (9.80, 0.395) that accounts for, by recalibrating
# on the employed-only rate: the same households, the same savings behaviour
# under job-loss risk, with the unemployed block taken out of the participation
# margin only.
#
# Pure interpolation on the cached stage-6 families, so it costs seconds.
#   julia --project=. scripts/s6_diag_block.jl
include(joinpath(@__DIR__, "s6_common.jl"))
const OMEGA = 0.30
include(joinpath(@__DIR__, "s6_pop.jl"))
res = read_results()
T_UI = res["T_UI"]
fl = family_u(CELLS[1].α, CELLS[1].δ; lumptax = T_UI)
fh = family_u(CELLS[2].α, CELLS[2].δ; lumptax = T_UI)

"Employed-only participation rate at each family node."
emprate(fam) = [sum(n.part[fam.employed]) / sum(n.mass[fam.employed]) for n in fam.nodes]
"Population rate at each node (mass sums to one)."
poprate(fam) = [sum(n.part) for n in fam.nodes]

const XG = collect(0.0:0.02:60.0)
xtab(u, col, σ) = (ms = taste_nodes_ln(σ; n = NQ); [mean(interp(u, col, x * m) for m in ms) for x in XG])
phi2(z) = exp(-z^2 / 2) / sqrt(2pi)

"""
Dense scan against the two moments, using `col` as the cell participation
column. Returns the best (kappa, sigma) and the equilibrium there.
"""
function recal(coll, colh; label = "")
    best = (L = Inf,)
    for σ in 0.25:0.005:1.00
        Rl = xtab(fl.u, coll, σ); Rh = xtab(fh.u, colh, σ)
        for κ in 5.0:0.05:20.0
            g = range(0.0, 1.0, length = 401)
            f(r) = (arg = OMEGA + (1 - OMEGA) * r;
                    lo = interp(XG, Rl, κ * CELLS[1].B * arg); hi = interp(XG, Rh, κ * CELLS[2].B * arg);
                    (0.5lo + 0.5hi, lo, hi))
            o = [f(r)[1] for r in g]
            for i in 1:400
                d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
                (d1 == 0 || sign(d1) != sign(d2)) || continue
                sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
                rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
                L = (lo - 0.25)^2 + (hi - 0.45)^2
                L < best.L && (best = (L = L, κ = κ, σ = σ, r = rs, lo = lo, hi = hi, slope = sl))
            end
        end
    end
    comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * best.r)
    dens = 0.5 * phi2(quantile_normal(1 - best.lo)) + 0.5 * phi2(quantile_normal(1 - best.hi))
    sb = comp * dens
    @printf("%-26s kappa %.2f sigma %.3f | rate %.4f groups %.3f/%.3f | rootloss %.4f | slope %.4f mult %.1f | sigbar %.4f ratio %.3f\n",
            label, best.κ, best.σ, best.r, best.lo, best.hi, sqrt(best.L), best.slope, 1/(1-best.slope), sb, best.σ/sb)
    best
end

println("stage 5b, for reference:   kappa 10.00 sigma 0.510 | rate 0.3526 groups 0.267/0.439 | rootloss 0.0200 | slope 0.8789 mult 8.3 | sigbar 0.4626 ratio 1.103")
println()
a = recal(poprate(fl), poprate(fh); label = "stage 6, population:")
b = recal(emprate(fl), emprate(fh); label = "stage 6, employed only:")
println()
@printf("employed-only gradient at the stage-6 calibration: %.4f (stage 5b population gradient 0.1722)\n",
        res["rate_hi_E"] - res["rate_lo_E"])
@printf("share of the sigma move explained by the block: %.0f percent\n",
        100 * (1 - (0.510 - b.σ) / (0.510 - a.σ)))
@printf("share of the slope move explained by the block:  %.0f percent\n",
        100 * (1 - (b.slope - 0.8789) / (a.slope - 0.8789)))
println("DONE")
