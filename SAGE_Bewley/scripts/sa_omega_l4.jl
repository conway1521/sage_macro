# Robustness of the verdict to the private share omega (stage 5: reads the
# logit-core families written by sa_figures_l4.jl), the one
# parameter with no point estimate. The families do not depend on omega (it
# enters only the belonging argument), so this is pure interpolation on the
# cached Level 4 families: for each omega, recalibrate (kappa, sigma_m) to the
# INSEE moments, then re-evaluate the bound and the numerical frontier.
#
#   julia --project=. scripts/sa_omega_l4.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf
const THETA = 0.005, Statistics

const NQ = 2000
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
dl = readdlm(joinpath(@__DIR__, @sprintf("sa_l5_theta%.4f_fam_low.txt", THETA)), '\t'; skipstart = 1)
dh = readdlm(joinpath(@__DIR__, @sprintf("sa_l5_theta%.4f_fam_high.txt", THETA)), '\t'; skipstart = 1)
fl = (dl[:,1], dl[:,2], dl[:,3], dl[:,4]); fh = (dh[:,1], dh[:,2], dh[:,3], dh[:,4])
const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, nq = NQ) = get!(TASTE, (σ, nq)) do; taste_nodes_ln(σ; n = nq) end
const _ = nothing
phi(z) = exp(-z^2/2)/sqrt(2pi)

function rates(κ, σ, ω, rin; nq = NQ)
    ms = tastes(σ, nq); arg = ω + (1-ω)*clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[2], κ*m*Blow*arg)  for m in ms)
    hi = mean(interp(fh[1], fh[2], κ*m*Bhigh*arg) for m in ms)
    (0.5lo + 0.5hi, lo, hi)
end
function eqs_of(κ, σ, ω; ngrid = 401, nq = NQ)
    g = range(0.0, 1.0, length = ngrid)
    o = [rates(κ, σ, ω, r; nq = nq)[1] for r in g]
    out = NamedTuple[]
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            push!(out, (r = g[i]+d1/(d1-d2)*(g[i+1]-g[i]), slope = sl, stable = sl < 1))
        end
    end
    out
end
function calibrate(ω, κs, σs; ngrid = 401, nq = NQ)
    best = nothing
    for κ in κs, σ in σs
        for e in eqs_of(κ, σ, ω; ngrid = ngrid, nq = nq)
            e.stable || continue
            _, lo, hi = rates(κ, σ, ω, e.r; nq = nq)
            L = (lo-0.25)^2 + (hi-0.45)^2
            (best === nothing || L < best.L) &&
                (best = (κ=κ, σ=σ, r=e.r, lo=lo, hi=hi, slope=e.slope, L=L))
        end
    end
    best
end

@printf("%-6s | %-7s | %-7s | %-7s | %-13s | %-8s | %-8s | %-7s | %s\n",
        "omega","kappa*","sigma*","rate","group rates","slope","sigma-bar","ratio","frontier")
for ω in (0.15, 0.30, 0.50)
    c = calibrate(ω, 2.0:1.0:30.0, 0.20:0.05:1.20; ngrid = 101, nq = 500)
    c = calibrate(ω, max(1.0,c.κ-1.5):0.25:c.κ+1.5, max(0.05,c.σ-0.08):0.01:c.σ+0.08)
    comp = (1-ω)/(ω+(1-ω)*c.r)
    dens = 0.5phi(quantile_normal(1-c.lo)) + 0.5phi(quantile_normal(1-c.hi))
    sb = comp*dens
    front = NaN
    for σ in 1.20:-0.02:0.05
        count(e -> e.stable, eqs_of(c.κ, σ, ω; ngrid = 201)) > 1 && (front = σ; break)
    end
    @printf("%.2f   | %6.2f  | %6.3f  | %.4f  | %.3f / %.3f | %.4f   | %.4f   | %.3f  | %s\n",
            ω, c.κ, c.σ, c.r, c.lo, c.hi, c.slope, sb, c.σ/sb,
            isnan(front) ? "none" : @sprintf("%.2f", front))
    flush(stdout)
end
println("DONE")
