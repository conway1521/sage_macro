# The group-by-place table (place_report): France at TL2, G+A parameters with E
# on, unemployment benefits 10% higher. Checks that the population-weighted
# place rows give back the national aggregates.
#
#   julia --project=scripts/run_env scripts/test_place_report.jl [CODE] [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GA"
c = SAGEConfig(country_config(code; config = cfg, S = occursin('S', cfg), A = occursin('A', cfg)); E = true)
t = @elapsed rB = solve_economy(c)
rP = solve_economy(SAGEConfig(c; rr = c.rr * 1.1); thresholds = [(rB.ypov, rB.abar)])
@printf("%s %s with E on, benefits +10%% (%.1f min for the baseline)\n", code, cfg, t / 60)
rows = place_report(rB, rP; code = code)
print_place_report(rows)
w = [r.weight for r in rows]
eB, eP = emissions(rB; code = code), emissions(rP; code = code, rB = rB)
@printf("checks: participation %.1e, emissions level %.1e, emissions change %.1e (weighted rows against national)\n",
        abs(sum(w .* [r.participation for r in rows]) - rB.rate), abs(sum(w .* [r.emissions for r in rows]) - eB.total),
        abs(sum(w .* [r.d_emissions for r in rows]) - (eP.total - eB.total)))
@printf("national welfare %+.3f%%\n", 100 * welfare_ce(rB, rP).total)
println("DONE")
