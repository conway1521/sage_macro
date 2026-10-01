# The MPC against the wealth effect on effort (France G by default): for each
# inverse Frisch elasticity psi, the effort scale phi is refitted to the effort
# target (secant), at two hand-to-mouth settings (impatient share at effective
# patience 0.70). Tests the cap psi / (psi + gamma) on a constrained household.
#
#   julia --project=scripts/run_env scripts/probe_mpc_psi.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
c0 = country_config(code; config = "G", S = false, A = false)
target = parse(Float64, country_rows()[code]["effort_target"])
function fit(c)
    # effort is close to log-linear in phi with slope -1 / (psi + gamma)
    lp = log(c.phi); r = nothing
    for _ in 1:5
        r = solve_economy(SAGEConfig(c; phi = exp(lp)); cache = false)
        abs(r.mean_effort_employed - target) < 5e-4 && break
        lp += (c.psi + 2.0) * log(r.mean_effort_employed / target)
    end
    (r, exp(lp))
end
for psi in (2.0, 4.0, 8.0, 16.0), sh in (0.0, 0.20)
    c = SAGEConfig(c0; psi = psi, beta_spread = sh == 0 ? c0.beta_spread : 0.0, impatient_share = sh, beta_low = sh == 0 ? 0.0 : 0.70)
    r, phi = fit(c)
    @printf("psi %4.1f (Frisch %.2f, cap %.2f) %-18s phi %8.2f effort %.4f | htm %.3f | MPC %.3f (of the htm %.3f) | saving %.3f | earnings %+.3f | consumption drop on job loss %.3f\n",
            psi, 1 / psi, psi / (psi + 2), sh == 0 ? "calibrated spread" : "impatient 0.20", phi, r.mean_effort_employed, r.hand_to_mouth_kvw, r.mpc, r.mpc_htm, r.mps, r.mpe, r.consumption_drop)
    flush(stdout)
end
println("DONE")
