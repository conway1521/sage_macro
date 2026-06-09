# Visual sanity check: reproduce the shapes of thesis Figures 2 (policy rules)
# and 4 (wealth distribution). Saves PNGs to SAGE_Bewley/figures/.
#
#   julia --project=. scripts/plots.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Plots
gr(fmt = :png)

p = SAGEParams()
sol = solve_model(p)
a = sol.a_grid

lo = 1; hi = 2
clo, chi = "#1f77b4", "#ff7f0e"   # blue = low income, orange = high (thesis convention)

# ---- Figure 2: policy rules (c, e, q, a') -----------------------------------
pc = plot(a, sol.c[:,lo], label="low", color=clo, lw=2, title="Consumption  c(a,z)",
          xlabel="assets a", legend=:bottomright)
plot!(pc, a, sol.c[:,hi], label="high", color=chi, lw=2)

pe = plot(a, sol.e[:,lo], label="low", color=clo, lw=2, title="Effort  e(a,z)",
          xlabel="assets a", legend=:topright)
plot!(pe, a, sol.e[:,hi], label="high", color=chi, lw=2)

pq = plot(a, sol.q[:,lo], label="low", color=clo, lw=2, title="Social contribution  q=1-e",
          xlabel="assets a", legend=:bottomright)
plot!(pq, a, sol.q[:,hi], label="high", color=chi, lw=2)

pa = plot(a, sol.a_next[:,lo], label="low", color=clo, lw=2, title="Next assets  a'(a,z)",
          xlabel="assets a", legend=:bottomright)
plot!(pa, a, sol.a_next[:,hi], label="high", color=chi, lw=2)
plot!(pa, a, a, label="45°", color=:black, ls=:dash, lw=1)

fig2 = plot(pc, pe, pq, pa, layout=(2,2), size=(900,650))
mkpath(joinpath(@__DIR__, "..", "figures"))
savefig(fig2, joinpath(@__DIR__, "..", "figures", "fig2_policies.png"))

# ---- Figure 4: wealth distribution ------------------------------------------
# focus on the low-wealth region where the action is
imax = findfirst(>(20.0), a); imax === nothing && (imax = length(a))
fig4 = plot(a[1:imax], sol.λ[1:imax,lo], label="low", color=clo, lw=2,
            title="Stationary wealth distribution", xlabel="assets a", ylabel="mass")
plot!(fig4, a[1:imax], sol.λ[1:imax,hi], label="high", color=chi, lw=2)
savefig(fig4, joinpath(@__DIR__, "..", "figures", "fig4_distribution.png"))

println("Saved figures/fig2_policies.png and figures/fig4_distribution.png")
println("Q=", round(sol.Q, digits=4),
        "  Gini=", round(SAGEBewley.wealth_gini(sol), digits=4),
        "  %constrained=", round(100SAGEBewley.frac_constrained(sol), digits=2))
