# Can G+S identify its two social parameters (kappa, sigma) without the
# education gap? France G+S at its committed parameters.
#  Test 1: the unemployed to employed ratio as a moment. The participation rule
#          is switched off, so the unemployed choose for themselves, and the
#          scan reports the ratio the model produces at every (sigma, kappa)
#          that hits overall participation.
#  Test 2: the fallback. Rule on, sigma held at France's G+S+A value, kappa
#          fitted to overall participation alone; the education gap reported
#          as untargeted.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/probe_gs_identification.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

c = country_config("FR"; config = "GS", S = true, A = false, ugrid = UGRID_COARSE)
cs = cells_of(c)
row = country_rows()["FR"]; num(k) = parse(Float64, row[k])
PART = (num("part_low"), num("part_high")); RATIO = num("ratio")
AGG = cs[1].share * PART[1] + cs[2].share * PART[2]
SIG_GSA = 0.98
t0 = time(); raw = collect(build_families(c, nothing; disk = true))
@printf("France G+S families in %.1f min | overall target %.4f, cells %.3f %.3f, national ratio %.3f\n",
        (time() - t0) / 60, AGG, PART..., RATIO)
emp = employment_mask(c)
XG = collect(0.0:0.02:60.0)
col(f, g) = [g(n) for n in f]
rE(n) = sum(n.part[emp]) / sum(n.mass[emp]); rU(n) = sum(n.part[.!emp]) / sum(n.mass[.!emp])
mE = [sum(f[1].mass[emp]) / sum(f[1].mass) for f in raw]

"Stable equilibria at (sigma, kappa) for families `fs`: (rate, lo, hi, slope, rateE, rateU)."
function equilibria(fs, σ, κ)
    ms = taste_nodes_ln(σ; n = c.nq)
    tab(v) = [mean(interp(c.ugrid, v, x * m) for m in ms) for x in XG]
    T = [(tab(col(fs[g], n -> n.rate)), tab(col(fs[g], rE)), tab(col(fs[g], rU))) for g in 1:2]
    at(g, k, r) = interp(XG, T[g][k], κ * cs[g].B * (c.omega + (1 - c.omega) * r))
    agg(r) = cs[1].share * at(1, 1, r) + cs[2].share * at(2, 1, r)
    gr = range(0.0, 1.0, length = 401); o = agg.(gr); out = []
    for i in 1:400
        d1 = o[i] - gr[i]; d2 = o[i+1] - gr[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (gr[i+1] - gr[i]); sl < 1 || continue
        r = gr[i] + d1 / (d1 - d2) * (gr[i+1] - gr[i])
        wE = [cs[g].share * mE[g] for g in 1:2]; wU = [cs[g].share * (1 - mE[g]) for g in 1:2]
        push!(out, (rate = r, lo = at(1, 1, r), hi = at(2, 1, r), slope = sl,
                    E = sum(wE[g] * at(g, 2, r) for g in 1:2) / sum(wE),
                    U = sum(wU[g] * at(g, 3, r) for g in 1:2) / sum(wU)))
    end
    isempty(out) ? nothing : out[end]      # the highest stable one, as solve_economy selects
end
"For each sigma, the kappa whose selected equilibrium hits overall participation."
function ridge(fs, sigmas)
    for σ in sigmas
        best = nothing
        for κ in 2.0:0.05:25.0
            e = equilibria(fs, σ, κ); e === nothing && continue
            L = abs(e.rate - AGG)
            (best === nothing || L < best[1]) && (best = (L, κ, e))
        end
        best === nothing && (@printf("  sigma %.2f: no stable equilibrium\n", σ); continue)
        L, κ, e = best
        @printf("  sigma %.2f: kappa %5.2f | overall %.4f (miss %.4f) | cells %.3f %.3f | U/E ratio %.3f | multiplier %.1f\n",
                σ, κ, e.rate, L, e.lo, e.hi, e.U / e.E, 1 / (1 - e.slope))
    end
end
println("\nTest 1. rule off, the unemployed choose; does sigma move the U/E ratio (data ", RATIO, ")?")
ridge(raw, [0.3, 0.5, 0.7, 0.98, 1.3, 1.7, 2.2, 3.0])
println("\nTest 2. rule on, kappa fitted to overall participation; the ridge across sigma, and the fallback at sigma = ", SIG_GSA)
imp = [impose_unemployed_ratio(f, emp, RATIO) for f in raw]
ridge(imp, [0.3, 0.5, 0.7, 0.98, 1.3, 1.7, 2.2, 3.0])
println("DONE")
