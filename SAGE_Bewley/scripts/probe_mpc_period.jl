# How much of the low annual MPC is the annual period? (V3_START.md, decision D3.)
#
# The same household problem at a quarterly period, built so that nothing else
# changes: the quarterly transition matrix is the fourth root of the annual one
# (four quarters reproduce the annual income and employment process), the
# discount factor and the return are fourth roots, every flow (pay, benefits,
# taxes) is a quarter of its annual value, and the effort scale is rescaled so
# the effort condition is unchanged (consumption per period is a quarter, so
# phi is multiplied by 4^(gamma - 1); the logit scale likewise). Wealth is a
# stock and keeps its grid.
#
# The ANNUAL MPC of the quarterly model is the expected extra consumption over
# the four quarters after a windfall, per unit of windfall: the consumption
# function is iterated forward along the household's own policies. The windfall
# is one month of annual income, as everywhere. Hand-to-mouth: liquid wealth at
# most one week of annual income, the model's definition, in both.
#
# Not recalibrated: the quarterly model has its own hand-to-mouth share, so the
# comparison is made across impatient shares, as (hand-to-mouth, MPC) pairs.
#
#   julia --project=scripts/run_env scripts/probe_mpc_period.jl [CODE]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, LinearAlgebra
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
c0 = country_config(code; config = "G", S = false, A = false)

"Fourth root of a transition matrix, cleaned to a transition matrix; returns it and how far its fourth power is from the original."
function quarter(Π)
    Q = real.(Π^0.25); Q = max.(Q, 0.0); Q ./= sum(Q, dims = 2)
    (Q, maximum(abs.(Q^4 .- Π)))
end

"Expected consumption, earnings and labour-plus-benefit income by state, mixing the participation choice."
function flows(p, s)
    a = s.a; z = s.z_vals; na, ns = length(a), length(z)
    cb = zeros(na, ns); yb = zeros(na, ns)
    for st in 1:ns
        α = p.α[st]; credit = net_participation(p, α, z[st]); tr = transfer_at(p, st)
        for i in 1:na, d in (0, 1)
            w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; w <= 0 && continue
            lab = (1 + p.subsidy) * α * s.e_d[d+1][i, st] * z[st] * p.Z
            cb[i, st] += w * (p.R * a[i] + lab - p.lumptax + credit * d + tr - s.a_d[d+1][i, st])
            yb[i, st] += w * (lab + tr)
        end
    end
    (cb, yb)
end

"Cumulative expected consumption over `n` periods from each state, along the household's policies."
function cumulative(p, s, cb, n)
    a = s.a; Π = SAGEBewley.income_process(p)[2]; na, ns = size(cb)
    C = copy(cb)
    for _ in 2:n
        Cn = copy(cb)
        for st in 1:ns, i in 1:na, d in (0, 1)
            w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; w <= 0 && continue
            ap = s.a_d[d+1][i, st]
            for s2 in 1:ns
                Π[st, s2] > 0 && (Cn[i, st] += w * Π[st, s2] * interp_ext(a, view(C, :, s2), ap))
            end
        end
        C = Cn
    end
    C
end

function measure(c; quarterly)
    cs = cells_of(c); bs, bw = betas_of(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    k = quarterly ? 4 : 1
    mpc = 0.0; mpcq = 0.0; htm = 0.0; mass = 0.0; eff = 0.0; mE = 0.0; wl = Float64[]; ww = Float64[]; yann = 0.0; worst = 0.0
    for g in 1:2, (j, p0) in enumerate(params_of(cT, cs[g]))
        p = update(p0; social_strength = 0.0)
        if quarterly
            Q, err = quarter(p.Π_override); worst = max(worst, err)
            p = update(p; β = p.β^0.25, R = p.R^0.25, Z = p.Z / 4, transfer = p.transfer ./ 4, lumptax = p.lumptax / 4,
                       ϕ = p.ϕ * 4.0^(p.γ - 1), Π_override = Q)
        end
        s = solve_participation_logit(p, 1.0; theta = c.theta * (quarterly ? 4.0^(p.γ - 1) : 1.0), full = true)
        cb, yb = flows(p, s); C = cumulative(p, s, cb, k)
        a = s.a; wgt = cs[g].share * bw[j]
        for st in eachindex(s.z_vals), i in eachindex(a)
            m = wgt * s.lambda[i, st]; m <= 0 && continue
            ya = k * yb[i, st]                       # annual income at this state's rate
            Δ = ya / 12
            mass += m; yann += m * ya
            a[i] <= ya / 52 && (htm += m)
            push!(wl, a[i]); push!(ww, m)
            if Δ > 0
                ai = a[i] + Δ / p.R
                mpc += m * (interp_ext(a, view(C, :, st), ai) - C[i, st]) / Δ
                mpcq += m * (interp_ext(a, view(cb, :, st), ai) - cb[i, st]) / Δ
            end
            if s.z_vals[st] > 0
                for d in (0, 1)
                    w = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]
                    eff += m * w * s.e_d[d+1][i, st]
                end
                mE += m
            end
        end
    end
    o = sortperm(wl); cw = cumsum(ww[o]); med = wl[o][findfirst(>=(0.5 * cw[end]), cw)]
    (mpc = mpc / mass, mpc_period = mpcq / mass, htm = htm / mass, effort = eff / mE, wealth = med / (yann / mass), root_error = worst)
end

@printf("%s G, household problem at an annual and at a quarterly period (not recalibrated)\n", code)
@printf("%-22s %-10s %6s %8s %12s %8s %10s\n", "impatient share", "period", "htm", "MPC/yr", "MPC/period", "effort", "liq/inc")
for sh in (0.0, 0.05, 0.10, 0.20, 0.30)
    c = sh == 0 ? c0 : SAGEConfig(c0; beta_spread = 0.0, impatient_share = sh, beta_low = 0.85)
    for q in (false, true)
        r = measure(c; quarterly = q)
        @printf("%-22s %-10s %6.3f %8.3f %12.3f %8.4f %10.3f%s\n", sh == 0 ? "calibrated spread" : @sprintf("%.2f at 0.85", sh),
                q ? "quarterly" : "annual", r.htm, r.mpc, r.mpc_period, r.effort, r.wealth,
                q ? @sprintf("   (root of the transition matrix off by %.1e)", r.root_error) : "")
        flush(stdout)
    end
end
println("DONE")
