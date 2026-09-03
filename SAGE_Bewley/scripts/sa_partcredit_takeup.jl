# Take-up incidence in the participation credit. Charitable-donation credits
# are claimed disproportionately by better-off households: itemisation,
# salience, and the paperwork of claiming all favour the high-education group.
# We model this as a take-up ratio tau: the low group's EFFECTIVE rebate is
# tau * rho while the high group receives the full rho. The fiscal cost counts
# only credits actually claimed, so it falls with take-up too.
#
# This does two things to the headline. It removes the near-corner result of
# the full-take-up case, and it produces a distributional table: an instrument
# that works with the social complementarity, but delivers its gains up the
# education gradient.
#
#   julia --project=. scripts/sa_partcredit_takeup.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B

d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow0 = (d[:, 1], d[:, 2], d[:, 3]); fhigh0 = (d[:, 1], d[:, 4], d[:, 5])

function eq_rate(fl, fh)
    _, _, e = trace_map(fl, fh, Blow, Bhigh, KAPPA, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    isempty(sts) ? NaN : sts[argmax([x[1] for x in sts])][1]
end

"Response family carrying the credit's fiscal base (4th column)."
function credit_family(α, ρ, T; u_max = 60.0, nu = 41, na = 200, ne = 40)
    u_grid = collect(range(0.0, u_max, length = nu))
    r = Float64[]; minc = Float64[]; pbase = Float64[]
    for u in u_grid
        p = update(cell_params(α; na = na, ne = ne, subsidy = 0.0, lumptax = T);
                   social_strength = u, partcredit = ρ)
        _, rate, mi, pb = solve_participation(p, 1.0)
        push!(r, rate); push!(minc, mi); push!(pbase, pb)
    end
    (u_grid, r, minc, pbase)
end

"Per-cell quantity at the equilibrium rate, column `col` of the family."
function cell_at(fam, B, rate, col)
    ms = taste_nodes_ln(SIGMA; n = 15)
    arg = OMEGA + (1 - OMEGA) * clamp(rate, 0.0, 1.0)
    mean(interp(fam[1], fam[col], KAPPA * m * B * arg) for m in ms)
end

"Financed credit with take-up ratio tau on the low-education group."
function run_takeup(ρ, τ; maxit = 3)
    T = 0.0; local fl, fh, r
    for it in 1:maxit
        fl = credit_family(CELL_LOW.α,  ρ * τ, T)
        fh = credit_family(CELL_HIGH.α, ρ,     T)
        r  = eq_rate(fl, fh)
        pbl = cell_at(fl, Blow,  r, 4); pbh = cell_at(fh, Bhigh, r, 4)
        Tnew = QBAR * (CELL_LOW.share * (ρ*τ) * pbl + CELL_HIGH.share * ρ * pbh)
        abs(Tnew - T) < 1e-4 && (T = Tnew; break)
        T = Tnew
    end
    rlo = cell_at(fl, Blow, r, 2); rhi = cell_at(fh, Bhigh, r, 2)
    (rate = r, rlo = rlo, rhi = rhi, cost = T)
end

# baseline
r0 = eq_rate(flow0, fhigh0)
rlo0 = cell_at(flow0, Blow, r0, 2)
rhi0 = cell_at(fhigh0, Bhigh, r0, 2)
mi0 = population_meaninc(flow0, fhigh0, Blow, Bhigh, KAPPA, OMEGA, SIGMA, r0)
@printf("baseline: rate %.3f (low %.3f, high %.3f), mean income %.3f\n\n", r0, rlo0, rhi0, mi0)

println("Participation credit with imperfect take-up by the low-education group")
@printf("%-22s | %-7s | %-7s | %-7s | %-8s | %s\n",
        "policy", "rate", "low", "high", "hi/lo", "cost / mi")
@printf("%-22s |  %.3f |  %.3f |  %.3f |  %.2f    |   ----\n",
        "baseline", r0, rlo0, rhi0, rhi0 == 0 ? NaN : rhi0/rlo0)
for (ρ, name) in ((0.66, "France 66%"), (0.25, "Gift Aid 25%"))
    for τ in (1.00, 0.50, 0.25)
        R = run_takeup(ρ, τ)
        @printf("%-22s |  %.3f |  %.3f |  %.3f |  %.2f    |  %.3f (%.1f%%)\n",
                "$name, take-up $(Int(100τ))%", R.rate, R.rlo, R.rhi,
                R.rlo == 0 ? NaN : R.rhi/R.rlo, R.cost, 100*R.cost/mi0)
        flush(stdout)
    end
end
println("\nDONE")
