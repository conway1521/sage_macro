# The wellbeing account of version 1 (phase 1 of ROADMAP.md; DIMENSIONS_SPEC.md, "Phase 1 scope"): what each
# dimension's own utility term is worth, per head and per year, in life-satisfaction points (WELLBYs) and as a
# share of consumption, on one solved economy. The weights across dimensions are not here (phase 5).
#
# One bridge for every term, the Green Book's (HM Treasury 2021; data/EVIDENCE_WELLBY.md): a share x of
# consumption lost is worth beta_Y ln(1 - x) points, beta_Y = 1.96105, and a gap of g points is worth the share
# 1 - exp(-g / beta_Y). Terms from the model are turned into points, terms from the evidence into shares. A model
# term is averaged over households as a share of consumption first and converted once, at that mean.
#
#   A, dread of losing work (in choices with SAGE_DREAD_CHOICE=1): the model's consumption equivalent among those
#      in work (`dread_cost_E`), times the share in work.
#   A, the cost of job search: the model's consumption equivalent among those out of work (`search_cost_out`).
#   A, being out of work beyond the income lost (decided by the user, 16 October: in wellbeing only, not in
#      choices; V3_START.md section 106): the share out of work times the ESS gap at the same income decile
#      (data/validation/ess_life_satisfaction.csv), with the within-person estimates for Germany below it
#      (Clark, Knabe and Rätzel, working paper: about 0.8 for men and women together) as the low end.
#   S, taking part: the model's participation rate times the fixed-effects effect of volunteering, 0.055 to
#      0.081 points (Meier and Stutzer 2008, Economica, Table 2), a transfer from Germany.
#   E, air quality: population-weighted PM2.5 (OECD, data/environment/oecd_pm25_tl2.csv, latest year) above the
#      WHO guideline of 5 micrograms (WHO 2021, a stated reference level), valued at 0.3% to 0.8% of income per
#      microgram (Menz and Welsch 2010, applied to PM2.5, a stated transfer); the national figure and the range
#      across TL2 regions. Households do not move in version 1, so this term changes no choice.
#   E, commuting: already in the model as time (the time cost of each unit of work); Stutzer and Frey's (2008)
#      0.20 points per hour each way is shown as a check on its size and NOT added (DIMENSIONS_SPEC.md, E).
#
# Version 2 (third argument `q`, V3_START.md section 136): the calibrated quarterly economy (`quarterly_calibrated`),
# solved once (no poverty thresholds, which the account does not use; a second pass would rebuild S's families). The
# model's terms are shares of consumption, so they read the same at a quarterly period.
#
#   julia --project=scripts/run_env scripts/wellbeing_account.jl CODE [CFG] [q]        (CFG: G GA GS GSA; default GSA)
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GSA"; Q = length(ARGS) >= 3 && ARGS[3] == "q"
const BY = 1.96105
pts(x) = BY * log(1 - x)                  # a share of consumption lost, in points
shr(g) = 1 - exp(-g / BY)                 # a gap in points, as a share of consumption
DATA = joinpath(@__DIR__, "..", "..", "data")

function ess_gap(code)
    for l in eachline(joinpath(DATA, "validation", "ess_life_satisfaction.csv"))
        f = split(l, ',')
        length(f) >= 4 && f[1] == code && occursin("same income decile", l) && occursin(",unemployed,", l) && return -parse(Float64, f[end-2])
    end
    error("no ESS gap for $code")
end
function pm25(code)
    iso = Dict("FR" => "FRA", "DE" => "DEU", "IT" => "ITA")[code]
    rows = [split(l, ',') for (k, l) in enumerate(eachline(joinpath(DATA, "environment", "oecd_pm25_tl2.csv"))) if k > 1]
    rows = [r for r in rows if r[1] == iso]
    yr = maximum(parse(Int, r[4]) for r in rows)
    nat = only(parse(Float64, r[5]) for r in rows if r[2] == iso && parse(Int, r[4]) == yr)
    reg = [parse(Float64, r[5]) for r in rows if r[2] != iso && parse(Int, r[4]) == yr]
    (year = yr, national = nat, lo = minimum(reg), hi = maximum(reg), n = length(reg))
