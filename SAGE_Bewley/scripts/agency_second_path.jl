# Independent code path for the agency column.
#
# The project's own gate (MODEL_READINESS.md, Part 7) asks that a quotable
# number be reproduced by a second code path. Everything in sa_agency.jl runs
# through the response-family reduction: solve each cell on a grid of belonging
# scales, then interpolate. This does it the other way, with no family and no
# interpolation. It draws taste nodes, solves EVERY node directly at its own
# belonging scale, and pools the resulting distributions. Slower by
# construction, which is why the family reduction exists, but it shares no code
# with it beyond the household solver.
#
# Two approximations are therefore tested at once: the linear interpolation
# across the family grid, and the 2000-node taste quadrature the driver uses.
# The direct path here uses fewer taste nodes, so it carries its own quadrature
# error; the comparison is meaningful to about the size of that error, which
# the node count below is chosen to keep small relative to the 0.002 grid band.
#
#   julia --project=. scripts/agency_second_path.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const NA, NE = 200, 80
const OMEGA, KAPPA, SIGMA = 0.30, 10.00, 0.510
const NDIRECT = 61                     # taste nodes solved directly

res = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_agency_results.txt"))
    startswith(ln, "#") && continue
    p = split(strip(ln), '\t'); length(p) == 2 && (res[p[1]] = parse(Float64, p[2]))
end
const ABAR = res["abar0"]; const RSTAR = res["r_base"]
@printf("direct path: %d taste nodes solved individually, no family, no interpolation\n", NDIRECT)
@printf("anchored threshold %.6f, belonging scales from the equilibrium rate %.4f\n\n",
        ABAR, RSTAR)

arg = OMEGA + (1 - OMEGA) * RSTAR
ms  = taste_nodes_ln(SIGMA; n = NDIRECT)

hcell = Float64[]; rcell = Float64[]; acell = Float64[]
for cell in (CELL_LOW, CELL_HIGH)
    hs = 0.0; rs = 0.0
    t0 = time()
    for m in ms
        u = KAPPA * m * cell.B * arg
        p = update(cell_params(cell.α; na = NA, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp); social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        d = cell_distributions(p, s)
        hs += share_below_interp(s.a, d.wcdf, ABAR) / length(ms)
        rs += d.rate / length(ms)
    end
    push!(hcell, hs); push!(rcell, rs); push!(acell, cell.α * (1 - hs))
    @printf("  %-9s alpha %.3f  hardship %.4f  rate %.4f  U^a %.4f   (%.1f min)\n",
            cell.name, cell.α, hs, rs, cell.α * (1 - hs), (time() - t0) / 60)
    flush(stdout)
end

Adirect = CELL_LOW.share * acell[1] + CELL_HIGH.share * acell[2]
rdirect = CELL_LOW.share * rcell[1] + CELL_HIGH.share * rcell[2]
hdirect = CELL_LOW.share * hcell[1] + CELL_HIGH.share * hcell[2]

println()
@printf("%-26s | %-9s %-9s %s\n", "quantity", "family", "direct", "difference")
println("-"^62)
for (nm, fam, dir) in (("participation rate", res["r_base"], rdirect),
                       ("asset poverty", res["h_base"], hdirect),
                       ("agency A", res["A_base"], Adirect),
                       ("U^a, low education", res["Alo_base"], acell[1]),
                       ("U^a, high education", res["Ahi_base"], acell[2]))
    @printf("%-26s | %.4f    %.4f    %+.4f\n", nm, fam, dir, dir - fam)
end
println("-"^62)
println("for scale: the asset-grid band on A is 0.0020, and the smallest")
println("difference the dashboard reports is the credit's 0.0077.")
println("DONE")
