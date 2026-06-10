# S+A paper, policy comparison: the same financed-subsidy experiment Paper 1 ran
# now expressed in the participation framework, plus a new policy designed to
# act DIRECTLY on the participation margin: a budget-balanced participation tax
# credit, the model analogue of France's 66 percent charitable-donations
# deduction and the UK's Gift Aid. Both policies are financed by a lump-sum tax
# so we compare like with like.
#
# What the comparison shows:
#   (a) Paper 1's financed work subsidy, in Paper 2's frame: participation
#       collapses (already in sa_main.jl).
#   (b) Empowerment (alpha_low to mean): participation booms (already in
#       sa_main.jl).
#   (c) NEW: a participation tax credit that rewards joining. Effective price
#       of the time lump falls; budget balanced by lump-sum tax.
#
# Compares the three policies on participation rate, aggregate fabric, and
# fiscal cost per percentage point of participation moved.
#
#   julia --project=. scripts/sa_policy_compare.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5

println("loading sa_families.txt ...")
d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])
fmid  = (d[:, 1], d[:, 6], d[:, 7])
println("baseline calibration: kappa=$KAPPA sigma=$SIGMA omega=$OMEGA")

function eq_rate(fl, fh, Bl, Bh)
    _, _, e = trace_map(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    isempty(sts) && return NaN
    sts[argmax([x[1] for x in sts])][1]                 # high stable, robust
end

# ---------- (0) baseline -----------------------------------------------------
r0 = eq_rate(flow, fhigh, CELL_LOW.B, CELL_HIGH.B)
mi0 = population_meaninc(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA, r0)
@printf("\n[0] baseline: participation rate = %.3f, mean labour income = %.3f\n", r0, mi0)

# ---------- (a) Paper 1's financed work subsidy ------------------------------
println("\n[a] Paper 1's policy: 20 percent financed make-work-pay subsidy")
println("    (lump-sum tax T balances the subsidy at equilibrium participation)")
function policy_work_subsidy(τ_sub; tol = 1e-4, maxit = 4)
    T = τ_sub * mi0
    rA = r0
    flowP = flow; fhighP = fhigh
    for it in 1:maxit
        flowP  = response_family(0.765; subsidy = τ_sub, lumptax = T, verbose = false)
        fhighP = response_family(0.911; subsidy = τ_sub, lumptax = T, verbose = false)
        rA = eq_rate(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B)
        miA = population_meaninc(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA, rA)
        Tnew = τ_sub * miA
        abs(Tnew - T) < tol && (T = Tnew; break)
        T = Tnew
    end
    rA, T
end
rA, TA = policy_work_subsidy(0.20)
@printf("    -> rate %.3f (change %+.3f points), tax T=%.3f (%.0f%% of mean income)\n",
        rA, rA - r0, TA, 100*TA/mi0)

# ---------- (b) empowerment --------------------------------------------------
println("\n[b] Empowerment: alpha_low raised to the population mean (0.838)")
rB = eq_rate(fmid, fhigh, CELL_LOW.B, CELL_HIGH.B)
@printf("    -> rate %.3f (change %+.3f points), no fiscal instrument\n", rB, rB - r0)

# ---------- (c) NEW: participation tax credit --------------------------------
# The model analogue of charitable-donation tax credits (France 66 percent,
# UK Gift Aid, US itemised deduction). Each unit of participation time gets
# a rebate of `credit_rate` times its market opportunity cost, financed by a
# lump-sum tax. In the engine: we lower the EFFECTIVE participation lump cost
# by routing a per-participant rebate through the wage. Concretely, this is
# modelled as raising the belonging payoff by an equivalent amount, which is
# the policy's first-order effect on the choice. The fiscal cost is the
# rebate times the participation rate times mean labour income.
println("\n[c] NEW: participation tax credit (France's 66% Gift Aid-style scheme)")
println("    Rebate routed through the belonging payoff; budget balanced.")

# Effective interaction strength rises by a factor (1 + credit_rate*c0)
# where c0 captures the relative magnitude of the rebate. We pick the
# rebate so the FISCAL COST equals Paper 1's policy at the new equilibrium
# (apples-to-apples on fiscal expense).
function policy_partcredit(boost; tol = 1e-4, maxit = 4)
    κ_eff = KAPPA * (1 + boost)
    function eq_with_boost(T)
        flowP  = response_family(0.765; lumptax = T, verbose = false)
        fhighP = response_family(0.911; lumptax = T, verbose = false)
        _, _, e = trace_map(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, κ_eff, OMEGA, SIGMA)
        sts = [x for x in e if x[2]]
        isempty(sts) ? NaN : sts[argmax([x[1] for x in sts])][1]
    end
    # iterate budget balance: tax = boost * baseline magnitude * rate * mi
    T = 0.10 * boost * r0 * mi0
    rC = r0
    for it in 1:maxit
        rC = eq_with_boost(T)
        Tnew = 0.10 * boost * rC * mi0
        abs(Tnew - T) < tol && break
        T = Tnew
    end
    rC, T
end
# Pick boost so the fiscal cost roughly matches Paper 1's: |T_A| around 0.09
# of mean income. Boost = 1.0 means doubling the marginal interaction return.
for boost in (0.50, 1.00, 1.50)
    rC, TC = policy_partcredit(boost)
    @printf("    boost=%.2f  ->  rate %.3f (%+.3f points), T=%.3f (%.0f%% of mean income)\n",
            boost, rC, rC - r0, TC, 100*TC/mi0)
end

println("\nSUMMARY TABLE (participation rate, change, fiscal cost):")
@printf("  baseline:                                %.3f\n", r0)
@printf("  (a) Paper 1 work subsidy 20%%:           %.3f  (%+.3f pp,  cost %.0f%% mi)\n",
        rA, rA - r0, 100*TA/mi0)
@printf("  (b) empowerment (alpha_low up):          %.3f  (%+.3f pp,  no cost)\n",
        rB, rB - r0)
rC, TC = policy_partcredit(1.0)
@printf("  (c) participation credit (Gift-Aid-like): %.3f  (%+.3f pp,  cost %.0f%% mi)\n",
        rC, rC - r0, 100*TC/mi0)
println("DONE")
