# Stage 1d, before calibrating S on the quarterly economy (V3_START.md section 130): G+S (or G+S+A) on stage 1c's
# quarterly economy at version 1's social parameters (kappa, sigma_m from calibration_v5m_<C>_<CFG>.txt) and the
# annual patience given, one solve: where participation lands against its targets (data/country_labour_participation.csv),
# as the starting point of the S calibration.
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/probe_v2_gs.jl CODE CONFIG BETA GAP
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); β = parse(Float64, ARGS[3]); gap = parse(Float64, ARGS[4])
A = occursin('A', cfg)
ca = country_config(code; config = cfg, v3 = :v5m, S = true, A = A)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0))
A && (c = SAGEConfig(c; search = false, out_ls = 0.0))
row = country_rows()[code]
t = @elapsed r = solve_economy(c; cache = false)
@printf("%s %s quarterly at patience %.4f, gap %.4f, kappa %.3f, sigma_m %.3f: participation %.4f (targets: low %s, high %s; ratio of the unemployed %s) | htm %.4f | MPC 12m %.4f | fall Kolsrud %.4f | %.1f min\n",
        code, cfg, β, gap, ca.kappa, ca.sigma_m, r.rate, row["part_low"], row["part_high"], row["ratio"], r.hand_to_mouth_kvw, r.mpc12, r.fall_kolsrud, t / 60)
for k in propertynames(r)
    s = string(k); (occursin("rate", s) || occursin("part", s)) && println("  ", s, " = ", getproperty(r, k))
end
println("DONE")
