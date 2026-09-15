# A on its own, and A alongside S: the agency dimension of the SAGE dashboard
# computed on the S+A model, at the stage-5b calibration, without touching
# behaviour.
#
# The agency object is U^a = alpha * (1 - p) of Snower and Lima de Miranda
# (2020) section 3.3, with p the probability of economic hardship. Hardship is
# the OECD asset-poverty event: liquid wealth too small to hold the household
# at the income poverty line for three months (Balestra and Tonkin 2018). See
# agency_core.jl for the derivation and for why the aggregate is exact.
#
# This is an ACCOUNTING layer. It reads the solved households and the existing
# equilibria; it does not enter decision utility, so no behaviour changes, no
# recalibration is implied, and every participation number here must reproduce
# sa_level4_results.txt. The script checks that.
#
#   julia --project=. scripts/sa_agency.jl
#
# Writes sa_agency.txt (log) and sa_agency_results.txt (key = value).

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics, DelimitedFiles, Serialization, LinearAlgebra

# ---- numerical footing: identical to sa_level4.jl, stage 5b -----------------
const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0),
                   collect(17.0:1.0:30.0))
const NQ     = 2000
# The social technology. With no arguments this is the stage-5b calibration.
# Passing (omega, kappa, sigma_m) runs the whole script at another point on the
# omega sweep of sa_omega_l4.txt, where kappa and sigma_m are RECALIBRATED to
# the participation moments rather than held fixed. Holding them fixed while
# omega moves drives the model into a near-zero-participation equilibrium and
# tells you nothing about omega; that is the same mistake as holding the
# calibration across a solver change, catalogued in MODEL_READINESS.md Part 1.
const OMEGA  = length(ARGS) >= 3 ? parse(Float64, ARGS[1]) : 0.30
const KAPPA  = length(ARGS) >= 3 ? parse(Float64, ARGS[2]) : 10.00
const SIGMA  = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.510
const TAG    = length(ARGS) >= 3 ? @sprintf("_om%03d", round(Int, 100 * OMEGA)) : ""
const Blow   = CELL_LOW.B
const Bhigh  = CELL_HIGH.B
const ALPHA_MID = 0.838
const NA, NE = 200, 80
const MONTHS = 3.0                 # OECD asset-poverty horizon

const RESULTS = Dict{String,Any}()
rec!(k, v) = (RESULTS[k] = v)

const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ; n = NQ) = get!(TASTE, σ) do; taste_nodes_ln(σ; n = n); end

# ============================================================ family caches ==
# The cheap four-column families are the ones sa_level4.jl already built; they
# are read only, so the fiscal fixed points below cost nothing and land on the
# same policies the paper reports.
const CACHEDIR = joinpath(@__DIR__,
    @sprintf("cache_l5_theta%.4f_amax%.1f_pexp%.1f_ne%d", THETA, GRID.a_max, GRID.pexp, NE))
isdir(CACHEDIR) || mkpath(CACHEDIR)
const FAMS = Dict{NTuple{4,Float64},NTuple{4,Vector{Float64}}}()
fkey(α, s, t, c) = (round(α, digits = 8), round(s, digits = 8),
                    round(t, digits = 8), round(c, digits = 8))
cachefile(key) = joinpath(CACHEDIR,
    "fam_" * join([replace(@sprintf("%.6f", k), "." => "p") for k in key], "_") * ".txt")

function family(α; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    key = fkey(α, subsidy, lumptax, partcredit)
    haskey(FAMS, key) && return FAMS[key]
    f = cachefile(key)
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1)
        return FAMS[key] = (d[:, 1], d[:, 2], d[:, 3], d[:, 4])
    end
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = NA, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp, subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, b = solve_participation_logit(p, 1.0; theta = THETA)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    @printf("  [rate family built] alpha %.3f sub %.2f tax %.6f credit %.2f\n",
            α, subsidy, lumptax, partcredit); flush(stdout)
    open(f, "w") do io
        println(io, join(["u", "r", "minc", "pbase"], '\t'))
        for i in eachindex(UGRID)
            println(io, join([UGRID[i], r[i], mi[i], pb[i]], '\t'))
        end
    end
    FAMS[key] = (copy(UGRID), r, mi, pb)
end

