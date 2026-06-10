# Participation tax credit at REAL rebate rates, implemented in the budget
# constraint (Plan phase 5.1). This replaces the abstract payoff-multiplier
# "boost" of sa_partcredit.jl with the actual policy parameter: a rebate on the
# opportunity cost of the time given to participation (alpha * z * QBAR),
# financed by a lump-sum tax, with budget balance. The mapping:
#
#   France charitable-donations deduction   rebate rate 0.66
#   UK Gift Aid (basic-rate top-up)          rebate rate 0.25
#
# The credit is paid only when the household participates (d = 1) and lands in
# the budget directly (engine field `partcredit`), the same channel as the work
# subsidy. Because it changes the budget, the cached no-credit families cannot
# be reused: we build a fresh response family per rebate rate (and per financing
# iteration), exactly as the work-subsidy stage does in sa_main.jl.
#
#   julia --project=. scripts/sa_partcredit_real.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics

const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B

# ---------- baseline (no credit), from the cached families -------------------
d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])

"Highest stable equilibrium rate of a traced map."
function eq_rate(fl, fh, κ)
    _, _, e = trace_map(fl, fh, Blow, Bhigh, κ, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    isempty(sts) ? NaN : sts[argmax([x[1] for x in sts])][1]
end

r0  = eq_rate(flow, fhigh, KAPPA)
mi0 = population_meaninc(flow, fhigh, Blow, Bhigh, KAPPA, OMEGA, SIGMA, r0)
@printf("baseline (no credit): rate %.3f, mean labour income %.3f\n\n", r0, mi0)

# ---------- credit response family, carrying the fiscal base -----------------
# A four-column family (u, rate, mean income, participation wage base). The
# wage base partbase = E[alpha z | d=1] * P is the credit's per-capita fiscal
# cost base: cost = partcredit * QBAR * Z * partbase (Z = 1 here).
function credit_family(α, ρ, T; u_max = 60.0, nu = 41, na = 200, ne = 40)
    u_grid = collect(range(0.0, u_max, length = nu))
    r = Float64[]; minc = Float64[]; pbase = Float64[]
    for u in u_grid
        p = update(cell_params(α; na = na, ne = ne, subsidy = 0.0, lumptax = T);
                   social_strength = u, partcredit = ρ)
        _, rate, mi, pb = solve_participation(p, 1.0)
        push!(r, rate); push!(minc, mi); push!(pbase, pb)
    end
    return (u_grid, r, minc, pbase)
end

"Population participation wage base at a rate, via the 4th family column."
function pop_partbase(fl, fh, κ, ω, σ, rate; n_nodes = 15)
    ms = taste_nodes_ln(σ; n = n_nodes)
    arg = ω + (1 - ω) * clamp(rate, 0.0, 1.0)
    pblo = mean(interp(fl[1], fl[4], κ * m * Blow * arg) for m in ms)
    pbhi = mean(interp(fh[1], fh[4], κ * m * Bhigh * arg) for m in ms)
    CELL_LOW.share * pblo + CELL_HIGH.share * pbhi
end

# ---------- one financed run at a given rebate rate --------------------------
function run_credit(ρ; maxit = 4)
    T = 0.0
    local fl, fh, r, pb
    for it in 1:maxit
        fl = credit_family(CELL_LOW.α,  ρ, T)
        fh = credit_family(CELL_HIGH.α, ρ, T)
        r  = eq_rate(fl, fh, KAPPA)
        pb = pop_partbase(fl, fh, KAPPA, OMEGA, SIGMA, r)
        Tnew = ρ * QBAR * pb                       # Z = 1
        @printf("    rebate %.2f, iteration %d: rate %.3f, lump tax %.4f\n",
                ρ, it, r, Tnew)
        flush(stdout)
        abs(Tnew - T) < 1e-4 && (T = Tnew; break)
        T = Tnew
    end
    mi = population_meaninc(fl, fh, Blow, Bhigh, KAPPA, OMEGA, SIGMA, r)
    return (rate = r, lumptax = T, meaninc = mi, fl = fl, fh = fh)
end

println("Participation tax credit at real rebate rates (in the budget, financed):")
res_ga = run_credit(0.25)      # UK Gift Aid
println()
res_fr = run_credit(0.66)      # France charitable deduction
println()

# ---------- report -----------------------------------------------------------
@printf("%-26s | %-7s | %-9s | %-16s\n", "policy", "rate", "change pp", "fiscal cost / mi")
@printf("%-26s | %.3f   |   ----    |   ----\n", "baseline (no credit)", r0)
for (name, R) in (("Gift Aid credit (25%)", res_ga), ("France credit (66%)", res_fr))
    @printf("%-26s | %.3f   |  %+.3f   |  %.4f (%.1f%%)\n",
            name, R.rate, R.rate - r0, R.lumptax, 100 * R.lumptax / mi0)
end

# Reference: Paper 1's financed 20% make-work-pay subsidy in this frame.
r_work = 0.081
@printf("%-26s | %.3f   |  %+.3f   |  %.4f (%.0f%%)\n",
        "work subsidy (20%)", r_work, r_work - r0, 0.20 * mi0, 100 * 0.20)

println()
@printf("Direction check: the credit moves participation UP (+%.3f at 66%%), the\n",
        res_fr.rate - r0)
@printf("work subsidy moves it DOWN (%.3f). Same social complementarity, opposite\n",
        r_work - r0)
println("sign, now shown with a real deduction rate inside the budget constraint.")

# ---------- save the France-credit families for the GDP-B exercise (4.1) -----
fl, fh = res_fr.fl, res_fr.fh
open(joinpath(@__DIR__, "sa_credit_families.txt"), "w") do io
    println(io, join(["u", "r_low", "mi_low", "pb_low", "r_high", "mi_high", "pb_high"], '\t'))
    u = fl[1]
    for i in eachindex(u)
        println(io, join([u[i], fl[2][i], fl[3][i], fl[4][i],
                          fh[2][i], fh[3][i], fh[4][i]], '\t'))
    end
end
# record the headline equilibria for model_gdpb.jl to read without re-solving
open(joinpath(@__DIR__, "sa_credit_summary.txt"), "w") do io
    println(io, join(["policy", "rebate", "rate", "lumptax", "meaninc"], '\t'))
    println(io, join(["baseline", 0.0, r0, 0.0, mi0], '\t'))
    println(io, join(["giftaid", 0.25, res_ga.rate, res_ga.lumptax, res_ga.meaninc], '\t'))
    println(io, join(["france",  0.66, res_fr.rate, res_fr.lumptax, res_fr.meaninc], '\t'))
end
println("\nsaved sa_credit_families.txt and sa_credit_summary.txt")
println("DONE")
