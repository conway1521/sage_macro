# The same work on two Julia builds: one family by the fast path (France G+S+A,
# lower education cell, 83 belonging scales) and the full calibrated economy
# with the cache off. Compare the time with bench_family.txt (Julia 1.7.2
# under Rosetta: 4.9 min) and the numbers with grid_test.txt (default row).
#
#   SAGE_WORKERS=4 ~/julia/julia-1.10.12/bin/julia --project=scripts/run_env_110 scripts/bench_julia.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))
c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
p0s = params_of(cT, cells_of(c)[1]); _, w = betas_of(c)
say("Julia ", VERSION, " ", Sys.MACHINE, " | ", nworkers(), " workers")
t = @elapsed build_family_ag(p0s, c.ugrid, c.theta; weights = w)
say(@sprintf("one family, fast path: %.1f min (Julia 1.7.2 under Rosetta: 4.9 min)", t / 60))
t = @elapsed r = solve_economy(c; cache = false)
say(@sprintf("calibrated G+S+A economy, no cache: %.1f min", t / 60))
say(@sprintf("part %.5f mult %.3f A %.5f A_cond %.5f htm %.5f effort %.5f room %.4f mpc %.4f", r.rate, 1 / (1 - r.slope),
             r.A, r.A_cond, r.hand_to_mouth_kvw, r.mean_effort_employed, r.room, r.mpc))
say("reference (1.7.2): part 0.23172 mult 1.868 A 0.99019 A_cond 0.86278 htm 0.02994 effort 0.64292 room 0.6935 mpc 0.1158")
say("DONE")
