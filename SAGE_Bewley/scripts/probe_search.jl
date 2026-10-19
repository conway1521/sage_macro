# Search effort (A, phase 1 of ROADMAP.md; DIMENSIONS_SPEC.md, "Phase 1 scope"): the first run. On G+A at its
# calibration (with dread in choices when the workflow's dread switch is on), nothing else refitted:
#   1. the cost level of search by education cell, for the first year out of work and for the state beyond
#      it, fitted so that the mean chances of finding work are the measured rates (f_find; f_long by cell),
#      the curvature at DellaVigna, Lindner, Reizer and Schmieder's 0.35 (QJE 2017, Table I column (1));
#   2. the untargeted test: the response of time out of work to the first year's benefit, holding the tax,
#      against the literature's median of 0.53 (Schmieder and von Wachter 2016; band 0.2 to 1.0), and the
#      response of the first year's chance of finding work (Chetty 2008: -0.53);
#   3. what search does to the economy: search off against on, at the fitted costs.
# Time out of work from a job loss, in years: the first year, then 1 / f_L with chance 1 - f_U.
#
# With a third argument, the cost of being out of work beyond income enters first (DIMENSIONS_SPEC.md: chi set
# first, from wellbeing data): a life-satisfaction gap in points, or `ess` for the country's gap at the same
# income decile in `data/validation/ess_life_satisfaction.csv`; converted by the Green Book bridge at the base's
# mean income (`out_ls`, `out_M` in sage_modular.jl).
#
# With GSA among the arguments, the costs are fitted in G+S+A (V3_START.md section 109): the participation
# equilibrium is solved once at the starting costs and held, and the chances are those of each education cell's
# households over the belonging scales the equilibrium puts them on, on a coarse grid of scales with the
# equilibrium's weights carried onto it (the chances are smooth in the scale). Section 3 is skipped there.
#
#   julia --project=scripts/run_env scripts/probe_search.jl CODE [gamma] [gap | ess] [GSA]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
CFG = any(==("GSA"), uppercase.(ARGS)) ? "GSA" : "GA"
# rate=X: the participation rate of the G+S+A calibration at the starting costs, from its log, in place of the
# first full solve (which the runner's memory guard stopped twice in Italy, 17 October)
RATE0 = (i = findfirst(a -> startswith(a, "rate="), ARGS); i === nothing ? NaN : parse(Float64, ARGS[i][6:end]))
ARGV = [a for a in ARGS if !(uppercase(a) in ("GSA", "GA")) && !startswith(a, "rate=")]
code = uppercase(ARGV[1]); γs = length(ARGV) >= 2 ? parse(Float64, ARGV[2]) : 0.35
function ess_gap(code)
    for l in eachline(joinpath(@__DIR__, "..", "..", "data", "validation", "ess_life_satisfaction.csv"))
        f = split(l, ',')
        length(f) >= 4 && f[1] == code && occursin("same income decile", l) && occursin(",unemployed,", l) && return -parse(Float64, f[end-2])
    end
    error("no ESS gap for $code")
end
ls = length(ARGV) >= 3 ? (lowercase(ARGV[3]) == "ess" ? ess_gap(code) : parse(Float64, ARGV[3])) : 0.0
say(x...) = (println(x...); flush(stdout))

const UCOARSE = [0.0, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0, 11.0, 15.0, 20.0, 30.0]
const ARGEQ = Ref(NaN)            # the participation equilibrium's argument (omega + (1 - omega) rate), G+S+A

