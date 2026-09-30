# The group-by-place table (place_report): France at TL2, G+A parameters with E
# on, unemployment benefits 10% higher. Checks that the population-weighted
# place rows give back the national aggregates.
#
# A third argument I solves on two assets (item 5: does hardship by place still
# come out wrong-signed?), with the arop_rate by place printed beside it.
#
#   julia --project=scripts/run_env scripts/test_place_report.jl [CODE] [CONFIG] [I]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GA"
two = length(ARGS) >= 3 && uppercase(ARGS[3]) == "I"
c = SAGEConfig(country_config(code; config = cfg, S = occursin('S', cfg), A = occursin('A', cfg), illiquid = two); E = true)
t = @elapsed rB = solve_economy(c)
rP = solve_economy(SAGEConfig(c; rr = c.rr * 1.1); thresholds = [(rB.ypov, rB.abar)])
@printf("%s %s%s with E on, benefits +10%% (%.1f min for the baseline)\n", code, cfg, two ? " two assets" : "", t / 60)
rows = place_report(rB, rP; code = code)
print_place_report(rows)
w = [r.weight for r in rows]
eB, eP = emissions(rB; code = code), emissions(rP; code = code, rB = rB)
@printf("checks: participation %.1e, emissions level %.1e, emissions change %.1e (weighted rows against national)\n",
        abs(sum(w .* [r.participation for r in rows]) - rB.rate), abs(sum(w .* [r.emissions for r in rows]) - eB.total),
        abs(sum(w .* [r.d_emissions for r in rows]) - (eP.total - eB.total)))
@printf("national welfare %+.3f%%\n", 100 * welfare_ce(rB, rP).total)
# hardship by place against the official at-risk-of-poverty rate (validation only)
arop = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "place", "place_tl2.csv"))
    f = split(ln, ","); length(f) >= 5 && f[1] == "arop_rate" && f[2] == code && (arop[f[3]] = parse(Float64, f[5]))
end
ks = [r.place for r in rows if haskey(arop, r.place)]
if length(ks) >= 3
    h = [r.hardship for r in rows if haskey(arop, r.place)]; ar = [arop[k] for k in ks]
    @printf("hardship by place against the at-risk-of-poverty rate (%d places): correlation %+.2f\n", length(ks), cor(h, ar))
end
println("DONE")
