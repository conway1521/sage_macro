# Does anything we report depend on the unemployed participating at one?
#
# THE DEFECT. The unemployed participate at 1.0000 against an employed 0.2629,
# a ratio of 3.80 where INSEE Premiere 1327 gives 0.486. Three mechanisms have
# now been closed: a money cost (wrong sign, twice), a devalued belonging
# payoff (no movement down to one percent of value), and committed time when
# out of work, which the French time-use data pin at 0.14 to 0.24 in model
# units, a range over which the probe shows bit-identical rows (STAGE7.md,
# 2026-09-14). There is no free parameter left to hit the moment with, so the
# question is no longer how to fix it but whether it contaminates the results.
#
# THE DESIGN: a bracket. Two economies differing only in how the unemployed
# behave on the participation margin.
#   U1  the calibrated footing as it stands, unemployed at 1.0000
#   U0  the same plus a time floor of 0.40 and belonging at 0.50, which
#       probe_defect.txt shows drives the unemployed to exactly 0.0000
# The truth sits at 0.486 x 0.2629 = 0.128, that is 13 percent of the way from
# U0 to U1, so U0 is much the better approximation and U1 is the worst case.
# Any gap between the two is an upper bound on the contamination, and about 87
# percent of that gap is the error in what is currently reported.
#
# WHY THE BRACKET IS CLEAN AT THE BASELINE. The time floor enters the time
# constraint and the disutility, the belonging scale enters the social payoff,
# and with partcredit at zero participation has no budget effect. So none of
# the three touches the budget constraint, the wealth distribution should be
# identical across the bracket, and the only thing that moves is participation.
# probe_defect.txt already shows hand-to-mouth at 0.2901 on both sides. Under
# the participation credit this stops holding, which is the point of running
# the policies rather than the baseline alone.
#
# PREDICTIONS, fixed before the run.
#  P1  At the baseline, agency, asset poverty, income poverty and hand-to-mouth
#      are identical across the bracket to four decimals. If this fails, either
#      the separability argument above is wrong or something couples the
#      participation decision to the budget where it should not.
#  P2  The EMPLOYED rate falls in U0, below 0.2629. The social multiplier acts
#      on the aggregate, and the aggregate is lower once the unemployed leave.
#      So the bracket is not a relabelling of one group: the defect feeds back
#      onto everyone. If P2 holds, the calibration itself is contaminated,
#      because kappa and sigma were fitted to an aggregate 25 percent too high.
#  P3  Policy effects on AGENCY agree across the bracket. Stage 7 found the
#      agency column is a distributional statistic that inherits almost nothing
#      from the fixed point. The participation credit is the exception to watch,
#      being the one policy whose budget effect runs through participation.
#  P4  Policy effects on PARTICIPATION differ materially. Participation is the
#      fixed point and inherits all of it.
#  P5  The two hardship concepts keep opposite signs on the replacement rate in
#      both brackets. If that flips, the central finding of this whole line of
#      work is contaminated and has to be requalified.
#
# Then a technology rescan on U0's own families, which is nearly free because
# response families do not depend on kappa or sigma. That answers the separate
# question of whether a corrected model would have calibrated elsewhere.
#
#   julia --project=. scripts/quarantine.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

# S = true is not optional here. Without it this is a no-cohesion economy whose
# participation rate is 0.0203, and the first attempt at this script ran exactly
# that for want of the flag. The suite's own G+S+A row is the check below.
const CAL = SAGEConfig(S = true, A = true, unemployment = true, beta_spread = 0.037,
                       kappa = 9.90, sigma_m = 0.385)
const SUITE_RATE = 0.357355      # test_modular.txt, G+S+A at the calibrated footing
const SUITE_HTM  = 0.299820
const SUITE_A    = 0.494665
const TAU_SUB  = 0.20
const RHO_CRED = 0.25
const RR_UP    = CAL.rr + 0.10
const RR_FLOOR = 0.57            # OECD TaxBEN France 2025, statutory floor
const ALPHA_MID = 0.838

say(args...) = (println(args...); flush(stdout))

"Close the lump tax on a policy that costs money. `cost` reads the tax off a solved economy."
function closed(c0, thr, cost; label = "")
    T = 0.0
    local r
    for it in 1:6
        r = solve_economy(SAGEConfig(c0; lumptax = T); thresholds = thr)
        Tn = cost(r)
        @printf("    %s iteration %d: rate %.4f, T %.5f -> %.5f\n", label, it, r.rate, T, Tn)
        flush(stdout)
        abs(Tn - T) < 1e-4 && break
        T = Tn
    end
    r
end

