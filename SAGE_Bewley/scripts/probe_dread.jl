# Agency version 2, Gate 3: does dread behave? France G+A at its current
# calibrated parameters and the audited inputs, with and without dread; and the
# reduction when agency is off. A short run.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/probe_dread.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))

base = country_config("FR"; config = "GA", S = false, A = true)
show(r, nm) = say(@sprintf("%-26s effort %.4f  poor htm %.4f  room %.4f  mpc %.3f (htm %.3f)  A %.4f  A_cond %.4f  drop %.4f  dread cost (employed) %.4f",
                           nm, r.mean_effort_employed, r.hand_to_mouth_kvw, r.room, r.mpc, r.mpc_htm, r.A, r.A_cond,
                           r.consumption_drop, r.dread_cost_E))
for d in (0.0, 1.0, 1.5, 2.45)
    show(solve_economy(SAGEConfig(base; dread = d)), @sprintf("G+A, dread %.2f", d))
end
# reduction: with agency off, dread must do nothing
g0 = solve_economy(SAGEConfig(base; A = false, dread = 0.0))
g1 = solve_economy(SAGEConfig(base; A = false, dread = 1.5))
gap = maximum(abs(getfield(g0, f) - getfield(g1, f)) for f in (:mean_effort_employed, :hand_to_mouth_kvw, :A, :mpc, :room))
say(@sprintf("reduction, agency off: dread 1.5 against 0, largest gap %.1e  %s", gap, gap == 0 ? "EXACT" : "FAILED"))
# wealth distribution check: mass near the top of the grid
r = solve_economy(SAGEConfig(base; dread = 1.5))
say(@sprintf("wealth p90 %.3f against a_max %.1f", r.wealth_p90, base.a_max))
say("DONE")
