# Where does the time go? One household problem at the production grid, timed
# stage by stage, on the Julia running this script. Used to compare Julia
# builds and solver changes; nothing here changes any result.
#
#   julia --project=scripts/run_env scripts/bench_solver.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
p0 = params_of(cT, cells_of(c)[1])[1]
p = update(p0; social_strength = 5.0)
println("Julia ", VERSION, " ", Sys.MACHINE, " | na ", p.na, " ne ", p.ne, " states ", length(p.transfer))

solve_participation_logit(p, 1.0; theta = c.theta, full = true)      # compile
t = @elapsed s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
t2 = @elapsed cs = cell_summary(p, s; thresholds = nothing)
t3 = @elapsed ag = agency_summary(p, s)
@printf("household solve %.2f s | cell summary %.3f s | agency summary %.3f s\n", t, t2, t3)
@printf("check: participation %.6f, mean assets %.6f\n", s.rate, sum(s.lambda .* s.a))

# stage timing inside the solver, with the profiler's flat view
using Profile
Profile.clear()
@profile for _ in 1:2
    solve_participation_logit(p, 1.0; theta = c.theta, full = true)
end
Profile.print(format = :flat, sortedby = :count, mincount = 200, maxdepth = 12)
