# Transitions and impulse responses (PLAN_MASTER.md, version 2.0, item 7b),
# one asset, the social dimension off (G and G+A) in this first version.
#
# A shock whose whole path is known in advance (an "MIT shock"): the economy
# starts in its steady state, the path of job-loss rates delta_t (and so the
# income-process matrix Pi_t, from t to t + 1) departs from it, and returns.
# Unemployment is exogenous here, so its path, the cost of unemployment
# insurance and the lump-sum tax that balances it each period follow exactly,
# before any household problem is solved. Households are solved backward from
# the steady state at the horizon, one EGM step per period (egm_step, the body
# of solve_participation_egm's iteration with that period's parameters), and the
# distribution is moved forward with each period's policies. A zero shock
# returns the steady state: the test.
#
# The social dimension needs the participation path as a fixed point over time
# and households indexed by their belonging taste: the next version.

using SparseArrays, LinearAlgebra

"""
    egm_step(p, a, V, Va; theta)

One backward step: next period's V and Va (na x nz) and this period's
parameters (whose income process is the one from this period to the next)
give this period's V, Va and policies, exactly as one iteration of
`solve_participation_egm`.
"""
function egm_step(p::SAGEParams, a, V, Va; theta::Float64)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = length(a), length(z_vals)
    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s)) for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    bel = [p.social_strength * p.Λ * p.B[s] * QBAR * belong_at(p, s) for s in 1:nz]
    D = zeros(na, nz); Dp = zeros(na, nz)
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    for s in 1:nz, d in (0, 1), i in 1:na
        c, e = egm_constrained(p, p.R * a[i] - a[1] + oth[s][d+1], wv[s], tfl[s], d)
        con_c[d+1][i, s] = c; con_e[d+1][i, s] = e
    end
    EV = V * Π'; EVa = Va * Π'
    cd = (zeros(na, nz), zeros(na, nz)); e_d = (zeros(na, nz), zeros(na, nz))
    a_d = (zeros(na, nz), zeros(na, nz)); vd = (zeros(na, nz), zeros(na, nz))
    aend = zeros(na); cend = zeros(na); eend = zeros(na)
    for s in 1:nz, d in (0, 1)
        egm_branch!(cd[d+1], e_d[d+1], a_d[d+1], vd[d+1], p, a, view(EV, :, s), view(EVa, :, s),
                    s, d, wv[s], oth[s][d+1], tfl[s], bel[s], con_c[d+1], con_e[d+1], aend, cend, eend,
                    view(D, :, s), view(Dp, :, s))
    end
    Vn = similar(V); Van = similar(Va); P1 = zeros(na, nz)
    @inbounds for i in eachindex(Vn)
        b0 = vd[1][i]; b1 = vd[2][i]; m = max(b0, b1)
        Vn[i] = m + theta * log(exp((b0 - m) / theta) + exp((b1 - m) / theta))
        P1[i] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
        mu0 = b0 == -Inf ? 0.0 : cd[1][i]^(-p.γ); mu1 = b1 == -Inf ? 0.0 : cd[2][i]^(-p.γ)
        Van[i] = p.R * p.Γ * ((1 - P1[i]) * mu0 + P1[i] * mu1)
    end
    (V = Vn, Va = Van, P1 = P1, e_d = e_d, a_d = a_d, c_d = cd, Π = Π, z = z_vals)
end

"One forward step of the distribution with a period's policies and its income process."
function dist_step(a, λ, pol)
    na, nz = size(λ); λn = zeros(na, nz)
    @inbounds for s in 1:nz, i in 1:na
        m = λ[i, s]; m <= 0 && continue
        for d in (0, 1)
            pd = d == 1 ? pol.P1[i, s] : 1 - pol.P1[i, s]; pd <= 0 && continue
            ap = pol.a_d[d+1][i, s]
            k = clamp(searchsortedlast(a, ap), 1, na - 1)
            w = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
            for s2 in 1:nz
                pr = pol.Π[s, s2] * pd * m; pr <= 0 && continue
                λn[k, s2] += pr * w; λn[k+1, s2] += pr * (1 - w)
            end
        end
    end
    λn
end

"Per-period sums over a distribution: mass, consumption, effort of the employed, assets, poor hand-to-mouth."
function period_stats(p, a, λ, pol)
    z = pol.z; na, nz = size(λ)
    mass = 0.0; cons = 0.0; effE = 0.0; mE = 0.0; assets = 0.0; htm = 0.0; consU = 0.0; mU = 0.0
    @inbounds for s in 1:nz
        tr = transfer_at(p, s)
        for i in 1:na
            m = λ[i, s]; m <= 0 && continue
            mass += m; assets += m * a[i]
            c = (1 - pol.P1[i, s]) * pol.c_d[1][i, s] + pol.P1[i, s] * pol.c_d[2][i, s]
            e = (1 - pol.P1[i, s]) * pol.e_d[1][i, s] + pol.P1[i, s] * pol.e_d[2][i, s]
            cons += m * c
            y = (1 + p.subsidy) * p.α[s] * e * z[s] * p.Z + tr
            a[i] <= y / 52 && (htm += m)
            if z[s] > 0
                effE += m * e; mE += m
            else
                consU += m * c; mU += m
            end
        end
    end
    (mass = mass, cons = cons, effE = effE, mE = mE, assets = assets, htm = htm, consU = consU, mU = mU)
