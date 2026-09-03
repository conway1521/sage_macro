# Definitive recalibration: fine-grid families, converged taste quadrature.
# The taste integral converges slowly because the cell response is a near-step,
# so the paper's 15 nodes are far too few; 2000 is converged to the third
# decimal (8000 moves the equilibrium by 0.002).
#
#   julia --project=. scripts/sa_recalibrate_final.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B; const OMEGA = 0.30
const NQ = 2000
d = readdlm(joinpath(@__DIR__, "sa_families_fine.txt"), '\t'; skipstart = 1)
fl = (d[:,1], d[:,2], d[:,3]); fh = (d[:,1], d[:,4], d[:,5])
phi(z) = exp(-z^2/2)/sqrt(2pi)

function equil(κ, σ; nodes = NQ, ngrid = 401)
    g = range(0.0, 1.0, length = ngrid)
    o = [population_rate(fl, fh, Bl, Bh, κ, OMEGA, σ, r; n_nodes = nodes)[1] for r in g]
    best = nothing; nstable = 0
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1/(d1-d2); rs = g[i]+t*(g[i+1]-g[i])
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            if sl < 1
                nstable += 1
                _, lo, hi = population_rate(fl, fh, Bl, Bh, κ, OMEGA, σ, rs; n_nodes = nodes)
                loss = (lo-0.25)^2 + (hi-0.45)^2
                (best === nothing || loss < best.loss) &&
                    (best = (r=rs, lo=lo, hi=hi, slope=sl, loss=loss))
            end
        end
    end
    best === nothing ? nothing : merge(best, (nstable = nstable,))
end

function search(κs, σs)
    bb = nothing
    for κ in κs, σ in σs
        b = equil(κ, σ)
        b === nothing && continue
        (bb === nothing || b.loss < bb.b.loss) && (bb = (κ=κ, σ=σ, b=b))
    end
    bb
end

println("stage 1: coarse search at $NQ quadrature nodes")
c = search(2.0:1.0:30.0, 0.20:0.05:1.20)
@printf("  kappa %.2f sigma %.2f -> rate %.4f (%.4f / %.4f) loss %.2e\n",
        c.κ, c.σ, c.b.r, c.b.lo, c.b.hi, c.b.loss)
println("stage 2: refine")
b = search(max(1.0,c.κ-1.0):0.25:c.κ+1.0, max(0.05,c.σ-0.05):0.01:c.σ+0.05)
@printf("  kappa* = %.2f  sigma* = %.3f -> rate %.4f (low %.4f, high %.4f), loss %.2e\n",
        b.κ, b.σ, b.b.r, b.b.lo, b.b.hi, b.b.loss)
@printf("  stable equilibria at the calibrated point: %d ; map slope %.4f\n",
        b.b.nstable, b.b.slope)

r, pl, ph = b.b.r, b.b.lo, b.b.hi
comp = (1-OMEGA)/(OMEGA+(1-OMEGA)*r)
dens = 0.5*phi(quantile_normal(1-pl)) + 0.5*phi(quantile_normal(1-ph))
sigbar = comp*dens
println("\nTHE PROPOSITION AT THE CONVERGED CALIBRATION")
@printf("  sigma-bar (multiplicity needs sigma below this) = %.4f\n", sigbar)
@printf("  sigma* (fits the gradient)                      = %.4f\n", b.σ)
@printf("  ratio sigma*/sigma-bar = %.3f   -> %s\n", b.σ/sigbar,
        b.σ/sigbar > 1 ? "OUTSIDE the coordination region (discipline result HOLDS)" :
                         "INSIDE the analytic condition (discipline result FAILS on the bound)")
@printf("  numerical slope %.4f (unique equilibrium requires < 1)\n", b.b.slope)

println("\nconvergence of the calibrated point")
for n in (500, 1000, 2000, 4000)
    e = equil(b.κ, b.σ; nodes = n)
    @printf("  n=%-5d rate %.4f (low %.4f, high %.4f) slope %.4f\n", n, e.r, e.lo, e.hi, e.slope)
end
println("DONE")