# The agency families carry the distributions, so they are new solves.
const ACACHE = joinpath(@__DIR__,
    @sprintf("cache_agency_theta%.4f_amax%.1f_pexp%.1f_ne%d_na%d",
             THETA, GRID.a_max, GRID.pexp, NE, NA))
isdir(ACACHE) || mkpath(ACACHE)
const AFAMS = Dict{NTuple{4,Float64},Any}()
acachefile(key) = joinpath(ACACHE,
    "afam_" * join([replace(@sprintf("%.6f", k), "." => "p") for k in key], "_") * ".jls")

function afamily(α; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0, na = NA)
    key = fkey(α, subsidy, lumptax, partcredit)
    haskey(AFAMS, key) && na == NA && return AFAMS[key]
    f = acachefile(key)
    if na == NA && isfile(f)
        return AFAMS[key] = deserialize(f)
    end
    nu = length(UGRID)
    W = zeros(nu, na); Y = zeros(nu, length(YGRID))
    ym = zeros(nu); rr = zeros(nu); agrid = Float64[]
    t0 = time()
    for (i, u) in enumerate(UGRID)
        p = update(cell_params(α; na = na, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp, subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        d = cell_distributions(p, s)
        W[i, :] = d.wcdf; Y[i, :] = d.ycdf; ym[i] = d.ymean; rr[i] = d.rate
        isempty(agrid) && (agrid = copy(s.a))
    end
    out = (u = copy(UGRID), W = W, Y = Y, ym = ym, r = rr, agrid = agrid, alpha = α)
    @printf("  [agency family] alpha %.3f sub %.2f tax %.6f credit %.2f na %d  (%.1f min)\n",
            α, subsidy, lumptax, partcredit, na, (time() - t0) / 60); flush(stdout)
    na == NA && (serialize(f, out); AFAMS[key] = out)
    out
end

# ==================================================== population aggregation ==
"""
Weight each family node by the taste mass that lands on it. Linear
interpolation in the belonging scale is linear in the distribution, so the
pooled cumulative distribution is the family matrix times this weight vector,
exactly as the pooled participation rate is the rate column times it.
"""
function node_weights(ugrid, κ, σ, B, arg)
    ms = tastes(σ); w = zeros(length(ugrid))
    for m in ms
        x = κ * m * B * arg
        if x <= ugrid[1]
            w[1] += 1
        elseif x >= ugrid[end]
            w[end] += 1
        else
            k = searchsortedlast(ugrid, x)
            t = (x - ugrid[k]) / (ugrid[k+1] - ugrid[k])
            w[k] += 1 - t; w[k+1] += t
        end
    end
    w ./ length(ms)
end

"Pooled distributions and rates at an equilibrium participation rate."
function pooled(afl, afh, r; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA)
    arg = OMEGA + (1 - OMEGA) * clamp(r, 0.0, 1.0)
    wl = node_weights(afl.u, κ, σ, Bl, arg)
    wh = node_weights(afh.u, κ, σ, Bh, arg)
    Wl = afl.W' * wl; Wh = afh.W' * wh
    Yl = afl.Y' * wl; Yh = afh.Y' * wh
    (Wlo = Wl, Whi = Wh,
     W = CELL_LOW.share * Wl + CELL_HIGH.share * Wh,
     Y = CELL_LOW.share * Yl + CELL_HIGH.share * Yh,
     rate = CELL_LOW.share * dot(wl, afl.r) + CELL_HIGH.share * dot(wh, afh.r),
     rlo = dot(wl, afl.r), rhi = dot(wh, afh.r),
     ymlo = dot(wl, afl.ym), ymhi = dot(wh, afh.ym),
     ymean = CELL_LOW.share * dot(wl, afl.ym) + CELL_HIGH.share * dot(wh, afh.ym),
     agrid = afl.agrid, alo = afl.alpha, ahi = afh.alpha)
end

"""
The agency column at a pooled state, given a wealth threshold. Returns the
aggregate A, the two cell values, and the two cell hardship rates.
"""
function agency(P, abar)
    hlo = share_below_interp(P.agrid, P.Wlo, abar)
    hhi = share_below_interp(P.agrid, P.Whi, abar)
    slo = share_below(P.agrid, P.Wlo, abar)          # step reading, lower bound
    shi = share_below(P.agrid, P.Whi, abar)
    Alo = P.alo * (1 - hlo); Ahi = P.ahi * (1 - hhi)
    (A = CELL_LOW.share * Alo + CELL_HIGH.share * Ahi,
     Alo = Alo, Ahi = Ahi, hlo = hlo, hhi = hhi,
     h = CELL_LOW.share * hlo + CELL_HIGH.share * hhi,
     hstep = CELL_LOW.share * slo + CELL_HIGH.share * shi,
     Astep = CELL_LOW.share * P.alo * (1 - slo) + CELL_HIGH.share * P.ahi * (1 - shi),
     alphabar = CELL_LOW.share * P.alo + CELL_HIGH.share * P.ahi)
end

# ============================================ equilibria, from the rate cache =
function popcol(fl, fh, Bl, Bh, κ, σ, rin, col)
    ms = tastes(σ); arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], κ * m * Bl * arg) for m in ms)
    hi = mean(interp(fh[1], fh[col], κ * m * Bh * arg) for m in ms)
    (CELL_LOW.share * lo + CELL_HIGH.share * hi, lo, hi)
