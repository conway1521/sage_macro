# Paper 1 figure 4: the policy-induced decoupling.
# By income group, the make-work-pay subsidy raises the material dimension
# (consumption) and lowers the social dimension (cohesion). The scissors.
#   julia --project=. scripts/paper1_policy_figure.jl

const ROOT = "/Users/ali/Desktop/UNI/Paris 8/extra_papers/SAGE/SAGE_Bewley"
include(joinpath(ROOT, "src", "SAGEBewley.jl"))
using .SAGEBewley, Plots, Printf, Statistics
gr(fmt = :png, size = (620, 360))
GREEN, PURPLE = "#2ca02c", "#9467bd"

function solve_financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z_vals, _ = SAGEBewley.income_process(p)
    T = 0.0; sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
        paid = 0.0
        for iz in 1:p.nz, ia in 1:p.na
            paid += sol.λ[ia, iz] * subsidy * p.α[iz] * sol.e[ia, iz] * z_vals[iz]
        end
        abs(paid - T) < tol && break
        T = 0.5 * T + 0.5 * paid
    end
    sol
end

p = SAGEParams(social_mode = :warmglow)
base = solve_financed(p; subsidy = 0.0)
pol  = solve_financed(p; subsidy = 0.20)

cmean(s, z) = sum(s.λ[:, z] .* s.c[:, z]) / sum(s.λ[:, z])
# material proxy = consumption; social dimension = Λ B Q
dC = [100*(cmean(pol, z)/cmean(base, z) - 1) for z in 1:2]            # by group
dS = fill(100*(pol.Q/base.Q - 1), 2)                                  # uniform (Us = ΛBQ)

w = 0.36
fig = plot(title = "Policy-induced decoupling (make-work-pay subsidy)",
           ylabel = "percent change", legend = :topright)
bar!(fig, [1, 2] .- w/2, dC, bar_width = w, c = GREEN,
     label = "material (consumption)")
bar!(fig, [1, 2] .+ w/2, dS, bar_width = w, c = PURPLE,
     label = "social cohesion")
hline!(fig, [0], c = :black, lw = 1, label = false)
plot!(fig, xticks = ([1, 2], ["low income", "high income"]))
savefig(fig, joinpath(ROOT, "figures", "paper1_decoupling.png"))
@printf("decoupling fig: material %+.1f%% / %+.1f%%, social %+.1f%% (both groups)\n",
        dC[1], dC[2], dS[1])
println("DONE")
