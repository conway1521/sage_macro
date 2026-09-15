# Calibrate the social technology with the unemployed at the INSEE ratio.
#
# The families quarantine2.jl built at the old footing are the families of the
# new one: they depend on the household problem, not on kappa, sigma or the
# participation rule, so the scan needs no household solve. They are first
# written into the modular family cache, which lets the suite's independent-
# path check and the calibrated economy's first pass reuse them.
#
# Targets as before: group participation 0.25 and 0.45 by education cell.
# The discount spread stays at 0.037, calibrated to hand-to-mouth 0.30; the
# script reports whether hand-to-mouth is still on target at the new point.
# Output: calibration_ratio.txt, which test_modular.jl reads.
#
#   julia --project=. scripts/calibrate_ratio.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf, Statistics, Serialization
say(args...) = (println(args...); flush(stdout))

const OLD = SAGEConfig(S = true, A = true, unemployment = true, beta_spread = 0.037,
                       kappa = 9.90, sigma_m = 0.385)
const RATIO = 0.17 / 0.35
const MED_OLD = 0.365028
const THR_OLD = [(0.5 * MED_OLD, hardship_threshold(MED_OLD; months = OLD.months))]
const RAW = deserialize(joinpath(@__DIR__, "cache_quarantine", "fams_U1_nz11_k990_s385_spread037.jls"))

say("seeding the family cache with the families quarantine2.jl built at exactly these inputs")
seed_family_cache!(OLD, THR_OLD, RAW)
const CR = SAGEConfig(OLD; unemployed_ratio = RATIO)
for cell in cells_of(CR)
    hh, tk = family_cache_key(CR, cell, THR_OLD)
    isfile(joinpath(FAMILY_CACHE_DIR, "fam_$(hh)_$(tk).jls")) ||
        (say("STOP. the rule changed the family key, which it must not"); exit(1))
end

# The switch against quarantine2.jl's own imposition, to the four decimals it logged.
r = _solve(CR, THR_OLD; fams = RAW)
Q2 = (rate = 0.0423, rate_E = 0.0442, rate_U = 0.0173, A = 0.5320, hardship = 0.3518, hand_to_mouth = 0.2669)
worst = maximum(abs(getfield(r, f) - getfield(Q2, f)) for f in keys(Q2))
@printf("switch against quarantine2.jl at the old technology, worst gap %.1e: %s\n", worst,
        worst <= 1e-4 ? "HELD" : "FAILED")
worst <= 1e-4 || exit(1)
FI = families(CR; thresholds = THR_OLD)
direct = [impose_unemployed_ratio(f, employment_mask(CR), RATIO) for f in RAW]
gap = maximum(abs(a.rate - b.rate) for (fa, fb) in zip(FI, direct) for (a, b) in zip(fa, fb))
@printf("families() through the cache against direct imposition, worst gap %.1e: %s\n", gap,
        gap == 0 ? "HELD" : "FAILED")
gap == 0 || exit(1)

say("\nscan: sigma 0.36 to 0.70 by 0.01, kappa 2.00 to 20.00 by 0.02, quadrature 2000, targets 0.25 and 0.45")
t0 = time()
rows = scan_technology(CR, FI, collect(0.36:0.01:0.70), collect(2.0:0.02:20.0))
@printf("(scan %.1f min)\n\n", (time() - t0) / 60)
ok = report_technology(rows)
okabs = [x for x in rows if x.loss <= 0.035]
isempty(okabs) ||
    @printf("on the absolute standard used at stage 7, root loss up to 0.035: sigma %.2f to %.2f, multiplier %.1f to %.1f\n",
            minimum(x.σ for x in okabs), maximum(x.σ for x in okabs),
            minimum(x.mult for x in okabs), maximum(x.mult for x in okabs))
best = rows[argmin([x.loss for x in rows])]
(best.σ in (0.36, 0.70)) && say("WARNING: the best sigma is on the edge of the grid")

cb = SAGEConfig(CR; kappa = best.κ, sigma_m = best.σ)
rb = _solve(cb, THR_OLD; fams = RAW)
@printf("\nbest point kappa %.2f sigma %.2f: participation %.4f (cells %.4f, %.4f; employed %.4f, unemployed %.4f)\n",
        best.κ, best.σ, rb.rate, rb.pooled[1].rate, rb.pooled[2].rate, rb.rate_E, rb.rate_U)
@printf("  agency %.4f, hardship %.4f, hand-to-mouth %.4f (%s), slope %.4f, multiplier %.1f\n",
        rb.A, rb.hardship, rb.hand_to_mouth,
        abs(rb.hand_to_mouth - 0.30) < 0.02 ? "on its 0.30 target" : "OFF its 0.30 target, the spread needs recalibrating",
        rb.slope, 1 / (1 - rb.slope))
say("  (levels anchored to the old poverty line here; the suite solves this economy on its own)")

open(joinpath(@__DIR__, "calibration_ratio.txt"), "w") do io
    println(io, "# written by calibrate_ratio.jl; read by test_modular.jl")
    @printf(io, "kappa = %.2f\nsigma_m = %.2f\nunemployed_ratio = %.12f\nbeta_spread = 0.037\n", best.κ, best.σ, RATIO)
end
say("wrote calibration_ratio.txt")
say("DONE")
