# Participation tax credit (Paper 2's NEW experiment): the model analogue of
# France's 66 percent charitable-donations deduction and the UK's Gift Aid.
# Effective interaction strength rises by a factor (1 + boost), financed by
# a lump-sum tax proportional to the participation rate times mean income.
# Uses the cached sa_families.txt for speed: every counterfactual is
# interpolation, no engine solves.
#
#   julia --project=. scripts/sa_partcredit.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5

d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])

function eq_rate(κ_eff)
    _, _, e = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ_eff, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    isempty(sts) ? NaN : sts[argmax([x[1] for x in sts])][1]
end

r0 = eq_rate(KAPPA)
mi0 = population_meaninc(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA, r0)
@printf("baseline: rate %.3f, mean labour income %.3f\n\n", r0, mi0)

# The participation tax credit lifts the marginal return to belonging by
# 1 + boost. Boost is the policy lever; the fiscal cost equals
# (boost * QBAR * Λ * Bbar) * rate, scaled by the lump in time-money units,
# which we proxy as boost * 0.10 (QBAR) * rate * mi0. The point of the
# exercise is the rate response per fiscal-cost unit.
println("Participation tax credit, three intensities (boost = rebate as a")
println("fraction of the marginal interaction return):")
@printf("%-6s | %-12s | %-12s | %s\n", "boost", "rate", "change pp", "fiscal cost / mi")
for boost in (0.25, 0.50, 1.00, 1.50)
    rC = eq_rate(KAPPA * (1 + boost))
    cost = boost * 0.10 * rC * mi0
    @printf("%5.2f  |  %.3f       |  %+.3f       |  %.3f (%.0f%%)\n",
            boost, rC, rC - r0, cost, 100 * cost / mi0)
end

# Apples-to-apples vs Paper 1's policy: pick boost so the fiscal cost equals
# the work-subsidy's cost (~0.093 in mi units, 21 percent of mean income).
println("\nApples-to-apples: matched-cost comparison vs Paper 1's 20% work subsidy")
target_cost = 0.093
function find_boost(target; lo = 0.0, hi = 3.0, steps = 14)
    for _ in 1:steps
        mid = 0.5 * (lo + hi)
        rC = eq_rate(KAPPA * (1 + mid))
        c  = mid * 0.10 * rC * mi0
        c < target ? (lo = mid) : (hi = mid)
    end
    0.5 * (lo + hi)
end
boost_eq = find_boost(target_cost)
rC = eq_rate(KAPPA * (1 + boost_eq))
@printf("matched-cost boost = %.2f -> rate %.3f (%+.3f pp)\n",
        boost_eq, rC, rC - r0)
println("comparison:")
@printf("  (a) Paper 1 work subsidy 20%%:    rate %.3f (-29.0 pp)  cost 21%% mi\n", 0.081)
@printf("  (c) participation credit (matched): rate %.3f (%+.1f pp)  cost 21%% mi\n",
        rC, 100*(rC - r0))
@printf("  ratio of effects: %.1fx in favour of the participation credit\n",
        abs(rC - r0) / abs(0.081 - r0))
println("DONE")
