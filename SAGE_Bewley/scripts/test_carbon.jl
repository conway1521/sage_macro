# The carbon tax and the valuation of its emissions change, one country.
#  1. A zero tax reproduces the baseline exactly.
#  2. A tax of EUR 100 per tonne, recycled lump-sum: emissions, welfare, and the
#     emissions change valued at each official carbon value.
#
#   julia --project=scripts/run_env scripts/test_carbon.jl [CODE] [CONFIG] [EUR]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
cfg = length(ARGS) >= 2 ? uppercase(ARGS[2]) : "GA"
eur = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 100.0
c = country_config(code; config = cfg, S = occursin('S', cfg), A = occursin('A', cfg))
rB = solve_economy(c)
thr = [(rB.ypov, rB.abar)]
z = carbon_tax_economy(c, 0.0; code = code, thresholds = thr)
@printf("1. zero tax: participation gap %.1e, consumption gap %.1e, welfare %.1e\n",
        abs(z.economy.rate - rB.rate), abs(z.economy.consumption - rB.consumption), welfare_ce(rB, z.economy).total)
x = carbon_tax_economy(c, eur; code = code, thresholds = thr)
rP = x.economy
eB, eP = emissions(rB; code = code), emissions(rP; code = code, rB = rB)
w = welfare_ce(rB, rP)
@printf("2. %s %s, EUR %.0f per tonne: tax %.2f%% of consumption, recycled %.4f\n", code, cfg, eur, 100 * x.rate, x.recycled)
@printf("   emissions %.3f -> %.3f t per head (%+.2f%%); cells %s\n", eB.total, eP.total, 100 * (eP.total / eB.total - 1),
        join((@sprintf("%+.2f%%", 100 * (b / a - 1)) for (a, b) in zip(eB.cells, eP.cells)), ", "))
@printf("   welfare %+.3f%% of consumption (cells %s); hardship %+.4f; participation %+.4f\n", 100 * w.total,
        join((@sprintf("%+.3f%%", 100 * v) for v in w.cells), ", "), rP.hardship - rB.hardship, rP.rate - rB.rate)
for key in ("uba_central", "uba_equal", "quinet_2030", "quinet_2050", "eib_2030", "eib_2050", "epa_central")
    v = carbon_value(rB, rP; code = code, key = key)
    @printf("   valued at %-12s (%s, %s %s): %+8.2f per head, %+.3f%% of consumption\n", key, v.kind, v.currency, v.price_year, v.eur, 100 * v.share)
end
println("DONE")