end
function equilibrium(fl, fh; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA, ngrid = 401)
    g = collect(range(0.0, 1.0, length = ngrid))
    o = [popcol(fl, fh, Bl, Bh, κ, σ, x, 2)[1] for x in g]
    best = nothing
    for i in 1:ngrid-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1] - o[i]) / (g[i+1] - g[i])
            if sl < 1
                rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i])
                (best === nothing || rs > best.r) && (best = (r = rs, slope = sl))
            end
        end
    end
    best
end
meaninc(fl, fh, r) = popcol(fl, fh, Blow, Bhigh, KAPPA, SIGMA, r, 3)[1]

println("="^78)
println("A: THE AGENCY COLUMN")
println("="^78)
@printf("hardship = OECD asset poverty: wealth below %.0f months of the income\n", MONTHS)
println("poverty line (50 percent of median disposable income).")
println("Balestra and Tonkin (2018), OECD Statistics Working Paper 2018/01, para 68.")
println()

# ---- the four policies, resolved on the cheap families ----------------------
fl0 = family(CELL_LOW.α); fh0 = family(CELL_HIGH.α); fmid = family(ALPHA_MID)
E0 = equilibrium(fl0, fh0); mi0 = meaninc(fl0, fh0, E0.r)
@printf("omega %.2f, kappa %.2f, sigma_m %.3f\n", OMEGA, KAPPA, SIGMA)
@printf("baseline rate      %.4f   (sa_level4 at omega 0.30: 0.3526)\n", E0.r)

TAU = 0.20
Tsub = TAU * mi0; flS = nothing; fhS = nothing; ES = nothing
for it in 1:6
    global Tsub, flS, fhS, ES
    flS = family(CELL_LOW.α;  subsidy = TAU, lumptax = Tsub)
    fhS = family(CELL_HIGH.α, subsidy = TAU, lumptax = Tsub)
    ES = equilibrium(flS, fhS)
    Tn = TAU * meaninc(flS, fhS, ES.r)
    # NOTE: on convergence do NOT advance T past the families just built.
    # Doing so leaves the recorded lump-sum tax one iterate ahead of the
    # households the equilibrium was solved on, so the agency distributions
    # would be computed at a policy the participation rate never saw.
    abs(Tn - Tsub) < 1e-4 && break
    Tsub = Tn
end
@printf("subsidy rate       %.4f   (sa_level4: 0.1132), lump tax %.6f\n", ES.r, Tsub)

EM = equilibrium(fmid, fh0)
@printf("empowerment rate   %.4f   (sa_level4: 0.4647)\n", EM.r)

RHO = 0.25
Tcr = 0.0; flC = nothing; fhC = nothing; EC = nothing
for it in 1:6
    global Tcr, flC, fhC, EC
    flC = family(CELL_LOW.α;  lumptax = Tcr, partcredit = RHO)
    fhC = family(CELL_HIGH.α; lumptax = Tcr, partcredit = RHO)
    EC = equilibrium(flC, fhC)
    _, pbl, pbh = popcol(flC, fhC, Blow, Bhigh, KAPPA, SIGMA, EC.r, 4)
    Tn = QBAR * RHO * (CELL_LOW.share * pbl + CELL_HIGH.share * pbh)
    abs(Tn - Tcr) < 1e-4 && break        # see the note above
    Tcr = Tn
