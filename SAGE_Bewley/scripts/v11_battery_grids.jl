# v1.1 validation battery A: grid convergence and sanity.
# Verifies that the headline aggregates are converged in the asset grid (na),
# the effort grid (ne), and that the asset-grid top is slack (beta-R knife edge
# harmless). Run on baseline (:off) and a behavioural mode (warmglow).
#   julia --project=. scripts/v11_battery_grids.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

function report(tag, p)
    s = solve_model(p)
    topmass = sum(s.λ[end-4:end, :])
    @printf("%-28s Q=%.4f e=%.4f wG=%.4f iG=%.4f HtM=%.4f top5=%.2e\n",
            tag, s.Q, sum(s.λ .* s.e), wealth_gini(s), income_gini(s),
            frac_constrained(s), topmass)
    flush(stdout)
end

println("--- baseline (:off), grid battery ---")
for na in (200, 300, 400), ne in (60, 120)
    report("na=$na ne=$ne", SAGEParams(na = na, ne = ne))
end

println("--- warmglow kappa=1, grid battery ---")
for na in (200, 300), ne in (60, 120)
    report("na=$na ne=$ne", SAGEParams(na = na, ne = ne,
           social_mode = :warmglow, social_strength = 1.0))
end

println("--- a_max stress (baseline): top of grid slack? ---")
for amax in (100.0, 150.0)
    report("a_max=$amax", SAGEParams(a_max = amax))
end

println("DONE")
