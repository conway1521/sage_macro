# The liquid-wealth calibration of the one-asset model: how median liquid wealth,
# the hand-to-mouth share and the (untargeted) MPC move together as mean patience
# falls, with and without an impatient group. Effort set by the job; phi is
# refitted to the effort target at each point (effort is log-linear in phi).
# HFCS 2021 targets printed for the country.
#
#   julia --project=scripts/run_env scripts/probe_liquid_calibration.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
DATA = Dict("FR" => (liq = 0.059, liqb = 0.380, htm = 0.222, htmb = 0.114, mpc = 0.392),
            "DE" => (liq = 0.140, liqb = 0.442, htm = 0.225, htmb = 0.146, mpc = 0.468),
            "IT" => (liq = 0.272, liqb = 0.316, htm = 0.179, htmb = 0.141, mpc = 0.469))[code]
E = parse(Float64, country_rows()[code]["effort_target"])
base = SAGEConfig(country_config(code; config = "G", S = false, A = false); effort_mode = :job, beta_spread = 0.0)
function fit(c)
    lp = log(c.phi); r = nothing
    for _ in 1:4
        r = solve_economy(SAGEConfig(c; phi = exp(lp)); cache = false)
        abs(r.mean_effort_employed - E) < 5e-4 && break
        lp += (c.psi + 2.0) * log(r.mean_effort_employed / E)
    end
    (r, exp(lp))
end
@printf("%s, HFCS 2021: median liquid wealth / after-tax income %.3f narrow (%.3f broad); hand-to-mouth, one-week rule %.3f narrow (%.3f broad); self-reported MPC %.3f\n",
        code, DATA.liq, DATA.liqb, DATA.htm, DATA.htmb, DATA.mpc)
@printf("%9s %7s %9s | %8s %10s %7s %7s %9s %9s %9s %10s\n", "beta_bar", "share", "beta_low", "phi", "liq/inc", "htm", "MPC", "MPC htm", "MPC rest", "job drop", "p90/inc")
for (bb, sh, bl) in ((0.96, 0.0, 0.0), (0.95, 0.0, 0.0), (0.94, 0.0, 0.0), (0.93, 0.0, 0.0), (0.92, 0.0, 0.0), (0.91, 0.0, 0.0), (0.90, 0.0, 0.0), (0.88, 0.0, 0.0),
                     (0.95, 0.10, 0.85), (0.94, 0.10, 0.85), (0.96, 0.15, 0.85))
    c = sh == 0 ? SAGEConfig(base; beta_bar = bb) : SAGEConfig(base; beta_bar = bb, impatient_share = sh, beta_low = bl)
    r, ph = fit(c)
    h = r.hand_to_mouth_kvw
    rest = h < 1 ? (r.mpc - h * r.mpc_htm) / (1 - h) : NaN
    @printf("%9.3f %7.2f %9.2f | %8.3f %10.4f %7.3f %7.3f %9.3f %9.3f %9.3f %10.3f\n", bb, sh, bl, ph, r.wealth_p50 / r.median_income, h, r.mpc, r.mpc_htm, rest,
            r.consumption_drop, r.wealth_p90 / r.median_income)
    flush(stdout)
end
println("DONE")
