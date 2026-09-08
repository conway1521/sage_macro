# Audit of the S+A core. Every check here exists because something was once
# reported wrong, or because a surface was never tested at all. The point is
# not to confirm the current numbers; it is to have standing evidence that the
# next number we quote is not going to reverse.
#
# A1  linearisation identity: amplification must equal 1/(1 - G'(r*)) for a
#     small shock. This is the sharpest single test we have, because it ties a
#     numerical experiment to an analytical prediction with no free parameter.
#     At the OLD footing it failed by 47 percent and nobody ran it.
# A2  asset grid in the participation core. Tier 1 tested na for the engine
#     used by the companion paper. It was never tested for THIS solver.
# A3  map grid: the number of points at which the aggregate map is traced.
# A4  fiscal fixed point: does the lump-sum tax loop actually converge, and to
#     what tolerance.
# A5  equilibrium selection: we take the highest stable crossing. Document the
#     full crossing set so the rule is visible rather than implicit.
# A6  independent route: the cross-country script computes France by a separate
#     code path. It must agree to the fourth decimal.
# A7  the credit's cross-country invariance, which looks too good.
#
#   julia --project=. scripts/audit_sa.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles
# ---- numerical footing, stage 5 (2026-09-08) --------------------------------
# Logit participation (Brock-Durlauf), theta a small regulariser whose limit is
# the hard-threshold model; asset grid rescaled to the wealth distribution.
const THETA = 0.01
const GRID  = (a_max = 4.0, pexp = 3.0)


const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ = 2000
const OMEGA = 0.30; const KAPPA = 10.75; const SIGMA = 0.750
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B

isdir(CACHEDIR) || mkpath(CACHEDIR)

const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ) = get!(TASTE, σ) do; taste_nodes_ln(σ; n = NQ) end

const CACHEDIR = joinpath(@__DIR__, @sprintf("cache_l5_theta%.4f_amax%.1f_pexp%.1f", THETA, GRID.a_max, GRID.pexp))
isdir(CACHEDIR) || mkpath(CACHEDIR)
cachefile(key) = joinpath(CACHEDIR,
    "fam_" * join([replace(@sprintf("%.6f", k), "." => "p") for k in key], "_") * ".txt")

const FAMS = Dict{Any,Any}()
"Response family. `na`/`ne` off the defaults get their own cache namespace."
function family(α; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0, na = 200, ne = 40)
    key = (round(α, digits = 8), round(subsidy, digits = 8),
           round(lumptax, digits = 8), round(partcredit, digits = 8))
    ck = (key, na, ne)
    haskey(FAMS, ck) && return FAMS[ck]
    f = (na == 200 && ne == 40) ? cachefile(key) :
        joinpath(CACHEDIR, "fam_na$(na)_ne$(ne)_" *
                 join([replace(@sprintf("%.6f", k), "." => "p") for k in key], "_") * ".txt")
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1)
        return FAMS[ck] = (d[:, 1], d[:, 2], d[:, 3], d[:, 4])
    end
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = na, ne = ne, a_max = GRID.a_max, pexp = GRID.pexp, subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, b = solve_participation_logit(p, 1.0; theta = THETA)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    open(f, "w") do io
        println(io, join(["u", "r", "minc", "pbase"], '\t'))
        for i in eachindex(UGRID); println(io, join([UGRID[i], r[i], mi[i], pb[i]], '\t')); end
    end
    @printf("    [built family alpha %.3f sub %.2f tax %.4f cred %.2f na %d ne %d]\n",
            α, subsidy, lumptax, partcredit, na, ne); flush(stdout)
    FAMS[ck] = (copy(UGRID), r, mi, pb)
end

function popcol(fl, fh, rin, col; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA, ω = OMEGA)
    ms = tastes(σ); arg = ω + (1 - ω) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], κ * m * Bl * arg) for m in ms)
    hi = mean(interp(fh[1], fh[col], κ * m * Bh * arg) for m in ms)
    (CELL_LOW.share * lo + CELL_HIGH.share * hi, lo, hi)
end
function crossings(fl, fh; ngrid = 401, kw...)
    g = collect(range(0.0, 1.0, length = ngrid))
    o = [popcol(fl, fh, r, 2; kw...)[1] for r in g]
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
function equil(fl, fh; ngrid = 401, kw...)
    c = crossings(fl, fh; ngrid = ngrid, kw...)
    st = [e for e in c if e.stable]
    isempty(st) && return nothing
    e = st[argmax([x.r for x in st])]
    _, lo, hi = popcol(fl, fh, e.r, 2; kw...)
    (r = e.r, lo = lo, hi = hi, slope = e.slope, n = length(st), nall = length(c))
