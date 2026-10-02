# How mean patience and the fixed cost move the two-asset moments: France G+A,
# the committed G+A effort scale and spread, the FR illiquid premium. Targets:
# median net wealth / median gross income 4.02 (HFCS 2021 Tables A1 and I1:
# 125.7 / 31.3), wealthy hand-to-mouth 0.173 and poor 0.032 (Kaplan, Violante
# and Weidner 2014 Table 5), median net liquid assets / gross income 0.249
# (HFCS 2021 Table F1).
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/probe_two_asset_map.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
c = country_config("FR"; config = "GA", S = false, A = true)
qmed(x, cm) = cdf_quantile(x, cm, 0.5)      # interpolated: the node above the median was up to 5% high, the width of the band (audit 2026-10-02)
for bb in (0.96, 0.975, 0.99), chi in (0.02, 0.1)
    cl = SAGEConfig(c; illiquid = true, illiquid_premium = 0.0354, chi0 = chi, beta_bar = bb)
    t = @elapsed r = solve_economy(cl; cache = false)
    nwm = qmed(NWGRID, r.Ntot); liq = qmed(r.agrid, r.Wtot)
    @printf("beta_bar %.3f chi0 %.2f (%.1f min): NW/median income %.2f | liquid/median income %.3f | poor htm %.3f wealthy %.3f | MPC %.3f | drop %.3f | effort %.4f | top of k grid %.1e\n",
            bb, chi, t / 60, nwm / r.median_income, liq / r.median_income, r.hand_to_mouth_kvw, r.wealthy_htm,
            r.mpc, r.consumption_drop, r.mean_effort_employed, r.Ktot[end] - r.Ktot[end-1])
    flush(stdout)
end
println("DONE")
