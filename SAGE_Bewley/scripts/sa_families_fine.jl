# Rebuild the response families on a grid concentrated where the response
# actually moves. The original grid was uniform on [0,60] with 41 nodes, but
# the cell response transitions from 0 to 1 between u = 3 and u = 7.5, so only
# about three nodes covered the transition and thirty-five sat in a flat region.
# Everything downstream interpolated a near-step function with three points.
#
# New grid: spacing 0.2 on [0,12] where the transition lives, then coarser out
# to 30, which covers the largest belonging scale the population reaches
# (kappa * m_max * B * arg is about 25 at the calibrated parameters).
#
#   julia --project=. scripts/sa_families_fine.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf

const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
println("grid: $(length(UGRID)) nodes, $(count(<=(12.0), UGRID)) of them below u = 12")

fams = Dict{Float64,Any}()
for α in (0.765, 0.911, 0.838)
    r = Float64[]; mi = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = 200, ne = 40); social_strength = u)
        _, rate, m = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m)
    end
    fams[α] = (r, mi)
    @printf("alpha %.3f done: transition from %.2f to %.2f\n", α,
            UGRID[something(findfirst(>(0.01), r), 1)],
            UGRID[something(findfirst(>(0.99), r), length(r))])
    flush(stdout)
end

open(joinpath(@__DIR__, "sa_families_fine.txt"), "w") do io
    println(io, join(["u","r765","mi765","r911","mi911","r838","mi838"], '\t'))
    for i in eachindex(UGRID)
        println(io, join([UGRID[i], fams[0.765][1][i], fams[0.765][2][i],
                          fams[0.911][1][i], fams[0.911][2][i],
                          fams[0.838][1][i], fams[0.838][2][i]], '\t'))
    end
end
println("saved sa_families_fine.txt")
println("DONE")
