# v1.1 validation battery B: re-locate the multiplier bistable window under the
# literature-disciplined parameters (gamma=2, psi=2, phi=1.861), heterogeneous
# agency. Two-start detection as in social_cohesion.jl. Coarse sweep then
# refinement around any bistable region.
#   julia --project=. scripts/v11_battery_window.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

function twostart(κ)
    p = SAGEParams(social_mode = :multiplier, social_strength = κ)
    lo = solve_model(p; A0 = 0.05).Q
    hi = solve_model(p; A0 = 0.98).Q
    return lo, hi
end

println("--- coarse kappa sweep (hetero agency, v1.1 params) ---")
println("  kappa    Q_low    Q_high   bistable")
hits = Float64[]
for κ in 1.0:1.0:12.0
    lo, hi = twostart(κ)
    b = abs(hi - lo) > 0.02
    b && push!(hits, κ)
    @printf("  %5.1f  %7.4f  %7.4f   %s\n", κ, lo, hi, b ? "YES" : "no")
    flush(stdout)
end

if isempty(hits)
    println("no bistable kappa found in [1,12] at step 1.0; refining near the largest jump")
    # refine where Q_low jumps most between consecutive kappas
    println("--- fine sweep 0.1 steps over [2.0, 8.0] Q_low only ---")
    for κ in 2.0:0.25:8.0
        lo, hi = twostart(κ)
        b = abs(hi - lo) > 0.02
        @printf("  %5.2f  %7.4f  %7.4f   %s\n", κ, lo, hi, b ? "YES" : "no")
        flush(stdout)
        b && break
    end
else
    κ0 = hits[1]
    println("--- refining around first hit $κ0 ---")
    for κ in (κ0 - 0.8):0.2:(κ0 + 0.8)
        lo, hi = twostart(κ)
        @printf("  %5.2f  %7.4f  %7.4f   %s\n", κ, lo, hi,
                abs(hi - lo) > 0.02 ? "YES" : "no")
        flush(stdout)
    end
end
println("DONE")
