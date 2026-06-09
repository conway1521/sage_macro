# Paper 1 figures: the social-cohesion tipping result.
#   1. paper1_map.png          the public-good map G(A) with multiple fixed points
#   2. paper1_bifurcation.png  equilibrium cohesion vs the social-return strength
#   3. paper1_who.png          who supplies cohesion in the low vs high equilibrium
#   julia --project=. scripts/paper1_figures.jl

const ROOT = "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley"
include(joinpath(ROOT, "src", "SAGEBewley.jl"))
using .SAGEBewley, Plots, Printf, Statistics
gr(fmt = :png, size = (760, 330))
BLUE, ORANGE, GREEN, PURPLE = "#1f77b4", "#ff7f0e", "#2ca02c", "#9467bd"
mkpath(joinpath(ROOT, "figures"))
p = SAGEParams()

mult(κ) = update(p; social_mode = :multiplier, social_strength = κ)
Gmap(κ, A) = solve_model(mult(κ); A0 = A, maxit = 1).Q          # one household solve given A
Aeq(κ, A0) = solve_model(mult(κ); A0 = A0, tol = 2e-3, maxit = 50).Q   # equilibrium from a start

# ---- Figure 1: the public-good map at a bistable social return ----------
κb = 3.3
Ag = range(0.02, 0.99, length = 26)
G  = [Gmap(κb, A) for A in Ag]
Alo = Aeq(κb, 0.05); Ahi = Aeq(κb, 0.98)
fig1 = plot(Ag, G, lw = 2.5, c = BLUE, label = "G(A)",
            xlabel = "public good this period, A", ylabel = "public good next period, G(A)",
            title = "Public-good map at social return κ = $(κb)", legend = :topleft)
plot!(fig1, Ag, Ag, c = :black, ls = :dash, lw = 1, label = "45 degrees")
scatter!(fig1, [Alo, Ahi], [Alo, Ahi], c = [GREEN PURPLE], ms = 7,
         label = "stable equilibria")
savefig(fig1, joinpath(ROOT, "figures", "paper1_map.png"))
@printf("map done: stable equilibria at A = %.3f and %.3f\n", Alo, Ahi)

# ---- Figure 2: bifurcation diagram --------------------------------------
κs  = collect(1.0:0.25:4.5)
los = [Aeq(κ, 0.05) for κ in κs]
his = [Aeq(κ, 0.98) for κ in κs]
win = [κs[i] for i in eachindex(κs) if abs(los[i] - his[i]) > 0.02]
fig2 = plot(xlabel = "social-return strength κ", ylabel = "equilibrium public good A*",
            title = "Equilibrium cohesion vs the social return", legend = :bottomright)
if !isempty(win)
    vspan!(fig2, [minimum(win) - 0.12, maximum(win) + 0.12], c = :gray, alpha = 0.15, label = "bistable")
end
plot!(fig2, κs, los, lw = 2.5, c = GREEN, marker = :circle, ms = 3, label = "low-cohesion branch")
plot!(fig2, κs, his, lw = 2.5, c = PURPLE, marker = :circle, ms = 3, label = "high-cohesion branch")
savefig(fig2, joinpath(ROOT, "figures", "paper1_bifurcation.png"))
@printf("bifurcation done: bistable window κ in [%.2f, %.2f]\n",
        isempty(win) ? NaN : minimum(win), isempty(win) ? NaN : maximum(win))

# ---- Figure 3: who supplies cohesion in each equilibrium ----------------
slo = solve_model(mult(κb); A0 = 0.05, tol = 2e-3, maxit = 50)
shi = solve_model(mult(κb); A0 = 0.98, tol = 2e-3, maxit = 50)
meanq(s, z) = sum(s.λ[:, z] .* s.q[:, z]) / sum(s.λ[:, z])
lowc  = [meanq(slo, 1), meanq(slo, 2)]      # [low income, high income]
highc = [meanq(shi, 1), meanq(shi, 2)]
w = 0.36
fig3 = plot(title = "Mean contribution q by group, in each equilibrium",
            ylabel = "mean contribution q = 1 - e", legend = :topleft)
bar!(fig3, [1, 2] .- w/2, lowc,  bar_width = w, c = GREEN,  label = "low-cohesion equilibrium")
bar!(fig3, [1, 2] .+ w/2, highc, bar_width = w, c = PURPLE, label = "high-cohesion equilibrium")
plot!(fig3, xticks = ([1, 2], ["low income", "high income"]), size = (560, 330))
savefig(fig3, joinpath(ROOT, "figures", "paper1_who.png"))
@printf("who done: aggregate Q = %.3f (low eq) vs %.3f (high eq)\n", slo.Q, shi.Q)

println("DONE")
