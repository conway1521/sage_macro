# Prototype run: solve the stationary SAGE/Bewley model and sanity-check it
# against the qualitative facts reported in the thesis (Figures 2, 4, 6).
#
#   julia --project=. scripts/prototype.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf, Statistics

p = SAGEParams()
@printf("Solving SAGE/Bewley model (na=%d, nz=%d, ne=%d)...\n", p.na, p.nz, p.ne)
@time sol = solve_model(p)

a = sol.a_grid
println("\n================ STATIONARY EQUILIBRIUM ================")
@printf("Public good Q (=A)        : %.4f   (thesis ≈ 0.72)\n", sol.Q)
@printf("Wealth Gini               : %.4f   (thesis ≈ 0.236 in egalitarian calib.)\n",
        SAGEBewley.wealth_gini(sol))
@printf("Fraction at constraint    : %.4f   (thesis ≈ 0.01)\n",
        SAGEBewley.frac_constrained(sol))

# ---- qualitative checks (print PASS/FAIL) ----------------------------------
check(name, cond) = @printf("  [%s] %s\n", cond ? "PASS" : "FAIL", name)

println("\nQualitative checks vs. thesis:")
# 1. consumption increasing in wealth, both states
check("consumption rises with wealth (low)",  issorted(sol.c[:,1]; lt=(x,y)->x<=y+1e-9) || sol.c[end,1] > sol.c[1,1])
check("consumption rises with wealth (high)", sol.c[end,2] > sol.c[1,2])
# 2. high income consumes more than low at every wealth level
check("high income consumes ≥ low income",    all(sol.c[:,2] .>= sol.c[:,1] .- 1e-8))
# 3. at low wealth both work ~full; high income works more than low overall
check("high income exerts more effort on avg", mean(sol.e[:,2]) > mean(sol.e[:,1]))
check("effort weakly falls with wealth (low)", sol.e[1,1] >= sol.e[end,1] - 1e-6)
# 4. low income contributes more to the public good (q higher) on average
check("low income contributes more (q)",       mean(sol.q[:,1]) > mean(sol.q[:,2]))
# 5. mass at the constraint is larger for low income
check("more low-income at constraint",
      sum(sol.λ[sol.a_next[:,1].<=a[1]+1e-6,1]) > sum(sol.λ[sol.a_next[:,2].<=a[1]+1e-6,2]))

# ---- snapshot of policies at a few wealth levels ---------------------------
println("\nPolicy snapshot (a, c_lo, c_hi, e_lo, e_hi):")
for ia in (1, 10, 50, 100, 150, 200)
    @printf("  a=%8.3f  c=(%.3f, %.3f)  e=(%.3f, %.3f)\n",
            a[ia], sol.c[ia,1], sol.c[ia,2], sol.e[ia,1], sol.e[ia,2])
end

# ---- public good composition (who supplies Q) ------------------------------
qlo = sum(sol.λ[:,1] .* sol.q[:,1]); qhi = sum(sol.λ[:,2] .* sol.q[:,2])
@printf("\nPublic good composition: low=%.1f%%  high=%.1f%%  (thesis: low-dominated)\n",
        100qlo/(qlo+qhi), 100qhi/(qlo+qhi))

# ---- wellbeing dashboard by wealth quartile --------------------------------
println("\nWellbeing dashboard (avg U^c, U^s) by within-state wealth quartile:")
for i_z in 1:2
    w = sol.λ[:,i_z] ./ sum(sol.λ[:,i_z])
    cumw = cumsum(w)
    @printf(" %s income:\n", i_z == 1 ? "Low " : "High")
    edges = (0.0, 0.25, 0.5, 0.75, 1.0)
    for qi in 1:4
        mask = (cumw .> edges[qi] .- 1e-9) .& (cumw .<= edges[qi+1] .+ 1e-9)
        any(mask) || (mask = falses(length(w)); mask[argmin(abs.(cumw .- edges[qi+1]))] = true)
        ww = w[mask] ./ sum(w[mask])
        Uc = sum(ww .* sol.Uc[mask, i_z]); Us = sum(ww .* sol.Us[mask, i_z])
        @printf("   Q%d:  U^c=%8.3f   U^s=%6.3f\n", qi, Uc, Us)
    end
end

println("\nDone.")
