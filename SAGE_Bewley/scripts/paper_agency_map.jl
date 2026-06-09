# The clinching figure: the public-good map under unequal vs equal agency.
# Unequal agency gives the S-shape (three crossings, bistable); equal agency is
# single-crossing. Agency inequality is what makes cohesion a coordination problem.
const ROOT = "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley"
include(joinpath(ROOT, "src", "SAGEBewley.jl"))
using .SAGEBewley, Plots, Printf
gr(fmt = :png, size = (820, 340))
BLUE, ORANGE = "#1f77b4", "#ff7f0e"
p0 = SAGEParams(); am = (p0.α[1] + p0.α[2]) / 2
κ = 3.3
G(p, Q) = solve_model(update(p; social_mode = :multiplier, social_strength = κ); A0 = Q, maxit = 1).Q
Qs = collect(0.30:0.02:0.99)

uneq = [G(p0, Q) for Q in Qs]
eq   = [G(update(p0; α = [am, am]), Q) for Q in Qs]

p1 = plot(Qs, uneq, lw = 2.5, c = ORANGE, label = "G(Q)", legend = :topleft,
          title = "Unequal agency", xlabel = "public good Q", ylabel = "G(Q)")
plot!(p1, Qs, Qs, c = :black, ls = :dash, lw = 1, label = "45 degrees")
p2 = plot(Qs, eq, lw = 2.5, c = BLUE, label = "G(Q)", legend = :topleft,
          title = "Equal agency", xlabel = "public good Q")
plot!(p2, Qs, Qs, c = :black, ls = :dash, lw = 1, label = "45 degrees")
fig = plot(p1, p2, layout = (1, 2))
savefig(fig, joinpath(ROOT, "figures", "paper1_agency_map.png"))
cross(v) = sum(sign(v[i]-Qs[i]) != sign(v[i+1]-Qs[i+1]) for i in 1:length(v)-1)
@printf("crossings: unequal=%d  equal=%d\n", cross(uneq), cross(eq))
println("DONE")