end

phi(z) = exp(-z^2 / 2) / sqrt(2pi)

println("="^78); println("AUDIT OF THE S+A CORE"); println("="^78)
fl0 = family(CELL_LOW.α); fh0 = family(CELL_HIGH.α)
E0 = equil(fl0, fh0); mi0 = popcol(fl0, fh0, E0.r, 3)[1]
@printf("reference: r* = %.5f, groups %.5f / %.5f, slope %.5f, mean income %.5f\n",
        E0.r, E0.lo, E0.hi, E0.slope, mi0)

# ---------------------------------------------------------------------- A1 --
println("\n" * "-"^78)
println("A1. LINEARISATION IDENTITY: amplification against 1/(1 - G')")
println("-"^78)
println("For a small financed subsidy the equilibrium response must equal the direct")
println("response divided by 1 - G'(r*). Curvature makes large shocks depart from it,")
println("so the test is the LIMIT as the shock shrinks, not the value at tau = 0.20.")
const NGA = 1601
E0f = equil(fl0, fh0; ngrid = NGA)
predicted = 1 / (1 - E0f.slope)
@printf("map traced at ngrid = %d for this test, since at small tau the equilibrium\n", NGA)
@printf("moves only a few grid steps and a coarse trace would measure the grid.\n")
@printf("predicted multiplier 1/(1 - %.5f) = %.4f\n\n", E0f.slope, predicted)
@printf("%-8s | %-9s | %-9s | %-9s | %-9s | %s\n",
        "tau", "direct", "equilib", "measured", "predicted", "error")
for τ in (0.01, 0.05, 0.20)
    T = τ * mi0
    local rE = NaN; local flP = fl0; local fhP = fh0
    for _ in 1:4
        flP = family(CELL_LOW.α;  subsidy = τ, lumptax = T)
        fhP = family(CELL_HIGH.α, subsidy = τ, lumptax = T)
        E = equil(flP, fhP; ngrid = NGA); rE = E.r
        Tn = τ * popcol(flP, fhP, rE, 3)[1]
        abs(Tn - T) < 1e-5 && (T = Tn; break)
        T = Tn
    end
    dir = popcol(flP, fhP, E0f.r, 2)[1]
    meas = (E0f.r - rE) / (E0f.r - dir)
    @printf("%.2f     | %+8.5f | %+8.5f | %8.4f  | %8.4f  | %+6.1f%%\n",
            τ, dir - E0f.r, rE - E0f.r, meas, predicted, 100*(meas/predicted - 1))
    flush(stdout)
end

# ---------------------------------------------------------------------- A2 --
println("\n" * "-"^78)
println("A2. ASSET GRID IN THE PARTICIPATION CORE (never tested before)")
println("-"^78)
@printf("%-6s | %-10s | %-10s | %-10s | %-10s | %s\n",
        "na", "r*", "low", "high", "slope", "mean income")
for na in (100, 200, 300, 400)
    fl = family(CELL_LOW.α; na = na); fh = family(CELL_HIGH.α; na = na)
    E = equil(fl, fh)
    @printf("%-6d | %.6f  | %.6f  | %.6f  | %.6f  | %.6f\n",
            na, E.r, E.lo, E.hi, E.slope, popcol(fl, fh, E.r, 3)[1])
    flush(stdout)
end

# ---------------------------------------------------------------------- A3 --
println("\n" * "-"^78)
println("A3. MAP GRID: how finely the aggregate map is traced")
println("-"^78)
@printf("%-8s | %-10s | %-10s | %-10s | %s\n", "ngrid", "r*", "slope", "crossings", "stable")
for ng in (101, 201, 401, 801, 1601)
    E = equil(fl0, fh0; ngrid = ng)
    @printf("%-8d | %.6f  | %.6f  | %-10d | %d\n", ng, E.r, E.slope, E.nall, E.n)
end
println("The slope is a forward difference on this grid, so it is the quantity most")
println("exposed to ngrid, and A1 depends on it directly.")

println("\n" * "-"^78)
println("A2b. WHAT THE ASSET-GRID WOBBLE DOES TO THE CONCLUSIONS")
println("-"^78)
println("A2 shows r* is not settled to better than about a point across na. The")
println("question that matters is whether the CONCLUSIONS move with it, so propagate")
println("each na row through the bound and the multiplier.")
@printf("%-6s | %-8s | %-8s | %-8s | %-9s | %-7s | %s\n",
        "na", "r*", "gap", "G'", "sigma-bar", "ratio", "multiplier")