end
@printf("credit rate        %.4f   (sa_level4: 0.8491), lump tax %.6f\n", EC.r, Tcr)
println()
flush(stdout)

# ---- the agency families ----------------------------------------------------
println("building agency families (each is $(length(UGRID)) household solves)")
afl0 = afamily(CELL_LOW.α);  afh0 = afamily(CELL_HIGH.α)
aflS = afamily(CELL_LOW.α;  subsidy = TAU, lumptax = Tsub)
afhS = afamily(CELL_HIGH.α; subsidy = TAU, lumptax = Tsub)
afmid = afamily(ALPHA_MID)
aflC = afamily(CELL_LOW.α;  lumptax = Tcr, partcredit = RHO)
afhC = afamily(CELL_HIGH.α; lumptax = Tcr, partcredit = RHO)
println()

P0 = pooled(afl0, afh0, E0.r)
PS = pooled(aflS, afhS, ES.r)
PM = pooled(afmid, afh0, EM.r)
PC = pooled(aflC, afhC, EC.r)

# consistency: the pooled rate must reproduce the map equilibrium
for (nm, P, E) in (("baseline", P0, E0), ("subsidy", PS, ES),
                   ("empowerment", PM, EM), ("credit", PC, EC))
    @printf("check %-12s pooled rate %.4f vs map %.4f  (diff %.5f)\n",
            nm, P.rate, E.r, P.rate - E.r)
end
println()

# ---- the poverty line -------------------------------------------------------
med0 = cdf_quantile(YGRID, P0.Y, 0.5)
abar0 = hardship_threshold(med0; months = MONTHS)
@printf("baseline median disposable income  %.4f   (mean %.4f, ratio %.3f)\n",
        med0, P0.ymean, med0 / P0.ymean)
@printf("income poverty line (half median)  %.4f\n", 0.5 * med0)
@printf("ANCHORED wealth threshold          %.4f  (%.1f months of the line)\n",
        abar0, MONTHS)
rec!("T_sub", Tsub); rec!("T_cred", Tcr); rec!("tau_sub", TAU); rec!("rho_cred", RHO)
rec!("alpha_mid", ALPHA_MID)
rec!("median0", med0); rec!("povline0", 0.5 * med0); rec!("abar0", abar0)
println()

# ================================================================ the table ==
println("="^78)
println("THE DASHBOARD: participation (S) and agency (A)")
println("="^78)
@printf("%-13s | %-6s | %-6s | %-6s | %-6s | %-6s | %-6s\n",
        "policy", "r (S)", "alpha", "hard", "A", "dA", "dA/A")
println("-"^78)
base = agency(P0, abar0)
rows = NamedTuple[]
for (nm, P, E, tag) in (("baseline", P0, E0, "base"), ("work subsidy", PS, ES, "sub"),
                        ("empowerment", PM, EM, "emp"), ("participation credit", PC, EC, "cred"))
    g = agency(P, abar0)
    @printf("%-13s | %.4f | %.4f | %.4f | %.4f | %+.4f | %+5.1f%%\n",
            nm, E.r, g.alphabar, g.h, g.A, g.A - base.A, 100 * (g.A / base.A - 1))
    push!(rows, (name = nm, tag = tag, r = E.r, g = g, P = P, med = cdf_quantile(YGRID, P.Y, 0.5)))
    rec!("r_" * tag, E.r); rec!("A_" * tag, g.A); rec!("h_" * tag, g.h)
    rec!("Alo_" * tag, g.Alo); rec!("Ahi_" * tag, g.Ahi)
    rec!("hlo_" * tag, g.hlo); rec!("hhi_" * tag, g.hhi)
    rec!("Astep_" * tag, g.Astep); rec!("rlo_" * tag, P.rlo); rec!("rhi_" * tag, P.rhi)
    rec!("alphabar_" * tag, g.alphabar)
end
println()
println("by education cell (low / high)")
@printf("%-21s | %-15s | %-15s | %-15s | %s\n",
        "policy", "mean income", "hardship", "agency U^a", "gap in A")
println("-"^94)
for x in rows
    @printf("%-21s | %.4f / %.4f | %.4f / %.4f | %.4f / %.4f | %+.4f\n",
            x.name, x.P.ymlo, x.P.ymhi, x.g.hlo, x.g.hhi,
            x.g.Alo, x.g.Ahi, x.g.Ahi - x.g.Alo)
