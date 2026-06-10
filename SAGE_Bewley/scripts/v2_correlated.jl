# Correlated types: does it matter WHO the givers are?
#
# Types are (social motive) x (agency tier) cells coupled through the shared
# public good Q. The agency tiers scale the alpha vector (within-cell income
# risk kept): disadvantaged = 0.9x, advantaged = 1.1x. Total giver share fixed
# at 0.2 (FGF-scale); we move the givers across tiers:
#   independent : givers split across tiers by tier size
#   poor givers : all givers in the disadvantaged tier
#   rich givers : all givers in the advantaged tier
# Each tier is half the population. Remaining mass is conditional cooperators.
#
# Hypothesis: low-agency agents face a lower return to work, so the same
# warm-glow motive buys MORE contributed time. Where the givers sit should
# change how much public good the same population of givers supplies.
#
#   julia --project=. scripts/v2_correlated.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

const KAPPA = 8.0
const ALO = [0.765, 0.911] .* 0.9    # disadvantaged tier
const AHI = [0.765, 0.911] .* 1.1    # advantaged tier

cell(name, share, mode, α; κ = KAPPA) =
    (name = name, share = share,
     p = SAGEParams(social_mode = mode, social_strength = mode === :off ? 0.0 : κ, α = α))

function aggregate_Q(cells, Q_in; cache)
    Qout = 0.0; per = Float64[]
    for t in cells
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

function solve_population(cells; Q0 = 0.3, damp = 0.5, tol = 1e-5, maxit = 200)
    cache = Dict{String,Float64}()
    Q = Q0; per = Float64[]
    for _ in 1:maxit
        Qout, per = aggregate_Q(cells, Q; cache = cache)
        abs(Qout - Q) < tol && (Q = Qout; break)
        Q = damp * Q + (1 - damp) * Qout
    end
    return Q, per
end

scenarios = Dict(
    "independent" => [cell("gL", 0.10, :warmglow,  ALO), cell("gH", 0.10, :warmglow,  AHI),
                      cell("cL", 0.40, :multiplier, ALO), cell("cH", 0.40, :multiplier, AHI)],
    "poor givers" => [cell("gL", 0.20, :warmglow,  ALO),
                      cell("cL", 0.30, :multiplier, ALO), cell("cH", 0.50, :multiplier, AHI)],
    "rich givers" => [cell("gH", 0.20, :warmglow,  AHI),
                      cell("cL", 0.50, :multiplier, ALO), cell("cH", 0.30, :multiplier, AHI)],
)

println("Correlated types at kappa = $KAPPA, giver share fixed at 0.20")
println("(tiers: alpha x0.9 disadvantaged, x1.1 advantaged; rest conditional)")
for name in ("independent", "poor givers", "rich givers")
    Q, per = solve_population(scenarios[name])
    @printf("  %-12s  Q = %.4f   per-cell q: %s\n", name, Q,
            join([@sprintf("%s=%.3f", c.name, q) for (c, q) in zip(scenarios[name], per)], "  "))
    flush(stdout)
end

println("\nGiver contribution by own agency (pure warmglow cells, kappa = $KAPPA):")
for (tag, α) in (("disadvantaged (x0.9)", ALO), ("baseline", [0.765, 0.911]), ("advantaged (x1.1)", AHI))
    s = SAGEBewley._solve_once(SAGEParams(social_mode = :warmglow, social_strength = KAPPA, α = α), 0.0)
    @printf("  %-22s q = %.4f\n", tag, s.Q)
    flush(stdout)
end
println("DONE")
