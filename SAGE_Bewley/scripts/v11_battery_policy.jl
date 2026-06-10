# v1.1 validation battery C: does the make-work-pay decoupling result survive
# the literature parametrization? Budget-balanced 20% labour subsidy (EITC
# phase-in scale) under warmglow cohesion.
#   julia --project=. scripts/v11_battery_policy.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

function solve_financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z_vals, _ = SAGEBewley.income_process(p)
    T = 0.0
    sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        paid = 0.0
        for iz in 1:p.nz, ia in 1:p.na
            paid += sol.λ[ia, iz] * subsidy * p.α[iz] * sol.e[ia, iz] * z_vals[iz]
        end
        abs(paid - T) < tol && break
        T = 0.5 * T + 0.5 * paid
        sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    end
    sol
end

agg(s, M) = sum(s.λ .* M)

for κ in (1.0, 2.0)
    p = SAGEParams(social_mode = :warmglow, social_strength = κ)
    b = solve_financed(p; subsidy = 0.0)
    s = solve_financed(p; subsidy = 0.20)
    @printf("kappa=%.1f  dC=%+.2f%%  dQ=%+.2f%%  dUc=%+.2f%%   decoupling: %s\n",
            κ, 100*(agg(s, s.c)/agg(b, b.c) - 1), 100*(s.Q/b.Q - 1),
            100*(agg(s, s.Uc)/agg(b, b.Uc) - 1),
            (agg(s, s.c) > agg(b, b.c) && s.Q < b.Q) ? "YES (C up, Q down)" : "no")
    flush(stdout)
end
println("DONE")
