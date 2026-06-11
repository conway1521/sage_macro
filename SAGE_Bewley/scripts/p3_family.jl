# Paper 3 (calibrated history): precompute the response family on a grid of
# agency levels alpha, so the entire multi-country, multi-year history is
# interpolation. The driver of the historical exercise is the agency gap (the
# low-education group's agency alpha_low falls as inequality rises, widening
# the between-group gap that the data records). For each alpha we store the
# participation response r(u) and the mean labour income minc(u) on the
# belonging-scale grid u, exactly the object sa_core.jl already builds for a
# single alpha. One overnight build; every year-solve thereafter is an
# interpolation in (u, alpha).
#
#   julia --project=. scripts/p3_family.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

# Agency grid: spans from a wide-gap, high-inequality low group (0.60) up
# through the calibrated baseline low (0.765) and counterfactual mean (0.838)
# to the high-education level (0.911, the fixed upper cell). Fine enough that
# linear interpolation in alpha is accurate; the family curves are smooth.
const ALPHA_GRID = [0.60, 0.66, 0.72, 0.765, 0.838, 0.911]
const OUTFILE = joinpath(@__DIR__, "p3_family.txt")

println("Building the 2D response family r(u, alpha) on the production grid.")
println("alpha grid: ", ALPHA_GRID)
rows = Vector{Vector{Float64}}()
ug = nothing
for α in ALPHA_GRID
    @printf("  alpha = %.3f ...\n", α); flush(stdout)
    u, r, minc = response_family(α; verbose = false)
    global ug = u
    for i in eachindex(u)
        push!(rows, [α, u[i], r[i], minc[i]])
    end
    @printf("    done: rate range [%.3f, %.3f]\n", minimum(r), maximum(r)); flush(stdout)
end

open(OUTFILE, "w") do io
    println(io, join(["alpha", "u", "rate", "minc"], '\t'))
    for row in rows
        println(io, join(row, '\t'))
    end
end
@printf("Saved %d rows to %s (%d alphas x %d u-nodes)\n",
        length(rows), basename(OUTFILE), length(ALPHA_GRID), length(ug))
println("DONE")
