# The pooled version of the agency grid check.
#
# agency_na_check.jl doubles na at seven belonging scales and finds the cell
# hardship rate moving by up to 0.012, concentrated at the scales near the
# participation transition. That is the same amplification the rest of this
# model shows near the fold, and per-node it is large enough to matter for the
# smallest effect the dashboard reports. What the dashboard actually quotes is
# the TASTE-WEIGHTED pool over the whole family, in which those scales carry
# only part of the mass, so this rebuilds the two baseline families at na = 400
# and pools them the same way the driver does.
#
# The equilibrium participation rate is HELD at its na = 200 value, so this
# isolates the distributional statistic from any movement in the equilibrium
# itself. That is the quantity at issue: whether A is a grid artefact.
#
#   julia --project=. scripts/agency_na_pooled.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics, Serialization, LinearAlgebra

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0),
                   collect(17.0:1.0:30.0))
const NQ, OMEGA, KAPPA, SIGMA = 2000, 0.30, 10.00, 0.510
const NE = 80
const MS = taste_nodes_ln(SIGMA; n = NQ)

res = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_agency_results.txt"))
    startswith(ln, "#") && continue
    p = split(strip(ln), '\t'); length(p) == 2 && (res[p[1]] = parse(Float64, p[2]))
end
const ABAR = res["abar0"]; const RSTAR = res["r_base"]
@printf("anchored threshold %.6f, equilibrium rate held at %.4f\n\n", ABAR, RSTAR)

function build(α, na)
    W = zeros(length(UGRID), na); rr = zeros(length(UGRID)); agrid = Float64[]
    t0 = time()
    for (i, u) in enumerate(UGRID)
        p = update(cell_params(α; na = na, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp); social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        d = cell_distributions(p, s)
        W[i, :] = d.wcdf; rr[i] = d.rate; isempty(agrid) && (agrid = copy(s.a))
    end
    @printf("  built alpha %.3f at na %d  (%.1f min)\n", α, na, (time()-t0)/60)
    flush(stdout)
    (W = W, r = rr, agrid = agrid)
end

function weights(B, arg)
    w = zeros(length(UGRID))
    for m in MS
        x = KAPPA * m * B * arg
        if x <= UGRID[1]; w[1] += 1
        elseif x >= UGRID[end]; w[end] += 1
        else
            k = searchsortedlast(UGRID, x)
            t = (x - UGRID[k]) / (UGRID[k+1] - UGRID[k])
            w[k] += 1 - t; w[k+1] += t
        end
    end
    w ./ length(MS)
end

arg = OMEGA + (1 - OMEGA) * RSTAR
wl = weights(CELL_LOW.B, arg); wh = weights(CELL_HIGH.B, arg)

@printf("%-5s | %-8s %-8s | %-8s %-8s | %-8s %-8s\n",
        "na", "h_low", "h_high", "A_low", "A_high", "A", "rate")
println("-"^70)
out = Dict{Int,Float64}()
for na in (200, 400)
    fl = build(CELL_LOW.α, na); fh = build(CELL_HIGH.α, na)
    Wl = fl.W' * wl; Wh = fh.W' * wh
    hl = share_below_interp(fl.agrid, Wl, ABAR)
    hh = share_below_interp(fh.agrid, Wh, ABAR)
    Al = CELL_LOW.α * (1 - hl); Ah = CELL_HIGH.α * (1 - hh)
    A = CELL_LOW.share * Al + CELL_HIGH.share * Ah
    rate = CELL_LOW.share * dot(wl, fl.r) + CELL_HIGH.share * dot(wh, fh.r)
    out[na] = A
    @printf("%-5d | %.4f   %.4f   | %.4f   %.4f   | %.4f   %.4f\n",
            na, hl, hh, Al, Ah, A, rate)
    flush(stdout)
end
println("-"^70)
@printf("pooled A moves %+.4f when na doubles from 200 to 400\n",
        out[400] - out[200])
println("for comparison, the changes the dashboard reports:")
@printf("  work subsidy %+.4f, empowerment %+.4f, participation credit %+.4f\n",
        res["dA_sub"], res["dA_emp"], res["dA_cred"])
println("DONE")
