# Stage 7 again, on seven productivity states and on the modular layer.
#
# WHY IT IS BEING RUN AGAIN. Everything in stages 6 and 7 was computed with two
# productivity states, at which the income distribution is two clusters with a
# gap and the median falls in the gap (MODULAR.md). The poverty line is half
# the median, so every hardship statistic, and the whole agency column, sat on
# a number that was not identified. The reductions, the identities, the
# independent-path check and the omega robustness are unaffected. The
# calibration and the levels are not.
#
# WHY ON THE MODULAR LAYER. The old driver carried its own copies of the
# population machinery. This one is thirteen configurations of one verified
# solver, which is what makes the run reproducible: the configuration IS the
# specification.
#
#   julia --project=. scripts/stage7_nz7.jl [kappa sigma spread]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics

const KAPPA  = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 10.00
const SIGMA  = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.400
const SPREAD = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.000
const TAU_SUB, RHO_CRED = 0.20, 0.25
const RR_UP, RR_FLOOR = 0.78, 0.57
const ALPHA_MID = 0.838

const BASE = SAGEConfig(S = true, A = true, unemployment = true, nz = 11,
                        kappa = KAPPA, sigma_m = SIGMA, beta_spread = SPREAD)
@printf("stage 7 on seven productivity states | kappa %.2f sigma_m %.3f spread %.3f | %d workers\n",
        KAPPA, SIGMA, SPREAD, nworkers())
println(describe(BASE)); println()

B = solve_economy(BASE)
const THR = [(B.ypov, B.abar)]
@printf("baseline: rate %.4f (E %.4f, U %.4f), median %.4f, line %.4f, asset threshold %.4f\n",
        B.rate, B.rate_E, B.rate_U, B.median_income, B.ypov, B.abar)
@printf("          hand-to-mouth %.4f, unemployment %.4f, effort %.4f, slope %.4f, multiplier %.1f\n\n",
        B.hand_to_mouth, B.unemployment, B.mean_effort_employed, B.slope, 1 / (1 - B.slope))

# ---- is the multiplier identified here either? -------------------------------
# At two productivity states the participation moments pinned a region in which
# the policy multiplier ran from 7 to over 100 with no material difference in
# fit. That is a property of the aggregate map rather than of the income
# process, so it should still be here, and a reader needs the range and not the
# point. The families do not depend on the social technology, so this is one
# build and then interpolation.
println("calibration robustness at this state space")
let fams = families(BASE)
    rows = scan_technology(BASE, fams, 0.30:0.01:0.60, 8.0:0.02:12.0)
    report_technology(rows)
end
println()

"Iterate a lump-sum tax to balance an instrument's budget, holding the
baseline's thresholds so the poverty line is anchored rather than floating."
function financed(cfg, cost; maxit = 8, tol = 1e-4)
    T = 0.0; local r
    for it in 1:maxit
        r = solve_economy(SAGEConfig(cfg; lumptax = T); thresholds = THR)
        Tn = cost(r)
        @printf("    iteration %d: rate %.4f, lump tax %.5f -> %.5f\n", it, r.rate, T, Tn)
        flush(stdout)
        abs(Tn - T) < tol && break      # do not advance T past the economy just solved
        T = Tn
    end
    (r = r, T = T)
end

println("policies")
S = (println("  work subsidy"); financed(SAGEConfig(BASE; subsidy = TAU_SUB), r -> TAU_SUB * r.mean_labour_income))
C = (println("  participation credit"); financed(SAGEConfig(BASE; partcredit = RHO_CRED), r -> QBAR * RHO_CRED * r.partbase))
E = solve_economy(SAGEConfig(BASE; alpha = (ALPHA_MID, 0.911)); thresholds = THR)
U = solve_economy(SAGEConfig(BASE; rr = RR_UP); thresholds = THR)
F = solve_economy(SAGEConfig(BASE; rr = RR_FLOOR); thresholds = THR)

const ROWS = (("baseline", B), ("work subsidy", S.r), ("empowerment", E),
              ("participation credit", C.r), (@sprintf("UI rr %.2f", RR_UP), U),
              (@sprintf("UI rr %.2f", RR_FLOOR), F))
println()
println("="^104)
@printf("%-22s | %-6s %-6s %-6s | %-6s %-6s %-6s | %-7s %-8s | %-7s %s\n",
        "policy", "r", "r_E", "r_U", "inc", "asset", "hard", "A", "dA", "A_inc", "dA_inc")
println("-"^104)
for (nm, r) in ROWS
    @printf("%-22s | %.4f %.4f %.4f | %.4f %.4f %.4f | %.4f %+.4f | %.4f %+.4f\n",
            nm, r.rate, r.rate_E, r.rate_U, r.income_poor, r.asset_poor, r.hardship,
            r.A, r.A - B.A, r.A_income_only, r.A_income_only - B.A_income_only)
end
println("-"^104)
println()
println("asset poverty by income quintile, against the OECD average (Balestra and Tonkin 2018, Figure 6.2)")
@printf("%-22s | %-8s %-8s %-8s %-8s %s\n", "policy", "Q1", "Q2", "Q3", "Q4", "Q5")
println("-"^70)
for (nm, r) in ROWS
    @printf("%-22s | %s\n", nm, join([@sprintf("%-8.4f", x) for x in r.asset_poor_by_quintile]))
end
@printf("%-22s | %-8.2f %-8s %-8s %-8.2f %.2f\n", "OECD average", 0.68, "n/a", "n/a", 0.43, 0.27)
println()
println("the two hardship concepts: they disagreed in sign on the replacement rate at two")
println("productivity states, and that finding is what this rerun most has to confirm or retract")
for (nm, r) in ROWS[2:end]
    du = r.A - B.A; di = r.A_income_only - B.A_income_only
    @printf("  %-22s union %+.4f, income only %+.4f  %s\n", nm, du, di,
            sign(du) != sign(di) ? "OPPOSITE SIGNS" : "same sign")
end
println()
open(joinpath(@__DIR__, "stage7_nz7_results.txt"), "w") do io
    println(io, "# Stage 7 at seven productivity states; see STAGE7.md and MODULAR.md")
    println(io, "kappa\t", KAPPA); println(io, "sigma_m\t", SIGMA); println(io, "beta_spread\t", SPREAD)
    println(io, "T_sub\t", S.T); println(io, "T_cred\t", C.T)
    for (nm, r) in ROWS
        tag = replace(lowercase(nm), " " => "_", "." => "")
        for (k, v) in (("r", r.rate), ("rE", r.rate_E), ("rU", r.rate_U), ("inc", r.income_poor),
                       ("asset", r.asset_poor), ("hard", r.hardship), ("A", r.A),
                       ("Ainc", r.A_income_only), ("htm", r.hand_to_mouth),
                       ("median", r.median_income), ("slope", r.slope))
            println(io, k, "_", tag, "\t", v)
        end
        for (i, q) in enumerate(r.asset_poor_by_quintile)
            println(io, "q", i, "_", tag, "\t", q)
        end
    end
end
println("saved stage7_nz7_results.txt")
println("DONE")
