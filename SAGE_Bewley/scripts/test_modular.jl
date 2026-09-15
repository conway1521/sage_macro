# The modularity suite: every switch, and every reduction it has to satisfy.
#
# The claim being tested is not that the model runs in each configuration. It
# is that turning a dimension OFF gives back exactly the economy without it,
# so that anyone building on this can add the piece they care about and know
# nothing else moved. Each test is a reduction, checked against a tolerance
# that reflects the solver rather than a hoped-for agreement.
#
# 2026-09-14. Two changes. The calibrated footing now has the unemployed at the
# INSEE participation ratio (the `unemployed_ratio` switch), with the technology
# read from calibration_ratio.txt, which calibrate_ratio.jl writes. The old
# footing was held up by the unemployed participating at one; its results are
# kept in test_modular_oldfooting.txt. And the convergence rows moved from the
# uncalibrated defaults to that footing, since discretisation error matters
# where numbers are quoted. They are anchored to the reference economy's
# poverty line and asset threshold, so each row is one family build rather than
# two, and the median column shows how far the line itself would have moved.
#
# 2026-09-15. France's footing comes from `france_footing()`: the EU-SILC
# country calibration once calibration_country_FR.txt exists, the INSEE-target
# footing otherwise. SUITE_SKIP_NA400=1 leaves the doubled asset grid to
# conv_na400.jl, which runs it on fewer workers because each needs 4 to 5 GB.
#
#   julia --project=. scripts/test_modular.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

const TOL = 1e-6
const FIELDS = (:rate, :A, :hardship, :income_poor, :asset_poor, :hand_to_mouth,
                :mean_labour_income, :median_income, :mean_effort_employed, :wealth_p50)
const RESULTS = NamedTuple[]

"Compare two economies field by field. `anchor` shares one's thresholds with the other."
function reduce_to(name, a, b; fields = FIELDS, tol = TOL)
    worst = 0.0; worstf = :none
    for f in fields
        d = abs(getfield(a, f) - getfield(b, f))
        d > worst && (worst = d; worstf = f)
    end
    ok = worst <= tol
    push!(RESULTS, (name = name, worst = worst, field = worstf, ok = ok))
    @printf("%-58s %-9.1e %-20s %s\n", name, worst, string(worstf), ok ? "pass" : "FAIL")
    flush(stdout)
    ok
end

println("="^100)
println("MODULARITY SUITE: does switching a dimension off give back the economy without it?")
println("="^100)
@printf("tolerance %.0e; production grid na %d ne %d, theta %.4f, nz %d; %d workers\n",
        TOL, 200, 80, 0.005, SAGEConfig().nz, nworkers())
println("poverty line anchored on mean income times the empirical median-to-mean ratio\n")
@printf("%-58s %-9s %-20s %s\n", "reduction", "largest", "on", "")
println("-"^100)

# ---------------------------------------------------------------- the four --
G    = solve_economy(SAGEConfig())
GA   = solve_economy(SAGEConfig(A = true))
GS   = solve_economy(SAGEConfig(S = true))
GSA  = solve_economy(SAGEConfig(S = true, A = true))

# 1. A off inside G+A is G. Agency heterogeneity is the only thing A turns on,
#    so equalising alpha at the value G uses must reproduce G exactly.
reduce_to("G+A with agency equalised  ->  G",
          solve_economy(SAGEConfig(A = true, alpha = (0.838, 0.838))), G)

# 2. S off inside G+S is G. kappa = 0 kills the social payoff; the household
#    problem is then the baseline one, which probe_reduction.jl separately
#    checks against the engine's own solver.
reduce_to("G+S with the interaction strength at zero  ->  G",
          solve_economy(SAGEConfig(S = true, kappa = 0.0)), G)

# 3 and 4. The same two reductions from the full model.
reduce_to("G+S+A with the interaction strength at zero  ->  G+A",
          solve_economy(SAGEConfig(S = true, A = true, kappa = 0.0)), GA)
