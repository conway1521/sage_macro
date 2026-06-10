# Confirmation run for the group-level bistability claim: kappa = 20, h = 1,
# tighter tolerance and more iterations, starting from each of the two
# candidate attractors for the low group. If both runs hold their gap, the
# bistability is a property of the model, not of loose convergence.
#   julia --project=. scripts/v2_homophily_confirm.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

p = SAGEParams(social_mode = :multiplier, social_strength = 20.0, homophily = 1.0)
for (tag, A0) in (("low start ", [0.05, 0.95]), ("high start", [0.95, 0.95]))
    s = solve_model(p; A0 = A0, tol = 1e-7, maxit = 400, damp = 0.5)
    gm = group_means(s)
    @printf("%s -> Qmean = [%.6f, %.6f]\n", tag, gm[1], gm[2])
    flush(stdout)
end
println("DONE")
