# The two gate rows the other checks do not cover.
#
# ONE. The stationarity identity. Everything in agency_core.jl rests on
#
#     sum_lambda p(a, z) = E_lambda[h(a')] = E_lambda'[h] = E_lambda[h],
#
# which is what lets the aggregate of the forward-looking hardship probability
# be computed as the contemporaneous asset-poverty rate. It is a theorem, but
# it is a theorem about the solver's own transition, and if the next-asset
# policy and the stationary distribution were built from inconsistent objects
# it would fail. So p is computed explicitly here, household by household,
# from the participation mixture and the Young lottery, and its mean is
# compared with the contemporaneous rate. This is the identity row of the gate
# in MODEL_READINESS.md, Part 7.
#
# The omega row of the gate is run elsewhere; see the note at the foot of this
# file for why it cannot be done by sweeping omega alone.
#
#   julia --project=. scripts/agency_gate.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
using Printf, Statistics, DelimitedFiles, Serialization, LinearAlgebra

const THETA = 0.005
const GRID  = (a_max = 4.0, pexp = 3.0)
const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0),
                   collect(17.0:1.0:30.0))
const NQ, KAPPA, SIGMA, NA, NE = 2000, 10.00, 0.510, 200, 80
const MS = taste_nodes_ln(SIGMA; n = NQ)

res = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_agency_results.txt"))
    startswith(ln, "#") && continue
    p = split(strip(ln), '\t'); length(p) == 2 && (res[p[1]] = parse(Float64, p[2]))
end
const ABAR = res["abar0"]

# ============================================ ONE. the stationarity identity ==
println("="^72)
println("IDENTITY: mean forward hardship probability against asset poverty")
println("="^72)
println("p(a,z) built explicitly from the participation mixture and the Young")
println("lottery, then averaged under the same stationary distribution.")
println()
@printf("%-9s %-6s | %-10s %-10s %-10s\n", "cell", "u", "E[p]", "asset pov", "difference")
println("-"^58)
worst = 0.0
for cell in (CELL_LOW, CELL_HIGH)
    for u in (3.0, 4.5, 5.5, 7.0, 10.0)
        global worst
        p = update(cell_params(cell.α; na = NA, ne = NE, a_max = GRID.a_max,
                               pexp = GRID.pexp); social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = THETA, full = true)
        a = s.a; λ = s.lambda
        h(x) = x < ABAR ? 1.0 : 0.0
        # contemporaneous
        hnow = sum(λ[i, j] * h(a[i]) for i in 1:NA, j in 1:p.nz)
        # forward: mix over the participation branch, then the lottery on a'
        Ep = 0.0
        for j in 1:p.nz, i in 1:NA
            w = λ[i, j]; w <= 0 && continue
            p1 = s.P1[i, j]
            pi_ = 0.0
            for d in (0, 1)
                pd = d == 1 ? p1 : 1 - p1
                pd <= 0 && continue
                ap = s.a_d[d+1][i, j]
                k = clamp(searchsortedlast(a, ap), 1, NA - 1)
                wl = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                pi_ += pd * (wl * h(a[k]) + (1 - wl) * h(a[k+1]))
            end
            Ep += w * pi_
        end
        worst = max(worst, abs(Ep - hnow))
        @printf("%-9s %5.1f | %.6f   %.6f   %+.6f\n", cell.name, u, Ep, hnow, Ep - hnow)
        flush(stdout)
    end
end
println("-"^58)
@printf("largest departure from the identity: %.6f\n", worst)
@printf("%s\n", worst < 1e-3 ? "identity holds; the aggregate construction is sound" :
                               "IDENTITY FAILS, the aggregate construction is not sound")

# The omega row of the gate is NOT done here. An earlier version of this file
# swept omega with (kappa, sigma_m) held at the stage-5b values, which drives
# the model to a near-zero-participation equilibrium and says nothing about
# omega. The sweep has to recalibrate at each omega, as sa_omega_l4.txt does,
# so it is run by calling sa_agency.jl with the recalibrated triple:
#
#   julia --project=. scripts/sa_agency.jl 0.15 13.00 0.760
#   julia --project=. scripts/sa_agency.jl 0.50  8.00 0.430
#
# and collated by scripts/agency_omega_table.jl.
println("DONE")