reduce_to("G+S+A with agency equalised  ->  G+S",
          solve_economy(SAGEConfig(S = true, A = true, alpha = (0.838, 0.838))), GS)

# 5. Both off from the full model is the baseline.
reduce_to("G+S+A with both switched off  ->  G",
          solve_economy(SAGEConfig(S = true, A = true, kappa = 0.0, alpha = (0.838, 0.838))), G)

# ----------------------------------------------------------- the extensions --
# 6. Unemployment at zero separation. The four-state process still has the
#    unemployed states, they are simply unreachable, so this also checks that
#    nothing leaks through the state space itself.
reduce_to("G+S+A with unemployment at zero separation  ->  G+S+A",
          solve_economy(SAGEConfig(S = true, A = true, unemployment = true, delta = (0.0, 0.0))), GSA)

# 7. Discount heterogeneity at zero spread.
reduce_to("G+S+A with the discount spread at zero  ->  G+S+A",
          solve_economy(SAGEConfig(S = true, A = true, beta_spread = 0.0, nbeta = 5)), GSA)

# 8. Both extensions off at once, from the fully loaded model.
reduce_to("G+S+A, unemployment and discount spread both off  ->  G+S+A",
          solve_economy(SAGEConfig(S = true, A = true, unemployment = true, delta = (0.0, 0.0),
                                   beta_spread = 0.0)), GSA)

# 9. The monetary participation cost, which stage 7 rejected on the evidence
#    but left in the code, must be inert at zero.
reduce_to("G+S+A with the monetary participation cost at zero  ->  G+S+A",
          solve_economy(SAGEConfig(S = true, A = true, pcost = 0.0)), GSA)

# 10. Policy instruments inert at zero.
reduce_to("G+S+A with every policy instrument at zero  ->  G+S+A",
          solve_economy(SAGEConfig(S = true, A = true, subsidy = 0.0, lumptax = 0.0,
                                   partcredit = 0.0)), GSA)

# --------------------------------------------------------------- replication --
# 11. The same configuration twice. Nothing in the solver may depend on order,
#     on a cache, or on anything outside the config.
reduce_to("G+S+A solved twice  ->  itself",
          solve_economy(SAGEConfig(S = true, A = true); cache = false), GSA; tol = 0.0)
reduce_to("G solved twice  ->  itself",
          solve_economy(SAGEConfig(); cache = false), G; tol = 0.0)

# 12. Cell order. Swapping which cell is listed first must not move an
#     aggregate, which catches any place the two cells are not treated
#     symmetrically.
let sw = solve_economy(SAGEConfig(S = true, A = true, alpha = (0.911, 0.765),
                                  B = (0.94, 0.80), share = (0.5, 0.5)))
    reduce_to("G+S+A with the two cells listed in the other order  ->  G+S+A", sw, GSA)
end

# ------------------------------------------------ the participation rule --
# The unemployed at a fixed multiple of the employed participation rate, in
# place of the choice that sends them to one. See `unemployed_ratio`.
const FF = france_footing()
const CAL = FF.config
println("France's footing: ", FF.source)

# 13. With S off, participation feeds back on nothing, so the rule may move
#     the participation rate and nothing else.
reduce_to("G+A, unemployment: the rule moves only participation",
          solve_economy(SAGEConfig(CAL; A = true)),
          solve_economy(SAGEConfig(CAL; A = true, unemployed_ratio = nothing));
          fields = Tuple(f for f in FIELDS if f != :rate))

# 14. The rule is refused wherever it would be wrong or would do nothing, and
#     the refusal comes before any household problem is solved.
function refused(cfg)
    try
        solve_economy(cfg; cache = false)
        false
    catch e
        e isa ErrorException
    end
