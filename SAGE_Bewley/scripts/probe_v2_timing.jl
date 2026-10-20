# Where the quarterly economy spends its time (stage 1a): the first quarterly G solve did not finish in six hours
# (run 39263256950) where the annual one took three minutes. Each step is timed on its own, with the household
# problem's iterations reported, so that the slow step is found before anything is changed.
#
#   julia --project=scripts/run_env scripts/probe_v2_timing.jl CODE
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
say(x...) = (println(x...); flush(stdout))
ca = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
t = @elapsed cq = quarterly_config(ca); say(@sprintf("quarterly_config: %.1f s", t))
# 1. one household problem of the quarterly economy at the annual job effort levels padded (no reference economy yet)
ca1 = floor_effort(ca)
cs = cells_of(cq)
for (lab, c, effort) in (("annual", ca1, nothing), ("quarterly, no floor", SAGEConfig(cq; cfloor = 0.0, effort_mode = :free), nothing))
    cc = SAGEConfig(c; sd_eps_cell = (0.0, 0.0), tax_mode = :lump)
    p = params_of(cc, cells_of(cc)[1])[1]; p = update(p; social_strength = 0.0)
    t = @elapsed s = solve_participation_logit(p, 1.0; theta = cc.theta, full = true)
    say(@sprintf("%-22s one household problem: %d states, %d iterations, %.1f s", lab, size(s.lambda, 2), s.iters, t))
end
# 2. the reference economy of the job's hours (floor_effort), with a time limit by printing as it goes
say("floor_effort on the quarterly economy ...")
t = @elapsed cqe = floor_effort(cq); say(@sprintf("floor_effort: %.1f s", t))
# 3. one household problem with the job's levels, the floor on
cT = SAGEConfig(cqe; lumptax = cqe.lumptax + ui_only_tax_of(cqe))
p = update(params_of(cT, cells_of(cqe)[1])[1]; social_strength = 0.0)
t = @elapsed s = solve_participation_logit(p, 1.0; theta = cqe.theta, full = true)
say(@sprintf("quarterly with floor, one household problem: %d states, %d iterations, %.1f s", size(s.lambda, 2), s.iters, t))
# 4. the floor's tax
say("floor_tax_of on the quarterly economy ...")
t = @elapsed F = floor_tax_of(cqe); say(@sprintf("floor_tax_of: %.6f in %.1f s", F, t))
println("DONE")
