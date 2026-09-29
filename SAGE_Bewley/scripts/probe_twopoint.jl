# Two patience groups in the two-asset model: can a patient majority hold the
# German and Italian median net wealth while an impatient minority gives the poor
# hand-to-mouth? G+A, one-asset effort scale, fixed cost 0.01, low group at
# effective patience 0.85.
#
#   SAGE_WORKERS=4 julia --project=scripts/run_env scripts/probe_twopoint.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
qmed(x, cm) = (k = findfirst(>=(0.5 * cm[end]), cm); x[k])
prem = Dict("DE" => 0.0216, "IT" => 0.0215); nwt = Dict("DE" => 2.38, "IT" => 5.51)
for (code, bh, pi) in (("DE", 0.985, 0.08), ("DE", 0.995, 0.08), ("IT", 0.99, 0.10), ("IT", 0.995, 0.10))
    c = country_config(code; config = "GA", S = false, A = true)
    surv = 1 - 1 / 45
    cl = SAGEConfig(c; illiquid = true, illiquid_premium = prem[code], chi0 = 0.01, beta_bar = bh / surv,
                    impatient_share = pi, beta_low = 0.85 / surv)
    t = @elapsed r = _solve(cl, nothing; disk = false)
    @printf("%s patient %.3f, impatient share %.2f (%.1f min): net wealth/income %.2f (target %.2f) | poor htm %.3f wealthy %.3f | effort %.4f | MPC %.3f | drop %.3f | liquid/income %.3f\n",
            code, bh, pi, t / 60, qmed(NWGRID, r.Ntot) / r.median_income, nwt[code], r.hand_to_mouth_kvw, r.wealthy_htm,
            r.mean_effort_employed, r.mpc, r.consumption_drop, qmed(r.agrid, r.Wtot) / r.median_income)
    flush(stdout)
end
println("DONE")
