# LEVEL 2, decisive test: does the pointwise interpolation error bias the
# AGGREGATE? Rebuild the families at half the spacing (h = 0.1 instead of 0.2)
# and recompute the calibrated equilibrium. Linear interpolation of a step
# carries an O(h * jump) bias, so halving h should halve it. If the equilibrium
# barely moves, the reduction is adequate for the paper's purposes; if it moves
# materially, the method needs replacing rather than regridding.
#
#   julia --project=. scripts/verify_L2_bias.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf

const KAPPA = 10.75; const SIGMA = 0.750; const OMEGA = 0.30
const Bl = CELL_LOW.B; const Bh = CELL_HIGH.B

function famgrid(h)
    vcat(collect(0.0:h:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
end
function build(α, ug)
    r = Float64[]; mi = Float64[]
    for u in ug
        p = update(cell_params(α; na = 200, ne = 40); social_strength = u)
        _, rate, m = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m)
    end
    (ug, r, mi)
end
function eq(fl, fh, nodes)
    g = range(0.0, 1.0, length = 1201)
    o = [population_rate(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA, r; n_nodes = nodes)[1] for r in g]
    for i in 1:1200
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1/(d1-d2); rs = g[i]+t*(g[i+1]-g[i])
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            if sl < 1
                _, lo, hi = population_rate(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA, rs; n_nodes = nodes)
                return (rs, lo, hi, sl)
            end
        end
    end
    (NaN, NaN, NaN, NaN)
end

@printf("%-10s | %-6s | %-8s | %-8s | %-8s | %-8s\n",
        "spacing", "nodes", "rate", "low", "high", "slope")
prev = nothing
for h in (0.4, 0.2, 0.1, 0.05)
    ug = famgrid(h)
    fl = build(0.765, ug); fh = build(0.911, ug)
    r, lo, hi, sl = eq(fl, fh, 2000)
    @printf("h=%-8.2f | %-6d | %.5f  | %.5f  | %.5f  | %.5f", h, length(ug), r, lo, hi, sl)
    prev === nothing ? println() : @printf("   change %.1e\n", abs(r-prev))
    global prev = r
    flush(stdout)
end
println("\nDONE")
