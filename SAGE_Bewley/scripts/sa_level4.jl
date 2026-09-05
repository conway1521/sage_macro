# Level 4: every S+A result recomputed on the verified numerical footing.
#
# The footing, established in VERIFICATION.md: response families on the
# concentrated belonging grid (spacing 0.2 across the transition, 83 nodes,
# not the original uniform 41 on [0,60] of which three covered the transition),
# taste quadrature at 2000 nodes (not 15; the near-step cell response makes the
# integral converge slowly), and the recalibrated (kappa, sigma_m) that footing
# implies, 10.75 and 0.750 rather than 10.0 and 0.50.
#
# Everything the paper reports is computed here, in one pass, from one cache,
# so no two numbers in the paper can come from different footings again:
# baseline, the gradient decomposition, the proposition and the numerical
# multiplicity boundary, the financed work subsidy with its direct/equilibrium
# split, empowerment, the participation credit at real rebate rates, the
# take-up table, and the GDP/GDP-B ledger. A closing section checks how much
# of any of it moves with the effort grid.
#
#   julia --project=. scripts/sa_level4.jl
#
# Writes sa_level4.txt (the log) and sa_level4_results.txt (key = value, read
# by scripts/sa_figures_l4.jl and quoted by the paper).

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles

# ---------------------------------------------------------------- settings --
const UGRID  = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0),
                    collect(17.0:1.0:30.0))
const NQ     = 2000
const OMEGA  = 0.30
const KAPPA  = 10.75
const SIGMA  = 0.750
const Blow   = CELL_LOW.B
const Bhigh  = CELL_HIGH.B
const Bbar   = CELL_LOW.share * Blow + CELL_HIGH.share * Bhigh
const ALPHA_MID = 0.838
const NA, NE = 200, 40

# experienced-wellbeing constants, as in the shared engine
const GAMMA = 2.0; const LAMBDA = 0.8757834; const GAM_GAIN = 1.0

const RESULTS = Dict{String,Any}()
rec!(k, v) = (RESULTS[k] = v)

# --------------------------------------------------------- taste quadrature --
const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ; n = NQ) = get!(TASTE, σ) do
    taste_nodes_ln(σ; n = n)
end

# ------------------------------------------------------------ family cache --
# One entry per (alpha, subsidy, lumptax, partcredit). Each family is 83 solves
# of the household problem with the participation choice; caching matters
# because the fiscal fixed points revisit the same policy repeatedly.
const FAMS = Dict{NTuple{4,Float64},NTuple{4,Vector{Float64}}}()
nfam = Ref(0)

const CACHEDIR = joinpath(@__DIR__, "cache_l4")
isdir(CACHEDIR) || mkpath(CACHEDIR)
cachefile(key) = joinpath(CACHEDIR,
    "fam_" * join([replace(@sprintf("%.6f", k), "." => "p") for k in key], "_") * ".txt")

function family(α; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    key = (round(α, digits = 8), round(subsidy, digits = 8),
           round(lumptax, digits = 8), round(partcredit, digits = 8))
    haskey(FAMS, key) && return FAMS[key]
    # Disk cache. A family is 83 solves of the household problem and depends on
    # nothing but this key, so it is worth keeping across runs: with the cache
    # warm the whole script is seconds rather than an hour and a half, which is
    # what makes re-verification cheap enough to actually do.
    f = cachefile(key)
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1)
        return FAMS[key] = (d[:, 1], d[:, 2], d[:, 3], d[:, 4])
    end
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = NA, ne = NE,
                               subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, b = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    nfam[] += 1
    @printf("  [family %2d] alpha %.3f  sub %.2f  tax %.4f  credit %.2f\n",
            nfam[], α, subsidy, lumptax, partcredit); flush(stdout)
    open(f, "w") do io
        println(io, join(["u", "r", "minc", "pbase"], '\t'))
        for i in eachindex(UGRID)
            println(io, join([UGRID[i], r[i], mi[i], pb[i]], '\t'))
        end
    end
    FAMS[key] = (copy(UGRID), r, mi, pb)
end

# ------------------------------------------------------- population objects --
# Hoisted versions of the sa_core helpers: the taste nodes are built once per
# sigma rather than once per map evaluation, which matters at 2000 nodes.
"Column `col` of the two families, integrated over tastes at rate `rin`."
function popcol(fl, fh, Bl, Bh, κ, σ, rin, col)
    ms = tastes(σ)
    arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], κ * m * Bl * arg) for m in ms)
    hi = mean(interp(fh[1], fh[col], κ * m * Bh * arg) for m in ms)
    (CELL_LOW.share * lo + CELL_HIGH.share * hi, lo, hi)
