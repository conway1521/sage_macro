# Scoping prototype (v2): heterogeneous social types.
#
# Question: instead of imposing ONE social motive on every agent, let the
# population be a mix of types. Does this solve cleanly, is it cheap, and does
# it produce economics the homogeneous model cannot?
#
# Key structural fact this prototype establishes: permanent social types couple
# ONLY through the shared scalar public good Q (everyone benefits from the same
# aggregate cohesion). So we do NOT need to add a type dimension to the state
# space. We solve each type's sub-economy given a trial Q, mix the results by
# population share, and iterate Q to a fixed point. The existing engine is the
# inner solve, untouched.
#
#   Q_out(Q_in) = sum_t share_t * E_t[1 - e | Q_in]
#   fixed point: Q = Q_out(Q)
#
# Bistability is detected the robust way (as in social_cohesion.jl): solve from
# a low start and a high start; if they land on different aggregates there are
# multiple equilibria.
#
#   julia --project=. scripts/het_types_scope.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

struct SocialType
    name::String
    share::Float64
    p::SAGEParams
end

# Production grid: a coarse grid collapses the low equilibrium to the ceiling
# and hides the bistability, so the type probe must use the real grid.
base(; kwargs...) = SAGEParams(; na = 200, ne = 60, kwargs...)

# Total public good produced by the population at a trial aggregate Q_in.
# Q-invariant types (warmglow) are solved once and cached; Q-responsive types
# (multiplier) are re-solved each iteration.
function aggregate_Q(types::Vector{SocialType}, Q_in; cache)
    Qout = 0.0; per = Float64[]
    for t in types
        q = if t.p.social_mode === :multiplier
            SAGEBewley._solve_once(t.p, Q_in).Q
        else
            get!(cache, t.name) do
                SAGEBewley._solve_once(t.p, 0.0).Q
            end
        end
        push!(per, q); Qout += t.share * q
    end
    return Qout, per
end

# Outer fixed point on the shared public good from a given start Q0.
function solve_population(types::Vector{SocialType}; Q0 = 0.3, damp = 0.5,
                          tol = 1e-5, maxit = 200)
    cache = Dict{String,Float64}()
    Q = Q0; per = Float64[]
    for _ in 1:maxit
        Qout, per = aggregate_Q(types, Q; cache = cache)
        abs(Qout - Q) < tol && (Q = Qout; break)
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q, per
end

# Multiplicity test: low start vs high start. Bistable if they disagree.
function bistable(types::Vector{SocialType}; gap = 0.02)
    Qlo, _ = solve_population(types; Q0 = 0.05)
    Qhi, _ = solve_population(types; Q0 = 0.95)
    return Qlo, Qhi, abs(Qhi - Qlo) > gap
end

println("="^70)
println("v2 SCOPING: heterogeneous social types")
println("="^70)

# Type builders. Givers contribute a fixed amount (warmglow); conditional
# cooperators respond to the aggregate (multiplier). Giver strength is moderate
# so their floor is partial, not saturated.
giverθ = 1.2
giver(share) = SocialType("U-giver", share, base(social_mode = :warmglow,  social_strength = giverθ))
coop(share, κ; α = [0.765, 0.911]) =
    SocialType("C-coop", share, base(social_mode = :multiplier, social_strength = κ, α = α))

# --- 1. Find the bistable window for a PURE conditional population -----------
println("\n[1] Pure conditional cooperators: where is the bistable window?")
println("      kappa     Q_low     Q_high     gap   bistable")
κstar = 3.3; bestgap = -1.0
for κ in 3.2:0.2:4.2
    global κstar, bestgap
    Qlo, Qhi, b = bistable([coop(1.0, κ)])
    gap = abs(Qhi - Qlo)
    (b && gap > bestgap) && (bestgap = gap; κstar = κ)
    @printf("    %5.1f   %7.4f   %7.4f   %6.4f     %s\n", κ, Qlo, Qhi, gap, b ? "YES" : "no")
    flush(stdout)
end
println("\n    using kappa* = $κstar (widest bistable gap) for the mixing experiments")

# --- 2. Committed-minority tipping ------------------------------------------
# A conditional population stuck in the LOW equilibrium. Inject a minority of
# unconditional givers. Their fixed floor can destroy the low equilibrium and
# pull the conditional majority up. This is the headline NEW mechanism.
println("\n[2] Can a giver minority tip a low-equilibrium conditional majority?")
println("    If the low-start aggregate jumps up as givers are added, the")
println("    committed minority has destroyed the low equilibrium.")
println("    share givers   Q(low start)   Q(high start)   bistable still?")
for f in (0.0, 0.05, 0.10, 0.20, 0.30)
    types = SocialType[]
    f > 0       && push!(types, giver(f))
    (1 - f) > 0 && push!(types, coop(1 - f, κstar))
    Qlo, _ = solve_population(types; Q0 = 0.05)
    Qhi, _ = solve_population(types; Q0 = 0.95)
    @printf("    f = %.2f       %7.4f        %7.4f         %s\n",
            f, Qlo, Qhi, abs(Qhi - Qlo) > 0.02 ? "yes" : "NO (collapsed to one)")
end

# --- 3. Agency out vs agency in ---------------------------------------------
# v1 finding: with EQUAL agency a homogeneous multiplier population is NOT
# bistable; inequality is needed. Does that survive here, and does a giver
# minority change it?
println("\n[3] Agency out vs in (pure conditional population)")
println("                       Q_low     Q_high   bistable")
for (label, α) in (("equal agency ", [0.84, 0.84]), ("hetero agency", [0.765, 0.911]))
    Qlo, Qhi, b = bistable([coop(1.0, κstar; α = α)])
    @printf("    %-14s   %7.4f   %7.4f     %s\n", label, Qlo, Qhi, b ? "YES" : "no")
    flush(stdout)
end

println("\n" * "="^70)
println("done")
