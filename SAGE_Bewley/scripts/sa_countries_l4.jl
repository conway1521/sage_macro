# Cross-country robustness for the S+A policy results, on the Level 4 footing.
# The social technology (kappa, sigma_m, omega) is held at the recalibrated
# French values; only the country's agency gap and belonging tastes move, from
# the engine's country rows. So this asks whether the SIGNS survive the
# observed cross-country spread in agency and belonging, not whether seven
# separate calibrations fit.
#
# Differences from the superseded sa_countries.jl: the concentrated belonging
# grid instead of the uniform one that put three nodes on the transition, 2000
# taste nodes instead of 15, and kappa = 10.75, sigma = 0.750.
#
#   julia --project=. scripts/sa_countries_l4.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics
# ---- numerical footing, stage 5 (2026-09-08) --------------------------------
# Logit participation (Brock-Durlauf), theta a small regulariser whose limit is
# the hard-threshold model; asset grid rescaled to the wealth distribution.
const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)


const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ = 2000
const OMEGA = 0.30; const KAPPA = 10.00; const SIGMA = 0.495
const SUB = 0.20        # financed work subsidy
const RHO = 0.25        # Gift Aid rate credit

const MS = taste_nodes_ln(SIGMA; n = NQ)

function build(α, T; subsidy = 0.0, partcredit = 0.0)
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = 200, ne = 40, a_max = GRID.a_max, pexp = GRID.pexp, subsidy = subsidy, lumptax = T);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, b = solve_participation_logit(p, 1.0; theta = THETA)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    (copy(UGRID), r, mi, pb)
end

function popcol(fl, fh, Bl, Bh, rin, col)
    arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], KAPPA * m * Bl * arg) for m in MS)
    hi = mean(interp(fh[1], fh[col], KAPPA * m * Bh * arg) for m in MS)
    (0.5 * lo + 0.5 * hi, lo, hi)
end

function eqr(fl, fh, Bl, Bh; ngrid = 401)
    g = range(0.0, 1.0, length = ngrid)
    o = [popcol(fl, fh, Bl, Bh, r, 2)[1] for r in g]
    best = NaN
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            sl < 1 && (best = g[i] + d1/(d1-d2)*(g[i+1]-g[i]))
        end
    end
    best
end

@printf("%-3s | %-9s | %-7s | %-7s | %-7s | %-7s | %s\n",
        "cty", "alpha gap", "base r", "subsidy", "credit", "dSub", "dCred")
rows = []
for code in ("FR", "DE", "IT", "US", "CO", "ZA", "CN")
    p = country_params(code)
    αl, αh = p.α[1], p.α[2]; Bl, Bh = p.B[1], p.B[2]

    fl = build(αl, 0.0); fh = build(αh, 0.0)
    r0 = eqr(fl, fh, Bl, Bh); mi0 = popcol(fl, fh, Bl, Bh, r0, 3)[1]

    T = SUB * mi0; local rs = NaN
    for _ in 1:3
        sl = build(αl, T; subsidy = SUB); sh = build(αh, T; subsidy = SUB)
        rs = eqr(sl, sh, Bl, Bh)
        T = SUB * popcol(sl, sh, Bl, Bh, rs, 3)[1]
    end

    Tc = 0.0; local rc = NaN
    for _ in 1:3
        cl = build(αl, Tc; partcredit = RHO); ch = build(αh, Tc; partcredit = RHO)
        rc = eqr(cl, ch, Bl, Bh)
        _, pbl, pbh = popcol(cl, ch, Bl, Bh, rc, 4)
        Tc = QBAR * RHO * (0.5 * pbl + 0.5 * pbh)
    end

    push!(rows, (code = code, gap = αh - αl, r0 = r0, rs = rs, rc = rc))
    @printf("%-3s |   %.3f   |  %.3f  |  %.3f  |  %.3f  |  %+.3f |  %+.3f\n",
            code, αh - αl, r0, rs, rc, rs - r0, rc - r0)
    flush(stdout)
end

nsub = count(x -> x.rs < x.r0, rows); ncred = count(x -> x.rc > x.r0, rows)
@printf("\nsigns: subsidy lowers participation in %d of %d, credit raises it in %d of %d\n",
        nsub, length(rows), ncred, length(rows))
open(joinpath(@__DIR__, "sa_countries_l4.txt"), "w") do io
    println(io, join(["code", "agency_gap", "baseline", "subsidy", "credit"], '\t'))
    for r in rows
        println(io, join([r.code, r.gap, r.r0, r.rs, r.rc], '\t'))
    end
end
println("saved sa_countries_l4.txt")
println("DONE")
