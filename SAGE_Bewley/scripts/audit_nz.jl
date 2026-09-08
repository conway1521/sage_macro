# Is nz = 2 the root cause of everything that went wrong?
#
# The diagnosis to test. With two income states a cell's participation response
# has two switching populations, so r(u) is essentially a two-step function: at
# the calibrated point it sits at 0 up to u = 4.4, hits a plateau at exactly
# 0.5, and reaches 1 by u = 6.2. The whole transition is 1.8 wide in u, which
# is 16 percent of the taste distribution. That is why the quadrature needs
# thousands of nodes: at fifteen nodes only 2.4 of them land in the transition,
# so the answer was decided by where those two or three nodes happened to fall.
# Every reversal in the S+A results traces back through that.
#
# If the diagnosis is right, raising nz should
#   H1  smooth the response: more, smaller steps over a wider interval
#   H2  make the taste quadrature converge with far fewer nodes
#   H3  improve the gradient fit, which no (kappa, sigma) pair can reach now
#   H4  lower the map slope, strengthening the discipline result and shrinking
#       the policy multiplier
#
# Run at na = 100 throughout, including the nz = 2 row, so the comparison is
# internal. The stationary distribution is computed by dense repeated squaring
# in the participation core, which is O(n^3) in na*nz, and that is what makes
# large nz expensive here.
#
#   julia --project=. scripts/audit_nz.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles

const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const OMEGA = 0.30
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const NA = 100
const CACHEDIR = joinpath(@__DIR__, "cache_nz")
isdir(CACHEDIR) || mkpath(CACHEDIR)

phi(z) = exp(-z^2 / 2) / sqrt(2pi)
const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, n) = get!(TASTE, (σ, n)) do; taste_nodes_ln(σ; n = n) end

"Cell parameters at an arbitrary number of income states."
cellp(αg, nz; na = NA, ne = 40) =
    SAGEParams(na = na, ne = ne, nz = nz, α = fill(αg, nz), B = fill(1.0, nz))

function family(α, nz)
    f = joinpath(CACHEDIR, "fam_nz$(nz)_na$(NA)_" * replace(@sprintf("%.3f", α), "." => "p") * ".txt")
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1); return (d[:, 1], d[:, 2], d[:, 3])
    end
    t0 = time()
    r = Float64[]; mi = Float64[]
    for u in UGRID
        _, rate, m, _ = solve_participation(update(cellp(α, nz); social_strength = u), 1.0)
        push!(r, rate); push!(mi, m)
    end
    open(f, "w") do io
        println(io, join(["u", "r", "minc"], '\t'))
        for i in eachindex(UGRID); println(io, join([UGRID[i], r[i], mi[i]], '\t')); end
    end
    @printf("    [family alpha %.3f nz %d built in %.0f s]\n", α, nz, time() - t0); flush(stdout)
    (copy(UGRID), r, mi)
end

function rates(fl, fh, κ, σ, rin, nq)
    ms = tastes(σ, nq); arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[2], κ * m * Blow  * arg) for m in ms)
    hi = mean(interp(fh[1], fh[2], κ * m * Bhigh * arg) for m in ms)
    (0.5lo + 0.5hi, lo, hi)
end
function equil(fl, fh, κ, σ; nq = 2000, ngrid = 401)
    g = range(0.0, 1.0, length = ngrid)
    o = [rates(fl, fh, κ, σ, r, nq)[1] for r in g]
    best = nothing; nst = 0
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            if sl < 1
                nst += 1
                rs = g[i] + d1/(d1-d2)*(g[i+1]-g[i])
                (best === nothing || rs > best.r) &&
                    (best = (r = rs, slope = sl))
            end
        end
    end
    best === nothing && return nothing
    _, lo, hi = rates(fl, fh, κ, σ, best.r, nq)
    (r = best.r, lo = lo, hi = hi, slope = best.slope, nstable = nst)