end
let cases = [("no unemployment", SAGEConfig(unemployed_ratio = CAL.unemployed_ratio)),
             ("credit", SAGEConfig(CAL; S = true, A = true, partcredit = 0.25)),
             ("money cost", SAGEConfig(CAL; S = true, A = true, pcost = 0.01)),
             ("search time", SAGEConfig(CAL; S = true, A = true, search_time = 0.2)),
             ("negative", SAGEConfig(CAL; unemployed_ratio = -0.1))]
    bad = [nm for (nm, cfg) in cases if !refused(cfg)]
    ok = isempty(bad)
    push!(RESULTS, (name = "the rule refused where it is wrong", worst = 0.0, field = :none, ok = ok))
    @printf("%-58s %-9s %-20s %s\n", "the rule refused where it is wrong (five cases)", "-",
            ok ? "all refused" : join(bad, ","), ok ? "pass" : "FAIL")
    flush(stdout)
end

# 15. An independent path. quarantine2.jl imposed the same rule with its own
#     code on families built at the old technology, anchored to the old
#     suite's poverty line. The switch has to give its numbers back, to the
#     four decimals that script logged.
let old = SAGEConfig(S = true, A = true, unemployment = true, beta_spread = 0.037,
                     kappa = 9.90, sigma_m = 0.385, unemployed_ratio = 0.17 / 0.35),
    thr = [(0.5 * 0.365028, hardship_threshold(0.365028; months = 3.0))],
    q2 = (rate = 0.0423, rate_E = 0.0442, rate_U = 0.0173, A = 0.5320, hardship = 0.3518,
          hand_to_mouth = 0.2669)
    reduce_to("G+S+A, rule, old technology  ->  quarantine2.jl",
              solve_economy(old; thresholds = thr), q2; fields = keys(q2), tol = 1e-4)
end

println("-"^100)
@printf("%d of %d reductions pass\n", count(x -> x.ok, RESULTS), length(RESULTS))

println()
println("="^100)
println("THE FOUR ECONOMIES")
println("="^100)
for (nm, r) in (("G      baseline Bewley", G), ("G+A    agency", GA),
                ("G+S    social cohesion", GS), ("G+S+A  both", GSA))
    report(r; label = nm)
    println()
end
println("="^100)
println("THE FOUR ECONOMIES AT THE CALIBRATED FOOTING")
println("="^100)
@printf("unemployment on, discount spread %.3f, kappa %.2f, sigma_m %.2f, unemployed at %.3f of the\n",
        CAL.beta_spread, CAL.kappa, CAL.sigma_m, CAL.unemployed_ratio)
println("employed participation rate. Footing: ", FF.source, ". These are the numbers to read.\n")
const CALR = Dict{String,Any}()
for (nm, key, cfg) in (("G      baseline Bewley", "G", CAL),
                       ("G+A    agency", "GA", SAGEConfig(CAL; A = true)),
                       ("G+S    social cohesion", "GS", SAGEConfig(CAL; S = true)),
                       ("G+S+A  both", "GSA", SAGEConfig(CAL; S = true, A = true)))
    r = solve_economy(cfg); CALR[key] = r
    report(r; label = nm)
    @printf("  participation employed %.4f, unemployed %.4f\n", r.rate_E, r.rate_U)
    @printf("  asset poverty by income quintile: %s\n",
            join([@sprintf("%.3f", x) for x in r.asset_poor_by_quintile], "  "))
    @printf("  OECD average for comparison:      0.680  n/a    n/a    0.430  0.270\n")
    println()
    flush(stdout)
end
let r = CALR["GSA"]
    @printf("G+S+A against its targets: cell participation %.4f and %.4f (%.3f, %.3f), hand-to-mouth %.4f (%.2f)\n",
            r.pooled[1].rate, r.pooled[2].rate, FF.part..., r.hand_to_mouth, FF.htm)
    @printf("slope %.4f, multiplier %.1f. The old footing, held up by the unemployed at one:\n", r.slope, 1 / (1 - r.slope))
    println("participation 0.3574, agency 0.4947, hand-to-mouth 0.2998, multiplier 34.0\n")
end

