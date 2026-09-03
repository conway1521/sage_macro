# Recalibrate on the fine-grid families, and check the taste quadrature is
# actually converged this time. Reports the new (kappa, sigma_m), the
# equilibrium it implies, and the proposition's bound at that equilibrium.
#
#   julia --project=. scripts/sa_recalibrate.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B; const OMEGA = 0.30
d = readdlm(joinpath(@__DIR__, "sa_families_fine.txt"), '\t'; skipstart = 1)
fl = (d[:,1], d[:,2], d[:,3]); fh = (d[:,1], d[:,4], d[:,5])
phi(z) = exp(-z^2/2)/sqrt(2pi)

function equil(κ, σ, ω; nodes = 60)
    grid = range(0.0, 1.0, length = 801)
    out  = [population_rate(fl, fh, Bl, Bh, κ, ω, σ, r; n_nodes = nodes)[1] for r in grid]
    best = nothing
    for i in 1:800
        d1 = out[i]-grid[i]; d2 = out[i+1]-grid[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1/(d1-d2); rs = grid[i]+t*(grid[i+1]-grid[i])
            slope = (out[i+1]-out[i])/(grid[i+1]-grid[i])
            if slope < 1
                _, lo, hi = population_rate(fl, fh, Bl, Bh, κ, ω, σ, rs; n_nodes = nodes)
                loss = (lo-0.25)^2 + (hi-0.45)^2
                (best === nothing || loss < best.loss) && (best = (r=rs, lo=lo, hi=hi, loss=loss))
            end
        end
    end
    best
end

println("(a) taste-quadrature convergence on the FINE families, at the old (kappa,sigma)")
for n in (15, 30, 60, 120, 200)
    b = equil(10.0, 0.5, OMEGA; nodes = n)
    b === nothing ? @printf("%-5d | no stable equilibrium\n", n) :
        @printf("%-5d | rate %.4f  low %.4f  high %.4f\n", n, b.r, b.lo, b.hi)
end

println("\n(b) recalibrating (kappa, sigma_m) to the INSEE targets 0.25 / 0.45, 120 nodes")
function search(κs, σs, nodes)
    bb = nothing
    for κ in κs, σ in σs
        b = equil(κ, σ, OMEGA; nodes = nodes)
        b === nothing && continue
        (bb === nothing || b.loss < bb.b.loss) && (bb = (κ=κ, σ=σ, b=b))
    end
    bb
end
coarse = search(2.0:1.0:30.0, 0.20:0.05:1.20, 120)
@printf("coarse stage: kappa %.2f sigma %.2f loss %.6f\n", coarse.κ, coarse.σ, coarse.b.loss)
best = search(max(1.0,coarse.κ-1.0):0.25:coarse.κ+1.0,
              max(0.05,coarse.σ-0.05):0.01:coarse.σ+0.05, 120)
@printf("kappa* = %.2f  sigma* = %.2f   ->  rate %.4f (low %.4f, high %.4f), loss %.6f\n",
        best.κ, best.σ, best.b.r, best.b.lo, best.b.hi, best.b.loss)

println("\n(c) the proposition at the new calibration")
r, pl, ph = best.b.r, best.b.lo, best.b.hi
comp = (1-OMEGA)/(OMEGA+(1-OMEGA)*r)
dens = 0.5*phi(quantile_normal(1-pl)) + 0.5*phi(quantile_normal(1-ph))
sigbar = comp*dens
@printf("sigma-bar = %.4f   sigma* = %.4f   ratio = %.3f  (>1 means NO multiplicity)\n",
        sigbar, best.σ, best.σ/sigbar)
G(x) = population_rate(fl, fh, Bl, Bh, best.κ, OMEGA, best.σ, x; n_nodes = 120)[1]
h = 1e-4
@printf("numerical G'(r*) = %.4f   analytic threshold slope = %.4f\n",
        (G(r+h)-G(r-h))/(2h), sigbar/best.σ)

println("\n(d) verdict on stability of the calibration itself")
for n in (60, 120, 200)
    b = equil(best.κ, best.σ, OMEGA; nodes = n)
    @printf("nodes %-4d | rate %.4f  low %.4f  high %.4f\n", n, b.r, b.lo, b.hi)
end
println("DONE")
