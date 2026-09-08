# Recalibration of (kappa, sigma_m) on the stage-5 core. The omega sweep found
# the moments are fit far better at (10.00, 0.510) than at the stage-4 point
# (10.75, 0.750), with a very different verdict. Redo it with the full
# protocol: 2000 taste nodes, 401-point map, fine refinement, and the loss
# surface printed so the shape of the valley is visible.
#   julia --project=. scripts/sa_recalibrate_l5.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics
const OMEGA = 0.30; const NQ = 2000
const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B
rd(f) = (d = readdlm(f, '\t'; skipstart = 1); (d[:,1], d[:,2], d[:,3], d[:,4]))
fl = rd(joinpath(@__DIR__, "cache_l5_theta0.0100_amax4.0_pexp3.0", "fam_0p765000_0p000000_0p000000_0p000000.txt"))
fh = rd(joinpath(@__DIR__, "cache_l5_theta0.0100_amax4.0_pexp3.0", "fam_0p911000_0p000000_0p000000_0p000000.txt"))
const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, n) = get!(TASTE, (σ, n)) do; taste_nodes_ln(σ; n = n) end
phi(z) = exp(-z^2/2)/sqrt(2pi)
function equil(κ, σ; n = NQ, ngrid = 401)
    ms = tastes(σ, n); g = range(0.0, 1.0, length = ngrid)
    f(rin) = (arg = OMEGA + (1-OMEGA)*clamp(rin,0,1);
              (0.5*mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms) +
               0.5*mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms)))
    o = [f(r) for r in g]; best = nothing; nst = 0
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            if sl < 1
                nst += 1; rs = g[i]+d1/(d1-d2)*(g[i+1]-g[i]); arg = OMEGA+(1-OMEGA)*rs
                lo = mean(interp(fl[1],fl[2],κ*m*Bl*arg) for m in ms)
                hi = mean(interp(fh[1],fh[2],κ*m*Bh*arg) for m in ms)
                L = (lo-0.25)^2 + (hi-0.45)^2
                (best === nothing || L < best.L) && (best = (r=rs, lo=lo, hi=hi, slope=sl, L=L))
            end
        end
    end
    best === nothing ? nothing : merge(best, (nstable = nst,))
end
println("loss surface, sqrt of the moment loss, 2000 nodes (rows sigma, cols kappa)")
ks = 8.0:0.5:13.0; ss = 0.40:0.05:0.90
@printf("%6s", "sig\\kap"); for κ in ks; @printf(" %6.1f", κ); end; println()
for σ in ss
    @printf("%6.2f", σ)
    for κ in ks
        e = equil(κ, σ; n = 500, ngrid = 201)
        e === nothing ? @printf(" %6s", "-") : @printf(" %6.3f", sqrt(e.L))
    end
    println(); flush(stdout)
end
println("\nfine search at 2000 nodes, 401 grid")
function search(κs, σs)
    bb = nothing
    for κ in κs, σ in σs
        e = equil(κ, σ); e === nothing && continue
        (bb === nothing || e.L < bb.e.L) && (bb = (κ=κ, σ=σ, e=e))
    end
    bb
end
c = search(8.0:0.25:13.0, 0.40:0.02:0.90)
b = search(max(1,c.κ-0.5):0.05:c.κ+0.5, max(0.05,c.σ-0.03):0.005:c.σ+0.03)
comp = (1-OMEGA)/(OMEGA+(1-OMEGA)*b.e.r)
dens = 0.5phi(quantile_normal(1-b.e.lo)) + 0.5phi(quantile_normal(1-b.e.hi))
sb = comp*dens
@printf("kappa* = %.2f  sigma* = %.3f\n", b.κ, b.σ)
@printf("rate %.4f, groups %.4f / %.4f (targets 0.25 / 0.45), sqrt loss %.4f\n", b.e.r, b.e.lo, b.e.hi, sqrt(b.e.L))
@printf("slope %.4f, multiplier 1/(1-G') %.2f, stable equilibria %d\n", b.e.slope, 1/(1-b.e.slope), b.e.nstable)
@printf("sigma-bar %.4f, ratio sigma*/sigma-bar %.3f\n", sb, b.σ/sb)
println("\nfor comparison, the stage-4 point on this core:")
e = equil(10.75, 0.750)
@printf("(10.75, 0.750): rate %.4f, groups %.4f / %.4f, sqrt loss %.4f, slope %.4f\n", e.r, e.lo, e.hi, sqrt(e.L), e.slope)
println("\nconvergence of the new point in taste nodes")
for n in (500, 1000, 2000, 4000)
    e = equil(b.κ, b.σ; n = n); @printf("  n=%-5d rate %.4f slope %.4f\n", n, e.r, e.slope)
end
println("DONE")
