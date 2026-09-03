# Numerical accuracy for the S+A paper. The paper's computational core is the
# response-family reduction: each cell's participation response is precomputed
# on a grid of the belonging scale, and every map evaluation, calibration step
# and counterfactual is interpolation on that family. So the checks that matter
# are (i) the taste quadrature, (ii) the resolution of the family grid, and
# (iii) the sensitivity of the equilibrium to the one parameter without a point
# estimate, the private share omega.
#
#   julia --project=. scripts/sa_diagnostics.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const KAPPA = 10.0; const SIGMA = 0.5
const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B
d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
fl = (d[:,1], d[:,2], d[:,3]); fh = (d[:,1], d[:,4], d[:,5])

function eqinfo(fl, fh, ω, σ; nodes = 15)
    grid = range(0.0, 1.0, length = 401)
    out  = [population_rate(fl, fh, Bl, Bh, KAPPA, ω, σ, r; n_nodes = nodes)[1] for r in grid]
    eqs = Tuple{Float64,Bool}[]
    for i in 1:400
        d1 = out[i]-grid[i]; d2 = out[i+1]-grid[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1/(d1-d2); rs = grid[i]+t*(grid[i+1]-grid[i])
            push!(eqs, (rs, (out[i+1]-out[i])/(grid[i+1]-grid[i]) < 1))
        end
    end
    st = [e for e in eqs if e[2]]
    isempty(st) && return (NaN, NaN, NaN, length(st))
    r = st[argmax([e[1] for e in st])][1]
    _, lo, hi = population_rate(fl, fh, Bl, Bh, KAPPA, ω, σ, r; n_nodes = nodes)
    (r, lo, hi, length(st))
end

println("(i) taste quadrature: equilibrium against the number of lognormal nodes")
@printf("%-8s | %-8s | %-8s | %-8s\n", "nodes", "rate", "low", "high")
for n in (10, 15, 30, 60)
    r, lo, hi, _ = eqinfo(fl, fh, 0.30, SIGMA; nodes = n)
    @printf("%-8d |  %.4f  |  %.4f  |  %.4f\n", n, r, lo, hi)
end

println("\n(ii) family grid: equilibrium on the full 41-node family and a 21-node subsample")
sub(f) = (f[1][1:2:end], f[2][1:2:end], f[3][1:2:end])
for (nm, a, b) in (("41 nodes", fl, fh), ("21 nodes", sub(fl), sub(fh)))
    r, lo, hi, _ = eqinfo(a, b, 0.30, SIGMA)
    @printf("%-8s |  %.4f  |  %.4f  |  %.4f\n", nm, r, lo, hi)
end

println("\n(iii) private share omega: equilibrium and stability at the calibrated kappa, sigma")
@printf("%-8s | %-8s | %-8s | %-8s | %s\n", "omega", "rate", "low", "high", "# stable")
for ω in (0.15, 0.30, 0.50)
    r, lo, hi, ns = eqinfo(fl, fh, ω, SIGMA)
    @printf("%-8.2f |  %.4f  |  %.4f  |  %.4f  |  %d\n", ω, r, lo, hi, ns)
end

println("\n(iv) slope of the aggregate map at the calibrated equilibrium")
r0, _, _, _ = eqinfo(fl, fh, 0.30, SIGMA)
G(x) = population_rate(fl, fh, Bl, Bh, KAPPA, 0.30, SIGMA, x)[1]
h = 1e-4
@printf("G'(r*) = %.4f  (stability requires < 1)\n", (G(r0+h)-G(r0-h))/(2h))
println("\nUnderlying household solves use na = 200 exponential asset nodes and")
println("ne = 40 effort nodes; the family is 41 nodes on the belonging scale.")
println("DONE")
