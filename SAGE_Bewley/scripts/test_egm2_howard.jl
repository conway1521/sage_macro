# Howard steps in the two-asset solver (V3_START.md section 139) against the plain value iteration, on the problem of
# test_egm2_fast.jl (stage 1c's quarterly G, the illiquid asset at version 1's two-asset reference, floor off), warm
# starts off: for H = 0 (the present solver) and each H given, the full steps, the Howard steps, the minutes, and
# against H = 0 the largest difference in the value (relative), in the distribution, and in the aggregates (liquid
# and illiquid wealth, the share adjusting). The fixed point is the same, so the differences should be of the order
# of the tolerance (1e-9 on the span of the bounds).
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_howard.jl CODE NK KSUB NB H[,H...] [trace]
# `trace`: the solver's trace (the bound, the relaxation and the share adjusting every 100 full steps).
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); nk = parse(Int, ARGS[2]); ksub = parse(Int, ARGS[3]); nb = parse(Int, ARGS[4])
Hs = parse.(Int, split(ARGS[5], ",")); tr = length(ARGS) >= 6 && ARGS[6] == "trace"
say(x...) = (println(x...); flush(stdout))
ref = Dict{String,Float64}()
for l in eachline(joinpath(@__DIR__, "calibration_v3fet_$(code)_G_I.txt"))
    t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue
    k, v = strip.(split(t, "=")); x = tryparse(Float64, split(v)[1]); x === nothing || (ref[k] = x)
end
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cq = floor_effort(SAGEConfig(duration_config(ca); cfloor = 0.0))
p1 = update(params_of(cq, cells_of(cq)[1])[1]; social_strength = 0.0)
p2 = update(p1; illiquid = true, Rk = p1.R + ref["illiquid_premium"] / 4, chi0 = ref["chi0"], death = 1 - (1 - 1 / 45)^(1 / 4),
            nk = nk, k_max = 4 * 150.0, k_sub = ksub, k_mid = 0.0, a_max = 4 * 15.0, na = nb, k_payout = true, R = 1.0,
            β = ref["beta_bar"]^(1 / 4), solver = :egm)
say(@sprintf("%s: %d income states, liquid %d x illiquid %d (%d targets an interval), %d threads", code, p2.nz, nb, nk, ksub, Threads.nthreads()))
agg(s) = (b = sum(s.lambda .* reshape(s.a, :, 1, 1)), k = sum(s.lambda .* reshape(s.k, 1, :, 1)), adj = sum(s.lambda .* s.Padj))
ENV["SAGE_WARM2"] = "0"
solve_two_asset_egm(p2, 1.0; maxit = 2, howard = 0); solve_two_asset_egm(p2, 1.0; maxit = 2, howard = 2)     # compile
s0 = nothing
for H in vcat(0, Hs)
    t = @elapsed s = solve_two_asset_egm(p2, 1.0; full = true, howard = H, trace = tr)
    g = agg(s)
    say(@sprintf("H %3d: %5d full steps, %6d Howard steps, %6.2f min (inner %.0f s, outer %.0f s, Howard %.0f s), stalled %.1e; liquid %.8f, illiquid %.8f, adjusting %.8f",
                 H, s.iters, s.timing.howard_steps, t / 60, s.timing.inner, s.timing.outer, s.timing.howard, s.stalled, g...))
    if H == 0
        global s0 = s
    else
        g0 = agg(s0)
        dv = maximum(abs.(s.V .- s0.V)) / maximum(abs.(s0.V)); dl = maximum(abs.(s.lambda .- s0.lambda))
        say(@sprintf("       against H 0: value %.2e (relative), distribution %.2e, liquid %.2e, illiquid %.2e, adjusting %.2e",
                     dv, dl, abs(g.b - g0.b), abs(g.k - g0.k), abs(g.adj - g0.adj)))
    end
end
println("DONE")