end
function commute_minutes(code)
    v = Float64[]; w = Float64[]
    tab = [split(l, ',') for (k, l) in enumerate(eachline(joinpath(DATA, "place", "place_by_degurba.csv"))) if k > 1]
    for d in ("DEG1", "DEG2", "DEG3")
        m = [parse(Float64, r[5]) for r in tab if r[1] == "commute_mean_minutes" && r[2] == code && r[3] == d]
        s = [parse(Float64, r[5]) for r in tab if r[1] == "pop_share" && r[2] == code && r[3] == d]
        (isempty(m) || isempty(s)) && continue
        push!(v, m[1]); push!(w, s[1])
    end
    isempty(v) ? NaN : sum(v .* w) / sum(w)
end

hasS = occursin('S', cfg); hasA = occursin('A', cfg)
c = Q ? quarterly_calibrated(code, cfg) : country_config(code; config = cfg, v3 = :v5m, S = hasS, A = hasA)
say(x...) = (println(x...); flush(stdout))
say(@sprintf("%s %s%s | dread %s, search %s", code, cfg, Q ? " (version 2, quarterly)" : "", hasA ? string(c.dread_mode) : "off", (hasA && c.search) ? "on" : "off"))
r = Q ? _solve(c, nothing; disk = false, any_thresholds = true) : solve_economy(c; cache = false)
u = r.unemployment; emp = 1 - u
# version 2 has the inactive state N, which `unemployment` counts as out of work; the ESS gap is measured among the
# unemployed, so the term covers the unemployed (U and L) and the inactive share is shown beside it
if Q
    let P = r.pooled, cs_ = cells_of(c), st = stypes(params_of(SAGEConfig(c; effort_mode = :free), cs_[1])[1])
        mN = sum(cs_[g].share * sum(P[g].mass[st .=== :N]) for g in 1:2) / sum(cs_[g].share * sum(P[g].mass) for g in 1:2)
        say(@sprintf("  out of work %.4f, of which inactive (N) %.4f: the out-of-work term uses the unemployed, %.4f", u, mN, u - mN))
        global u = u - mN; global uN = mN
    end
end
# the inactive's own gap (version 2): ESS, the working-age inactive by main activity pooled (not looking, sick or
# disabled, retired under 65, housework and care) against employees on unlimited contracts at the same income decile
# (data/validation/ess_life_satisfaction_inactive.csv; V3_START.md section 136)
function ess_gap_inactive(code)
    for l in eachline(joinpath(DATA, "validation", "ess_life_satisfaction_inactive.csv"))
        f = split(l, ',')
        length(f) >= 4 && f[1] == code && occursin("the four together", l) && return -parse(Float64, f[end-2])   # the group's name holds a comma
    end
    error("no ESS gap for the inactive in $code")
end
say(@sprintf("  out of work %.4f; taking part %.4f; consumption per head %.4f; mean income %.4f", u, r.rate, r.consumption, r.mean_income))
hasA && c.search && !Q && say(@sprintf("  search: the chance of finding work chosen, first year %.4f, beyond %.4f (measured %.3f; %.3f %.3f by cell)", r.search_UL..., c.f_find, c.f_long...))
hasA && c.search && Q && say("  search: the chance of finding work chosen by period of the spell, by cell: ", string(round.(r.search_exit[1], digits = 3)), " ", string(round.(r.search_exit[2], digits = 3)))

