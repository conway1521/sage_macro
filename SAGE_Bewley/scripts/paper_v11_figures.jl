# All numbers and figures for the v1.1 rewrite of the S paper, in one script,
# so the text and the code cannot drift apart. Prints every value the paper
# quotes and writes the three figures into ../paper/figures/.
#   julia --project=. scripts/paper_v11_figures.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf, Statistics
ENV["GKSwstype"] = "100"
using Plots
gr()

const FIGDIR = joinpath(@__DIR__, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const ORANGE = RGB(0.86, 0.49, 0.13)
const GREEN = RGB(0.18, 0.55, 0.34); const PURPLE = RGB(0.46, 0.28, 0.64)

# ---------- 1. Policy experiment, v1.1, warmglow kappa = 1 ------------------
function solve_financed(p; subsidy = 0.0, tol = 1e-5, maxit = 40)
    z_vals, _ = SAGEBewley.income_process(p)
    T = 0.0
    sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    for _ in 1:maxit
        paid = sum(sol.λ[ia, iz] * subsidy * p.α[iz] * sol.e[ia, iz] * z_vals[iz]
                   for iz in 1:p.nz, ia in 1:p.na)
        abs(paid - T) < tol && break
        T = 0.5 * T + 0.5 * paid
        sol = solve_model(update(p; subsidy = subsidy, lumptax = T))
    end
    sol
end

agg(s, M) = sum(s.λ .* M)
gmean(s, M, z) = sum(s.λ[:, z] .* M[:, z]) / sum(s.λ[:, z])

p = SAGEParams(social_mode = :warmglow, social_strength = 1.0)
base = solve_financed(p; subsidy = 0.0)
pol  = solve_financed(p; subsidy = 0.20)

println("=== POLICY TABLE (v1.1, warmglow kappa=1, 20% financed subsidy) ===")
@printf("consumption   base %.4f  pol %.4f  change %+.1f%%\n",
        agg(base, base.c), agg(pol, pol.c), 100*(agg(pol,pol.c)/agg(base,base.c)-1))
@printf("public good Q base %.4f  pol %.4f  change %+.1f%%\n",
        base.Q, pol.Q, 100*(pol.Q/base.Q-1))
@printf("material Uc   base %.4f  pol %.4f\n", agg(base, base.Uc), agg(pol, pol.Uc === nothing ? pol.Uc : pol.Uc))
flush(stdout)

# by group, for the decoupling figure
socialU(s, z) = p.Λ * p.B[z] * s.Q
ucb = [gmean(base, base.Uc, z) for z in 1:2]; ucp = [gmean(pol, pol.Uc, z) for z in 1:2]
usb = [socialU(base, z) for z in 1:2];        usp = [socialU(pol, z) for z in 1:2]
@printf("Uc by group  base [%.3f, %.3f]  pol [%.3f, %.3f]\n", ucb..., ucp...)
@printf("Us by group  base [%.4f, %.4f]  pol [%.4f, %.4f]\n", usb..., usp...)
flush(stdout)

groups = ["low income", "high income"]
plt = plot(layout = (1, 2), size = (900, 360), bottom_margin = 5Plots.mm)
bar!(plt[1], [1, 2] .- 0.17, ucb, bar_width = 0.3, c = BLUE,  label = "baseline",
     xticks = ([1, 2], groups), ylabel = "material gain (utils)", title = "Material dimension")
bar!(plt[1], [1, 2] .+ 0.17, ucp, bar_width = 0.3, c = ORANGE, label = "with subsidy")
bar!(plt[2], [1, 2] .- 0.17, usb, bar_width = 0.3, c = BLUE,  label = "baseline",
     xticks = ([1, 2], groups), ylabel = "social cohesion (utils)", title = "Social dimension")
bar!(plt[2], [1, 2] .+ 0.17, usp, bar_width = 0.3, c = ORANGE, label = "with subsidy")
savefig(plt, joinpath(FIGDIR, "v11_decoupling.png"))
println("fig v11_decoupling.png written"); flush(stdout)

# change version: percent change by group and dimension (the readable one)
duc = 100 .* (ucp .- ucb) ./ abs.(ucb)
dus = 100 .* (usp .- usb) ./ abs.(usb)
@printf("pct changes  Uc [%.2f, %.2f]  Us [%.2f, %.2f]\n", duc..., dus...)
pltd = plot(size = (640, 400), ylabel = "change under the subsidy (% of baseline)",
            xticks = ([1, 2], groups), legend = :bottomright)
hline!(pltd, [0], c = :black, lw = 1, label = "")
bar!(pltd, [1, 2] .- 0.17, duc, bar_width = 0.3, c = BLUE,  label = "material gain")
bar!(pltd, [1, 2] .+ 0.17, dus, bar_width = 0.3, c = ORANGE, label = "social cohesion")
savefig(pltd, joinpath(FIGDIR, "v11_decoupling_delta.png"))
println("fig v11_decoupling_delta.png written"); flush(stdout)

# ---------- 2. The no-fold contrast: honest vs rejected elasticity ----------
function sweep(ps, κs)
    lo = Float64[]; hi = Float64[]
    for κ in κs
        q = update(ps; social_mode = :multiplier, social_strength = κ)
        push!(lo, solve_model(q; A0 = 0.05).Q)
        push!(hi, solve_model(q; A0 = 0.98).Q)
        @printf("  sweep psi=%.2f kappa=%.2f lo=%.4f hi=%.4f\n", ps.ψ, κ, lo[end], hi[end])
        flush(stdout)
    end
    lo, hi
end

println("=== NO-FOLD SWEEP (v1.1, Frisch 0.5) ===")
κ_new = collect(1.0:1.0:12.0)
lo_new, hi_new = sweep(SAGEParams(), κ_new)

println("=== OLD-WORLD SWEEP (v1.0 params, Frisch 4, for the contrast panel) ===")
p_old = SAGEParams(γ = 1.5, ψ = 0.25, ϕ = 1.0, β = 0.99, R = 1.01)
κ_old = collect(2.6:0.1:4.0)
lo_old, hi_old = sweep(p_old, κ_old)

plt2 = plot(layout = (1, 2), size = (950, 380), bottom_margin = 5Plots.mm)
plot!(plt2[1], κ_old, lo_old, lw = 2.5, c = GREEN, marker = :circle, ms = 3,
      label = "from low start", xlabel = "social-return strength", ylabel = "equilibrium cohesion Q*",
      title = "Frisch = 4 (rejected by evidence)", legend = :bottomright)
plot!(plt2[1], κ_old, hi_old, lw = 2.5, c = PURPLE, marker = :circle, ms = 3, label = "from high start")
plot!(plt2[2], κ_new, lo_new, lw = 2.5, c = GREEN, marker = :circle, ms = 3,
      label = "from low start", xlabel = "social-return strength",
      title = "Frisch = 0.5 (Chetty et al. 2011)", legend = :bottomright)
plot!(plt2[2], κ_new, hi_new, lw = 2.5, c = PURPLE, marker = :circle, ms = 3, label = "from high start")
savefig(plt2, joinpath(FIGDIR, "v11_nofold.png"))
println("fig v11_nofold.png written"); flush(stdout)

# ---------- 3. Homophily: segregation of group cohesion ---------------------
println("=== HOMOPHILY SWEEP (kappa = 8) ===")
hs = 0.0:0.25:1.0
gl = Float64[]; gh = Float64[]
for h in hs
    s = solve_model(SAGEParams(social_mode = :multiplier, social_strength = 8.0, homophily = h))
    gm = group_means(s)
    push!(gl, gm[1]); push!(gh, gm[2])
    @printf("  h=%.2f  Qmean=[%.4f, %.4f]\n", h, gm[1], gm[2])
    flush(stdout)
end
plt3 = plot(size = (640, 400), xlabel = "homophily h (0 bridging, 1 bonding)",
            ylabel = "group mean contribution", legend = :right)
plot!(plt3, collect(hs), gl, lw = 2.5, c = BLUE, marker = :circle, label = "lower education group")
plot!(plt3, collect(hs), gh, lw = 2.5, c = ORANGE, marker = :circle, label = "higher education group")
savefig(plt3, joinpath(FIGDIR, "v11_homophily.png"))
println("fig v11_homophily.png written")
println("ALL DONE")