end

"Aggregate map and all its crossings: returns (grid, out, equilibria)."
function themap(fl, fh, Bl, Bh, κ, σ; ngrid = 401)
    g = collect(range(0.0, 1.0, length = ngrid))
    o = [popcol(fl, fh, Bl, Bh, κ, σ, r, 2)[1] for r in g]
    eqs = NamedTuple[]
    for i in 1:ngrid-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1 / (d1 - d2)
            rs = g[i] + t * (g[i+1] - g[i])
            sl = (o[i+1] - o[i]) / (g[i+1] - g[i])
            push!(eqs, (r = rs, slope = sl, stable = sl < 1))
        end
    end
    g, o, eqs
end

"Highest stable equilibrium, with its group rates and map slope."
function equilibrium(fl, fh; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA)
    _, _, eqs = themap(fl, fh, Bl, Bh, κ, σ)
    st = [e for e in eqs if e.stable]
    isempty(st) && return nothing
    e = st[argmax([x.r for x in st])]
    _, lo, hi = popcol(fl, fh, Bl, Bh, κ, σ, e.r, 2)
    (r = e.r, lo = lo, hi = hi, slope = e.slope, nstable = length(st))
end

meaninc(fl, fh, r; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA) =
    popcol(fl, fh, Bl, Bh, κ, σ, r, 3)[1]
partbase(fl, fh, r; Bl = Blow, Bh = Bhigh, κ = KAPPA, σ = SIGMA) =
    popcol(fl, fh, Bl, Bh, κ, σ, r, 4)[1]

phi(z) = exp(-z^2 / 2) / sqrt(2pi)

# =============================================================== A. baseline =
println("="^76); println("A. BASELINE at the recalibrated point"); println("="^76)
@printf("kappa = %.2f, sigma_m = %.3f, omega = %.2f, %d taste nodes, %d family nodes\n",
        KAPPA, SIGMA, OMEGA, NQ, length(UGRID))

fl0 = family(CELL_LOW.α); fh0 = family(CELL_HIGH.α)
B0 = equilibrium(fl0, fh0)
mi0 = meaninc(fl0, fh0, B0.r)
@printf("\nequilibrium rate       %.4f   (targets: aggregate about 0.35)\n", B0.r)
@printf("group rates            %.4f / %.4f   (targets 0.25 / 0.45)\n", B0.lo, B0.hi)
@printf("gradient               %.4f          (target 0.200)\n", B0.hi - B0.lo)
@printf("map slope at r*        %.4f\n", B0.slope)
@printf("stable equilibria      %d\n", B0.nstable)
@printf("mean labour income     %.4f\n", mi0)
rec!("r0", B0.r); rec!("r0_lo", B0.lo); rec!("r0_hi", B0.hi)
rec!("slope0", B0.slope); rec!("mi0", mi0); rec!("nstable0", B0.nstable)
rec!("kappa", KAPPA); rec!("sigma", SIGMA); rec!("omega", OMEGA)

# =================================================== B. gradient decomposition
println(); println("="^76)
println("B. GRADIENT DECOMPOSITION: taste or agency?"); println("="^76)
fmid = family(ALPHA_MID)

# tastes equalised at Bbar, agency left unequal -> the agency-only gap
Bt = equilibrium(fl0, fh0; Bl = Bbar, Bh = Bbar)
# agency equalised at the mean, tastes left unequal -> the taste-only gap
Ba = equilibrium(fmid, fmid)

gap_full  = B0.hi - B0.lo
gap_agency = Bt.hi - Bt.lo
gap_taste  = Ba.hi - Ba.lo
@printf("full model         gap %.4f  (rate %.4f, %.4f / %.4f)\n",
        gap_full, B0.r, B0.lo, B0.hi)
@printf("tastes equalised   gap %.4f  (rate %.4f, %.4f / %.4f)  <- agency alone\n",
        gap_agency, Bt.r, Bt.lo, Bt.hi)
@printf("agency equalised   gap %.4f  (rate %.4f, %.4f / %.4f)  <- taste alone\n",
        gap_taste, Ba.r, Ba.lo, Ba.hi)
@printf("shares of the full gap: agency %.0f%%, taste %.0f%%, sum %.0f%%\n",
        100gap_agency/gap_full, 100gap_taste/gap_full,
        100(gap_agency+gap_taste)/gap_full)
