# The gate, on the modular layer and the corrected footing.
#
# MODEL_READINESS.md Part 7 makes a number quotable when five things hold:
# every discretisation it touches is shown converged, it satisfies an identity
# an independent formula predicts, a second code path reproduces it, it
# survives the parameters that have no point estimate, and it is not a sign
# against a threshold that depends on an unidentified parameter.
#
# test_modular.jl does the first. This does the second and third, at the
# calibrated footing: eleven productivity states, unemployment on, discount
# spread 0.037, poverty line anchored on mean income. The stage-6 and stage-7
# versions of these checks ran at two states and on the old machinery.
#
#   julia --project=. scripts/verify_modular.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics, LinearAlgebra

const CAL = SAGEConfig(S = true, A = true, unemployment = true,
                       beta_spread = 0.037, kappa = 9.90, sigma_m = 0.385)
println("="^96)
println("THE GATE, ON THE CORRECTED FOOTING")
println("="^96)
println(describe(CAL)); println()

R = solve_economy(CAL)
const THR = (R.ypov, R.abar)
@printf("reference economy: participation %.6f, agency %.6f, hardship %.6f\n", R.rate, R.A, R.hardship)
@printf("                   poverty line %.6f, asset threshold %.6f, hand-to-mouth %.6f\n\n",
        R.ypov, R.abar, R.hand_to_mouth)

# ===================================================== 1. the identity =======
# Everything in the agency column rests on
#     sum_lambda p(a, z) = E_lambda[h(a')] = E_lambda'[h] = E_lambda[h],
# which is what lets the aggregate of the forward-looking hardship probability
# be computed as the contemporaneous rate. It is a theorem about the solver's
# own transition, so if the next-asset policy and the stationary distribution
# were built from inconsistent objects it would fail. p is therefore built
# explicitly here, household by household, from the participation mixture and
# the Young lottery, at eleven productivity states, two employment states and
# five discount types.
println("1. STATIONARITY IDENTITY: mean forward hardship against the contemporaneous rate")
@printf("%-9s %-7s %-6s | %-12s %-12s %s\n", "cell", "u", "beta", "E[p]", "E[h]", "difference")
println("-"^66)
worst = 0.0
let cs = cells_of(CAL), (bs, bw) = betas_of(CAL), T = CAL.lumptax + ui_tax_of(CAL)
    for (gi, cell) in enumerate(cs), u in (3.0, 5.0, 8.0), bi in (1, 3, 5)
        p = update(cell_params_u(cell.α; δ = cell.δ, f = CAL.f_find, rr = CAL.rr, na = CAL.na,
                                 ne = CAL.ne, a_max = CAL.a_max, pexp = CAL.pexp,
                                 lumptax = T, β = bs[bi], nz = CAL.nz); social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = CAL.theta, full = true)
        a = s.a; λ = s.lambda; z = s.z_vals; nz = p.nz
        ypov, abar = THR
        h = zeros(CAL.na, nz)
        for i_z in 1:nz, i_a in 1:CAL.na
            α = p.α[i_z]; zz = z[i_z]; cap = (p.R - 1) * a[i_a]
            cr = p.partcredit * α * zz * p.Z * QBAR; tr = transfer_at(p, i_z)
            p1 = s.P1[i_a, i_z]
            for d in (0, 1)
                pd = d == 1 ? p1 : 1 - p1
                y = (1 + p.subsidy) * α * zz * p.Z * s.e_d[d+1][i_a, i_z] + cap -
                    p.lumptax + (d == 1 ? cr : 0.0) + tr
                h[i_a, i_z] += pd * ((a[i_a] < abar || y < ypov) ? 1.0 : 0.0)
            end
        end
        _, Π = SAGEBewley.income_process(p)
        Eh = sum(λ .* h); Ep = 0.0
        for i_z in 1:nz, i_a in 1:CAL.na
            w = λ[i_a, i_z]; w <= 0 && continue
            p1 = s.P1[i_a, i_z]; acc = 0.0
            for d in (0, 1)
                pd = d == 1 ? p1 : 1 - p1; pd <= 0 && continue
                ap = s.a_d[d+1][i_a, i_z]
                k = clamp(searchsortedlast(a, ap), 1, CAL.na - 1)
                wl = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                for i_zn in 1:nz
                    acc += pd * Π[i_z, i_zn] * (wl * h[k, i_zn] + (1 - wl) * h[k+1, i_zn])
                end
            end
            Ep += w * acc
        end
        global worst = max(worst, abs(Ep - Eh))
        @printf("%-9s %-7.1f %-6.3f | %-12.9f %-12.9f %+.2e\n",
                gi == 1 ? "low edu" : "high edu", u, bs[bi], Ep, Eh, Ep - Eh)
        flush(stdout)
    end
