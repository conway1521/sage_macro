# The income-process sweep, repeated on the stage-5 core. The stage-4 version
# (audit_nz.jl) ran on the hard threshold at the old calibration and found the
# conclusions stable from nz = 5 upward. That result is inherited rather than
# established until it is redone here, because the core, the asset grid, the
# effort grid and the calibrated point have all changed since.
#
# Held fixed for an internal comparison: na = 100 (as in the stage-4 version,
# so the two are comparable), ne = 80, theta = 0.005, a_max = 4, pexp = 3.
# (kappa, sigma_m) is RECALIBRATED at each nz, since holding it fixed across a
# structural change is the mistake that produced the stage-4 detour.
#
#   julia --project=. scripts/audit_nz_l5.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles

const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const OMEGA = 0.30; const THETA = 0.005
const GRID = (a_max = 4.0, pexp = 3.0)
const NA = 200; const NE = 80
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const CACHEDIR = joinpath(@__DIR__, "cache_nz_l5"); isdir(CACHEDIR) || mkpath(CACHEDIR)
phi(z) = exp(-z^2/2)/sqrt(2pi)
const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, n) = get!(TASTE, (σ,n)) do; taste_nodes_ln(σ; n=n) end

cellp(αg, nz) = SAGEParams(na = NA, ne = NE, nz = nz, α = fill(αg, nz),
                           B = fill(1.0, nz), a_max = GRID.a_max, pexp = GRID.pexp)

function family(α, nz)
    f = joinpath(CACHEDIR, @sprintf("fam_nz%d_na%d_ne%d_%.3f.txt", nz, NA, NE, α))
    if isfile(f); d = readdlm(f,'\t'; skipstart=1); return (d[:,1], d[:,2], d[:,3]); end
    t0 = time(); r = Float64[]; mi = Float64[]
    for u in UGRID
        _, rate, m, _ = solve_participation_logit(update(cellp(α, nz); social_strength = u),
                                                  1.0; theta = THETA)
        push!(r, rate); push!(mi, m)
    end
    open(f,"w") do io
        println(io, join(["u","r","minc"],'\t'))
        for i in eachindex(UGRID); println(io, join([UGRID[i],r[i],mi[i]],'\t')); end
    end
    @printf("    [family alpha %.3f nz %d built in %.0f s]\n", α, nz, time()-t0); flush(stdout)
    (copy(UGRID), r, mi)
end

function rates(fl, fh, κ, σ, rin, nq)
    ms = tastes(σ, nq); arg = OMEGA + (1-OMEGA)*clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[2], κ*m*Blow*arg)  for m in ms)
    hi = mean(interp(fh[1], fh[2], κ*m*Bhigh*arg) for m in ms)
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
                nst += 1; rs = g[i] + d1/(d1-d2)*(g[i+1]-g[i])
                (best === nothing || rs > best.r) && (best = (r=rs, slope=sl))
            end
        end
    end
    best === nothing && return nothing
    _, lo, hi = rates(fl, fh, κ, σ, best.r, nq)
    (r=best.r, lo=lo, hi=hi, slope=best.slope, nstable=nst)
end
function calibrate(fl, fh)
    b = nothing
    for κ in 6.0:0.5:16.0, σ in 0.30:0.05:1.00
        E = equil(fl, fh, κ, σ; nq = 500, ngrid = 201); E === nothing && continue
        L = (E.lo-0.25)^2 + (E.hi-0.45)^2
        (b === nothing || L < b.L) && (b = (κ=κ, σ=σ, L=L))
    end
    b2 = nothing
    for κ in max(1.0,b.κ-0.5):0.05:b.κ+0.5, σ in max(0.05,b.σ-0.05):0.01:b.σ+0.05
        E = equil(fl, fh, κ, σ); E === nothing && continue
        L = (E.lo-0.25)^2 + (E.hi-0.45)^2
        (b2 === nothing || L < b2.L) && (b2 = (κ=κ, σ=σ, E=E, L=L))
    end
    b2
end

println("Income process on the stage-5 core. na=$NA ne=$NE theta=$THETA, recalibrated at each nz.")
@printf("\n%-4s | %-7s %-7s | %-8s %-13s %-8s | %-8s %-7s | %-8s %-7s | %s\n",
        "nz","kappa*","sigma*","rate","groups","rtloss","slope","mult","sigbar","ratio","width")
for nz in (2, 3, 5, 7)
    fl = family(CELL_LOW.α, nz); fh = family(CELL_HIGH.α, nz)
    b = calibrate(fl, fh)
    if b === nothing; @printf("%-4d | no stable equilibrium found\n", nz); continue; end
    E = b.E
    comp = (1-OMEGA)/(OMEGA+(1-OMEGA)*E.r)
    dens = 0.5phi(quantile_normal(1-E.lo)) + 0.5phi(quantile_normal(1-E.hi))
    sb = comp*dens
    # transition width of the low cell's response, the stage-4 diagnostic
    i0 = something(findfirst(>(0.01), fl[2]), 1); i1 = something(findfirst(>(0.99), fl[2]), length(fl[2]))
    @printf("%-4d | %-7.2f %-7.3f | %-8.4f %.3f / %.3f %-8.4f | %-8.4f %-7.2f | %-8.4f %-7.3f | %.1f\n",
            nz, b.κ, b.σ, E.r, E.lo, E.hi, sqrt(b.L), E.slope, 1/(1-E.slope), sb, b.σ/sb,
            fl[1][i1]-fl[1][i0])
    flush(stdout)
end
println("\nDONE")