rec!("gap_full", gap_full); rec!("gap_agency", gap_agency); rec!("gap_taste", gap_taste)

# ============================================ C. the proposition at this point
println(); println("="^76)
println("C. THE PROPOSITION AT THE RECALIBRATED POINT"); println("="^76)
comp = (1 - OMEGA) / (OMEGA + (1 - OMEGA) * B0.r)
dens = CELL_LOW.share  * phi(quantile_normal(1 - B0.lo)) +
       CELL_HIGH.share * phi(quantile_normal(1 - B0.hi))
sigbar = comp * dens
gprime = comp * dens / SIGMA
@printf("complementarity factor (1-w)/(w+(1-w)r)   %.4f\n", comp)
@printf("density term  sum s_g phi(Phi^-1(1-p_g))  %.4f\n", dens)
@printf("sigma-bar (multiplicity needs sigma below) %.4f\n", sigbar)
@printf("sigma* (fits the gradient as well as it can) %.4f\n", SIGMA)
@printf("ratio sigma*/sigma-bar                     %.3f  -> %s\n",
        SIGMA/sigbar, SIGMA/sigbar > 1 ? "OUTSIDE the coordination region" :
                                          "inside: the discipline result FAILS")
@printf("proposition slope G'(r*)                   %.4f\n", gprime)
@printf("numerical slope at r*                      %.4f  (proposition is the upper one: %s)\n",
        B0.slope, gprime >= B0.slope ? "yes" : "NO, check")
rec!("comp", comp); rec!("dens", dens); rec!("sigbar", sigbar)
rec!("ratio", SIGMA/sigbar); rec!("gprime", gprime)

# =========================================== D. numerical multiplicity frontier
println(); println("="^76)
println("D. THE NUMERICAL MULTIPLICITY FRONTIER"); println("="^76)
println("stable equilibria as sigma_m falls, at the calibrated kappa")
function scan_frontier()
    front = NaN
    for σ in 0.80:-0.01:0.10
        _, _, eqs = themap(fl0, fh0, Blow, Bhigh, KAPPA, σ)
        ns = count(e -> e.stable, eqs)
        if ns > 1 && isnan(front)
            front = σ
            @printf("  sigma %.2f : %d stable   <- multiplicity appears here\n", σ, ns)
        elseif isnan(front) ? mod(round(Int, 100σ), 5) == 0 : σ >= front - 0.03
            @printf("  sigma %.2f : %d stable\n", σ, ns)
        end
        flush(stdout)
    end
    front
end
frontier = scan_frontier()
@printf("numerical frontier: multiplicity for sigma_m <= %.2f\n", frontier)
@printf("analytical bound sigma-bar = %.4f, so the numerical frontier sits %s it, as it must\n",
        sigbar, frontier <= sigbar ? "inside" : "OUTSIDE (check)")
rec!("frontier", frontier)

# ======================================================== E. the work subsidy =
println(); println("="^76)
println("E. FINANCED MAKE-WORK-PAY SUBSIDY (20 percent)"); println("="^76)
const TAU_SUB = 0.20
function financed_subsidy(τ; maxit = 6, tol = 1e-4)
    T = τ * mi0
    local flP, fhP, E
    for it in 1:maxit
        flP = family(CELL_LOW.α;  subsidy = τ, lumptax = T)
        fhP = family(CELL_HIGH.α, subsidy = τ, lumptax = T)
        E = equilibrium(flP, fhP)
        Tnew = τ * meaninc(flP, fhP, E.r)
        @printf("  iteration %d: rate %.4f, lump tax %.4f -> %.4f\n", it, E.r, T, Tnew)
        flush(stdout)
        abs(Tnew - T) < tol && (T = Tnew; break)
        T = Tnew
    end
    (fl = flP, fh = fhP, e = E, T = T)
end
S = financed_subsidy(TAU_SUB)
# the direct effect: the policy families evaluated at the BASELINE belonging level
direct, dlo, dhi = popcol(S.fl, S.fh, Blow, Bhigh, KAPPA, SIGMA, B0.r, 2)
miS = meaninc(S.fl, S.fh, S.e.r)
@printf("\nlump-sum tax             %.4f  (%.1f%% of baseline mean income)\n",
        S.T, 100*S.T/mi0)
@printf("direct effect            %.4f -> %.4f  (%+.1f points)\n",
        B0.r, direct, 100*(direct - B0.r))