"Baseline and the five policies for one side of the bracket."
function side(c, b; label)
    say("\n", "="^78); say(label, ": ", describe(c)); say("="^78)
    thr = [(b.ypov, b.abar)]
    sub = closed(SAGEConfig(c; subsidy = TAU_SUB), thr,
                 r -> TAU_SUB * r.mean_labour_income; label = "subsidy")
    cred = closed(SAGEConfig(c; partcredit = RHO_CRED), thr,
                  r -> QBAR * RHO_CRED * r.partbase; label = "credit")
    emp = solve_economy(SAGEConfig(c; alpha = (ALPHA_MID, c.alpha[2])); thresholds = thr)
    up  = solve_economy(SAGEConfig(c; rr = RR_UP); thresholds = thr)
    fl  = solve_economy(SAGEConfig(c; rr = RR_FLOOR); thresholds = thr)
    (base = b, sub = sub, cred = cred, emp = emp, up = up, fl = fl, thr = thr)
end

const NAMES = [(:base, "baseline"), (:sub, "work subsidy 0.20"),
               (:emp, "empowerment"), (:cred, "participation credit 0.25"),
               (:up, @sprintf("UI rr %.2f", RR_UP)), (:fl, @sprintf("UI rr %.2f", RR_FLOOR))]

# Both baselines first. The bracket is only the bracket if U0 actually drives
# the unemployed out AT THE EQUILIBRIUM belonging scale; probe_defect.txt read
# them at a fixed scale of 5.0, which is near but not equal to it. If the
# unemployed are not near zero here, the design has not done what it claims and
# the run stops rather than reporting a bracket it does not have.
say("\nbaselines first, to verify the bracket before the policies run.")
B1 = solve_economy(CAL)
@printf("  U1 rate %.4f | employed %.4f | unemployed %.4f | A %.4f | htm %.4f\n",
        B1.rate, B1.rate_E, B1.rate_U, B1.A, B1.hand_to_mouth); flush(stdout)
if abs(B1.rate - SUITE_RATE) > 1e-3 || abs(B1.A - SUITE_A) > 1e-3 ||
   abs(B1.hand_to_mouth - SUITE_HTM) > 1e-3
    @printf("\nSTOP. U1 is not the calibrated economy. Expected rate %.6f, agency %.6f, hand-to-mouth %.6f from test_modular.txt; got %.6f, %.6f, %.6f.\n",
            SUITE_RATE, SUITE_A, SUITE_HTM, B1.rate, B1.A, B1.hand_to_mouth)
    exit(1)
end
say("  matches test_modular.txt on rate, agency and hand-to-mouth.")

# The U0 end of the bracket. probe_defect.txt chose (0.40, 0.50) by reading
# participation at a FIXED belonging scale of 5.0; the equilibrium sits near
# 4.4 in the low cell and 5.1 in the high one, times a taste draw, and the flip
# is sharp, so the pair may not bite here. Walk a short ladder until the
# unemployed are actually out rather than assert a bracket we do not have.
const LADDER = [(search_time = 0.40, belong_u = 0.50),
                (search_time = 0.50, belong_u = 0.30),
                (search_time = 0.50, belong_u = 0.10),
                (search_time = 0.60, belong_u = 0.05)]
CU0 = CAL; B0 = B1; found = false
for k in LADDER
    global CU0, B0, found
    CU0 = SAGEConfig(CAL; k...)
    B0 = solve_economy(CU0)
    @printf("  U0 try, floor %.2f belonging %.2f | rate %.4f | employed %.4f | unemployed %.4f\n",
            k.search_time, k.belong_u, B0.rate, B0.rate_E, B0.rate_U); flush(stdout)
    if B0.rate_U < 0.05
        found = true
        break
    end
end
if !found
    say("\nSTOP. No pair on the ladder drives the unemployed out at the equilibrium",
        " belonging scale. The bracket cannot be built as designed and the",
        " question has to be approached another way.")
    exit(1)
end
TARGET_U = 0.486 * B1.rate_E
@printf("  bracket spans unemployed %.4f to %.4f; the data target %.4f is %.0f%% of the way up\n",
        B0.rate_U, B1.rate_U, TARGET_U,
        100 * (TARGET_U - B0.rate_U) / max(B1.rate_U - B0.rate_U, 1e-9)); flush(stdout)

U1 = side(CAL, B1; label = "U1, as it stands")
U0 = side(CU0, B0; label = "U0, unemployed driven out")

# ------------------------------------------------------------------ levels --
say("\n", "="^78); say("LEVELS, each bracket on its own"); say("="^78)
@printf("%-26s | %-31s | %-31s\n", "", "U1, unemployed at one", "U0, unemployed at zero")
@printf("%-26s | %-7s %-7s %-7s %-7s %-7s | %-7s %-7s %-7s %-7s %-7s\n",
        "policy", "rate", "rate_E", "rate_U", "A", "hard", "rate", "rate_E", "rate_U", "A", "hard")
println("-"^116)
for (f, nm) in NAMES
    a = getfield(U1, f); b = getfield(U0, f)
    @printf("%-26s | %-7.4f %-7.4f %-7.4f %-7.4f %-7.4f | %-7.4f %-7.4f %-7.4f %-7.4f %-7.4f\n",
            nm, a.rate, a.rate_E, a.rate_U, a.A, a.hardship,
            b.rate, b.rate_E, b.rate_U, b.A, b.hardship)