end
println()
println("discretisation band: A read as a step function of the asset grid")
for x in rows
    @printf("  %-21s A %.4f   step reading %.4f   band %.4f\n",
            x.name, x.g.A, x.g.Astep, x.g.A - x.g.Astep)
end

# ---- does A move when alpha does not? --------------------------------------
println()
println("="^78)
println("THE TEST: does A move under policies that leave alpha unchanged?")
println("="^78)
for x in rows[2:end]
    # A = sum_g share_g * alpha_g * (1 - h_g), so the change decomposes exactly
    dalpha = 0.0; dhard = 0.0; cross = 0.0
    for (sh, a0, h0, a1, h1) in ((CELL_LOW.share,  base.Alo / (1 - base.hlo), base.hlo,
                                  x.g.Alo / (1 - x.g.hlo), x.g.hlo),
                                 (CELL_HIGH.share, base.Ahi / (1 - base.hhi), base.hhi,
                                  x.g.Ahi / (1 - x.g.hhi), x.g.hhi))
        dalpha += sh * (a1 - a0) * (1 - h0)
        dhard  += sh * a0 * (h0 - h1)
        cross  += sh * (a1 - a0) * (h0 - h1)
    end
    @printf("%-20s  d(A) %+.4f  =  alpha %+.4f  +  hardship %+.4f  +  interaction %+.4f\n",
            x.name, x.g.A - base.A, dalpha, dhard, cross)
    rec!("dA_" * x.tag, x.g.A - base.A)
    rec!("dA_alpha_" * x.tag, dalpha); rec!("dA_hard_" * x.tag, dhard)
end

# ---- sensitivity to the horizon and to anchoring ----------------------------
println()
println("="^78)
println("SENSITIVITY")
println("="^78)
println("threshold horizon (months of the poverty line), anchored line.")
println("asset poverty h, then agency A, at each horizon:")
@printf("%-21s |%s\n", "policy", join([@sprintf("%17.0f months", m) for m in (1.0, 3.0, 6.0, 12.0)]))
for x in rows
    g = [agency(x.P, hardship_threshold(med0; months = m)) for m in (1.0, 3.0, 6.0, 12.0)]
    @printf("%-21s |%s\n", x.name,
            join([@sprintf("   %.4f / %.4f", y.h, y.A) for y in g]))
end
println()
println("threshold moved plus and minus ten percent, three-month horizon.")
println("this is the band the model's compressed income distribution implies:")
println("its median-to-mean income ratio is above the French one, so the")
println("poverty line it generates is on the high side.")
@printf("%-21s | %-17s %-17s %s\n", "policy", "abar -10%", "abar", "abar +10%")
for x in rows
    v = [agency(x.P, abar0 * f) for f in (0.9, 1.0, 1.1)]
    @printf("%-21s | %s\n", x.name,
            join([@sprintf("%.4f / %.4f  ", y.h, y.A) for y in v]))
end
println()
println("anchored versus floating poverty line (A at three months):")
for x in rows
    P = x.P
    af = hardship_threshold(x.med; months = MONTHS)
    @printf("%-13s  median %.4f  anchored A %.4f   floating A %.4f\n",
            x.name, x.med, agency(P, abar0).A, agency(P, af).A)
end

# ---- external comparison ----------------------------------------------------
println()
println("="^78)
println("EXTERNAL COMPARISON (untargeted)")
println("="^78)
@printf("model asset-poverty rate, three months, France cells   %.4f\n", base.h)
println("OECD, Balestra and Tonkin (2018) Figure 6.1: 14 percent of people are")
println("income poor and a further 36 percent are asset poor but not income poor.")
println("OECD (2025) regional paper puts France below 40 percent on the same test,")
println("with Austria and Denmark below 30 and Slovenia at 61.")
rec!("h_base", base.h)

open(joinpath(@__DIR__, "sa_agency_results" * TAG * ".txt"), "w") do io
    println(io, "# Agency column, OECD three-month asset poverty, stage-5b footing")
    for k in sort(collect(keys(RESULTS)))
        println(io, k, "\t", RESULTS[k])
    end
end
println("\nsaved sa_agency_results" * TAG * ".txt")
println("DONE")
