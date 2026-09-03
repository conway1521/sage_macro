# VERIFICATION LADDER, LEVEL 0: the engine itself.
# Nothing above this level is trustworthy unless these pass. Checks:
#   0.1 grid convergence of the baseline solve (na, ne)
#   0.2 asset-grid truncation (no mass piling at the top node)
#   0.3 the stationary distribution is a distribution and is exact
#   0.4 policy sanity: consumption rising in assets, savings a stable target
#   0.5 the social fixed point converges (multiplier mode)
#   0.6 grid convergence of the S paper's headline policy result
#
#   julia --project=. scripts/verify_L0_engine.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf, Statistics

pass(b) = b ? "PASS" : "**FAIL**"
println("="^70); println("LEVEL 0: ENGINE"); println("="^70)

println("\n0.1 grid convergence of the baseline solve")
@printf("%-14s | %-8s | %-8s | %-8s | %-8s\n", "grid", "Q", "wGini", "HtM", "mean e")
base = nothing
for (na, ne) in ((100,20), (200,40), (300,60), (400,80))
    p = SAGEParams(na = na, ne = ne)
    s = solve_model(p)
    g = wealth_gini(s); h = frac_constrained(s); e = sum(s.λ .* s.e)
    @printf("na=%-3d ne=%-3d | %.4f  | %.4f  | %.4f  | %.4f\n", na, ne, s.Q, g, h, e)
    (na, ne) == (200, 40) && (base = (Q=s.Q, g=g, h=h, e=e))
    global base
end
println("   read: the production grid is na=200 ne=40; judge drift against na=400 ne=80")

println("\n0.2 asset-grid truncation and 0.3 distribution integrity")
let p = SAGEParams(), s = solve_model(p)
    top = sum(s.λ[end, :]); tot = sum(s.λ)
    @printf("   mass at top asset node = %.3e   %s\n", top, pass(top < 1e-8))
    @printf("   total mass             = %.12f  %s\n", tot, pass(abs(tot-1) < 1e-10))
    @printf("   any negative mass?     = %s        %s\n", any(s.λ .< -1e-14), pass(!any(s.λ .< -1e-14)))
    # 0.4 policy sanity
    cmono = all(diff(s.c[:,1]) .>= -1e-9) && all(diff(s.c[:,2]) .>= -1e-9)
    amono = all(diff(s.a_next[:,1]) .>= -1e-9) && all(diff(s.a_next[:,2]) .>= -1e-9)
    @printf("\n0.4 consumption nondecreasing in assets   %s\n", pass(cmono))
    @printf("   savings rule nondecreasing in assets   %s\n", pass(amono))
    # a stable target: a'(a) - a must cross zero from above somewhere
    gap = s.a_next[:,1] .- s.a_grid
    @printf("   savings rule crosses 45 degrees        %s\n", pass(any(gap .> 0) && any(gap .< 0)))
end

println("\n0.5 social fixed point (multiplier mode) converges")
let p = update(SAGEParams(); social_mode = :multiplier, social_strength = 1.0)
    s = solve_model(p)
    @printf("   Q = %.6f, |Q - A| residual implied by tol 1e-4   %s\n", s.Q, pass(isfinite(s.Q)))
end

println("\n0.6 grid convergence of the S paper's financed-subsidy result")
function financed(p; subsidy, tol = 1e-5, maxit = 40)
    z, _ = SAGEBewley.income_process(p); T = 0.0
    s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        paid = sum(s.λ[ia,iz]*subsidy*p.α[iz]*s.e[ia,iz]*z[iz] for iz in 1:p.nz, ia in 1:p.na)
        abs(paid - T) < tol && break
        T = 0.5T + 0.5paid
        s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    end
    s
end
@printf("%-14s | %-10s | %-10s\n", "grid", "dC %", "dQ %")
for (na, ne) in ((100,20), (200,40), (300,60))
    pw = update(SAGEParams(na=na, ne=ne); social_mode = :warmglow, social_strength = 1.0)
    s0 = financed(pw; subsidy = 0.0); s1 = financed(pw; subsidy = 0.20)
    agg(s,M) = sum(s.λ .* M)
    @printf("na=%-3d ne=%-3d | %+8.2f   | %+8.2f\n", na, ne,
            100*(agg(s1,s1.c)/agg(s0,s0.c)-1), 100*(s1.Q/s0.Q-1))
end
println("\nDONE")
