# The carbon tax on two assets (the consumption price in egm2_core.jl).
#  1. the illiquid asset inert, with a consumption tax: every result equals the
#     one-asset economy with the same tax;
#  2. France G+A on two assets, EUR 100 per tonne recycled lump-sum: emissions,
#     welfare, the adding-up of the propensities, and the valuation.
#
#   julia --project=scripts/run_env scripts/test_carbon2.jl [CODE] [EUR]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
eur = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 100.0
c1 = country_config(code; config = "GA", S = false, A = true)
t = eur * footprint_intensity(code) / 1000
inert(c) = SAGEConfig(c; illiquid = true, chi0 = 1e10, death = 0.0, b_max = c.a_max, nb = c.na, nk = 4, k_max = 5.0)
r1 = solve_economy(SAGEConfig(c1; ctax = t); cache = false); ri = solve_economy(inert(SAGEConfig(c1; ctax = t)); cache = false)
F = (:rate, :hardship, :A, :mean_effort_employed, :consumption, :mpc, :mps, :mpe, :mpp, :wealthy_htm)
worst = maximum(abs(getfield(r1, f) - getfield(ri, f)) for f in F)
gw = maximum(abs.([r1.welfare.V - ri.welfare.V, r1.welfare.Vc - ri.welfare.Vc]))
@printf("1. tax %.2f%%, inert illiquid against one asset: largest gap %.1e (results), %.1e (welfare)\n", 100 * t, worst, gw)
flush(stdout)
c = country_config(code; config = "GA", S = false, A = true, illiquid = true)
rB = solve_economy(c; cache = false)
x = carbon_tax_economy(c, eur; code = code, thresholds = [(rB.ypov, rB.abar)])
rP = x.economy
eB, eP = emissions(rB; code = code), emissions(rP; code = code, rB = rB)
w = welfare_ce(rB, rP); v = carbon_value(rB, rP; code = code)
@printf("2. %s G+A two assets, EUR %.0f: emissions %.3f -> %.3f (%+.2f%%); welfare %+.3f%% (cells %+.3f%%, %+.3f%%); hardship %+.4f\n",
        code, eur, eB.total, eP.total, 100 * (eP.total / eB.total - 1), 100 * w.total, 100 * w.cells[1], 100 * w.cells[2], rP.hardship - rB.hardship)
@printf("   adding-up under the tax: MPC %.4f + saving %.4f - earnings %.4f = %.6f\n", rP.mpc, rP.mps, rP.mpe, rP.mpc + rP.mps - rP.mpe)
@printf("   valued at uba_central: %+.2f EUR per head, %+.3f%% of consumption\n", v.eur, 100 * v.share)
println("DONE")
