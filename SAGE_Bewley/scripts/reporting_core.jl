# The reporting layer, per household solve (PLAN_MASTER.md, version 2.0, item 7).
#
# WELFARE. The value function splits into what it is made of, under the policies
# the household actually follows: consumption, effort (time), belonging, and the
# remainder, which is the value of having choices (the logit option value) plus
# numerical error. Each part is a policy evaluation, V_k = u_k + beta T V_k, with
# T the same transition the stationary distribution uses (the lottery on next
# assets, mixed over participation, times the income process). Consumption
# equivalents follow in `welfare_ce` (sage_modular.jl): the share of consumption,
# every year, that would make the baseline as good as the policy (Lucas 1987;
# Conesa, Kitao and Krueger 2009).
#
# PROPENSITIES. For the windfall the MPC uses (one month of the household's own
# labour and benefit income, as cash on hand), how much goes to liquid saving,
# to earnings (the marginal propensity to earn, usually negative) and to the
# probability of taking part. With no participation credit, consumption plus
# saving add up to the windfall plus the change in earnings exactly, which is
# the check.
#
# Sums over the stationary distribution, per state, so they pool across discount
# types and belonging scales like every other family field. One asset here; the
# two-asset summaries carry NaN until their version is built.

using SparseArrays, LinearAlgebra

"""
Linear interpolation that extrapolates the end segments instead of holding flat.
For windfall responses: holding flat beyond the top of the grid made households
there appear not to respond at all, which biased the MPC and the other
propensities down (the adding-up check came to 0.998 instead of 1, 2026-09-29).
"""
@inline function interp_ext(x::AbstractVector, y::AbstractVector, xq)
    n = length(x)
    k = xq <= x[1] ? 1 : (xq >= x[n] ? n - 1 : searchsortedlast(x, xq))
    t = (xq - x[k]) / (x[k+1] - x[k])
    (1 - t) * y[k] + t * y[k+1]
end

function welfare_parts(p::SAGEParams, sol)
    a = sol.a; λ = sol.lambda; P1 = sol.P1; na = length(a)
    z, Π = SAGEBewley.income_process(p); ns = length(z)
    κ = 1.0 + p.commute
    idx(i, s) = (s - 1) * na + i
    n = na * ns
    uc = zeros(n); ue = zeros(n); ub = zeros(n)
    abar = zeros(na, ns); lbar = zeros(na, ns); ybar = zeros(na, ns)
    rows = Int[]; cols = Int[]; vals = Float64[]
    @inbounds for s in 1:ns
        α = p.α[s]; credit = net_participation(p, α, z[s]); tr = transfer_at(p, s); tfl = floor_at(p, s)
        bel = p.social_strength * p.Λ * p.B[s] * QBAR * belong_at(p, s)
        for i in 1:na
            x = idx(i, s)
            for d in (0, 1)
                w = d == 1 ? P1[i, s] : 1 - P1[i, s]
                w <= 0 && continue
                e = sol.e_d[d+1][i, s]; ap = sol.a_d[d+1][i, s]
                lab = (1 + p.subsidy) * α * e * z[s] * p.Z
                c = max((p.R * a[i] + lab - p.lumptax + credit * d + tr - ap) / p.pc, 1e-10)
                T = tfl + κ * e + QBAR * d
                uc[x] += w * p.Γ * c^(1 - p.γ) / (1 - p.γ)
                ue[x] -= w * p.Γ * p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)
                ub[x] += w * bel * d
                abar[i, s] += w * ap; lbar[i, s] += w * lab; ybar[i, s] += w * (lab + tr)
                k = clamp(searchsortedlast(a, ap), 1, na - 1)
                wk = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                for s2 in 1:ns
                    pr = Π[s, s2] * w; pr <= 0 && continue
                    push!(rows, x); push!(cols, idx(k, s2)); push!(vals, pr * wk)
                    push!(rows, x); push!(cols, idx(k + 1, s2)); push!(vals, pr * (1 - wk))
                end
            end
        end
    end
    M = sparse(1:n, 1:n, ones(n), n, n) - p.β * sparse(rows, cols, vals, n, n)
    F = lu(M)
    Vc = F \ uc; Ve = F \ ue; Vb = F \ ub
    vmass = zeros(ns); vcmass = zeros(ns); vemass = zeros(ns); vbmass = zeros(ns)
    mpsmass = zeros(ns); mpemass = zeros(ns); mppmass = zeros(ns)
    @inbounds for s in 1:ns, i in 1:na
        m = λ[i, s]; m <= 0 && continue
        x = idx(i, s)
        vmass[s] += m * sol.V[i, s]; vcmass[s] += m * Vc[x]; vemass[s] += m * Ve[x]; vbmass[s] += m * Vb[x]
        Δ = ybar[i, s] / 12
        if Δ > 0
            ai = a[i] + Δ / p.R
            mpsmass[s] += m * (interp_ext(a, view(abar, :, s), ai) - abar[i, s]) / Δ
            mpemass[s] += m * (interp_ext(a, view(lbar, :, s), ai) - lbar[i, s]) / Δ
            mppmass[s] += m * (interp_ext(a, view(P1, :, s), ai) - P1[i, s])
        end
    end
    (vmass = vmass, vcmass = vcmass, vemass = vemass, vbmass = vbmass,
     mpsmass = mpsmass, mpemass = mpemass, mppmass = mppmass)
end

"The same fields, NaN: for summaries whose welfare and propensities are not built yet (two assets)."
welfare_parts_nan(ns) = (vmass = fill(NaN, ns), vcmass = fill(NaN, ns), vemass = fill(NaN, ns), vbmass = fill(NaN, ns),
                         mpsmass = fill(NaN, ns), mpemass = fill(NaN, ns), mppmass = fill(NaN, ns))
