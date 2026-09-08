# Would the linearisation identity have caught the defect?
#
# I claimed it would, on the grounds that the old paper reported a slope of
# 0.81 and an amplification of 3.6, while 1/(1-0.81) = 5.26, a 47 percent gap.
# That claim is not safe as stated, because the old amplification was measured
# on a 29-point move and the identity holds only in the limit of a small shock.
# Curvature alone pushes the measured multiplier below the local prediction, in
# exactly the direction observed. At the corrected footing a 10-point move
# already costs about 6 percent, so some of the 47 is curvature, not error.
#
# The decisive experiment is to run the identity at a SMALL shock on the OLD
# footing: the uniform 41-node family grid on [0,60] and 15 taste nodes, at the
# old calibrated kappa = 10.0, sigma_m = 0.50. If the identity fails there for
# tau = 0.01, the test would have caught the defect and is worth keeping as a
# standing gate. If it passes, the test is still valuable but it would not have
# saved us, and I should stop claiming otherwise.
#
#   julia --project=. scripts/audit_oldfooting.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using Printf, Statistics, DelimitedFiles

const OMEGA = 0.30
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const CACHE = joinpath(@__DIR__, "cache_old")
isdir(CACHE) || mkpath(CACHE)

# the two footings, exactly as each was actually used
const OLD = (ugrid = collect(range(0.0, 60.0, length = 41)), nq = 15,
             κ = 10.0,  σ = 0.50, name = "OLD  (41 uniform nodes on [0,60], 15 taste nodes)")
const NEW = (ugrid = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0)),
             nq = 2000, κ = 10.75, σ = 0.750, name = "NEW  (83 concentrated nodes, 2000 taste nodes)")

const TASTE = Dict{Tuple{Float64,Int},Vector{Float64}}()
tastes(σ, n) = get!(TASTE, (σ, n)) do; taste_nodes_ln(σ; n = n) end

function family(F, α; subsidy = 0.0, lumptax = 0.0)
    tag = F === OLD ? "old" : "new"
    f = joinpath(CACHE, "fam_$(tag)_" *
        join([replace(@sprintf("%.6f", x), "." => "p") for x in (α, subsidy, lumptax)], "_") * ".txt")
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1); return (d[:, 1], d[:, 2], d[:, 3])
    end
    r = Float64[]; mi = Float64[]
    for u in F.ugrid
        p = update(cell_params(α; na = 200, ne = 40, subsidy = subsidy, lumptax = lumptax);
                   social_strength = u)
        _, rate, m, _ = solve_participation(p, 1.0)
        push!(r, rate); push!(mi, m)
    end
    open(f, "w") do io
        println(io, join(["u", "r", "minc"], '\t'))
        for i in eachindex(F.ugrid); println(io, join([F.ugrid[i], r[i], mi[i]], '\t')); end
    end
    (copy(F.ugrid), r, mi)
end

function rates(F, fl, fh, rin, col)
    ms = tastes(F.σ, F.nq); arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], F.κ * m * Blow  * arg) for m in ms)
    hi = mean(interp(fh[1], fh[col], F.κ * m * Bhigh * arg) for m in ms)
    0.5lo + 0.5hi
end
function equil(F, fl, fh; ngrid = 1601)
    g = range(0.0, 1.0, length = ngrid)
    o = [rates(F, fl, fh, r, 2) for r in g]
    best = nothing
    for i in 1:ngrid-1
        d1 = o[i]-g[i]; d2 = o[i+1]-g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            sl = (o[i+1]-o[i])/(g[i+1]-g[i])
            sl < 1 && (best = (r = g[i]+d1/(d1-d2)*(g[i+1]-g[i]), slope = sl))
        end
    end
    best
end

println("="^78)
println("WOULD THE IDENTITY TEST HAVE CAUGHT IT? Old footing against new")
println("="^78)
println("The identity: for a small financed subsidy the equilibrium response must")
println("equal the direct response divided by 1 - G'(r*). Run at tau = 0.01, where")
println("curvature over the move is negligible, so any gap is a numerical fault.\n")

for F in (OLD, NEW)
    println("-"^78); println(F.name); println("-"^78)
    fl = family(F, CELL_LOW.α); fh = family(F, CELL_HIGH.α)
    E = equil(F, fl, fh)
    mi0 = rates(F, fl, fh, E.r, 3)
    pred = 1 / (1 - E.slope)
    @printf("baseline r* = %.5f, G'(r*) = %.5f, predicted multiplier = %.4f\n",
            E.r, E.slope, pred)
    @printf("%-8s | %-10s | %-10s | %-9s | %-9s | %s\n",
            "tau", "direct", "equilib", "measured", "predicted", "error")
    for τ in (0.01, 0.20)
        T = τ * mi0; local rE = NaN; local flP = fl; local fhP = fh
        for _ in 1:4
            flP = family(F, CELL_LOW.α;  subsidy = τ, lumptax = T)
            fhP = family(F, CELL_HIGH.α, subsidy = τ, lumptax = T)
            EP = equil(F, flP, fhP); rE = EP.r
            Tn = τ * rates(F, flP, fhP, rE, 3)
            abs(Tn - T) < 1e-5 && (T = Tn; break)
            T = Tn
        end
        dir = rates(F, flP, fhP, E.r, 2)
        meas = (E.r - rE) / (E.r - dir)
        @printf("%.2f     | %+9.5f | %+9.5f | %8.4f  | %8.4f  | %+6.1f%%\n",
                τ, dir - E.r, rE - E.r, meas, pred, 100*(meas/pred - 1))
        flush(stdout)
    end
    println()
end
println("Read the tau = 0.01 rows. A large error there is a numerical fault, since")
println("curvature cannot explain a gap at a shock that small. The tau = 0.20 rows")
println("show how much of the published gap was curvature over a big move.")
println("DONE")