# 16. Replication through the family cache: clear the in-memory economy cache
#     and solve the calibrated G+S+A again, so its families come from disk.
clear_cache!()
reduce_to("calibrated G+S+A, families from disk  ->  itself",
          solve_economy(SAGEConfig(CAL; S = true, A = true)), CALR["GSA"]; tol = 0.0)

# =========================================================== convergence ====
# Reductions say the switches are clean. They say nothing about whether the
# numbers have settled in the discretisations. These are the ones the agency
# column depends on, since it is a threshold statistic and thresholds are the
# first thing a coarse grid gets wrong. At the calibrated footing, anchored to
# the reference's thresholds; a row whose median moves more than 0.002 is not
# counted as settled, because anchoring would hide the move.
println()
println("="^100)
println("CONVERGENCE AT THE CALIBRATED FOOTING: has the agency column settled?")
println("="^100)
@printf("%-44s %-11s %-11s %-11s %-9s %s\n", "discretisation", "agency", "asset pov", "median", "move", "median move")
println("-"^100)
const CONV = NamedTuple[]
# 0.005 on agency. The residual oscillation in the state space is about 0.002
# (probe_nz4.txt) and it is irreducible without going far beyond twenty states,
# so anything inside 0.005 is settled to the two decimals agency is quoted to.
function conv(name, cfg, ref; tol = 0.005)
    r = solve_economy(cfg; thresholds = [(ref.ypov, ref.abar)])
    d = abs(r.A - ref.A); dm = r.median_income - ref.median_income
    ok = d <= tol && abs(dm) <= 0.002
    push!(CONV, (name = name, move = d, ok = ok))
    @printf("%-44s %-11.6f %-11.6f %-11.6f %+.5f  %+.5f%s\n", name, r.A, r.asset_poor,
            r.median_income, r.A - ref.A, dm,
            (d <= tol ? "" : " <- NOT SETTLED") * (abs(dm) <= 0.002 ? "" : " <- LINE MOVED"))
    flush(stdout)
    r
end
let base = SAGEConfig(CAL; S = true, A = true)
    ref = CALR["GSA"]
    @printf("%-44s %-11.6f %-11.6f %-11.6f  (reference)\n", "G+S+A at the calibrated footing", ref.A, ref.asset_poor, ref.median_income)
    conv("taste quadrature, 8000 nodes against 2000", SAGEConfig(base; nq = 8000), ref)
    conv("productivity states, nz 9 against 11", SAGEConfig(base; nz = 9), ref)
    conv("productivity states, nz 13 against 11", SAGEConfig(base; nz = 13), ref)
    conv("choice smoothing, theta halved", SAGEConfig(base; theta = 0.0025), ref)
    conv("asset grid top, a_max 8 against 4", SAGEConfig(base; a_max = 8.0, na = 252), ref)
    conv("belonging grid at spacing 0.1 against 0.2",
         SAGEConfig(base; ugrid = vcat(collect(0.0:0.5:2.0), collect(2.1:0.1:12.0),
                                       collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))), ref)
    conv("effort grid, ne 160 against 80", SAGEConfig(base; ne = 160), ref)
    get(ENV, "SUITE_SKIP_NA400", "0") == "1" ?
        println("asset grid, na 400 against 200: run separately by conv_na400.jl on fewer workers") :
        conv("asset grid, na 400 against 200", SAGEConfig(base; na = 400), ref)
end
println("-"^100)
@printf("%d of %d discretisations settled within 0.005 on agency\n",
        count(x -> x.ok, CONV), length(CONV))
for x in CONV
    x.ok || @printf("  NOT SETTLED: %-44s moves %.5f\n", x.name, x.move)
end
np = count(x -> x.ok, RESULTS) + count(x -> x.ok, CONV)
ntot = length(RESULTS) + length(CONV)
@printf("\n%d of %d checks pass\n", np, ntot)
println(np == ntot ? "MODULARITY SUITE PASSES" : "MODULARITY SUITE FAILS")
println("DONE")
