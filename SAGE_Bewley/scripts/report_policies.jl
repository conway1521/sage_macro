# The reporting layer on a full economy: France G+S+A, three policies from the
# policy tests, each against the baseline. Welfare in consumption equivalents
# (total, by component, by education cell, by employment status), the WISE
# indicators beside it, and the propensities, with participation's aggregate
# response through the social multiplier.
#
#   julia --project=scripts/run_env scripts/report_policies.jl FR
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? ARGS[1] : "FR"
b = country_config(code; config = "GSA", S = true, A = true)
rB = solve_economy(b)
thr = [(rB.ypov, rB.abar)]
mult = 1 / (1 - rB.slope)
@printf("%s G+S+A baseline: participation %.4f (multiplier %.2f) | propensities out of a one-month windfall: consume %.3f, save %.3f, earn %+.3f, take part %+.5f (with feedback %+.5f); check %.6f\n",
        code, rB.rate, mult, rB.mpc, rB.mps, rB.mpe, rB.mpp, rB.mpp * mult, rB.mpc + rB.mps - rB.mpe)
pols = ["benefits +0.10" => SAGEConfig(b; rr = b.rr + 0.10), "benefits -0.10" => SAGEConfig(b; rr = b.rr - 0.10),
        "empowerment" => SAGEConfig(b; alpha = ((b.alpha[1] + b.alpha[2]) / 2, b.alpha[2]))]
@printf("\n%-15s %9s | %9s %9s %9s %9s | %9s %9s | %9s %9s | %8s %8s %8s %8s\n", "policy", "welfare", "consump.", "effort", "belong.",
        "rest", "low edu", "high edu", "employed", "unempl.", "d part.", "d agency", "d prot.", "d hard.")
for (lab, cP) in pols
    rP = solve_economy(cP; thresholds = thr)
    ce = welfare_ce(rB, rP)
    @printf("%-15s %+8.3f%% | %+8.3f%% %+8.3f%% %+8.3f%% %+8.3f%% | %+8.3f%% %+8.3f%% | %+8.3f%% %+8.3f%% | %+8.4f %+8.4f %+8.4f %+8.4f\n",
            lab, 100 * ce.total, 100 * ce.parts.consumption, 100 * ce.parts.effort, 100 * ce.parts.belonging, 100 * ce.parts.choice_and_rest,
            100 * ce.cells[1], 100 * ce.cells[2], 100 * ce.employed, 100 * ce.unemployed,
            rP.rate - rB.rate, rP.A - rB.A, rP.A_cond - rB.A_cond, rP.hardship - rB.hardship)
    flush(stdout)
end
println("\nWelfare: consumption equivalent, steady state to steady state (no transition). Status: employed or unemployed today.")
println("DONE")