rows = Tuple{String,Float64,Float64,String}[]          # term, points per head (central), share of consumption, note
row!(t, p, s, n) = push!(rows, (t, p, s, n))
# Being out of work: the measured gap is the whole cost beyond income (it is measured among the unemployed
# looking for work, so it holds the strain of searching); the model's search cost is shown as a part of it and
# the rest beside it, so nothing is counted twice (agreed by the user, 17 October; V3_START.md section 108).
g = ess_gap(code)
xs = (hasA && c.search) ? r.search_cost_out : 0.0
if hasA
    # dread enters the choices of everyone facing a change of status next year, in work and out of it (the methods
    # review of 18 October): its consumption equivalent averaged over the population, and shown by status
    P = r.pooled; cs_ = cells_of(c); em = r.employed
    msum(f, mk) = sum(cs_[g].share * sum(getfield(P[g], f)[mk]) for g in 1:2)
    xall = msum(:xmass, trues(length(em))) / msum(:mass, trues(length(em)))
    xE = msum(:xmass, em) / msum(:mass, em); xO = msum(:xmass, .!em) / msum(:mass, .!em)
    row!("A  dread of a change of status", pts(xall), xall, @sprintf("%.4f of consumption in work, %.4f out of work", xE, xO))
end
row!("A  out of work beyond income", -u * g, u * shr(g), @sprintf("gap %.2f points a person (ESS); at 0.8: %.4f per head", g, -u * 0.8))
if Q
    gN = ess_gap_inactive(code)
    row!("A  inactive (N) beyond income", -uN * gN, uN * shr(gN), @sprintf("gap %.2f points a person (ESS, the working-age inactive pooled), on %.4f inactive", gN, uN))
end
if xs > 0
    gs = -pts(xs)
    row!("     of which job search", u * pts(xs), u * xs, @sprintf("%.2f points a person out of work (%.4f of their consumption)%s", gs, xs, gs > g ? ": ABOVE the measured gap" : ""))
    row!("     of which the rest", -u * max(g - gs, 0.0), u * shr(max(g - gs, 0.0)), @sprintf("%.2f points a person out of work", max(g - gs, 0.0)))
end
if hasS
    row!("S  taking part", r.rate * 0.068, -r.rate * shr(0.068), @sprintf("0.055 to 0.081 points a participant: %.4f to %.4f per head", r.rate * 0.055, r.rate * 0.081))
    # the model's own belonging, for comparison (the review): the share of consumption, every year, that losing the
    # belonging part of lifetime value would cost (welfare_ce's formula), per head and per participant
    γu = SAGEBewley.SAGEParams().γ
    xb = 1 - (1 - r.welfare.Vb / r.welfare.Vc)^(1 / (1 - γu))        # positive: what belonging is worth
    say(@sprintf("  S, the model's own belonging: %.4f of consumption per head (%.4f points), %.4f per participant (%.3f points a participant)",
                 xb, -pts(xb), xb / r.rate, -pts(min(xb / r.rate, 0.99))))
end
pm = pm25(code); ex = pm.national - 5.0
row!("E  air quality (PM2.5 above 5)", pts(ex * 0.0055), ex * 0.0055,
     @sprintf("%.1f µg/m³ in %d; 0.3%% to 0.8%%: %.4f to %.4f points; regions %.1f to %.1f µg/m³ (%d)", pm.national, pm.year,
              pts(ex * 0.003), pts(ex * 0.008), pm.lo, pm.hi, pm.n))
say("\nper head and year           points    share of consumption   note")
for (t, p, s, n) in rows
    say(@sprintf("  %-30s %+8.4f   %8.4f               %s", t, p, s, n))
end
cm = commute_minutes(code)
say(@sprintf("\n  check, not added: commuting %.1f minutes one way (Eurostat lfso_19plwk28, by type of place weighted), which at 0.20 points an hour (Stutzer and Frey 2008) would be %.4f points per head in work", cm, -0.20 * cm / 60))
say(@sprintf("  welfare parts in the model's utility (per head, lifetime): consumption %.3f, time %.3f, belonging %.4f, dread %.4f, search %.4f",
             r.welfare.Vc, r.welfare.Ve, r.welfare.Vb, r.welfare.Vd, r.welfare.Vk))
say("  (the terms are not summed: weights across dimensions are phase 5's)")
println("DONE")
