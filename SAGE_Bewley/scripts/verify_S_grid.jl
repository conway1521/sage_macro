# Does the S paper survive the grid finding? The engine shares a_max = 100
# with a wealth distribution that ends near 2, so fifteen of its 200 nodes
# carry everything. The S paper's headline is the financed-subsidy decoupling
# (consumption +5.6, Q -5.2 at ne = 320) and its untargeted moments (HtM 0.33,
# wealth Gini 0.55). Recompute both on the rescaled grid at two na.
#   julia --project=. scripts/verify_S_grid.jl
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl")); using .SAGEBewley
using Printf
function financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z, _ = income_process(p); T = 0.0
    s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        paid = sum(s.λ[i,j]*subsidy*p.α[j]*s.e[i,j]*z[j] for j in 1:p.nz, i in 1:p.na)
        abs(paid - T) < tol && break
        T = 0.5T + 0.5paid
        s = solve_model(update(p; subsidy = subsidy, lumptax = T))
    end
    s
end
agg(s, M) = sum(s.λ .* M)
@printf("%-8s %-5s %-5s | %-7s %-7s %-7s | %-9s %-9s | %-7s\n",
        "a_max","pexp","na","Q","Gini","HtM","dC %","dQ %","eff.nodes")
for (amax, pe) in ((100.0, 1.5), (4.0, 3.0)), na in (200, 400)
    p  = update(country_params("FR"); a_max = amax, pexp = pe, na = na)
    s  = solve_model(p)
    lam = vec(sum(s.λ, dims = 2)); cum = cumsum(lam ./ sum(lam))
    eff = something(findfirst(>=(0.999), cum), length(cum))
    pw = update(p; ne = 320, social_mode = :warmglow, social_strength = 1.0)
    s0 = financed(pw); s1 = financed(pw; subsidy = 0.20)
    @printf("%-8.0f %-5.1f %-5d | %-7.4f %-7.4f %-7.4f | %+8.2f  %+8.2f  | %-7d\n",
            amax, pe, na, s.Q, wealth_gini(s), hand_to_mouth(s),
            100*(agg(s1,s1.c)/agg(s0,s0.c)-1), 100*(s1.Q/s0.Q-1), eff)
    flush(stdout)
end
println("DONE")
