# Grid check for the agency column.
#
# The hardship statistic is a threshold on the stationary wealth distribution,
# and the participation LEVEL was the one quantity in this model that refused
# to converge in na under a hard threshold (see MODEL_READINESS.md, Part 1).
# The failure there was structural: the cutoff sat on the atom at the borrowing
# constraint. The asset-poverty threshold does not, it sits well above the
# atom, so the statistic should converge at the usual rate. This checks that
# rather than assuming it.
#
# Cheap by design: rather than rebuilding whole families at a finer grid, it
# takes a spread of belonging scales, solves each at na = 200 and na = 400, and
# compares the cell-level hardship rate and agency value at the anchored
# threshold. If those move by less than the reported precision, the pooled
# figures inherit that.
#
#   julia --project=. scripts/agency_na_check.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics, DelimitedFiles

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const NE = 80
const MONTHS = 3.0

res = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_agency_results.txt"))
    startswith(ln, "#") && continue
    parts = split(strip(ln), '\t')
    length(parts) == 2 && (res[parts[1]] = parse(Float64, parts[2]))
end
abar = res["abar0"]
@printf("anchored threshold from the main run: %.6f\n\n", abar)

const US = (2.0, 3.5, 4.5, 5.5, 6.5, 8.0, 12.0)

@printf("%-6s %-6s | %-8s %-8s %-8s | %-8s %-8s\n",
        "alpha", "u", "h(200)", "h(400)", "diff", "A(200)", "A(400)")
println("-"^68)
worst_h = 0.0; worst_A = 0.0
for α in (CELL_LOW.α, CELL_HIGH.α)
    for u in US
        global worst_h, worst_A
        vals = Dict{Int,Tuple{Float64,Float64}}()
        for na in (200, 400)
            p = update(cell_params(α; na = na, ne = NE, a_max = GRID.a_max,
                                   pexp = GRID.pexp); social_strength = u)
            s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
            d = cell_distributions(p, s)
            h = share_below_interp(s.a, d.wcdf, abar)
            vals[na] = (h, α * (1 - h))
        end
        dh = vals[400][1] - vals[200][1]; dA = vals[400][2] - vals[200][2]
        worst_h = max(worst_h, abs(dh)); worst_A = max(worst_A, abs(dA))
        @printf("%.3f  %5.1f | %.4f   %.4f   %+.4f  | %.4f   %.4f\n",
                α, u, vals[200][1], vals[400][1], dh, vals[200][2], vals[400][2])
        flush(stdout)
    end
end
println("-"^68)
@printf("largest move in the cell hardship rate  %.4f\n", worst_h)
@printf("largest move in the cell agency value   %.4f\n", worst_A)
println("DONE")