end
function calibrate(fl, fh; nq = 2000)
    best = nothing
    for κ in 2.0:1.0:30.0, σ in 0.20:0.05:1.20
        E = equil(fl, fh, κ, σ; nq = nq, ngrid = 201); E === nothing && continue
        L = (E.lo - 0.25)^2 + (E.hi - 0.45)^2
        (best === nothing || L < best.L) && (best = (κ=κ, σ=σ, L=L))
    end
    b2 = nothing
    for κ in max(1.0, best.κ-1.0):0.25:best.κ+1.0, σ in max(0.05, best.σ-0.05):0.01:best.σ+0.05
        E = equil(fl, fh, κ, σ; nq = nq); E === nothing && continue
        L = (E.lo - 0.25)^2 + (E.hi - 0.45)^2
        (b2 === nothing || L < b2.L) && (b2 = (κ=κ, σ=σ, L=L, E=E))
    end
    b2
end

println("="^78)
println("IS nz = 2 THE ROOT CAUSE? Response shape, quadrature, fit and slope")
println("="^78)
@printf("na = %d throughout, including the nz = 2 row, so the comparison is internal.\n\n", NA)

results = []
for nz in (2, 3, 5, 7)
    @printf("--- nz = %d ---\n", nz); flush(stdout)
    fl = family(CELL_LOW.α, nz); fh = family(CELL_HIGH.α, nz)

    # H1: the shape of the response
    r = fl[2]
    i0 = findfirst(>(0.001), r); i1 = findfirst(>(0.999), r)
    width = (i0 === nothing || i1 === nothing) ? NaN : UGRID[i1] - UGRID[i0]
    levels = length(unique(round.(r, digits = 3)))
    plateau = maximum(vcat(0, [count(x -> abs(x - v) < 1e-6, r) for v in unique(r) if 0.01 < v < 0.99]))
    @printf("  H1 shape: transition %.1f wide in u, %d distinct levels, longest interior plateau %d nodes\n",
            width, levels, plateau)

    # H3/H4: recalibrate and read the bound
    c = calibrate(fl, fh)
    comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * c.E.r)
    dens = 0.5phi(quantile_normal(1 - c.E.lo)) + 0.5phi(quantile_normal(1 - c.E.hi))
    sigbar = comp * dens
    @printf("  H3 fit:   kappa* %.2f sigma* %.3f -> rate %.4f, groups %.4f / %.4f, gap %.4f (target 0.200)\n",
            c.κ, c.σ, c.E.r, c.E.lo, c.E.hi, c.E.hi - c.E.lo)
    @printf("  H4 slope: G' %.4f, multiplier 1/(1-G') %.2f, sigma-bar %.4f, ratio %.3f\n",
            c.E.slope, 1/(1 - c.E.slope), sigbar, c.σ / sigbar)

    # H2: how many quadrature nodes does the calibrated point need?
    ref = equil(fl, fh, c.κ, c.σ; nq = 8000).r
    need = missing
    for nq in (15, 30, 60, 125, 250, 500, 1000, 2000, 4000)
        e = equil(fl, fh, c.κ, c.σ; nq = nq)
        err = abs(e.r - ref)
        if need === missing && err < 0.002; need = nq; end
    end
    @printf("  H2 quad:  nodes needed for 0.002 accuracy: %s (reference at 8000 nodes: %.4f)\n\n",
            need === missing ? ">4000" : string(need), ref)
    flush(stdout)
    push!(results, (nz=nz, width=width, levels=levels, κ=c.κ, σ=c.σ, r=c.E.r,
                    lo=c.E.lo, hi=c.E.hi, slope=c.E.slope, sigbar=sigbar, need=need))
end

println("="^78)
@printf("%-4s | %-9s | %-7s | %-7s | %-13s | %-7s | %-7s | %-6s | %s\n",
        "nz", "width", "kappa*", "sigma*", "group rates", "gap", "G'", "ratio", "nodes")
for x in results
    @printf("%-4d | %9.1f | %7.2f | %7.3f | %.3f / %.3f | %7.4f | %7.4f | %6.3f | %s\n",
            x.nz, x.width, x.κ, x.σ, x.lo, x.hi, x.hi - x.lo, x.slope,
            x.σ/x.sigbar, x.need === missing ? ">4000" : string(x.need))
end
open(joinpath(@__DIR__, "audit_nz_results.txt"), "w") do io
    println(io, join(["nz","width","levels","kappa","sigma","rate","lo","hi","slope","sigbar","nodes"], '\t'))
    for x in results
        println(io, join([x.nz, x.width, x.levels, x.κ, x.σ, x.r, x.lo, x.hi, x.slope, x.sigbar,
                          x.need === missing ? -1 : x.need], '\t'))
    end
end
println("\nDONE")
