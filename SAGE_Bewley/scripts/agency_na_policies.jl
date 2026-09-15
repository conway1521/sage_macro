# Does the grid move the CHANGES, not just the level?
#
# agency_na_pooled.jl showed the baseline pooled A moving 0.0020 when na
# doubles. What the dashboard reports is differences, and differences often
# survive a grid better than levels do because the two states share most of
# their discretisation error. This rebuilds ALL FOUR policy states at na = 400
# and recomputes the differences, holding each policy at the equilibrium rate
# and lump-sum tax the na = 200 run found, so the comparison isolates the
# distributional statistic.
#
#   julia --project=. scripts/agency_na_policies.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics, LinearAlgebra

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0),
                   collect(17.0:1.0:30.0))
const NQ, OMEGA, KAPPA, SIGMA, NE = 2000, 0.30, 10.00, 0.510, 80
const MS = taste_nodes_ln(SIGMA; n = NQ)

res = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_agency_results.txt"))
    startswith(ln, "#") && continue
    p = split(strip(ln), '\t'); length(p) == 2 && (res[p[1]] = parse(Float64, p[2]))
end
const ABAR = res["abar0"]
@printf("anchored threshold %.6f\n\n", ABAR)

function build(α, na; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    W = zeros(length(UGRID), na); agrid = Float64[]
    for (i, u) in enumerate(UGRID)
        p = update(cell_params(α; na = na, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp, subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        W[i, :] = cell_distributions(p, s).wcdf
        isempty(agrid) && (agrid = copy(s.a))
    end
    (W = W, agrid = agrid)
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

"A at one policy state, on a grid of na nodes."
function stateA(na, αlo, αhi, r; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    arg = OMEGA + (1 - OMEGA) * r
    fl = build(αlo, na; subsidy = subsidy, lumptax = lumptax, partcredit = partcredit)
    fh = build(αhi, na; subsidy = subsidy, lumptax = lumptax, partcredit = partcredit)
    Wl = fl.W' * weights(CELL_LOW.B, arg); Wh = fh.W' * weights(CELL_HIGH.B, arg)
    hl = share_below_interp(fl.agrid, Wl, ABAR); hh = share_below_interp(fh.agrid, Wh, ABAR)
    CELL_LOW.share * αlo * (1 - hl) + CELL_HIGH.share * αhi * (1 - hh)
end

const POLICIES = (
    (name = "baseline",    αlo = CELL_LOW.α, αhi = CELL_HIGH.α, r = res["r_base"],
     kw = (subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)),
    (name = "work subsidy", αlo = CELL_LOW.α, αhi = CELL_HIGH.α, r = res["r_sub"],
     kw = (subsidy = res["tau_sub"], lumptax = res["T_sub"], partcredit = 0.0)),
    (name = "empowerment", αlo = res["alpha_mid"], αhi = CELL_HIGH.α, r = res["r_emp"],
     kw = (subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)),
    (name = "participation credit", αlo = CELL_LOW.α, αhi = CELL_HIGH.α, r = res["r_cred"],
     kw = (subsidy = 0.0, lumptax = res["T_cred"], partcredit = res["rho_cred"])),
)

A = Dict{Tuple{String,Int},Float64}()
for na in (200, 400)
    for P in POLICIES
        t0 = time()
        A[(P.name, na)] = stateA(na, P.αlo, P.αhi, P.r; P.kw...)
        @printf("  %-21s na %d  A %.4f   (%.1f min)\n",
                P.name, na, A[(P.name, na)], (time() - t0) / 60)
        flush(stdout)
    end
end

println()
@printf("%-21s | %-8s %-8s %-8s | %-9s %-9s %s\n",
        "policy", "A(200)", "A(400)", "level", "dA(200)", "dA(400)", "move")
println("-"^80)
for P in POLICIES
    a2 = A[(P.name, 200)]; a4 = A[(P.name, 400)]
    d2 = a2 - A[("baseline", 200)]; d4 = a4 - A[("baseline", 400)]
    @printf("%-21s | %.4f   %.4f   %+.4f | %+.4f   %+.4f   %+.4f\n",
            P.name, a2, a4, a4 - a2, d2, d4, d4 - d2)
end
println("-"^80)
worst = maximum(abs((A[(P.name,400)] - A[("baseline",400)]) -
                    (A[(P.name,200)] - A[("baseline",200)])) for P in POLICIES)
@printf("largest movement in a reported difference: %.4f\n", worst)
println("DONE")
