# Participation margin with taste dispersion (Brock-Durlauf direction).
# The common-threshold prototype is degenerate (all-or-nothing). Here the
# population mixes three taste tertiles for belonging (B scaled x0.5, x1.0,
# x1.5), each a sub-economy coupled through the participation fabric Q.
# Question: interior participation rates, and any fold at plausible kappa?
#   julia --project=. scripts/proto_participation_taste.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
using Printf

const TASTES = (0.5, 1.0, 1.5)            # B multipliers, tertiles
const SHARES = (1/3, 1/3, 1/3)

function population_Q(p0, κ, Q_in)
    Qout = 0.0; rates = Float64[]
    for (m, sh) in zip(TASTES, SHARES)
        p = update(p0; social_strength = κ, B = [0.80, 0.94] .* m)
        q, r = solve_participation(p, Q_in)
        Qout += sh * q; push!(rates, r)
    end
    return Qout, rates
end

function fp(p0, κ, Q0; damp = 0.5, tol = 1e-5, maxit = 120)
    Q = Q0; rates = Float64[]
    for _ in 1:maxit
        Qout, rates = population_Q(p0, κ, Q)
        abs(Qout - Q) < tol && return Qout, rates
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q, rates
end

p0 = SAGEParams(na = 120, ne = 40)
println("kappa sweep, taste-dispersed participation, two starts")
println("  kappa    Q_lo  rates_lo           Q_hi  rates_hi          bistable")
for κ in (20.0, 40.0, 60.0, 80.0, 120.0)
    Qlo, rlo = fp(p0, κ, 0.001)
    Qhi, rhi = fp(p0, κ, 0.099)
    @printf("  %5.0f  %.4f  [%s]   %.4f  [%s]   %s\n", κ,
            Qlo, join([@sprintf("%.2f", r) for r in rlo], " "),
            Qhi, join([@sprintf("%.2f", r) for r in rhi], " "),
            abs(Qhi - Qlo) > 0.005 ? "YES" : "no")
    flush(stdout)
end
println("DONE")
