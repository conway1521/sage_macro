# Why did the map steepen? A four-way decomposition.
#
# Stage 5b had map slope 0.879 at the calibrated point, a multiplier of 8.3,
# and sigma_m / sigma-bar = 1.103, inside the S+A paper's uniqueness condition.
# Stage 6 has slope 0.947, multiplier 18.7, ratio 0.852. The first diagnostic
# (s6_diag_block.jl) showed the unemployed block is NOT the cause: removing it
# makes the map STEEPER still, because a block that participates at one
# whatever the social scale scales the aggregate response down by (1 - u).
#
# So the cause is in the employed households themselves. Three candidates are
# separated here, each on its own family build:
#
#   A  delta = 0, no UI tax          stage 5b exactly
#   B  delta = 0, UI tax charged     the lump-sum tax alone
#   C  delta > 0, UI tax, employed   adds precautionary saving against job loss
#   D  delta > 0, UI tax, population adds the unemployed block back
#
# The mechanism is read off the RESPONSE FUNCTION directly, independent of any
# calibration: the width of the belonging scale over which a cell goes from 20
# to 80 percent participation. A gradual response needs households spread out
# in wealth; the atom at the borrowing constraint is what produced that spread.
#
#   julia --project=. scripts/s6_diag_decomp.jl
include(joinpath(@__DIR__, "s6_common.jl"))
const OMEGA = 0.30
include(joinpath(@__DIR__, "s6_pop.jl"))
res = read_results()
const T_UI = res["T_UI"]

emprate(f) = [sum(n.part[f.employed]) / sum(n.mass[f.employed]) for n in f.nodes]
poprate(f) = [sum(n.part) for n in f.nodes]
"Wealth CDF over the employed only, and over everyone, at a node."
empW(n, f) = vec(sum(n.W[f.employed, :], dims = 1)) ./ sum(n.mass[f.employed])

"Belonging-scale width over which the cell goes from 20 to 80 percent."
function width(u, r)
    f(t) = begin
        i = findfirst(>=(t), r); i === nothing && return NaN
        i == 1 && return u[1]
        u[i-1] + (t - r[i-1]) / (r[i] - r[i-1]) * (u[i] - u[i-1])
    end
    f(0.8) - f(0.2)
end

const XG = collect(0.0:0.02:60.0)
xtab(u, col, σ) = (ms = taste_nodes_ln(σ; n = NQ); [mean(interp(u, col, x * m) for m in ms) for x in XG])
phi2(z) = exp(-z^2 / 2) / sqrt(2pi)
function recal(ul, cl, uh, ch)
    best = (L = Inf,)
    for σ in 0.25:0.005:1.00
        Rl = xtab(ul, cl, σ); Rh = xtab(uh, ch, σ)
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
    (best..., sigbar = comp * dens, ratio = best.σ / (comp * dens), mult = 1 / (1 - best.slope))
end

# ---- the four family pairs -------------------------------------------------
println("building families (A and B are new; C and D come from the stage-6 cache)\n")
FA = (family_u(CELLS[1].α, 0.0; lumptax = 0.0),  family_u(CELLS[2].α, 0.0; lumptax = 0.0))
FB = (family_u(CELLS[1].α, 0.0; lumptax = T_UI), family_u(CELLS[2].α, 0.0; lumptax = T_UI))
FC = (family_u(CELLS[1].α, CELLS[1].δ; lumptax = T_UI), family_u(CELLS[2].α, CELLS[2].δ; lumptax = T_UI))

CASES = (("A  no risk, no tax",     FA, poprate, "stage 5b"),
         ("B  no risk, UI tax",     FB, poprate, "adds the tax"),
         ("C  risk, employed only", FC, emprate, "adds precautionary saving"),
         ("D  risk, population",    FC, poprate, "adds the unemployed block"))

@printf("%-24s | %-6s %-6s | %-7s %-6s %-7s | %-7s %-7s | %s\n",
        "case", "kappa", "sigma", "slope", "mult", "ratio", "width lo", "width hi", "what it adds")
println("-"^118)
prev = nothing
for (nm, F, col, note) in CASES
    e = recal(F[1].u, col(F[1]), F[2].u, col(F[2]))
    wl = width(F[1].u, col(F[1])); wh = width(F[2].u, col(F[2]))
    @printf("%-24s | %-6.2f %-6.3f | %-7.4f %-6.1f %-7.3f | %-7.3f %-7.3f | %s\n",
            nm, e.κ, e.σ, e.slope, e.mult, e.ratio, wl, wh, note)
    flush(stdout)
end
println()
# ---- the wealth distribution behind it -------------------------------------
println("employed wealth distribution at a common belonging scale (u = 5.0), low cell:")
@printf("%-24s | %-8s %-8s %-8s %-8s | %s\n", "case", "at a<1e-6", "p10", "p50", "p90", "rate")
println("-"^76)
for (nm, F, col, _) in CASES[[1, 2, 3]]
    f = F[1]; i = findfirst(==(5.0), f.u); n = f.nodes[i]
    W = empW(n, f); ag = f.agrid
    @printf("%-24s | %.4f   %.4f   %.4f   %.4f   | %.4f\n", nm,
            share_below_interp(ag, W, 1e-6), cdf_quantile(ag, W, 0.1),
            cdf_quantile(ag, W, 0.5), cdf_quantile(ag, W, 0.9), col(f)[i])
end
println()
println("The transition width is the diagnostic: a cell whose households are")
println("spread out in wealth crosses the participation threshold gradually.")
println("DONE")
