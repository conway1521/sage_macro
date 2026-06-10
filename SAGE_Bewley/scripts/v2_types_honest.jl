# v2 re-verification under the honest (v1.1) parametrization, plus the
# literature-disciplined type distribution.
#
# Under v1.0 parameters (Frisch 4) the conditional-cooperator economy was
# bistable and a strong-giver minority tipped it. Under v1.1 (Frisch 0.5) the
# intensive-margin multiplier has no fold, so the questions become:
#   1. FGF economy: the Fischbacher-Gachter-Fehr (2001) type mix
#      (50% conditional cooperators, 30% free riders, 20% unconditional
#      givers) - where does its cohesion settle vs homogeneous economies?
#   2. Giver-minority LEVEL effect: how much does each percentage point of
#      committed givers raise equilibrium cohesion?
#   3. Residual multiplicity: two-start test on the mixed economy at high kappa.
#   4. Who carries the public good: per-type contribution decomposition.
#
#   julia --project=. scripts/v2_types_honest.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

struct SocialType
    name::String
    share::Float64
    p::SAGEParams
end

# One swept social strength for all motives (identification: kappa*Lambda*B).
const KAPPA = 8.0   # mid range of the honest sweep; sensitivity reported below

giver(share, κ = KAPPA)  = SocialType("giver",   share, SAGEParams(social_mode = :warmglow,  social_strength = κ))
coop(share, κ = KAPPA)   = SocialType("coop",    share, SAGEParams(social_mode = :multiplier, social_strength = κ))
selfish(share)           = SocialType("selfish", share, SAGEParams(social_mode = :off))

function aggregate_Q(types, Q_in; cache)
    Qout = 0.0; per = Float64[]
    for t in types
        q = if t.p.social_mode === :multiplier
            SAGEBewley._solve_once(t.p, Q_in).Q
        else
            get!(cache, t.name * string(t.p.social_strength)) do
                SAGEBewley._solve_once(t.p, 0.0).Q
            end
        end
        push!(per, q); Qout += t.share * q
    end
    return Qout, per
end

function solve_population(types; Q0 = 0.3, damp = 0.5, tol = 1e-5, maxit = 200)
    cache = Dict{String,Float64}()
    Q = Q0; per = Float64[]
    for _ in 1:maxit
        Qout, per = aggregate_Q(types, Q; cache = cache)
        abs(Qout - Q) < tol && (Q = Qout; break)
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q, per
end

println("[1] Homogeneous benchmarks at kappa = $KAPPA")
for (tag, types) in (("all selfish", [selfish(1.0)]),
                     ("all conditional", [coop(1.0)]),
                     ("all givers", [giver(1.0)]))
    Q, per = solve_population(types)
    @printf("    %-16s Q = %.4f\n", tag, Q)
    flush(stdout)
end

println("\n[2] The FGF (2001) economy: 50% conditional, 30% free riders, 20% givers")
QF, perF = solve_population([coop(0.5), selfish(0.3), giver(0.2)])
@printf("    Q = %.4f   per-type contribution: coop %.4f selfish %.4f giver %.4f\n",
        QF, perF[1], perF[2], perF[3])
@printf("    shares of the public good: coop %.1f%%  selfish %.1f%%  giver %.1f%%\n",
        100*0.5*perF[1]/QF, 100*0.3*perF[2]/QF, 100*0.2*perF[3]/QF)
flush(stdout)

println("\n[3] Giver-minority level effect (rest conditional, kappa = $KAPPA)")
println("    f_giver    Q     dQ per pp of givers")
function minority_sweep()
    Qprev = NaN
    for f in (0.0, 0.05, 0.10, 0.20, 0.30)
        Q, _ = solve_population(f > 0 ? [giver(f), coop(1 - f)] : [coop(1.0)])
        slope = isnan(Qprev) ? NaN : (Q - Qprev) / 5 * 100
        @printf("    %.2f     %.4f   %s\n", f, Q,
                isnan(slope) ? "-" : @sprintf("%+.3f pp", slope))
        Qprev = Q
        flush(stdout)
    end
end
minority_sweep()

println("\n[4] Residual multiplicity: two-start test, FGF mix, kappa in (8, 20)")
for κ in (8.0, 20.0)
    types = [coop(0.5, κ), selfish(0.3), giver(0.2, κ)]
    Qlo, _ = solve_population(types; Q0 = 0.05)
    Qhi, _ = solve_population(types; Q0 = 0.95)
    @printf("    kappa=%5.1f  Qlo=%.4f Qhi=%.4f  %s\n", κ, Qlo, Qhi,
            abs(Qhi - Qlo) > 0.02 ? "BISTABLE" : "single")
    flush(stdout)
end
println("DONE")