@printf("equilibrium effect       %.4f -> %.4f  (%+.1f points)\n",
        B0.r, S.e.r, 100*(S.e.r - B0.r))
@printf("amplification            %.2f\n", (B0.r - S.e.r) / (B0.r - direct))
@printf("group rates              %.4f / %.4f\n", S.e.lo, S.e.hi)
@printf("mean labour income       %.4f -> %.4f (%+.1f%%)\n", mi0, miS, 100*(miS/mi0-1))
rec!("r_sub", S.e.r); rec!("r_sub_direct", direct); rec!("T_sub", S.T)
rec!("amp", (B0.r - S.e.r)/(B0.r - direct)); rec!("mi_sub", miS)
rec!("r_sub_lo", S.e.lo); rec!("r_sub_hi", S.e.hi)

# ========================================================== F. empowerment ===
println(); println("="^76)
println("F. EMPOWERMENT: low-education agency raised to the population mean")
println("="^76)
E = equilibrium(fmid, fh0)
miE = meaninc(fmid, fh0, E.r)
@printf("alpha_low %.3f -> %.3f, no fiscal instrument\n", CELL_LOW.α, ALPHA_MID)
@printf("equilibrium              %.4f -> %.4f  (%+.1f points)\n",
        B0.r, E.r, 100*(E.r - B0.r))
@printf("group rates              %.4f / %.4f\n", E.lo, E.hi)
@printf("mean labour income       %.4f -> %.4f (%+.1f%%)\n", mi0, miE, 100*(miE/mi0-1))
rec!("r_emp", E.r); rec!("r_emp_lo", E.lo); rec!("r_emp_hi", E.hi); rec!("mi_emp", miE)

# =============================================== G. participation tax credit ==
println(); println("="^76)
println("G. PARTICIPATION TAX CREDIT AT REAL REBATE RATES"); println("="^76)
"Financed credit at rebate rho, with take-up ratio tau on the low group."
function financed_credit(ρ; τ = 1.0, maxit = 6, tol = 1e-4)
    T = 0.0
    local fl, fh, E
    for it in 1:maxit
        fl = family(CELL_LOW.α;  lumptax = T, partcredit = ρ * τ)
        fh = family(CELL_HIGH.α; lumptax = T, partcredit = ρ)
        E  = equilibrium(fl, fh)
        _, pblo, pbhi = popcol(fl, fh, Blow, Bhigh, KAPPA, SIGMA, E.r, 4)
        Tnew = QBAR * (CELL_LOW.share * (ρ*τ) * pblo + CELL_HIGH.share * ρ * pbhi)
        @printf("  rho %.2f tau %.2f iteration %d: rate %.4f, tax %.4f -> %.4f\n",
                ρ, τ, it, E.r, T, Tnew); flush(stdout)
        abs(Tnew - T) < tol && (T = Tnew; break)
        T = Tnew
    end
    (fl = fl, fh = fh, e = E, T = T, mi = meaninc(fl, fh, E.r))
end

CRED = Dict{Tuple{Float64,Float64},Any}()
for (ρ, name) in ((0.25, "Gift Aid"), (0.66, "France"))
    for τ in (1.00, 0.50, 0.25)
        CRED[(ρ, τ)] = financed_credit(ρ; τ = τ)
    end
end
println()
@printf("%-26s | %-7s | %-7s | %-7s | %-6s | %s\n",
        "scenario", "rate", "low", "high", "hi/lo", "cost (% mean income)")
@printf("%-26s |  %.4f |  %.4f |  %.4f |  %.2f  |  ---\n",
        "baseline", B0.r, B0.lo, B0.hi, B0.hi/B0.lo)
for (ρ, name) in ((0.25, "Gift Aid 25%"), (0.66, "France 66%"))
    for τ in (1.00, 0.50, 0.25)
        C = CRED[(ρ, τ)]
        @printf("%-26s |  %.4f |  %.4f |  %.4f |  %.2f  |  %.2f\n",
                "$name, take-up $(Int(100τ))%", C.e.r, C.e.lo, C.e.hi,
                C.e.lo > 0 ? C.e.hi/C.e.lo : NaN, 100*C.T/mi0)
        rec!("cred_$(Int(100ρ))_$(Int(100τ))_r",    C.e.r)
        rec!("cred_$(Int(100ρ))_$(Int(100τ))_lo",   C.e.lo)
        rec!("cred_$(Int(100ρ))_$(Int(100τ))_hi",   C.e.hi)
        rec!("cred_$(Int(100ρ))_$(Int(100τ))_cost", 100*C.T/mi0)
        rec!("cred_$(Int(100ρ))_$(Int(100τ))_mi",   C.mi)
    end
