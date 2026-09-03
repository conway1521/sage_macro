# TIER 1 follow-up.
#   T1.3b hand-to-mouth: which threshold is grid-stable
#   T1.4b effort grid at fixed na: does the oscillation damp with ne
#
#   julia --project=. scripts/verify_T1b.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf, Statistics
E = SAGEBewley

function htm(s, weeks)
    p = s.p; z, _ = E.income_process(p)
    minc = sum(s.λ[ia,iz]*p.α[iz]*s.e[ia,iz]*z[iz] for iz in 1:p.nz, ia in 1:p.na)
    thr = (weeks/52)*minc
    (sum(s.λ[ia,iz] for iz in 1:p.nz, ia in 1:p.na if s.a_grid[ia] < thr),
     count(<(thr), s.a_grid))
end

println("T1.3b hand-to-mouth by threshold; (n) = asset nodes below the threshold")
@printf("%-12s | %-13s | %-13s | %-13s | %-13s\n", "grid", "4 weeks", "8 weeks", "13 weeks", "26 weeks")
for (na, ne) in ((200,40), (300,60), (400,80), (600,80))
    s = solve_model(SAGEParams(na = na, ne = ne))
    vals = map(w -> htm(s, w), (4.0, 8.0, 13.0, 26.0))
    @printf("na=%-4d ne=%-2d | %.4f (%2d)  | %.4f (%2d)  | %.4f (%2d)  | %.4f (%2d)\n",
            na, ne, vals[1]..., vals[2]..., vals[3]..., vals[4]...)
    flush(stdout)
end

println("\nT1.4b effort grid at FIXED na = 200: does the oscillation damp?")
function financed(p; subsidy, tol = 1e-6, maxit = 60)
    z, _ = E.income_process(p); T = 0.0; s = solve_model(update(p; subsidy=subsidy, lumptax=T))
    for _ in 1:maxit
        paid = sum(s.λ[ia,iz]*subsidy*p.α[iz]*s.e[ia,iz]*z[iz] for iz in 1:p.nz, ia in 1:p.na)
        abs(paid - T) < tol && break
        T = 0.5T + 0.5paid
        s = solve_model(update(p; subsidy=subsidy, lumptax=T))
    end
    s
end
@printf("%-8s | %-9s | %-9s | %-10s | %-10s\n", "ne", "dC %", "dQ %", "Q base", "mean e base")
for ne in (40, 80, 160, 320)
    pw = update(SAGEParams(na = 200, ne = ne); social_mode = :warmglow, social_strength = 1.0)
    s0 = financed(pw; subsidy = 0.0); s1 = financed(pw; subsidy = 0.20)
    agg(s,M) = sum(s.λ .* M)
    @printf("ne=%-5d | %+7.2f   | %+7.2f   | %.5f    | %.5f\n", ne,
            100*(agg(s1,s1.c)/agg(s0,s0.c)-1), 100*(s1.Q/s0.Q-1),
            s0.Q, sum(s0.λ .* s0.e))
    flush(stdout)
end
println("\nDONE")
