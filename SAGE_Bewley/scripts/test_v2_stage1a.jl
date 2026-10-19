# Stage 1a tests (V2_BUILD_PLAN.md).
# 1. EXACTNESS: the labour chain at an annual period with one period of first spell (`chain = true`) is version 1's
#    model in another representation: G and G+A (dread, search) in three countries, at version 1's job effort
#    levels, must give version 1's moments to 1e-10 (taxes from the chain's numerical masses included).
# 2. THE QUARTER: G converted to a quarter (`quarterly_config`, nothing refitted) against the annual G, in units that
#    compare: hand-to-mouth (a week of income), median liquid wealth over a year's income, the MPC out of a month's
#    income within the period, the fall on entering unemployment (over a first year, against over a first quarter),
#    the share out of work, and the budget.
#
#   julia --project=scripts/run_env scripts/test_v2_stage1a.jl [exact|quarter|both] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
what = length(ARGS) >= 1 ? ARGS[1] : "both"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
say(x...) = (println(x...); flush(stdout))
KEYS = (:hand_to_mouth_kvw, :wealth_p50, :median_income, :mpc, :consumption_drop, :unemployment, :mean_effort_employed, :budget_gap)
if what in ("exact", "both")
    worst = 0.0
    for code in codes, (cfg, A_) in (("G", false), ("GA", true))
        c1 = floor_effort(country_config(code; config = cfg, v3 = :v5m, S = false, A = A_))
        r1 = solve_economy(c1; cache = false)
        r2 = solve_economy(SAGEConfig(c1; chain = true); cache = false)
        for k in KEYS
            a = getfield(r1, k); b = getfield(r2, k)
            d = abs(a) < 1e-9 ? abs(a - b) / 1e-2 : abs(a - b) / abs(a)          # budget gaps: both at machine precision
            global worst = max(worst, d)
            d > 1e-10 && say(@sprintf("   %s %s %s: %.15g against %.15g", code, cfg, k, b, a))
        end
        say(@sprintf("%s %s: chain against version 1 done (ui tax %.12f against %.12f)", code, cfg, ui_tax_of(SAGEConfig(c1; chain = true)), ui_tax_of(c1)))
    end
    say(@sprintf("EXACTNESS: largest relative difference %.2e -> %s", worst, worst < 1e-10 ? "PASS" : "FAIL"))
end
if what in ("quarter", "both")
    say("\nTHE QUARTER (G, nothing refitted): annual against quarterly")
    say(@sprintf("  %-4s %-9s %8s %8s %8s %8s %8s %10s %8s", "", "period", "htm", "med/yr", "MPC", "fall", "out", "budget", "minutes"))
    for code in codes
        ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
        cq = quarterly_config(ca)
        say(@sprintf("  %s quarterly: find %.4f, exits from L %.4f %.4f, loss %.5f %.5f, beta %.5f, R %.5f, rho %.4f %.4f, s_eta %.4f %.4f, s_eps %.4f %.4f",
                     code, cq.f_find, cq.f_long..., cq.delta..., cq.beta_bar, cq.R_one, cq.rho_cell..., cq.eta_cell..., cq.sd_eps_cell...))
        for (lab, c, k) in (("annual", ca, 1), ("quarterly", cq, 4))
            t = @elapsed r = solve_economy(c; cache = false)
            say(@sprintf("  %-4s %-9s %8.4f %8.4f %8.4f %8.4f %8.4f %10.1e %8.1f", code, lab, r.hand_to_mouth_kvw, r.wealth_p50 / (k * r.median_income),
                         r.mpc, r.consumption_drop, r.unemployment, r.budget_gap, t / 60))
        end
    end
end
println("DONE")