end

say("\nbaseline distribution, which the bracket should NOT move (P1):")
@printf("%-24s %-12s %-12s %s\n", "", "U1", "U0", "difference")
for (nm, f) in [("agency", :A), ("agency, income only", :A_income_only),
                ("hardship, union", :hardship), ("income poverty", :income_poor),
                ("asset poverty", :asset_poor), ("hand-to-mouth", :hand_to_mouth),
                ("mean labour income", :mean_labour_income),
                ("median disposable", :median_income), ("wealth p50", :wealth_p50),
                ("employed effort", :mean_effort_employed)]
    a = getfield(U1.base, f); b = getfield(U0.base, f)
    @printf("%-24s %-12.6f %-12.6f %+.6f%s\n", nm, a, b, b - a,
            abs(b - a) < 5e-5 ? "" : "   <- MOVED")
end

# ------------------------------------------------------------------ effects --
say("\n", "="^78); say("POLICY EFFECTS, the object actually reported"); say("="^78)
@printf("%-26s | %-9s %-9s %-9s | %-9s %-9s %-9s\n",
        "", "dA U1", "dA U0", "gap", "drate U1", "drate U0", "gap")
println("-"^88)
for (f, nm) in NAMES[2:end]
    a = getfield(U1, f); b = getfield(U0, f)
    dA1 = a.A - U1.base.A; dA0 = b.A - U0.base.A
    dr1 = a.rate - U1.base.rate; dr0 = b.rate - U0.base.rate
    @printf("%-26s | %+-9.4f %+-9.4f %+-9.4f | %+-9.4f %+-9.4f %+-9.4f\n",
            nm, dA1, dA0, dA0 - dA1, dr1, dr0, dr0 - dr1)
end

say("\nthe two hardship concepts on the replacement rate (P5):")
@printf("%-26s %-12s %-12s %-12s %s\n", "", "dA union", "dA income", "same sign?", "")
for (f, nm) in [(:up, @sprintf("UI rr %.2f", RR_UP)), (:fl, @sprintf("UI rr %.2f", RR_FLOOR))]
    for (S, tag) in [(U1, "U1"), (U0, "U0")]
        p = getfield(S, f)
        du = p.A - S.base.A; di = p.A_income_only - S.base.A_income_only
        @printf("%-26s %+-12.4f %+-12.4f %-12s %s\n", "$nm, $tag", du, di,
                sign(du) == sign(di) ? "yes" : "NO, opposite", "")
    end
end

# --------------------------------------------------------------- verdicts --
say("\n", "="^78); say("VERDICTS"); say("="^78)
p1 = all(abs(getfield(U0.base, f) - getfield(U1.base, f)) < 5e-5
         for f in (:A, :hardship, :income_poor, :asset_poor, :hand_to_mouth))
say("P1 baseline distribution untouched by the bracket: ", p1 ? "HELD" : "FAILED")
@printf("P2 employed rate %.4f in U1 against %.4f in U0: %s\n", U1.base.rate_E, U0.base.rate_E,
        U0.base.rate_E < U1.base.rate_E - 1e-4 ? "HELD, the defect feeds back onto the employed" :
        "FAILED, the employed do not notice")
gapsA = [abs((getfield(U0, f).A - U0.base.A) - (getfield(U1, f).A - U1.base.A)) for (f, _) in NAMES[2:end]]
gapsR = [abs((getfield(U0, f).rate - U0.base.rate) - (getfield(U1, f).rate - U1.base.rate)) for (f, _) in NAMES[2:end]]
@printf("P3 largest gap in an agency effect %.4f (%s): %s\n", maximum(gapsA),
        NAMES[2:end][argmax(gapsA)][2], maximum(gapsA) < 0.005 ? "HELD" : "FAILED")
@printf("P4 largest gap in a participation effect %.4f (%s): %s\n", maximum(gapsR),
        NAMES[2:end][argmax(gapsR)][2], maximum(gapsR) >= 0.005 ? "HELD" : "FAILED")
p5 = all(sign(getfield(S, f).A - S.base.A) != sign(getfield(S, f).A_income_only - S.base.A_income_only)
         for f in (:up, :fl), S in (U1, U0))
say("P5 hardship concepts keep opposite signs on the replacement rate in both: ", p5 ? "HELD" : "FAILED")

# ------------------------------------------------- would it recalibrate? --
say("\n", "="^78); say("WOULD A CORRECTED MODEL HAVE CALIBRATED ELSEWHERE?"); say("="^78)
say("Free, because response families do not depend on the social technology.")
c0 = CU0
f0 = families(c0)
rows = scan_technology(c0, f0, collect(0.30:0.01:1.00), collect(2.0:0.05:20.0))
ok = report_technology(rows)
say("\nagainst the footing in use, kappa 9.90 and sigma 0.385.")
say("DONE")