end
rec!("ratio0", B0.hi/B0.lo)

# ================================================== H. the GDP / GDP-B ledger =
println(); println("="^76)
println("H. THE TWO LEDGERS: GDP AND GDP-B"); println("="^76)
cbar = mi0
pi_model = (LAMBDA / GAM_GAIN) * Bbar * cbar^GAMMA
@printf("model shadow price of the fabric  pi = %.4f income units per unit of P\n", pi_model)
@printf("  a fully participating society's cohesion is worth %.0f%% of baseline GDP\n\n",
        100 * pi_model / mi0)

Cfr = CRED[(0.66, 1.00)]; Cga = CRED[(0.25, 1.00)]
states = [("baseline",                  B0.r,    mi0),
          ("work subsidy (20%)",        S.e.r,   miS),
          ("empowerment",               E.r,     miE),
          ("participation credit (25%)",Cga.e.r, Cga.mi),
          ("participation credit (66%)",Cfr.e.r, Cfr.mi)]
gdpb0 = mi0 + pi_model * B0.r
@printf("%-28s | %-6s | %-8s | %-8s | %-8s | %s\n",
        "state", "P", "GDP", "dGDP%", "GDP-B", "dGDP-B%")
for (nm, P, Y) in states
    gb = Y + pi_model * P
    @printf("%-28s | %.3f  | %.4f  | %+6.1f  | %.4f  | %+6.1f\n",
            nm, P, Y, 100*(Y-mi0)/mi0, gb, 100*(gb-gdpb0)/gdpb0)
    rec!("gdp_" * replace(nm, " " => "_"), 100*(Y-mi0)/mi0)
    rec!("gdpb_" * replace(nm, " " => "_"), 100*(gb-gdpb0)/gdpb0)
end
pi_star = (miS - mi0) / (B0.r - S.e.r)
@printf("\nbreakeven price for the work subsidy  pi* = %.4f  (%.0f%% of GDP per unit P)\n",
        pi_star, 100*pi_star/mi0)
@printf("the model price is %.2f times the breakeven, so at its own price the subsidy\n",
        pi_model/pi_star)
@printf("%s GDP-B; it %s only if the fabric is priced above %.0f%% of GDP per unit P\n",
        pi_model > pi_star ? "LOWERS" : "RAISES",
        pi_model > pi_star ? "raises it" : "lowers it", 100*pi_star/mi0)
rec!("pi_model", pi_model); rec!("pi_star", pi_star)
rec!("pi_model_pct", 100*pi_model/mi0); rec!("pi_star_pct", 100*pi_star/mi0)

# ================================================ I. effort-grid robustness ===
println(); println("="^76)
println("I. EFFORT-GRID ROBUSTNESS OF THE LEVEL 4 NUMBERS"); println("="^76)
println("Participation is a discrete choice, so it should be far less effort-grid")
println("sensitive than the companion paper's Q = E[1-e]. Mean labour income is")
println("the quantity that inherits the effort grid, so the GDP ledger is checked.")
function refam(α, ne; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    r = Float64[]; mi = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = NA, ne = ne,
                               subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, _ = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m)
    end
    (copy(UGRID), r, mi, mi)
end
@printf("\n%-5s | %-9s | %-9s | %-9s | %-9s\n", "ne", "rate", "low", "high", "mean income")
for ne in (40, 80, 160)
    fl = ne == NE ? fl0 : refam(CELL_LOW.α, ne)
    fh = ne == NE ? fh0 : refam(CELL_HIGH.α, ne)
    Eg = equilibrium(fl, fh)
    @printf("%-5d | %.5f  | %.5f  | %.5f  | %.5f\n",
            ne, Eg.r, Eg.lo, Eg.hi, meaninc(fl, fh, Eg.r))
    flush(stdout)
end

# ------------------------------------------------------------------- output --
open(joinpath(@__DIR__, "sa_level4_results.txt"), "w") do io
    println(io, "# Level 4 results: fine families, $(NQ) taste nodes, kappa=$(KAPPA), sigma=$(SIGMA)")
    for k in sort(collect(keys(RESULTS)))
        println(io, k, "\t", RESULTS[k])
    end
end
@printf("\n%d families solved and cached\n", nfam[])
println("saved sa_level4_results.txt")
println("DONE")
