# The quarterly probe (V3_START.md section 103): how much of the fall in consumption on job loss, and of the
# MPC, is the length of the model's period? Each country's calibrated G is solved twice, nothing refitted,
# both without the state out of work (which an annual period holds as one year and a quarterly one cannot
# yet): once as calibrated, once with every rate converted to a quarter.
#
# The conversion (a stated normalisation, not a calibration):
#   - job finding: the chance of not finding work in four quarters equals the year's, f_q = 1 - (1 - f)^(1/4);
#     job loss by education then keeps each group's unemployment rate, delta_q = u f_q / (1 - u);
#   - patience and the return: beta_q = beta^(1/4) for each group, R_q = R^(1/4);
#   - persistent income: rho_q = rho^(1/4) with the same unconditional variance; the transitory part with
#     four times the variance per quarter, so that a year's average carries the year's;
#   - income keeps its normalisation per period, so hours, the floor (a share of the period's median) and
#     the benefits are unchanged; the asset grid's top is four times higher, in periods of income.
# Reported in comparable units: the fall over a first period out of work (a year, or a quarter, which is the
# horizon of the studies); the MPC out of a windfall over the period; liquid wealth below one week of mean
# annual income; median liquid wealth over annual income.
#
#   julia --project=scripts/run_env scripts/probe_quarterly.jl [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
codes = isempty(ARGS) ? ["FR", "DE", "IT"] : uppercase.(ARGS)
for code in codes
    c = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
    ca = SAGEConfig(c; f_long = (NaN, NaN))
    u = ntuple(g -> ca.delta[g] / (ca.delta[g] + ca.f_find), 2)
    fq = 1 - (1 - ca.f_find)^(1 / 4)
    dq = ntuple(g -> u[g] * fq / (1 - u[g]), 2)
    bq = ca.beta_bar^(1 / 4)
    dbq = ntuple(g -> (ca.beta_bar + ca.beta_cell[g])^(1 / 4) - bq, 2)
    rq = ntuple(g -> ca.rho_cell[g]^(1 / 4), 2)
    eq = ntuple(g -> ca.eta_cell[g] * sqrt((1 - rq[g]^2) / (1 - ca.rho_cell[g]^2)), 2)
    sq = ntuple(g -> 2 * ca.sd_eps_cell[g], 2)
    Rq = isnan(ca.R_one) ? NaN : ca.R_one^(1 / 4)
    cq = SAGEConfig(ca; f_find = fq, delta = dq, beta_bar = bq, beta_cell = dbq, rho_cell = rq, eta_cell = eq, sd_eps_cell = sq,
                    R_one = Rq, a_max = 4 * ca.a_max, na = 300)
    @printf("\n%s G, without the state out of work | annual: find %.3f, loss %.4f %.4f, beta %.4f, R %.4f | quarterly: find %.3f, loss %.4f %.4f, beta %.5f, R %.5f\n",
            code, ca.f_find, ca.delta..., ca.beta_bar, ca.R_one, fq, dq..., bq, Rq)
    @printf("  %-10s %8s %8s %10s %10s %10s %10s\n", "period", "fall", "MPC", "htm, week", "median/y", "out", "engine htm")
    for (lab, cv, k) in (("annual", ca, 1), ("quarterly", cq, 4))
        t = @elapsed r = try
            solve_economy(cv; cache = false)
        catch err
            @printf("  %-10s no solution: %s\n", lab, first(replace(sprint(showerror, err), "\n" => " "), 160)); nothing
        end
        r === nothing && continue
        yann = k * r.mean_income                       # mean income over a year
        htmw = share_below_interp(r.agrid, r.Wtot, yann / 52)
        @printf("  %-10s %8.4f %8.4f %10.4f %10.4f %10.4f %10.4f  [%.1f min]\n", lab, r.consumption_drop, r.mpc, htmw,
                r.wealth_p50 / (k * r.median_income), r.unemployment, r.hand_to_mouth_kvw, t / 60)
        flush(stdout)
    end
end
println("DONE")
