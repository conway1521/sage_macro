# The illiquid asset at the level of the economy: the reduction (adjustment
# unaffordable, no death, the one-asset liquid grid: every result must equal
# the one-asset economy's), then a first live look. France G+A (no social
# families, so it is quick).
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/test_two_asset_economy.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf

c = country_config("FR"; config = "GA", S = false, A = true)
FIELDS = (:rate, :A, :A_cond, :hardship, :hand_to_mouth_kvw, :wealthy_htm, :mpc, :mpc_htm, :consumption_drop,
          :shock_loss, :shock_loss_income, :room, :dread_cost_E, :mean_effort_employed, :median_income, :mean_income)
t = @elapsed r1 = solve_economy(c; cache = false)
@printf("one asset: %.1f s\n", t)
c0 = SAGEConfig(c; illiquid = true, chi0 = 1e10, death = 0.0, b_max = c.a_max, nb = c.na, nk = 4, k_max = 5.0)
t = @elapsed r2 = solve_economy(c0; cache = false)
@printf("two assets, inert: %.1f s\n", t)
worst = 0.0
for f in FIELDS
    x, y = getfield(r1, f), getfield(r2, f)
    global worst = max(worst, abs(x - y))
    @printf("  %-22s %.10f  %.10f  %.1e\n", f, x, y, abs(x - y))
end
@printf("REDUCTION largest difference %.1e: %s\n", worst, worst < 1e-8 ? "pass" : "FAIL")
flush(stdout)

prem = parse(Float64, "0.0354")
for chi in (0.02, 0.05)
    cl = SAGEConfig(c; illiquid = true, illiquid_premium = prem, chi0 = chi)
    t = @elapsed r = solve_economy(cl; cache = false)
    med(x, cm) = x[findfirst(>=(0.5 * cm[end]), cm)]
    @printf("\nlive, chi0 %.2f (%.1f min): poor htm %.4f wealthy htm %.4f | MPC %.3f (poor htm %.3f, wealthy %.3f) | drop %.3f | protection %.4f | room %.3f | hardship %.4f | median liquid / mean income %.3f, illiquid %.3f | effort %.4f\n",
            chi, t / 60, r.hand_to_mouth_kvw, r.wealthy_htm, r.mpc, r.mpc_htm, r.mpc_wealthy, r.consumption_drop, r.A_cond,
            r.room, r.hardship, med(r.agrid, r.Wtot) / r.mean_income, med(r.kgrid, r.Ktot) / r.mean_income, r.mean_effort_employed)
    flush(stdout)
end
println("DONE")
