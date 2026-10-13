# The policy levers on the base with the state out of work, as checks of the model (V3_START.md
# section 94, item 3): each lever is moved once in one configuration and the new steady state is set
# against the old one, on the old one's poverty line. The budget closes by itself in each (the tax
# rate adjusts to the insurance bill and to the floor's outlay).
#
#   1. benefit      the first year's replacement rate +0.10 (the public part carries the change)
#   2. minimum      the minimum income +10%
#   3. finding      the yearly chance of finding work within the first year +0.05
#
# What is checked is what the theory signs without doubt: the budget balances; a higher benefit
# lowers the fall in consumption on job loss; a higher minimum income pays out more and does not
# lower the share without a buffer (Hubbard, Skinner and Zeldes 1995); better job finding lowers the
# share out of work and raises welfare. The rest is reported, not checked. With A on the comparison
# of steady states is all version 1 has (no paths with households who choose their hours).
#
#   julia --project=scripts/run_env scripts/policy_checks_base.jl CODE CONFIG [policy number: one alone]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2])
ONE = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 0
S_ON = occursin('S', cfg); A_ON = occursin('A', cfg)
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))

b = country_config(code; config = cfg, v3 = :v5m, S = S_ON, A = A_ON)
t0 = @elapsed rB = solve_economy(b)
thr = [(rB.ypov, rB.abar)]
gaptol(r) = S_ON ? 5e-4 * r.mean_income : 1e-8
@printf("%s %s, the base [%.1f min]: out of work %.4f, hand-to-mouth %.4f, hours %.4f, participation %.4f, fall on job loss %.4f, floor outlay %.5f, budget gap %+.1e\n",
        code, cfg, t0 / 60, rB.unemployment, rB.hand_to_mouth_kvw, rB.mean_effort_employed, rB.rate, rB.consumption_drop, rB.floor_outlay, rB.budget_gap)
check("the base's budget balances", abs(rB.budget_gap) < gaptol(rB))

rrp = isnan(b.rr_public) ? b.rr : b.rr_public
pols = [("benefit +0.10", SAGEConfig(b; rr = b.rr + 0.10, rr_public = rrp + 0.10)),
        ("minimum income +10%", SAGEConfig(b; cfloor = 1.1 * b.cfloor)),
        ("job finding +0.05", SAGEConfig(b; f_find = min(b.f_find + 0.05, 0.99)))]
@printf("\n%-20s %8s %8s %8s %8s %8s %8s %8s | %9s %9s %9s %9s %9s | %9s\n", "", "out", "htm", "hours", "part.", "fall", "poor", "outlay",
        "welfare", "low edu", "high edu", "in work", "out", "gap")
for (k, (lab, cP)) in enumerate(pols)
    (ONE == 0 || ONE == k) || continue
    t = @elapsed rP = solve_economy(cP; thresholds = thr)
    ce = try
        welfare_ce(rB, rP)
    catch
        (total = NaN, cells = (NaN, NaN), employed = NaN, unemployed = NaN)
    end
    @printf("%-20s %+8.4f %+8.4f %+8.4f %+8.4f %+8.4f %+8.4f %+8.5f | %+8.3f%% %+8.3f%% %+8.3f%% %+8.3f%% %+8.3f%% | %+9.1e  [%.1f min]\n", lab,
            rP.unemployment - rB.unemployment, rP.hand_to_mouth_kvw - rB.hand_to_mouth_kvw, rP.mean_effort_employed - rB.mean_effort_employed,
            rP.rate - rB.rate, rP.consumption_drop - rB.consumption_drop, rP.income_poor - rB.income_poor, rP.floor_outlay - rB.floor_outlay,
            100 * ce.total, 100 * ce.cells[1], 100 * ce.cells[2], 100 * ce.employed, 100 * ce.unemployed, rP.budget_gap, t / 60)
    check("$lab: the budget balances", abs(rP.budget_gap) < gaptol(rP))
    k == 1 && check("$lab: the fall in consumption on job loss is smaller", rP.consumption_drop < rB.consumption_drop)
    k == 2 && check("$lab: the floor pays out more", rP.floor_outlay > rB.floor_outlay)
    k == 2 && check("$lab: the share without a buffer does not fall", rP.hand_to_mouth_kvw > rB.hand_to_mouth_kvw - 1e-4)
    k == 3 && check("$lab: fewer are out of work", rP.unemployment < rB.unemployment)
    k == 3 && check("$lab: welfare rises", ce.total > 0)
    S_ON && @printf("      participation by education %+.4f %+.4f; multiplier %.2f, was %.2f\n", rP.pooled[1].rate - rB.pooled[1].rate,
                    rP.pooled[2].rate - rB.pooled[2].rate, 1 / (1 - rP.slope), 1 / (1 - rB.slope))
end
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks pass%s\n", length(results) - nf, length(results), nf == 0 ? "" : "; FAILED: " * join([x[1] for x in results if !x[2]], "; "))
println("Welfare: consumption equivalent, steady state to steady state, no transition; in work or out of work today.")
println("DONE")
