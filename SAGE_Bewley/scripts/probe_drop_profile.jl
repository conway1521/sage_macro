# Where does the consumption drop on job loss come from? One household problem
# per country (lower-education cell, most and least patient discount types, the
# calibrated belonging scale at mid-range), the drop 1 - c_U(a) / c_E(a) at the
# same assets and latent productivity, by liquid wealth in years of the type's
# mean earnings, and its average by wealth quintile of the type's own stationary
# distribution. Reproduces the aggregate measure (agency_shock.jl, dmass) state
# by state.
#
#   julia --project=scripts/run_env scripts/probe_drop_profile.jl
include(joinpath(@__DIR__, "modular_stack.jl"))
using Printf

function cbar_of(p, sol)
    a = sol.a; P1 = sol.P1; z, _ = SAGEBewley.income_process(p); ns = length(z)
    cbar = zeros(p.na, ns); ybar = zeros(p.na, ns)
    for s in 1:ns
        α = p.α[s]; credit = net_participation(p, α, z[s]); tr = transfer_at(p, s)
        for i in 1:p.na, d in (0, 1)
            w = d == 1 ? P1[i, s] : 1 - P1[i, s]; w <= 0 && continue
            lab = (1 + p.subsidy) * α * sol.e_d[d+1][i, s] * z[s] * p.Z
            cbar[i, s] += w * (p.R * a[i] + lab - p.lumptax + credit * d + tr - sol.a_d[d+1][i, s])
            ybar[i, s] += w * (lab + tr)
        end
    end
    cbar, ybar, z
end
for code in ("FR", "DE", "IT")
    c = country_config(code; config = "GSA", S = true, A = true)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    cell = cells_of(c)[1]
    ps = params_of(cT, cell)
    for (lab, p0) in (("least patient", ps[1]), ("most patient", ps[end]))
        p = update(p0; social_strength = 4.0)
        sol = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
        cbar, ybar, z = cbar_of(p, sol)
        ns = length(z); nh = ns ÷ 2; a = sol.a; λ = sol.lambda
        emp = nh+1:ns
        yE = sum(λ[:, s]' * ybar[:, s] for s in emp) / sum(λ[:, emp])
        drop(i, s) = 1 - cbar[i, s - nh] / cbar[i, s]
        dm = sum(λ[i, s] * drop(i, s) for i in 1:p.na, s in emp) / sum(λ[:, emp])
        @printf("\n%s cell 1, %s (beta %.3f, rr %.3f, f %.2f): mean earnings %.3f, mean drop among the employed %.3f\n",
                code, lab, p.β, c.rr, c.f_find, yE, dm)
        smid = nh + (nh + 1) ÷ 2
        print("  drop at the median productivity by assets (years of mean earnings):")
        for k in (0.0, 0.25, 0.5, 1.0, 2.0, 4.0)
            i = clamp(searchsortedfirst(a, k * yE), 1, p.na)
            @printf("  %.2f: %.3f", k, drop(i, smid))
        end
        # quintiles of the employed wealth distribution of this type
        wE = vec(sum(λ[:, emp], dims = 2)); cw = cumsum(wE) ./ sum(wE)
        print("\n  mean drop by wealth quintile:")
        lo = 1
        for q in 1:5
            hi = q == 5 ? p.na : max(lo, findfirst(>=(q / 5), cw))
            m = sum(λ[i, s] for i in lo:hi, s in emp)
            @printf("  Q%d (assets up to %.2f): %.3f", q, a[hi] / yE, m > 0 ? sum(λ[i, s] * drop(i, s) for i in lo:hi, s in emp) / m : NaN)
            lo = hi + 1; lo > p.na && break
        end
        @printf("\n  share of the employed with assets below one month of earnings: %.3f\n",
                sum(λ[i, s] for i in 1:p.na, s in emp if a[i] < yE / 12) / sum(λ[:, emp]))
        flush(stdout)
    end
end
println("DONE")
