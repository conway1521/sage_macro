# The cost of one iteration of the household problem, annual against quarterly (stage 1a). The timing probe (run
# 39354410626) found a quarterly problem with hours chosen taking 15 s an iteration against 6 ms for an annual one
# with hours set by the job. Here the cases are matched: annual and quarterly, hours set by the job (the quarterly
# chain's employed states take the annual levels of the same latent productivity) and hours chosen; the annual
# economy also on the chain (`chain = true`). Each problem runs 60 iterations only (maxit), so the time per
# iteration is measured without waiting for convergence. No floor, no transitory part, lump tax.
#
#   julia --project=scripts/run_env scripts/probe_v2_iter.jl CODE
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
say(x...) = (println(x...); flush(stdout))
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
cq = quarterly_config(ca)
ca1 = floor_effort(ca)                                   # the annual job levels, states (U, E, L)
nz = ca.nz
# the quarterly chain's states (U_1..U_4, E, L) x nz: the employed states take the annual E levels by latent index
qlev(v) = vcat(zeros(4nz), v[nz+1:2nz], zeros(nz))
plain(c) = SAGEConfig(c; cfloor = 0.0, sd_eps_cell = (0.0, 0.0), tax_mode = :lump)
cases = [("annual, job hours", plain(ca1)),
         ("annual chain, job hours", SAGEConfig(plain(ca1); chain = true)),
         ("annual, hours chosen", SAGEConfig(plain(ca); effort_mode = :free)),
         ("quarterly, job hours", SAGEConfig(plain(cq); effort_by_cell = (qlev(ca1.effort_by_cell[1]), qlev(ca1.effort_by_cell[2])))),
         ("quarterly, hours chosen", SAGEConfig(plain(cq); effort_mode = :free)),
         ("quarterly 200 pts, job hours", SAGEConfig(plain(cq); na = 200, effort_by_cell = (qlev(ca1.effort_by_cell[1]), qlev(ca1.effort_by_cell[2]))))]
for (lab, c) in cases
    p = update(params_of(c, cells_of(c)[1])[1]; social_strength = 0.0)
    solve_participation_logit(p, 1.0; theta = c.theta, full = true, maxit = 3)            # compile
    t = @elapsed s = solve_participation_logit(p, 1.0; theta = c.theta, full = true, maxit = 60)
    say(@sprintf("%-30s %3d states, %3d points, job hours %-5s: %4d iterations in %8.2f s, %8.1f ms an iteration",
                 lab, size(s.lambda, 2), length(s.a), string(!isempty(p.effort_set)), s.iters, t, 1000 * t / max(s.iters, 1)))
end
# and one quarterly problem to convergence, job hours, with the distribution solved directly where needed
let c = cases[4][2]
    p = update(params_of(c, cells_of(c)[1])[1]; social_strength = 0.0)
    t = @elapsed s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
    say(@sprintf("quarterly, job hours, to convergence: %d iterations, %.1f s; mass %.12f", s.iters, t, sum(s.lambda)))
end
println("DONE")
