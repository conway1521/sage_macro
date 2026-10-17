# Why G+S+A with job search is slow (V3_START.md section 108): the household problems of one country solved
# one at a time, search off and on, with S off (as in G+A) and at three belonging scales of S, reporting the
# iterations, whether the floor's stall rule ended them, and the time. Nothing is fitted.
#
#   julia --project=scripts/run_env scripts/probe_search_numerics.jl CODE [problems per cell]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); np = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 3
c = country_config(code; config = "GSA", v3 = :v5m, S = true, A = true)
c.search || error("search is off: run with SAGE_DREAD_CHOICE=1 and the search file in place")
c = floor_effort(c); cs = cells_of(c)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
cO = SAGEConfig(cT; search = false)
us = c.ugrid[[1, cld(length(c.ugrid), 2), length(c.ugrid)]]
@printf("%s G+S+A, search costs %s %s | belonging scales tried: S off, %s\n", code, string(c.search_kU), string(c.search_kL), join((@sprintf("%.3f", u) for u in us), ", "))
@printf("  %-5s %-4s %-8s %-9s %7s %9s %9s\n", "cell", "type", "search", "S scale", "iters", "seconds", "mean x")
for g in 1:2
    psO = params_of(cO, cs[g]); psS = params_of(cT, cs[g])
    for k in round.(Int, range(1, length(psS), length = min(np, length(psS))))
        for (lab, ps) in (("off", psO), ("on", psS)), u in (0.0, us...)
            p = update(ps[k]; social_strength = u)
            t = @elapsed s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
            sr = p.search_k .> 0
            mx = any(sr) ? sum(s.lambda[:, sr] .* s.search_x[:, sr]) / sum(s.lambda[:, sr]) : NaN
            @printf("  %-5d %-4d %-8s %-9s %7d %9.2f %9.4f\n", g, k, lab, u == 0 ? "S off" : @sprintf("%.3f", u), s.iters, t, mx)
            flush(stdout)
        end
    end
end
println("DONE")
