# Stage 1d's test of the response of job finding to benefits (paper/sage_v2_design.md, section 3.4; V3_START.md
# section 135): on the calibrated quarterly G+A with its fitted search costs (search_v5q_<C>_GA.txt), the benefit of the
# entitled spell raised by 10 per cent in every quarter (the tax unchanged: a partial response), and the elasticity of
# the chance of finding work, mass-weighted over the spell's quarters, and of the expected duration out of work.
# Benchmarks: Chetty (2008), a hazard elasticity of -0.53 (weekly hazard); Schmieder and von Wachter (2016), a median
# duration elasticity of about 0.5.
#
# SEVERANCE (second argument `severance`; design section 7, item 2): the comparison with Chetty (2008) made the way
# his estimate is made. A lump sum at the start of the spell is a payment in its first quarter (every spell passes
# through it once), sized at the expected cash value per new spell of the benefit rise: the sum over the entitled
# quarters of 10 per cent of each quarter's replacement, weighted by the chance of still being unemployed there (the
# baseline's mass by quarter of the spell over the mass in the first, both cells pooled), undiscounted. It is in the
# same units as the benefit (a share of the household's income in work), as severance pay is a multiple of earnings.
# The ratio of the two responses is the model's counterpart of Chetty's liquidity share (about 0.6). It is not
# called moral hazard's complement: the rest also holds the timing of payments, their contingency and dread.
# NODREAD (third argument `nodread`): dread moved out of choices (wellbeing only), every other parameter held.
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/probe_v2_benefit.jl CODE [benefit|severance] [nodread]
# COHORT (second argument `cohort`, third the lump sum X as a share of a period's income in work, fourth optionally
# `nodread`): the current spell only, as severance pay is (Chetty 2008). Solved once: the job losers' cohort is
# followed with the baseline's policies, its assets on entry raised by X (agency_shock.jl, part 3). X is the equal cash
# value printed by the severance mode. Set before the workers start, which inherit it.
length(ARGS) >= 3 && ARGS[2] == "cohort" && (ENV["SAGE_COHORT_LUMP"] = ARGS[3])
# REVIEW OPTIONS (the methods review of 27 October): grp=LO,HI restricts the lump-sum cohort, with and without the lump
# sum, to job losers with liquid wealth in [LO, HI) times their last income in work (agency_shock.jl, part 3), in the
# cohort and benefit modes alike; entN gives those entering unemployment from inactivity no entitlement (the design's
# spell without it, paid as L), so that a spell broken by inactivity does not restart the benefit clock.
"dh1" in ARGS && (ENV["SAGE_DREAD_HORIZON"] = "1")      # dread of the coming quarter, not the year (sensitivity)
let gi = findfirst(a -> startswith(a, "grp="), ARGS); gi === nothing || (ENV["SAGE_COHORT_GROUP"] = split(ARGS[gi], "=")[2]); end
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = "GA"
mode = length(ARGS) >= 2 ? ARGS[2] : "benefit"; nodread = "nodread" in ARGS[2:end]
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
# TRIAL COSTS (an argument costs=SUFFIX): search_v5q_<C>_GA_<SUFFIX>.txt, with its own curvature (section 137)
ct = something(findfirst(a -> startswith(a, "costs="), ARGS), 0)
sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg)" * (ct > 0 ? "_" * split(ARGS[ct], "=")[2] : "") * ".txt"))
γq = parse(Float64, sq["search_gamma"])
kq = (parse.(Float64, split(sq["search_kq_cell1"])), parse.(Float64, split(sq["search_kq_cell2"])))
ca = country_config(code; config = cfg, v3 = :v5m, S = false, A = true)
entN = "entN" in ARGS
cb = duration_config(ca; entitle = entN)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = γq, search_kq = kq)
get(q, "dread_mode", "") == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
nodread && (c = SAGEConfig(c; dread_mode = :overlay))
println(code, " G+A, ", mode, ", dread ", c.dread_mode === :overlay ? "in wellbeing only" : "in choices", entN ? ", no entitlement on entry from inactivity" : "",
        haskey(ENV, "SAGE_COHORT_GROUP") ? ", lump cohort restricted to liquid wealth in [" * ENV["SAGE_COHORT_GROUP"] * ") of income" : "")
"The MPC within the quarter, as the twelve-month one is pooled in sage_modular.jl."
mpcq(r) = sum(cells_of(c)[g].share * sum(r.pooled[g].mpcmass) for g in 1:2) / sum(cells_of(c)[g].share * sum(r.pooled[g].mass) for g in 1:2)
function exits(r)
    e = r.search_exit; nU = cb.nU
    # mass-weighted over the cells' unemployed in the entitled quarters: the cells' masses from the pooled distribution
    pg = r.pooled; num = 0.0; den = 0.0
    for g in 1:2
        w = cells_of(c)[g].share * sum(pg[g].mass[.!r.employed])
        num += w * sum(e[g][1:nU]) / nU; den += w
    end
    num / den
