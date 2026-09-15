# How many workers fit in memory on this machine. Solves a handful of household
# problems at France's footing on two workers, reads each worker's peak
# resident memory, and prints the worker count that keeps the peaks, with a 1.5
# margin, inside a budget. At na 400 a worker was seen at 4 to 5 GB on a 24 GB
# machine, which is why this exists.
#
#   SAGE_WORKERS=2 julia --project=. scripts/probe_memory.jl [na] [budget_GB]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
const NA = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 200
const BUDGET = (length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 16.0) * 1024^3
c = SAGEConfig(S = true, A = true, unemployment = true, beta_spread = 0.037, unemployed_ratio = 0.17 / 0.35, na = NA)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
jobs = [(p, u) for p in params_of(cT, cells_of(c)[1]) for u in (4.0, 8.0)]
pmap(jobs) do j
    s = solve_participation_logit(update(j[1]; social_strength = j[2]), 1.0; theta = c.theta, full = true)
    cell_summary(j[1], s)
    nothing
end
peak = maximum(Float64(remotecall_fetch(Sys.maxrss, w)) for w in workers())
nw = clamp(floor(Int, BUDGET / (1.5 * peak)), 1, 13)
@printf("na %d: peak worker memory %.2f GB; with a 1.5 margin, %d workers fit a %.0f GB budget\n",
        NA, peak / 1024^3, nw, BUDGET / 1024^3)
println("WORKERS=", nw)
