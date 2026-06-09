# Paper 1 normative experiment: a budget-balanced make-work-pay labour subsidy,
# under behavioural social cohesion. Shows decoupling (material up, social down)
# and the two-planner contrast a single-index objective is blind to.
#   julia --project=. scripts/policy_experiment.jl

const ROOT = "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley"
include(joinpath(ROOT, "src", "SAGEBewley.jl"))
using .SAGEBewley, Printf, Statistics

# solve with the subsidy financed by a lump-sum tax (budget balance: the tax
# equals the per-capita subsidy paid). Outer loop on the lump-sum tax.
function solve_financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z_vals, _ = SAGEBewley.income_process(p)
    T = 0.0; sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
        paid = 0.0                              # per-capita subsidy paid = subsidy * E[α e z]
        for iz in 1:p.nz, ia in 1:p.na
            paid += sol.λ[ia, iz] * subsidy * p.α[iz] * sol.e[ia, iz] * z_vals[iz]
        end
        abs(paid - T) < tol && break
        T = 0.5 * T + 0.5 * paid
    end
    sol
end

p = SAGEParams(social_mode = :warmglow)         # behavioural social cohesion

base = solve_financed(p; subsidy = 0.0)
pol  = solve_financed(p; subsidy = 0.20)        # 20% make-work-pay subsidy, financed

gmean(s, M, z) = sum(s.λ[:, z] .* M[:, z]) / sum(s.λ[:, z])
agg(s, M)      = sum(s.λ .* M)
socialU(s, z)  = p.Λ * p.B[z] * s.Q             # social-cohesion dimension for group z

println("============ make-work-pay subsidy (20%, budget-balanced) ============")
@printf("%-26s  %10s  %10s  %8s\n", "", "baseline", "subsidy", "change")
@printf("%-26s  %10.4f  %10.4f  %+7.1f%%\n", "aggregate consumption",
        agg(base, base.c), agg(pol, pol.c), 100*(agg(pol,pol.c)/agg(base,base.c)-1))
@printf("%-26s  %10.4f  %10.4f  %+7.1f%%\n", "public good Q",
        base.Q, pol.Q, 100*(pol.Q/base.Q - 1))
@printf("%-26s  %10.4f  %10.4f  %+7.1f%%\n", "aggregate material gain Uc",
        agg(base, base.Uc), agg(pol, pol.Uc), 100*(agg(pol,pol.Uc)/agg(base,base.Uc)-1))
println()
println("By income group (material gain Uc and social cohesion Us):")
@printf("%-12s  %12s %12s  | %12s %12s\n", "", "Uc base", "Uc subsidy", "Us base", "Us subsidy")
for (zi, name) in ((1,"low income"), (2,"high income"))
    @printf("%-12s  %12.4f %12.4f  | %12.4f %12.4f\n", name,
            gmean(base, base.Uc, zi), gmean(pol, pol.Uc, zi),
            socialU(base, zi), socialU(pol, zi))
end

println("\n----- the two planners -----")
dC  = 100*(agg(pol,pol.c)/agg(base,base.c)-1)
dUs = 100*(pol.Q/base.Q - 1)
@printf("consumption / material planner sees: consumption %+.1f%%  -> ADOPT\n", dC)
@printf("wellbeing planner also sees:         social cohesion %+.1f%%  -> the cost a single index misses\n", dUs)
println("\nDONE")