"Mean chance of finding work, by education cell, in the first year out of work and beyond it."
function exit_rates(c)
    CFG == "GSA" && return exit_rates_S(c)
    c = floor_effort(c); cs = cells_of(c); _, bw = betas_by_cell(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    map(1:2) do g
        ps = params_of(cT, cs[g])
        res = (nworkers() > 1 ? pmap : map)(ps) do p
            p = update(p; social_strength = 0.0)
            s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
            (s.lambda, s.search_x, stypes(p))
        end
        mU = xU = mL = xL = 0.0
        for (k, (λ, x, st)) in enumerate(res)
            w = bw[g][k]
            for s in findall(st .=== :U); m = sum(view(λ, :, s)); mU += w * m; xU += w * sum(view(λ, :, s) .* view(x, :, s)); end
            for s in findall(st .=== :L); m = sum(view(λ, :, s)); mL += w * m; xL += w * sum(view(λ, :, s) .* view(x, :, s)); end
        end
        (xU / mU, xL / mL)
    end
end

"The same with S on, at the held participation equilibrium (ARGEQ)."
function exit_rates_S(c)
    c = floor_effort(c); cs = cells_of(c); _, bw = betas_by_cell(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    nc = length(UCOARSE)
    map(1:2) do g
        wf = node_weights(c, cs[g].B, ARGEQ[])                 # the equilibrium's weights on c.ugrid
        wc = zeros(nc)
        for (j, u) in enumerate(c.ugrid)
            wf[j] == 0 && continue
            k = clamp(searchsortedlast(UCOARSE, u), 1, nc - 1)
            t = clamp((u - UCOARSE[k]) / (UCOARSE[k+1] - UCOARSE[k]), 0.0, 1.0)
            wc[k] += wf[j] * (1 - t); wc[k+1] += wf[j] * t
        end
        ps = params_of(cT, cs[g])
        jobs = [(k, j) for k in eachindex(ps) for j in 1:nc if wc[j] > 0]
        res = (nworkers() > 1 ? pmap : map)(jobs) do (k, j)
            p = update(ps[k]; social_strength = UCOARSE[j])
            s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
            λ, x = s.lambda, s.search_x; st = stypes(p); iU = findall(st .=== :U); iL = findall(st .=== :L)
            (sum(view(λ, :, iU)), sum(view(λ, :, iU) .* view(x, :, iU)), sum(view(λ, :, iL)), sum(view(λ, :, iL) .* view(x, :, iL)))
        end
        mU = xU = mL = xL = 0.0
        for ((k, j), (a1, a2, a3, a4)) in zip(jobs, res)
            w = bw[g][k] * wc[j]; mU += w * a1; xU += w * a2; mL += w * a3; xL += w * a4
        end
        (xU / mU, xL / mL)
    end
end

cF = country_config(code; config = CFG, v3 = :v5m, S = CFG == "GSA", A = true)        # with the search file, if any
c0 = SAGEConfig(cF; search = false)
say(@sprintf("%s %s%s | measured: first-year finding %.3f, exit from the state %.3f %.3f | curvature %.2f",
             code, CFG, c0.dread_mode == :behaviour ? " (dread in choices)" : "", c0.f_find, c0.f_long..., γs))
if CFG == "GSA" && !isnan(RATE0)
    ARGEQ[] = cF.omega + (1 - cF.omega) * RATE0
    say(@sprintf("  the participation equilibrium at the starting costs: rate %.4f, from the calibration's log (held)", RATE0))
elseif CFG == "GSA"
    t_ = @elapsed rS = solve_economy(cF; cache = false)
    ARGEQ[] = cF.omega + (1 - cF.omega) * rS.rate
    say(@sprintf("  the participation equilibrium at the starting costs: rate %.4f (held) | chances chosen %.4f %.4f; out of work %.4f  [%.0f min]",
                 rS.rate, rS.search_UL..., rS.unemployment, t_ / 60))
end
cB = c0
if ls > 0
    rB = solve_economy(c0; cache = false); M = rB.mean_income
    global c0 = SAGEConfig(c0; out_ls = ls, out_M = M)
    θ = exp(-ls / c0.out_betaY); γu = SAGEBewley.SAGEParams().γ
    say(@sprintf("  the cost of being out of work: %.3f life-satisfaction points, as %.1f%% of mean income %.4f lost (Green Book bridge, beta_Y %.3f): %.4f a year in utility",
                 ls, 100 * (1 - θ), M, c0.out_betaY, M^(1 - γu) / (1 - γu) * (1 - θ^(1 - γu))))
end

# 1. the cost levels, by a secant in logs for each of the four (at a given gain from work x ~ k^(-1/gamma),
# which gives the first step; the gain itself grows as search gets dearer, which the secant then learns)
# starting points (a numerical setting; the fit does not depend on them): the costs fitted without the cost of
# being out of work on 16 October (runs 38940077883, 38940086160, 38940094501), else one
k0 = Dict("FR" => (8.890, 4.310, 10.73, 3.425), "DE" => (13.12, 12.78, 21.10, 19.88), "IT" => (9.078, 10.77, 10.34, 12.01))
kU = cF.search ? collect(cF.search_kU) : haskey(k0, code) ? [k0[code][1], k0[code][2]] : [1.0, 1.0]
kL = cF.search ? collect(cF.search_kL) : haskey(k0, code) ? [k0[code][3], k0[code][4]] : [1.0, 1.0]
tU = c0.f_find; tL = collect(c0.f_long)
prev = Dict{Tuple{Symbol,Int},Tuple{Float64,Float64}}()
c = c0; r = nothing
function step!(key, k, x, target)
    lk, lx = log(k), log(max(x, 1e-6))
    slope = -1 / γs
    if haskey(prev, key)
        (lk0, lx0) = prev[key]
        abs(lk - lk0) > 1e-8 && (sl = (lx - lx0) / (lk - lk0); sl < -0.05 && (slope = sl))
    end
    prev[key] = (lk, lx)
    exp(lk + clamp((log(target) - lx) / slope, -1.5, 1.5))
end
for it in 1:30
    global c = SAGEConfig(c0; search = true, search_gamma = γs, search_kU = Tuple(kU), search_kL = Tuple(kL))
    global r = exit_rates(c)
    gap = maximum(max(abs(r[g][1] - tU), abs(r[g][2] - tL[g])) for g in 1:2)
    say(@sprintf("  iteration %2d: k first year %.4g %.4g, beyond %.4g %.4g | chance first year %.4f %.4f, beyond %.4f %.4f | gap %.1e",
                 it, kU..., kL..., r[1][1], r[2][1], r[1][2], r[2][2], gap))
    gap < 1e-3 && break
    for g in 1:2
        kU[g] = step!((:U, g), kU[g], r[g][1], tU)
        kL[g] = step!((:L, g), kL[g], r[g][2], tL[g])
    end
end
cS = c
maximum(max(abs(r[g][1] - tU), abs(r[g][2] - tL[g])) for g in 1:2) < 1e-3 || say("  NOT CONVERGED: the costs below miss the measured rates")

# 2. the response to the first year's benefit, holding the tax
D(rU, rL) = 1 + (1 - rU) / rL
rrp = isnan(cS.rr_public) ? cS.rr : cS.rr_public
r1 = exit_rates(SAGEConfig(cS; rr = 1.1 * cS.rr, rr_public = rrp + 0.1 * cS.rr))
say("\n2. the first year's benefit 10% higher, the tax held")
for g in 1:2
    d0 = D(r[g]...); d1 = D(r1[g]...)
    say(@sprintf("  cell %d: chance first year %.4f -> %.4f (elasticity %+.2f) | beyond %.4f -> %.4f | time out of work %.3f -> %.3f years: elasticity %+.2f",
                 g, r[g][1], r1[g][1], log(r1[g][1] / r[g][1]) / log(1.1), r[g][2], r1[g][2], d0, d1, log(d1 / d0) / log(1.1)))
end
say("  literature: duration elasticity median 0.53, band 0.2 to 1.0 (Schmieder and von Wachter 2016); hazard elasticity -0.53 (Chetty 2008)")

# 3. the economy with search off and on
say("\n3. the economy, search off and on (nothing else refitted)")
say(@sprintf("  %-12s %8s %8s %8s %8s %8s %8s", "", "fall", "htm", "median", "MPC", "out", "hours"))
# with chi and no search, chi is a constant within each state: every aggregate must be the base's
rows = ls > 0 ? (("search off", cB), ("chi, no search", c0), ("on, with chi", cS)) : (("search off", cB), ("search on", cS))
for (lab, cv) in (CFG == "GA" ? rows : ())
    rr_ = solve_economy(cv; cache = false)
    say(@sprintf("  %-12s %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f", lab, rr_.consumption_drop, rr_.hand_to_mouth_kvw,
                 rr_.wealth_p50 / rr_.median_income, rr_.mpc, rr_.unemployment, rr_.mean_effort_employed))
end
say(@sprintf("\nfitted: search_kU = %.6g %.6g, search_kL = %.6g %.6g (gamma %.2f; out_ls %.3f, out_M %.5g)", kU..., kL..., γs, cS.out_ls, cS.out_M))
# the file country_config reads (scripts/search_v5m_CODE_GA.txt; committed by hand from this log)
ls == 0 && open(joinpath(@__DIR__, "search_v5m_$(code)_$(CFG).txt"), "w") do io
    println(io, "# written by probe_search.jl $(code) $(γs) $(CFG): search cost levels fitted to the measured rates at the $(CFG) calibration with dread in choices", CFG == "GSA" ? " (participation equilibrium held at the starting costs)" : "", "; read by country_config")
    @printf(io, "search_gamma = %.4f\nsearch_kU = %.6g %.6g\nsearch_kL = %.6g %.6g\n", γs, kU..., kL...)
end
println("DONE")
