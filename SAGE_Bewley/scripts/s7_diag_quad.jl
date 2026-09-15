# Last suspect for the jagged loss surface: the taste quadrature.
#
# Ruled out already: the belonging grid (a fourfold refinement changes nothing
# above sigma 0.40) and the discount discretisation (5 and 15 points agree to
# four decimals everywhere). What remains is the 2000-node lognormal
# quadrature. The cell response is steep, and integrating a steep function
# against equal-probability nodes leaves an error that moves with sigma, which
# would put narrow spikes in the loss surface exactly where the driver's
# refinement goes looking.
#
# The driver's refined point, sigma 0.375, has root loss 0.0184 and slope
# 0.9908, and sits between sigma 0.370 with 0.0667 and 0.380 with 0.0335. If
# that dip survives an eightfold finer quadrature it is the economy; if it
# moves, the calibration was chasing quadrature noise and the multiplier it
# implies, 109 against 17 one step away, is not a quantity the moments
# identify.
#
#   julia --project=. scripts/s7_diag_quad.jl
include(joinpath(@__DIR__, "s7_workers.jl"))
const OMEGA = 0.30
const NABLA = 0.030
include(joinpath(@__DIR__, "s7_pop.jl"))
res = read_results()
fl = family_u(CELLS[1].α, CELLS[1].δ; lumptax = res["T_UI"])
fh = family_u(CELLS[2].α, CELLS[2].δ; lumptax = res["T_UI"])

const XG = collect(0.0:0.01:60.0)
xtab(f, σ, nq) = (ms = taste_nodes_ln(σ; n = nq); [mean(interp(f.u, f.r, x * m) for m in ms) for x in XG])
function best(Rl, Rh, κ; ng = 6401)
    g = range(0.0, 1.0, length = ng); out = nothing
    f(r) = (arg = OMEGA + (1 - OMEGA) * r;
            lo = interp(XG, Rl, κ * CELLS[1].B * arg); hi = interp(XG, Rh, κ * CELLS[2].B * arg);
            (CELLS[1].share * lo + CELLS[2].share * hi, lo, hi))
    o = [f(r)[1] for r in g]
    for i in 1:ng-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        (d1 == 0 || sign(d1) != sign(d2)) || continue
        sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
        rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
        L = (lo - 0.25)^2 + (hi - 0.45)^2
        (out === nothing || L < out.L) && (out = (r = rs, lo = lo, hi = hi, slope = sl, L = L))
    end
    out
end
function valley(σ, nq)
    Rl = xtab(fl, σ, nq); Rh = xtab(fh, σ, nq); kb = nothing
    for κ in 8.0:0.02:12.0
        e = best(Rl, Rh, κ); e === nothing && continue
        (kb === nothing || e.L < kb.e.L) && (kb = (κ = κ, e = e))
    end
    kb
end

const NQS = (2000, 8000, 32000)
@printf("%-7s |%s\n", "sigma", join([@sprintf("%28s", "nq = $n") for n in NQS]))
@printf("%-7s |%s\n", "", join([@sprintf("%10s%9s%9s", "kappa", "rootloss", "slope") for _ in NQS]))
println("-"^(8 + 28 * length(NQS)))
for σ in 0.360:0.005:0.430
    vs = [valley(σ, nq) for nq in NQS]
    @printf("%-7.3f |%s\n", σ,
            join([@sprintf("%10.2f%9.4f%9.4f", v.κ, sqrt(v.e.L), v.e.slope) for v in vs]))
    flush(stdout)
end
println()
for nq in NQS
    b = nothing
    for σ in 0.33:0.005:0.60
        v = valley(σ, nq)
        (b === nothing || v.e.L < b.v.e.L) && (b = (σ = σ, v = v))
    end
    @printf("nq %6d: best sigma %.3f kappa %.2f rootloss %.4f slope %.4f mult %.1f\n",
            nq, b.σ, b.v.κ, sqrt(b.v.e.L), b.v.e.slope, 1 / (1 - b.v.e.slope))
end
println()
println("roughness, mean absolute change in slope between adjacent sigma over 0.36 to 0.43:")
for nq in NQS
    sl = [valley(σ, nq).e.slope for σ in 0.360:0.005:0.430]
    @printf("  nq %6d: %.4f\n", nq, sum(abs, diff(sl)) / (length(sl) - 1))
end
println("DONE")
