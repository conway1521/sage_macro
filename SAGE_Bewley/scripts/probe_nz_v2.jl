# Version 2 preparation (paper/sage_v2_design.md, section 2): the larger labour-state space of version 2 is paid
# for by fewer persistent income states, 7 Rouwenhorst states in place of 11. Before that is adopted, this
# shows what it costs on version 1's model: G and G+A (dread in choices, search) at 11 and 7 states, nothing
# refitted. At 7 states the published income process is purged of job loss again at that size, as
# country_config does at 11.
#
#   julia --project=scripts/run_env scripts/probe_nz_v2.jl CODE
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1])
say(x...) = (println(x...); flush(stdout))
say(@sprintf("%s | persistent income states 11 against 7, nothing refitted", code))
say(@sprintf("  %-6s %4s %8s %8s %8s %8s %8s %8s %8s %8s", "", "nz", "htm", "median", "MPC", "fall", "out", "hours", "chanceU", "minutes"))
pub(k) = manual_input(code, k)
for (lab, cfg, A_) in (("G", "G", false), ("G+A", "GA", true))
    c11 = country_config(code; config = cfg, v3 = :v5m, S = false, A = A_)
    ρ = (pub("rho_low"), pub("rho_high")); sη = sqrt.((pub("var_persistent_low"), pub("var_persistent_high")))
    sε = sqrt.((pub("var_transitory_low"), pub("var_transitory_high")))
    pr = ntuple(g -> purged_income_risk(7, c11.n_eps, ρ[g], sη[g], sε[g], c11.delta[g], c11.f_find, c11.f_long[g], c11.rr, c11.rr_long), 2)
    c7 = SAGEConfig(c11; nz = 7, eta_cell = (pr[1][1], pr[2][1]), sd_eps_cell = (pr[1][2], pr[2][2]))
    for (nz, c) in ((11, c11), (7, c7))
        t = @elapsed r = solve_economy(c; cache = false)
        say(@sprintf("  %-6s %4d %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %8.1f", lab, nz, r.hand_to_mouth_kvw, r.wealth_p50 / r.median_income,
                     r.mpc, r.consumption_drop, r.unemployment, r.mean_effort_employed, isnan(r.search_UL[1]) ? NaN : r.search_UL[1], t / 60))
    end
end
println("DONE")