for na in (100, 200, 300, 400)
    fl = family(CELL_LOW.α; na = na); fh = family(CELL_HIGH.α; na = na)
    E = equil(fl, fh)
    comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * E.r)
    dens = 0.5*phi(quantile_normal(1 - E.lo)) + 0.5*phi(quantile_normal(1 - E.hi))
    sb = comp * dens
    @printf("%-6d | %.5f  | %.5f  | %.5f  | %.5f   | %.4f  | %.4f\n",
            na, E.r, E.hi - E.lo, E.slope, sb, SIGMA/sb, 1/(1 - E.slope)); flush(stdout)
end
println("If the last three columns are stable while the first two are not, the model")
println("is imprecise about the LEVEL of participation and precise about the bound")
println("and the multiplier, which are what the paper actually claims.")

# ---------------------------------------------------------------------- A4 --
println("\n" * "-"^78)
println("A4. FISCAL FIXED POINT: convergence of the lump-sum tax loop")
println("-"^78)
function fiscal_loop()
    Tx = 0.20 * mi0
    @printf("%-6s | %-12s | %-12s | %-12s\n", "iter", "tax in", "rate", "tax out")
    for it in 1:8
        flP = family(CELL_LOW.α;  subsidy = 0.20, lumptax = Tx)
        fhP = family(CELL_HIGH.α, subsidy = 0.20, lumptax = Tx)
        E = equil(flP, fhP); Tn = 0.20 * popcol(flP, fhP, E.r, 3)[1]
        @printf("%-6d | %.9f | %.9f | %.9f\n", it, Tx, E.r, Tn)
        flush(stdout)
        abs(Tn - Tx) < 1e-9 && break
        Tx = Tn
    end
end
fiscal_loop()

# ---------------------------------------------------------------------- A5 --
println("\n" * "-"^78)
println("A5. EQUILIBRIUM SELECTION: the full crossing set at the calibrated point")
println("-"^78)
for e in crossings(fl0, fh0)
    @printf("  crossing at r = %.5f, slope %.5f, %s\n",
            e.r, e.slope, e.stable ? "STABLE" : "unstable")
end
println("The selection rule (highest stable) is only binding when there is more than")
println("one; if the line above shows a single stable crossing the rule is inert here.")

# ---------------------------------------------------------------------- A7 --
println("\n" * "-"^78)
println("A7. WHY IS THE CREDIT'S EFFECT SO SIMILAR ACROSS COUNTRIES?")
println("-"^78)
println("The cross-country run gives the credit a +30 to +34 point effect in every")
println("country, from baselines ranging 0.20 to 0.37. Deltas that stable across")
println("economies that different are more likely to be a saturation artefact than a")
println("finding, so decompose: how much of the move is the direct budget effect and")
println("how much is the feedback?")
@printf("\n%-4s | %-8s | %-8s | %-8s | %-8s | %-8s | %s\n",
        "cty", "base", "direct", "equilib", "d(dir)", "d(eq)", "implied mult")
for code in ("FR", "ZA")
    p = country_params(code)
    αl, αh = p.α[1], p.α[2]; Bl, Bh = p.B[1], p.B[2]
    fl = family(αl); fh = family(αh)
    Eb = equil(fl, fh; Bl = Bl, Bh = Bh)
    Tc = 0.0; local Ec = nothing; local cl = fl; local ch = fh
    for _ in 1:4
        cl = family(αl; lumptax = Tc, partcredit = 0.25)
        ch = family(αh; lumptax = Tc, partcredit = 0.25)
        Ec = equil(cl, ch; Bl = Bl, Bh = Bh)
        _, pl, ph = popcol(cl, ch, Ec.r, 4; Bl = Bl, Bh = Bh)
        Tn = QBAR * 0.25 * (0.5*pl + 0.5*ph)
        abs(Tn - Tc) < 1e-5 && (Tc = Tn; break)
        Tc = Tn
    end
    dir = popcol(cl, ch, Eb.r, 2; Bl = Bl, Bh = Bh)[1]
    @printf("%-4s | %.4f  | %.4f  | %.4f  | %+.4f  | %+.4f  | %.2f\n",
            code, Eb.r, dir, Ec.r, dir - Eb.r, Ec.r - Eb.r,
            (Ec.r - Eb.r) / (dir - Eb.r))
    flush(stdout)
end

println("\nAUDIT DONE"); flush(stdout)
