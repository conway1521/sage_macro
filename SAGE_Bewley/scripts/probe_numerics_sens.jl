# Two numerical checks asked for by the methods review of 18 October (V3_START.md section 111).
#
# 1. The top of the asset grid (`amax`): G+A with dread and search solved at the base's ceiling of four years of
#    mean income and at eight (with twice the points, so the density is kept), reporting the moments, the chances
#    of finding work chosen, and the response of the first year's chance to a benefit 10% higher (tax held).
# 2. The residual accepted at the floor (`stall`): G+S+A household problems at three belonging scales, every
#    type of both cells, solved with the accepted residual at 1e-2 (every result so far) and at 1e-6 with up to
#    20,000 iterations, reporting the largest differences in participation, search and consumption.
#
#   julia --project=scripts/run_env scripts/probe_numerics_sens.jl CODE amax|stall
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); what = lowercase(ARGS[2])
say(x...) = (println(x...); flush(stdout))

if what == "amax"
    c = country_config(code; config = "GA", v3 = :v5m, S = false, A = true)
    say(@sprintf("%s G+A, search %s | the top of the asset grid at 4 and 8 years of mean income", code, c.search ? "on" : "off"))
    say(@sprintf("  %-8s %8s %8s %8s %8s %8s %8s %8s %8s", "a_max", "htm", "median", "MPC", "fall", "chanceU", "chanceL", "elastU", "top mass"))
    for (am, na) in ((c.a_max, c.na), (2 * c.a_max, 2 * c.na))
        cc = SAGEConfig(c; a_max = am, na = na)
        r = solve_economy(cc; cache = false)
        rrp = isnan(cc.rr_public) ? cc.rr : cc.rr_public
        r1 = solve_economy(SAGEConfig(cc; rr = 1.1 * cc.rr, rr_public = rrp + 0.1 * cc.rr); cache = false)
        el = log(r1.search_UL[1] / r.search_UL[1]) / log(1.1)
        top = 1 - share_below_interp(r.agrid, r.Wtot, 0.95 * am)
        say(@sprintf("  %-8.2f %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %8.3f %8.1e", am, r.hand_to_mouth_kvw, r.wealth_p50 / r.median_income,
                     r.mpc, r.consumption_drop, r.search_UL..., el, top))
    end
elseif what == "stall"
    c = country_config(code; config = "GSA", v3 = :v5m, S = true, A = true)
    c = floor_effort(c); cs = cells_of(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    us = (0.0, 8.2, 30.0)
    say(@sprintf("%s G+S+A | household problems at belonging scales %s, every type, residual 1e-2 against 1e-6", code, string(us)))
    say(@sprintf("  %-4s %-4s %-6s %7s %7s %10s %10s %10s %10s", "cell", "type", "scale", "iters", "iters6", "d partic.", "d search", "d cons.", "d value"))
    worst = zeros(4)
    for g in 1:2, (k, p0) in enumerate(params_of(cT, cs[g])), u in us
        p = update(p0; social_strength = u)
        s1 = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        s2 = solve_participation_logit(update(p; stall_tol = 1e-6), 1.0; theta = c.theta, full = true, maxit = 20_000)
        λ = s2.lambda; m = sum(λ)
        dP = abs(sum(λ .* s1.P1) - sum(λ .* s2.P1)) / m
        sr = isempty(p.search_k) ? falses(size(λ, 2)) : p.search_k .> 0
        dX = any(sr) ? abs(sum(λ[:, sr] .* s1.search_x[:, sr]) - sum(λ[:, sr] .* s2.search_x[:, sr])) / sum(λ[:, sr]) : 0.0
        c1 = (1 .- s1.P1) .* s1.c_d[1] .+ s1.P1 .* s1.c_d[2]; c2 = (1 .- s2.P1) .* s2.c_d[1] .+ s2.P1 .* s2.c_d[2]
        dC = sum(λ .* abs.(c1 .- c2) ./ max.(c2, 1e-12)) / m
        dV = sum(λ .* abs.(s1.V .- s2.V)) / m
        worst .= max.(worst, [dP, dX, dC, dV])
        (s1.iters != s2.iters) && say(@sprintf("  %-4d %-4d %-6.1f %7d %7d %10.1e %10.1e %10.1e %10.1e", g, k, u, s1.iters, s2.iters, dP, dX, dC, dV))
    end
    say(@sprintf("  largest differences over every problem: participation %.1e, search %.1e, consumption %.1e, value %.1e", worst...))
end
println("DONE")