end
println("-"^66)
@printf("largest departure %.2e   %s\n\n", worst,
        worst < 1e-9 ? "identity holds" : "IDENTITY FAILS")

# ================================================ 2. an independent path =====
# Shares nothing with the driver but the household solver: every taste node is
# solved directly at its own belonging scale, with no response family and no
# interpolation anywhere.
println("2. INDEPENDENT PATH: every taste node solved directly, no response family")
const ND = 61
let cs = cells_of(CAL), (bs, bw) = betas_of(CAL), T = CAL.lumptax + ui_tax_of(CAL),
    ms = taste_nodes_ln(CAL.sigma_m; n = ND), arg = CAL.omega + (1 - CAL.omega) * R.rate,
    agrid = SAGEBewley.exponential_grid(1e-10, CAL.a_max, CAL.na, CAL.pexp)
    acc = Dict{String,Float64}(); Wt = zeros(CAL.na); Yt = zeros(length(YGRID)); Pt = zeros(length(YGRID))
    for (gi, cell) in enumerate(cs)
        p0s = [cell_params_u(cell.α; δ = cell.δ, f = CAL.f_find, rr = CAL.rr, na = CAL.na,
                             ne = CAL.ne, a_max = CAL.a_max, pexp = CAL.pexp, lumptax = T,
                             β = b, nz = CAL.nz) for b in bs]
        jobs = [(i, j) for j in 1:ND for i in eachindex(bs)]
        out = pmap(ij -> begin
                i, j = ij
                s = solve_participation_logit(update(p0s[i]; social_strength = CAL.kappa * ms[j] * cell.B * arg),
                                              1.0; theta = CAL.theta, full = true)
                cell_summary(p0s[i], s; thresholds = [THR])
            end, jobs)
        nt = length(bs)
        nodes = [collapse(out[(j-1)*nt+1 : j*nt], bw) for j in 1:ND]
        d = collapse(nodes, fill(1 / ND, ND))
        ast = sum(share_below_interp(agrid, view(d.W, i, :), THR[2]) for i in 1:size(d.W, 1))
        inc = sum(view(d.jinc, :, 1)); both = sum(view(d.jboth, :, 1))
        for (k, v) in (("rate", d.rate), ("inc", inc), ("asset", ast), ("union", inc + ast - both),
                       ("minc", d.minc), ("A", cell.α * (1 - (inc + ast - both))))
            acc[k] = get(acc, k, 0.0) + cell.share * v
        end
        Wt .+= cell.share .* vec(sum(d.W, dims = 1))
        Yt .+= cell.share .* d.Y; Pt .+= cell.share .* d.ypoor
        @printf("  %-9s rate %.6f  asset %.6f  U^a %.6f\n",
                gi == 1 ? "low edu" : "high edu", d.rate, ast, cell.α * (1 - (inc + ast - both)))
        flush(stdout)
    end
    htm = share_below_interp(agrid, Wt, (4 / 52) * acc["minc"])
    q5 = asset_poverty_by_quantile(Yt, Pt, 5)
    println()
    @printf("%-22s | %-12s %-12s %s\n", "quantity", "modular", "direct", "difference")
    println("-"^58)
    flush(stdout)
    for (nm, k, fv) in (("participation", "rate", R.rate), ("income-poor", "inc", R.income_poor),
                        ("asset-poor", "asset", R.asset_poor), ("hardship", "union", R.hardship),
                        ("agency", "A", R.A))
        @printf("%-22s | %-12.6f %-12.6f %+.6f\n", nm, fv, acc[k], acc[k] - fv)
    end
    @printf("%-22s | %-12.6f %-12.6f %+.6f\n", "hand-to-mouth", R.hand_to_mouth, htm, htm - R.hand_to_mouth)
    println()
    @printf("asset poverty by quintile, modular %s\n", join([@sprintf("%.4f", x) for x in R.asset_poor_by_quintile], " "))
    @printf("                          direct  %s\n", join([@sprintf("%.4f", x) for x in q5.rate], " "))
    flush(stdout)
end
println()
println("The asset grid and the choice-smoothing scale are checked by test_modular.jl,")
println("which moved agency by 0.0017 and 0.0014 on those rows. Repeating them here at")
println("the calibrated footing costs more than everything above put together, because")
println("four hundred asset nodes against twenty-two states is the most expensive")
println("configuration in the project, and it answers a question already answered.")
println("DONE")
