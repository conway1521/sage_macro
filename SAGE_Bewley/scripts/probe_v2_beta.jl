# Stage 1b with patience refitted (a probe before stage 1d's recalibration): the quarterly economy with flows fitted
# to the duration of unemployment holds far more liquid wealth than the annual one at the same annual patience
# (V3_START.md section 121), which understates the fall on job loss. Each run solves G at one level of patience
# (annual equivalent, the cells' gap kept); three levels a country in parallel, and the fall read at the patience
# that gives the hand-to-mouth target.
#
#   julia --project=scripts/run_env scripts/probe_v2_beta.jl CODE BETA_ANNUAL
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); βa = parse(Float64, ARGS[2])
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cb = duration_config(ca)
gap = -ca.beta_cell[1]
HTM = Dict("FR" => 0.2680, "DE" => 0.2517, "IT" => 0.2028)          # HFCS 2021, the hand-to-mouth targets of version 1
c = SAGEConfig(cb; beta_bar = βa^(1 / 4), beta_cell = ((βa - gap)^(1 / 4) - βa^(1 / 4), 0.0))
t = @elapsed r = solve_economy(c; cache = false)
@printf("%s stage 1b, annual patience %.4f (gap %.4f): htm %.4f (target %.4f) | median/yr %.4f | MPC %.4f | fall %.4f | out %.4f | %.1f min\n",
        code, βa, gap, r.hand_to_mouth_kvw, HTM[code], r.wealth_p50 / (4 * r.median_income), r.mpc, r.consumption_drop, r.unemployment, t / 60)
println("DONE")
