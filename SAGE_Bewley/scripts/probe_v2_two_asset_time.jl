# Can the two-asset household problem be solved at a quarterly period on a runner? (V3_START.md section 127.) One
# household problem of stage 1c's quarterly G (one education cell, one patience), with the illiquid asset at version
# 1's two-asset reference (calibration_v3fet_<code>_G_I.txt: the premium, the fixed cost, the return paid out, liquid
# wealth earning nothing, patience as its fourth root), the floor off (not built for two assets): first 30 iterations
# timed, then to convergence with the distribution, reporting iterations, minutes and memory. Nothing is fitted; the
# answer is the cost, not the moments.
#
#   julia --project=scripts/run_env scripts/probe_v2_two_asset_time.jl CODE [NK] [KSUB] [NB]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); nk = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 24
ksub = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 4; nb = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 120
say(x...) = (println(x...); flush(stdout))
ref = Dict{String,Float64}()
for l in eachline(joinpath(@__DIR__, "calibration_v3fet_$(code)_G_I.txt"))
    t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue
    k, v = strip.(split(t, "=")); x = tryparse(Float64, split(v)[1]); x === nothing || (ref[k] = x)
end
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cq = floor_effort(SAGEConfig(duration_config(ca); cfloor = 0.0))          # the job's hours of the quarterly economy, floor off
p1 = update(params_of(cq, cells_of(cq)[1])[1]; social_strength = 0.0)
βq = ref["beta_bar"]^(1 / 4)
p2 = update(p1; illiquid = true, Rk = p1.R + ref["illiquid_premium"] / 4, chi0 = ref["chi0"], death = 1 - (1 - 1 / 45)^(1 / 4),
            nk = nk, k_max = 4 * 150.0, k_sub = ksub, k_mid = 0.0, a_max = 4 * 15.0, na = nb, k_payout = true, R = 1.0, β = βq, solver = :egm)
say(@sprintf("%s: %d income states, liquid %d x illiquid %d (%d targets an interval); patience %.4f a quarter, premium %.4f, fixed cost %.3f",
             code, p2.nz, nb, nk, ksub, βq, ref["illiquid_premium"] / 4, ref["chi0"]))
solve_two_asset_egm(p2, 1.0; maxit = 2)                                    # compile
t = @elapsed s = solve_two_asset_egm(p2, 1.0; maxit = 30)
say(@sprintf("30 iterations: %.1f s (%.2f s an iteration); memory so far %.2f GB", t, t / 30, Sys.maxrss() / 2^30))
t = @elapsed s = solve_two_asset_egm(p2, 1.0; full = true)
say(@sprintf("to convergence with the distribution: %d iterations, %.1f min; peak memory %.2f GB", s.iters, t / 60, Sys.maxrss() / 2^30))
println("DONE")