end

"""
    transition(c; delta_scale, T = 80)

The economy's path after a shock to job-loss rates: `delta_scale[t]` multiplies
both cells' separation rates in period t (1 after its end). G or G+A (S off),
one asset. Returns per-period national paths (unemployment, consumption, effort
of the employed, assets, poor hand-to-mouth, consumption of the unemployed
relative to the employed, the lump-sum tax) and the welfare of the path as a
consumption equivalent against staying in the steady state, overall and by cell.
"""
function transition(c::SAGEConfig; delta_scale::Vector{Float64}, T::Int = 80)
    c.S && error("the transition solver covers S off so far")
    c.E && error("the transition solver covers E off so far")
    ds = vcat(delta_scale, ones(max(0, T - length(delta_scale))))[1:T]
    cs = cells_of(c); bs, bw = betas_of(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    # the unemployment path and the UI cost per period, cell by cell, exactly
    base_ps = [params_of(cT, cs[g]) for g in 1:2]           # per cell, per discount type
    Πpath = [[begin
                  cg = SAGEConfig(c; delta = (g == 1 ? (c.delta[1] * ds[t], c.delta[2]) : (c.delta[1], c.delta[2] * ds[t])))
                  params_of(SAGEConfig(cg; lumptax = cT.lumptax), cells_of(cg)[g])[1].Π_override
              end for t in 1:T] for g in 1:2]
    μ = Vector{Vector{Vector{Float64}}}(undef, 2)
    for g in 1:2
        Π0 = base_ps[g][1].Π_override
        v = fill(1.0 / size(Π0, 1), size(Π0, 1)); for _ in 1:20_000; v = vec(v' * Π0); end
        μ[g] = [v]
        for t in 1:T; push!(μ[g], vec(μ[g][end]' * Πpath[g][t])); end
    end
    uicost(t) = sum(cs[g].share * sum(μ[g][t][s] * transfer_at(base_ps[g][1], s) for s in eachindex(μ[g][t])) for g in 1:2)
    lump = [c.lumptax + uicost(t) for t in 1:T]
    # households
    out = [(cons = zeros(T), effE = zeros(T), mE = zeros(T), assets = zeros(T), htm = zeros(T), consU = zeros(T), mU = zeros(T),
            mass = zeros(T), W1 = 0.0, Wss = 0.0, Vcss = 0.0) for _ in 1:2]
    welf = zeros(2, 3)   # per cell: W along the path at t = 1, W in the steady state, Vc in the steady state (mass-weighted)
    for g in 1:2, (k, p0) in enumerate(base_ps[g])
        p0 = update(p0; social_strength = 0.0)
        ss = solve_participation_logit(p0, 1.0; theta = c.theta, full = true)
        a = ss.a
        ps = [update(p0; lumptax = lump[t], Π_override = Πpath[g][t]) for t in 1:T]
        pols = Vector{Any}(undef, T)
        V, Va = ss.V, ss.Va
        for t in T:-1:1
            pol = egm_step(ps[t], a, V, Va; theta = c.theta)
            pols[t] = pol; V, Va = pol.V, pol.Va
        end
        λ = ss.lambda
        wk = bw[k] * cs[g].share
        for t in 1:T
            st = period_stats(ps[t], a, λ, pols[t])
            for f in (:cons, :effE, :mE, :assets, :htm, :consU, :mU, :mass)
                getfield(out[g], f)[t] += bw[k] * getfield(st, f)
            end
            λ = dist_step(a, λ, pols[t])
        end
        # welfare: expected value at t = 1 under the path against the steady state, same distribution
        wp = welfare_parts(p0, ss)
        welf[g, 1] += bw[k] * sum(ss.lambda .* pols[1].V)
        welf[g, 2] += bw[k] * sum(wp.vmass)
        welf[g, 3] += bw[k] * sum(wp.vcmass)
    end
    γ = base_ps[1][1].γ
    ce(dW, Vc) = (x = 1 + dW / Vc; x > 0 ? x^(1 / (1 - γ)) - 1 : NaN)
    nat(f) = [sum(cs[g].share * getfield(out[g], f)[t] for g in 1:2) for t in 1:T]
    mass = nat(:mass); mE = nat(:mE); mU = nat(:mU)
    (unemployment = mU ./ mass, cons = nat(:cons) ./ mass, effort_employed = nat(:effE) ./ mE,
     assets = nat(:assets) ./ mass, htm = nat(:htm) ./ mass,
     cons_unemployed_rel = (nat(:consU) ./ mU) ./ ((nat(:cons) .- nat(:consU)) ./ mE),
     lumptax = lump, delta_scale = ds,
     welfare = ce(sum(cs[g].share * (welf[g, 1] - welf[g, 2]) for g in 1:2), sum(cs[g].share * welf[g, 3] for g in 1:2)),
     welfare_cell = Tuple(ce(welf[g, 1] - welf[g, 2], welf[g, 3]) for g in 1:2))
end
