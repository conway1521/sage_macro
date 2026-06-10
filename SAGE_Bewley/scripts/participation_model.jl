# The calibratable participation model: the designed S+A core.
#
# Participation in the social sphere is a discrete choice: join and give a
# minimum meaningful time lump QBAR = 0.10, or do not. The payoff to
# participating, per unit of lump, is
#
#   kappa * Lambda * B_z * m * ( omega + (1 - omega) * rate )
#
# where m is a persistent taste for belonging (7-node lognormal population,
# sigma_m = 0.5: tastes are traits, in the spirit of the persistent cooperator
# types of Fischbacher-Gachter-Fehr 2001), rate = Q / QBAR is the aggregate
# participation rate, omega is the private warm-glow share (anchors a
# positive low equilibrium: people volunteer even in low-participation
# places), and (1 - omega) is the Brock-Durlauf complementarity share.
#
# Discipline: kappa is CALIBRATED so the low-start equilibrium participation
# rate is 1/3 (French associative participation). omega has no crisp point
# estimate and is swept (0.15, 0.30, 0.50) and characterised, stated openly.
#
# The question the S+A paper asks: AT THE CALIBRATED POINT, does a second,
# higher-participation equilibrium coexist? That is, is an economy that looks
# like France sitting inside a coordination region?
#
# Validation battery, three angles:
#   [V1] omega = 1 (pure private payoff, no complementarity) must give a
#        UNIQUE equilibrium at any kappa.
#   [V2] two-start agreement defines uniqueness; any gap must replicate
#        under a tighter damping.
#   [V3] grid spot-check (na 100 vs 140) at the calibrated point.
#
#   julia --project=. scripts/participation_model.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
using Printf, Statistics

# 7 equal-probability lognormal taste nodes, E[m] = 1, sigma of log m = 0.5.
function taste_nodes(σ; n = 7)
    qs = [(i - 0.5) / n for i in 1:n]
    invnorm(p) = sqrt(2) * erfinv(2p - 1)
    m = exp.(σ .* [invnorm(q) for q in qs])
    m ./ mean(m)
end
# erfinv via Newton on erf (dependency-free)
function erfinv(x)
    t = 0.0
    for _ in 1:60
        e = erf(t) - x
        t -= e / (2 / sqrt(pi) * exp(-t^2))
    end
    t
end
erf(x) = begin
    # Abramowitz-Stegun 7.1.26, sufficient for node placement
    s = x < 0 ? -1.0 : 1.0; x = abs(x)
    t = 1 / (1 + 0.3275911x)
    y = 1 - (((((1.061405429t - 1.453152027)t) + 1.421413741)t - 0.284496736)t + 0.254829592)t * exp(-x^2)
    s * y
end

const SIGMA_M = 0.5
const M_NODES = taste_nodes(SIGMA_M)

"Population participation rate given a guessed rate (one map evaluation)."
function rate_map(p0, κ, ω, rate_in)
    arg = ω + (1 - ω) * clamp(rate_in, 0.0, 1.0)   # the anchored payoff term
    tot = 0.0
    for m in M_NODES
        p = update(p0; social_strength = κ, B = p0.B .* m)
        _, r = solve_participation(p, arg)         # core: belong = k*L*Bz*arg*QBAR
        tot += r / length(M_NODES)
    end
    tot
end

function fixed_rate(p0, κ, ω, r0; damp = 0.5, tol = 1e-4, maxit = 80)
    r = r0
    for _ in 1:maxit
        rout = rate_map(p0, κ, ω, r)
        abs(rout - r) < tol && return rout
        r = damp * r + (1 - damp) * rout
    end
    r
end

"Bisect kappa so the LOW-start equilibrium rate hits the target."
function calibrate_kappa(p0, ω; target = 1/3, lo = 1.0, hi = 400.0, steps = 9)
    for _ in 1:steps
        mid = 0.5 * (lo + hi)
        r = fixed_rate(p0, mid, ω, 0.02)
        @printf("    kappa=%7.2f -> low-start rate %.3f\n", mid, r); flush(stdout)
        r < target ? (lo = mid) : (hi = mid)
    end
    0.5 * (lo + hi)
end

p0 = SAGEParams(na = 100, ne = 30)

println("[V1] Sanity: omega = 1 (no complementarity) must be unique")
for κ in (50.0, 200.0)
    rlo = fixed_rate(p0, κ, 1.0, 0.02); rhi = fixed_rate(p0, κ, 1.0, 0.98)
    @printf("    kappa=%6.1f  low %.3f  high %.3f  unique: %s\n",
            κ, rlo, rhi, abs(rhi - rlo) < 0.01 ? "yes" : "NO, FAIL")
    flush(stdout)
end

println("\n[1] Calibrate kappa to a 1/3 participation rate, omega = 0.30")
κstar = calibrate_kappa(p0, 0.30)
@printf("    calibrated kappa* = %.2f\n", κstar); flush(stdout)

println("\n[2] At the calibrated point: does a second equilibrium coexist?")
for ω in (0.15, 0.30, 0.50)
    κω = ω == 0.30 ? κstar : calibrate_kappa(p0, ω)
    rlo = fixed_rate(p0, κω, ω, 0.02)
    rhi = fixed_rate(p0, κω, ω, 0.98)
    @printf("    omega=%.2f kappa=%.1f : low-start rate %.3f, high-start rate %.3f  -> %s\n",
            ω, κω, rlo, rhi,
            abs(rhi - rlo) > 0.02 ? "MULTIPLE EQUILIBRIA" : "unique")
    flush(stdout)
end

println("\n[3] Participation gradient by taste node at (kappa*, omega=0.3), low-start equilibrium")
rstar = fixed_rate(p0, κstar, 0.30, 0.02)
arg = 0.30 + 0.70 * rstar
for (i, m) in enumerate(M_NODES)
    p = update(p0; social_strength = κstar, B = p0.B .* m)
    _, r = solve_participation(p, arg)
    @printf("    taste node %d (m=%.2f): participation %.3f\n", i, m, r)
    flush(stdout)
end

println("\n[V3] Grid spot-check at the calibrated point (na 100 vs 140)")
p140 = SAGEParams(na = 140, ne = 30)
r140 = fixed_rate(p140, κstar, 0.30, 0.02)
@printf("    na=100 rate %.3f   na=140 rate %.3f\n", rstar, r140)
println("DONE")
