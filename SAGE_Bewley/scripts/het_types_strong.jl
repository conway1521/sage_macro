# Follow-up to het_types_scope.jl: the SIGN of the committed-minority effect.
#
# With weak givers (who contribute less than the conditional crowd) a minority
# dilutes cohesion. The interesting case is STRONG unconditional givers, who
# out-contribute the conditional high equilibrium. Then their fixed floor can
# pull a low-start conditional majority UP, over its tipping point.
#
#   julia --project=. scripts/het_types_strong.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

base(; kwargs...) = SAGEParams(; na = 200, ne = 60, kwargs...)

# Q contributed by a pure warmglow population at strength theta (Q-invariant).
giver_Q(θ) = SAGEBewley._solve_once(base(social_mode = :warmglow, social_strength = θ), 0.0).Q

# Mixed population: share f of strong givers (fixed contribution Qg) plus
# conditional cooperators at strength kappa. Outer fixed point from start Q0.
function mixed_lowstart(f, Qg, κ; Q0 = 0.05, damp = 0.5, tol = 1e-5, maxit = 200)
    pc = base(social_mode = :multiplier, social_strength = κ)
    Q = Q0
    for _ in 1:maxit
        Qc = SAGEBewley._solve_once(pc, Q).Q
        Qout = f * Qg + (1 - f) * Qc
        abs(Qout - Q) < tol && (Q = Qout; break)
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q
end

κstar = 3.4

println("Giver contribution by strength (pure warmglow population):")
Qg = 0.0
for θ in (1.2, 2.0, 3.0, 4.0)
    g = giver_Q(θ)
    global Qg = g
    @printf("    theta = %.1f -> Q_giver = %.4f\n", θ, g)
    flush(stdout)
end
# Use the strongest givers (theta = 4.0, Qg from the loop above).
@printf("\nStrong givers contribute Q_giver = %.4f (vs conditional high eq ~0.978)\n", Qg)

println("\nCommitted-minority tipping from a LOW start (kappa* = $κstar):")
println("    share strong givers   Q(low start)")
for f in (0.0, 0.05, 0.10, 0.15, 0.20)
    Q = mixed_lowstart(f, Qg, κstar)
    @printf("    f = %.2f               %.4f\n", f, Q)
    flush(stdout)
end
println("\ndone")
