# VERIFICATION LADDER, LEVELS 1 AND 2: the participation core, and whether the
# response-family reduction is a faithful stand-in for a direct solve.
#   1.1 grid convergence of the cell response
#   1.2 the cell response is monotone in the belonging scale
#   1.3 the shape: is the near-step genuinely the two-state z structure
#   2.1 REDUCTION FIDELITY: interpolated family value vs a direct solve, off-grid
#   2.2 quadrature convergence at the NEW calibration
#
#   julia --project=. scripts/verify_L1_core.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics

pass(b) = b ? "PASS" : "**FAIL**"
println("="^70); println("LEVELS 1-2: PARTICIPATION CORE AND THE REDUCTION"); println("="^70)

println("\n1.1 grid convergence of the cell response (alpha = 0.765)")
@printf("%-14s | %-8s | %-8s | %-8s\n", "grid", "u=4.8", "u=5.4", "u=6.0")
for (na, ne) in ((100,20), (200,40), (400,80))
    vals = map((4.8, 5.4, 6.0)) do u
        p = update(cell_params(0.765; na = na, ne = ne); social_strength = u)
        solve_participation(p, 1.0)[2]
    end
    @printf("na=%-3d ne=%-3d | %.4f   | %.4f   | %.4f\n", na, ne, vals...)
end

println("\n1.2 / 1.3 shape of the cell response on the fine family")
d = readdlm(joinpath(@__DIR__, "sa_families_fine.txt"), '\t'; skipstart = 1)
u = d[:,1]; rlo = d[:,2]
mono = all(diff(rlo) .>= -1e-9)
@printf("   monotone in u: %s\n", pass(mono))
plateau = count(x -> abs(x - 0.5) < 1e-6, rlo)
@printf("   nodes sitting exactly at 0.5 (the nz=2 signature): %d\n", plateau)
println("   interpretation: a plateau at exactly one half means the two z states")
println("   flip at different thresholds, so the cell response is a two-step and")
println("   ALL aggregate smoothness comes from the taste distribution.")

println("\n2.1 REDUCTION FIDELITY: family interpolation vs a direct solve, off-grid u")
fam_u = d[:,1]; fam_r = d[:,2]
@printf("%-8s | %-12s | %-12s | %-10s\n", "u", "interpolated", "direct solve", "abs error")
maxerr = 0.0
for uq in (4.7, 5.1, 5.3, 5.7, 6.1, 7.3)
    itp = interp(fam_u, fam_r, uq)
    p = update(cell_params(0.765; na = 200, ne = 40); social_strength = uq)
    dir = solve_participation(p, 1.0)[2]
    err = abs(itp - dir); global maxerr = max(maxerr, err)
    @printf("%-8.2f | %.6f     | %.6f     | %.2e\n", uq, itp, dir, err)
end
@printf("   max interpolation error = %.2e   %s\n", maxerr, pass(maxerr < 0.02))

println("\n2.2 quadrature convergence at the NEW calibration (kappa 10.75, sigma 0.750)")
fl = (d[:,1], d[:,2], d[:,3]); fh = (d[:,1], d[:,4], d[:,5])
Bl = CELL_LOW.B; Bh = CELL_HIGH.B
function eq(κ, σ, nodes)
    g = range(0.0, 1.0, length = 801)
    o = [population_rate(fl, fh, Bl, Bh, κ, 0.30, σ, r; n_nodes = nodes)[1] for r in g]
    for i in 1:800
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1/(d1-d2); rs = g[i]+t*(g[i+1]-g[i])
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            sl < 1 && return (rs, sl)
        end
    end
    (NaN, NaN)
end
prev = NaN
for n in (500, 1000, 2000, 4000, 8000)
    r, s = eq(10.75, 0.750, n)
    @printf("   n=%-5d  rate %.5f  slope %.5f   change %s\n", n, r, s,
            isnan(prev) ? "-" : @sprintf("%.1e", abs(r-prev)))
    global prev = r
end
println("\nDONE")
