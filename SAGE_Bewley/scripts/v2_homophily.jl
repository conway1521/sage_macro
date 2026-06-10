# Homophily belonging channel: experiments under the honest (v1.1) parameters.
#
# A_eff[g] = (1-h)·Q + h·Qmean[g]: h = 0 is bridging (everyone draws belonging
# from the whole economy), h = 1 is bonding (only own group). Questions:
#   1. Does homophily SEGREGATE cohesion (group means diverging as h rises)?
#   2. Does concentrating the feedback within groups restore group-level
#      multiplicity that the economy-wide multiplier lost? (asymmetric starts)
#   3. Wellbeing: who gains and who loses from bonding-only belonging?
#
#   julia --project=. scripts/v2_homophily.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

const KAPPA = 8.0

println("[1] h sweep at kappa = $KAPPA: segregation of group cohesion")
println("      h     Q      Qmean_low  Qmean_high   gap")
for h in (0.0, 0.25, 0.5, 0.75, 1.0)
    p = SAGEParams(social_mode = :multiplier, social_strength = KAPPA, homophily = h)
    s = solve_model(p)
    gm = group_means(s)
    @printf("    %.2f  %.4f   %.4f     %.4f    %+.4f\n", h, s.Q, gm[1], gm[2], gm[2] - gm[1])
    flush(stdout)
end

println("\n[2] Group-level multiplicity hunt: h = 1, asymmetric starts, kappa in (8, 20)")
for κ in (8.0, 20.0)
    p = SAGEParams(social_mode = :multiplier, social_strength = κ, homophily = 1.0)
    s_ll = solve_model(p; A0 = [0.05, 0.05]); s_hh = solve_model(p; A0 = [0.95, 0.95])
    s_lh = solve_model(p; A0 = [0.05, 0.95]); s_hl = solve_model(p; A0 = [0.95, 0.05])
    for (tag, s) in (("low/low ", s_ll), ("high/high", s_hh), ("low/high", s_lh), ("high/low", s_hl))
        gm = group_means(s)
        @printf("    kappa=%4.1f start %-9s -> Qmean = [%.4f, %.4f]\n", κ, tag, gm[1], gm[2])
    end
    flush(stdout)
end

println("\n[3] Wellbeing under bonding vs bridging (kappa = $KAPPA)")
println("    Us by group: Lambda*B[g]*A_eff[g]")
for h in (0.0, 1.0)
    p = SAGEParams(social_mode = :multiplier, social_strength = KAPPA, homophily = h)
    s = solve_model(p)
    gm = group_means(s)
    for g in 1:2
        aeff = (1 - h) * s.Q + h * gm[g]
        @printf("    h=%.1f group %d: A_eff=%.4f  Us=%.4f\n", h, g, aeff, p.Λ * p.B[g] * aeff)
    end
    flush(stdout)
end
println("DONE")
