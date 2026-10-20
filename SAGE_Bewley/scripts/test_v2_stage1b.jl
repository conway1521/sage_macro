# Stage 1b's first economy (V2_BUILD_PLAN.md): G with the flows fitted to the duration of unemployment and the
# inactive state, at a quarter, nothing refitted, against the annual G and stage 1a's quarterly G (version 1's
# flows). Reported: hand-to-mouth (a week), median liquid wealth over a year's income, the MPC (a month, within the
# period), the fall on entering unemployment, and from the chain: the unemployment rate, the share of the
# unemployed out of work for a year or more (against Eurostat une_ltu_a), the inactive share.
#
#   julia --project=scripts/run_env scripts/test_v2_stage1b.jl CODE
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1])
say(x...) = (println(x...); flush(stdout))
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cb = duration_config(ca)
say(@sprintf("%s stage 1b: exits to work by quarter %s, to inactivity %s, L %.4f / %.4f, job loss %.5f %.5f, E->N %.4f %.4f, N->E %.4f, N->U %.4f",
             code, string(round.(cb.hU_vec; digits = 3)), string(round.(cb.sU_vec; digits = 3)), cb.f_long[1], cb.sL, cb.delta..., cb.iotaE..., cb.nuE, cb.nuU))
say(@sprintf("   income: rho %.4f %.4f, s_eta %.4f %.4f, s_eps %.4f %.4f", cb.rho_cell..., cb.eta_cell..., cb.sd_eps_cell...))
let ch = labour_chain(SAGEParams(nz = 2, α = fill(1.0, 2), B = fill(1.0, 2)); nU = cb.nU, hU = cb.hU_vec, hL = cb.f_long[1], δ = cb.delta[1], chain_flows(cb, 1)...)
    m = ch.mass; nU = cb.nU
    mu = sum(m[1:nU]) + m[ch.iL]; ltu = sum(m[5:nU]) + m[ch.iL]
    say(@sprintf("   chain (cell 1): unemployment rate %.4f, share of the unemployed out a year or more %.3f, inactive %.3f, employed %.3f",
                 mu / (mu + m[ch.iE]), ltu / mu, m[ch.iN], m[ch.iE]))
end
say(@sprintf("  %-12s %8s %8s %8s %8s %8s %8s", "", "htm", "med/yr", "MPC", "fall", "out", "minutes"))
for (lab, c, k) in (("annual", ca, 1), ("stage 1b", cb, 4))
    t = @elapsed r = solve_economy(c; cache = false)
    say(@sprintf("  %-12s %8.4f %8.4f %8.4f %8.4f %8.4f %8.1f", lab, r.hand_to_mouth_kvw, r.wealth_p50 / (k * r.median_income), r.mpc, r.consumption_drop, r.unemployment, t / 60))
end
println("DONE")
