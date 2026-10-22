# The two-asset solver's speed changes (V3_START.md section 128) against the old path, on stage 1c's quarterly G with
# the illiquid asset at version 1's two-asset reference (as probe_v2_two_asset_time.jl), floor off:
#   1. the same problem with `fast` off and on (warm starts off): iterations, minutes, the largest difference in the
#      value, and the aggregates over the stationary distribution (liquid and illiquid wealth, the share adjusting);
#   2. warm starts: a second problem at slightly different patience, cold and from the first solution.
# Grid: NK illiquid nodes, KSUB targets an interval, NB liquid points (small by default, so the old path finishes).
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_fast.jl CODE [NK] [KSUB] [NB] [ONLYFAST]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); nk = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 12
ksub = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 2; nb = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 80
onlyfast = length(ARGS) >= 5 && ARGS[5] == "1"
say(x...) = (println(x...); flush(stdout))
ref = Dict{String,Float64}()
for l in eachline(joinpath(@__DIR__, "calibration_v3fet_$(code)_G_I.txt"))
    t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue
    k, v = strip.(split(t, "=")); x = tryparse(Float64, split(v)[1]); x === nothing || (ref[k] = x)
end
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cq = floor_effort(SAGEConfig(duration_config(ca); cfloor = 0.0))
p1 = update(params_of(cq, cells_of(cq)[1])[1]; social_strength = 0.0)
mk(β) = update(p1; illiquid = true, Rk = p1.R + ref["illiquid_premium"] / 4, chi0 = ref["chi0"], death = 1 - (1 - 1 / 45)^(1 / 4),
               nk = nk, k_max = 4 * 150.0, k_sub = ksub, k_mid = 0.0, a_max = 4 * 15.0, na = nb, k_payout = true, R = 1.0, β = β, solver = :egm)
βq = ref["beta_bar"]^(1 / 4); p2 = mk(βq)
say(@sprintf("%s: %d income states, liquid %d x illiquid %d (%d targets an interval), %d threads", code, p2.nz, nb, nk, ksub, Threads.nthreads()))
agg(s) = (b = sum(s.lambda .* reshape(s.a, :, 1, 1)), k = sum(s.lambda .* reshape(s.k, 1, :, 1)), adj = sum(s.lambda .* s.Padj))
ENV["SAGE_WARM2"] = "0"
solve_two_asset_egm(p2, 1.0; maxit = 2, fast = true); solve_two_asset_egm(p2, 1.0; maxit = 2, fast = false)      # compile
tn = @elapsed sn = solve_two_asset_egm(p2, 1.0; full = true, fast = true)
say(@sprintf("fast: %d iterations, %.2f min (inner %.1f s, outer %.1f s, sparse %s); liquid %.6f, illiquid %.6f, adjusting %.6f",
             sn.iters, tn / 60, sn.timing.inner, sn.timing.outer, string(sn.timing.sparse), agg(sn)...))
if !onlyfast
    to = @elapsed so = solve_two_asset_egm(p2, 1.0; full = true, fast = false)
    say(@sprintf("old:  %d iterations, %.2f min (inner %.1f s, outer %.1f s); liquid %.6f, illiquid %.6f, adjusting %.6f",
                 so.iters, to / 60, so.timing.inner, so.timing.outer, agg(so)...))
    dv = maximum(abs.(sn.V .- so.V)) / maximum(abs.(so.V)); dl = maximum(abs.(sn.lambda .- so.lambda))
    a1, a0 = agg(sn), agg(so)
    say(@sprintf("difference: value %.2e (relative), distribution %.2e, liquid %.2e, illiquid %.2e, adjusting %.2e; speed-up %.1f",
                 dv, dl, abs(a1.b - a0.b), abs(a1.k - a0.k), abs(a1.adj - a0.adj), to / tn))
end
ENV["SAGE_WARM2"] = "1"
p3 = mk(βq * 0.9995); p4 = mk(βq * 0.999)
empty!(WARM2); solve_two_asset_egm(p3, 1.0; full = true)                      # stores its solution
tw = @elapsed sw = solve_two_asset_egm(p4, 1.0; full = true)                   # warm from it
empty!(WARM2); tc = @elapsed sc = solve_two_asset_egm(p4, 1.0; full = true)    # the same problem cold
say(@sprintf("warm start, the same problem: cold %d iterations %.2f min, warm %d iterations %.2f min; liquid %.6f against %.6f",
             sc.iters, tc / 60, sw.iters, tw / 60, agg(sw).b, agg(sc).b))
println("DONE")
