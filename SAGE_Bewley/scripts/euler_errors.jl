# Euler-equation errors (Judd 1992) of a household solution: at every state
# and branch with next assets above the limit, how far consumption is from
# what the Euler equation implies, u'(c) = beta R E[sum_d' P_d' u'(c')], with
# next period's consumption interpolated from the solution itself. Reported as
# log10 of the absolute relative error, mass-weighted, for both solvers.
#
#   julia --project=scripts/run_env scripts/euler_errors.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

function consumption(p, s)
    a = s.a; z, _ = SAGEBewley.income_process(p); na, nz = p.na, p.nz
    c = (zeros(na, nz), zeros(na, nz))
    for j in 1:nz, i in 1:na, d in (0, 1)
        w = (1 + p.subsidy) * p.α[j] * z[j] * p.Z
        c[d+1][i, j] = p.R * a[i] + w * s.e_d[d+1][i, j] - p.lumptax + net_participation(p, p.α[j], z[j]) * d +
                       transfer_at(p, j) - s.a_d[d+1][i, j]
    end
    c
end
function euler_error(p, s)
    a = s.a; _, Π = SAGEBewley.income_process(p); na, nz = p.na, p.nz
    c = consumption(p, s)
    mu = [(1 - s.P1[i, j]) * max(c[1][i, j], 1e-12)^(-p.γ) + s.P1[i, j] * max(c[2][i, j], 1e-12)^(-p.γ)
          for i in 1:na, j in 1:nz]
    num = 0.0; den = 0.0; worst = 0.0
    for j in 1:nz, i in 1:na, d in (0, 1)
        pd = d == 1 ? s.P1[i, j] : 1 - s.P1[i, j]
        m = s.lambda[i, j] * pd
        ap = s.a_d[d+1][i, j]
        (m <= 0 || ap <= a[1] * 1.0001 || ap >= a[end]) && continue
        rhs = p.β * p.R * sum(Π[j, k] * SAGEBewley.interp_lin(a, view(mu, :, k), ap) for k in 1:nz)
        err = abs(1 - rhs^(-1 / p.γ) / c[d+1][i, j])
        num += m * err; den += m; worst = max(worst, err)
    end
    (mean = num / den, worst = worst)
end
c = country_config("FR"; config = "GSA", S = true, A = true)
cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
for (g, cell) in enumerate(cells_of(c)), u in (0.0, 4.0)
    base = update(params_of(cT, cell)[1]; social_strength = u)
    for (nm, pp) in (("grid", base), ("egm", update(base; solver = :egm)))
        s = solve_participation_logit(pp, 1.0; theta = c.theta, full = true)
        e = euler_error(pp, s)
        @printf("cell %d u %.0f %-5s mean error 10^%.2f  worst 10^%.2f  assets %.5f\n", g, u, nm,
                log10(e.mean), log10(e.worst), sum(s.lambda .* s.a))
        flush(stdout)
    end
end
println("DONE")