end
# PBD (second argument `pbd`, then Q0 and Q1; V3_START.md section 138): potential benefit duration. Two economies, the
# entitled benefit paid for Q0 and for Q1 quarters (each quarter's own replacement up to Q0, the last entitled quarter's
# rate from Q0 to Q1, the post-exhaustion rate rr_long after), the tax held at the calibrated economy's. The estimand of
# Schmieder, von Wachter and Bender (2012): extra months out of work (job loss to the next job, through every state out
# of work, capped at 36 months) per extra month of entitlement. Germany's calibrated entitlement is four quarters, so
# `pbd 4 6` is their 12 to 18 months at age 42.
if mode == "pbd"
    Q0 = parse(Int, ARGS[3]); Q1 = parse(Int, ARGS[4]); nU = cb.nU
    rrq(Q) = [d <= Q0 ? c.rrU_vec[d] : d <= Q ? c.rrU_vec[Q0] : c.rr_long for d in 1:nU]
    ra = solve_economy(SAGEConfig(c; rrU_vec = rrq(Q0)); cache = false)
    rb = solve_economy(SAGEConfig(c; rrU_vec = rrq(Q1)); cache = false)
    dP = 3.0 * (Q1 - Q0)
    @printf("%s G+A, pbd: entitlement %d -> %d quarters (%.0f extra months) | months out of work after job loss, capped at 36: %.4f -> %.4f, %.4f a month of entitlement; capped at 48: %.4f -> %.4f, %.4f a month\n",
            code, Q0, Q1, dP, ra.nonemp.months36, rb.nonemp.months36, (rb.nonemp.months36 - ra.nonemp.months36) / dP,
            ra.nonemp.months48, rb.nonemp.months48, (rb.nonemp.months48 - ra.nonemp.months48) / dP)
    @printf("  elasticity of capped duration to entitlement %.4f (arc, at 36 months) | hand-to-mouth %.4f -> %.4f | mean entitled chance %.5f -> %.5f\n",
            log(rb.nonemp.months36 / ra.nonemp.months36) / log(Q1 / Q0), ra.hand_to_mouth_kvw, rb.hand_to_mouth_kvw, exits(ra), exits(rb))
    println("  share still out of work by quarter: ", round.(ra.nonemp.surv[1:12], digits = 4), " -> ", round.(rb.nonemp.surv[1:12], digits = 4))
    println("DONE"); exit()
end
r0 = solve_economy(c; cache = false)
if mode == "cohort"
    lc = r0.lump_cohort
    @printf("%s G+A, cohort: lump sum %s of a period's income in work at the start of the spell, current spell only | chance of finding work over the entitled quarters %.6f -> %.6f, log change %.6f\n",
            code, ARGS[3], lc.base, lc.lump, log(lc.lump / lc.base))
    println("  by quarter: ", round.(lc.base_q, digits = 5), " -> ", round.(lc.lump_q, digits = 5))
    @printf("  baseline (check against the economy's own): mean entitled chance %.6f, hand-to-mouth %.4f\n", exits(r0), r0.hand_to_mouth_kvw)
    println("DONE"); exit()
end
if mode == "severance"
    nU = cb.nU
    m = [sum(cells_of(c)[g].share * r0.search_mass[g][d] for g in 1:2) for d in 1:nU]
    surv = m ./ m[1]
    X = sum(surv .* 0.1 .* c.rrU_vec[1:nU])
    @printf("survival by quarter of the spell %s; lump sum %.5f of income in work (the first quarter's replacement %.4f -> %.4f)\n",
            string(round.(surv, digits = 4)), X, c.rrU_vec[1], c.rrU_vec[1] + X)
    rr1 = copy(c.rrU_vec); rr1[1] += X
    c1 = SAGEConfig(c; rrU_vec = rr1)
else
    c1 = SAGEConfig(c; rrU_vec = 1.1 .* c.rrU_vec)
end
r1 = solve_economy(c1; cache = false)
x0, x1 = exits(r0), exits(r1)
el = log(x1 / x0) / log(1.1)
@printf("%s G+A, %s: mean chance of finding work in the entitled quarters %.6f -> %.6f, log change %.6f; as an elasticity to a 10%% rise %.4f (Chetty 2008: -0.53 for a weekly hazard) | fall Kolsrud %.4f -> %.4f | htm %.4f -> %.4f\n",
        code, mode, x0, x1, log(x1 / x0), el, r0.fall_kolsrud, r1.fall_kolsrud, r0.hand_to_mouth_kvw, r1.hand_to_mouth_kvw)
# the same response on the job losers' cohort (exits over its stock through the entitled quarters, lump_cohort.base),
# the basis of the cohort mode, so that the two compare like with like
@printf("  job losers' cohort: chance over the entitled quarters %.6f -> %.6f, log change %.6f\n",
        r0.lump_cohort.base, r1.lump_cohort.base, log(r1.lump_cohort.base / r0.lump_cohort.base))
# the duration elasticity the evidence reports (the review's first point): months out of work after job loss, through
# every state out of work, capped at 36 and 48, without and with the change, against log(1.1)
@printf("  time out of work after job loss, capped at 36 months: %.4f -> %.4f, duration elasticity %.4f; capped at 48: %.4f -> %.4f, %.4f\n",
        r0.nonemp.months36, r1.nonemp.months36, log(r1.nonemp.months36 / r0.nonemp.months36) / log(1.1),
        r0.nonemp.months48, r1.nonemp.months48, log(r1.nonemp.months48 / r0.nonemp.months48) / log(1.1))
@printf("  MPC within the quarter %.4f, over twelve months %.4f (baseline)\n", mpcq(r0), r0.mpc12)
for g in 1:2
    @printf("  cell %d chance by quarter: %s -> %s\n", g, string(round.(r0.search_exit[g], digits = 5)), string(round.(r1.search_exit[g], digits = 5)))
end
println("DONE")
