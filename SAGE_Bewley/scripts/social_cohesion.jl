# Paper 1 (S): behavioural social cohesion, via the engine's social_mode flag.
# Regression-checks that :off is unchanged, confirms the behavioural modes move
# effort, and maps the social-multiplier tipping boundary.
#   julia --project=. scripts/social_cohesion.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley, Printf, Statistics

mean_effort(s) = sum(s.λ .* s.e)

p = SAGEParams()

println("== regression: :off must match the canonical baseline ==")
s0 = solve_model(p)
@printf("  mean effort = %.4f (expect ~0.66)   Q = %.4f (expect ~0.34)\n",
        mean_effort(s0), s0.Q)

println("\n== :warmglow (effort should respond) ==")
sw = solve_model(update(p; social_mode = :warmglow))
@printf("  mean effort = %.4f   Q = %.4f   policy change vs off = %.4f\n",
        mean_effort(sw), sw.Q, sum(abs.(sw.e .- s0.e))/length(s0.e))

println("\n== :multiplier (outer fixed point must converge, no NaN) ==")
sm = solve_model(update(p; social_mode = :multiplier))
@printf("  mean effort = %.4f   Q = %.4f\n", mean_effort(sm), sm.Q)

println("\n== tipping map: A* from low vs high start, by social strength κ ==")
println("   κ      A*(low)   A*(high)   bistable?")
for κ in 1.0:0.5:6.0
    pκ = update(p; social_mode = :multiplier, social_strength = κ)
    Alo = solve_model(pκ; A0 = 0.05).Q
    Ahi = solve_model(pκ; A0 = 0.98).Q
    bist = abs(Alo - Ahi) > 0.02
    @printf("  %4.1f   %7.4f   %8.4f   %s\n", κ, Alo, Ahi, bist ? "YES" : "no")
end
println("\nDONE")
