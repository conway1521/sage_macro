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
    bel = [p.social_strength * p.Λ * p.B[s] * p.qbar * belong_at(p, s) for s in 1:nz]
    D = zeros(na, nz); Dp = zeros(na, nz)
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    for s in 1:nz, d in (0, 1), i in 1:na
        c, e = egm_constrained(p, p.R * a[i] - a[1] + oth[s][d+1], wv[s], tfl[s], d; efix = isempty(p.effort_set) ? NaN : p.effort_set[s])
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
        Van[i] = p.R * p.Γ * ((1 - P1[i]) * mu0 + P1[i] * mu1) / p.pc
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
    # the job's effort levels where they are given (the floor, the transitory part, the proportional
    # tax): what a job asks does not move along the path
    c = floor_effort(c)
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
    # benefits paid, over the UNEMPLOYED states only: the employed states carry minus
    # the levy when levy_employed is set, which is not an insurance outlay (audit 2026-10-02)
    unemp = [SAGEBewley.income_process(base_ps[g][1])[1] .== 0 for g in 1:2]
    uicost(t) = sum(cs[g].share * sum(μ[g][t][s] * transfer_at(base_ps[g][1], s) for s in eachindex(μ[g][t]) if unemp[g][s]) for g in 1:2)
    # The floor's tax is held at its steady-state amount along the path (2026-10-06): its outlay moves
    # with the distribution, which is not known before the households are solved; the budget of the
    # floor is then balanced in the steady state and not period by period. Zero without a floor.
    lump = [c.lumptax + uicost(t) + floor_tax_of(c) for t in 1:T]
    # Under a proportional tax the period's total is raised at the period's rate on the period's
    # labour income per head, which falls when fewer are in work.
    prop = c.tax_mode === :prop
    zs = [SAGEBewley.income_process(base_ps[g][1])[1] for g in 1:2]
    labour(t) = sum(cs[g].share * sum(μ[g][t][s] * base_ps[g][1].α[s] * base_ps[g][1].effort_set[s] * zs[g][s] * base_ps[g][1].Z for s in eachindex(μ[g][t])) for g in 1:2)
    rate = prop ? [lump[t] / labour(t) for t in 1:T] : zeros(T)
    # households
    out = [(cons = zeros(T), effE = zeros(T), mE = zeros(T), assets = zeros(T), htm = zeros(T), consU = zeros(T), mU = zeros(T),
            mass = zeros(T), W1 = 0.0, Wss = 0.0, Vcss = 0.0) for _ in 1:2]
    welf = zeros(2, 3)   # per cell: W along the path at t = 1, W in the steady state, Vc in the steady state (mass-weighted)
    for g in 1:2, (k, p0) in enumerate(base_ps[g])
        p0 = update(p0; social_strength = 0.0)
        ss = solve_participation_logit(p0, 1.0; theta = c.theta, full = true)
        a = ss.a
        ps = prop ? [update(p0; subsidy = c.subsidy - rate[t], Π_override = Πpath[g][t]) for t in 1:T] :
                    [update(p0; lumptax = lump[t], Π_override = Πpath[g][t]) for t in 1:T]
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
     lumptax = lump, taxrate = rate, delta_scale = ds,
     welfare = ce(sum(cs[g].share * (welf[g, 1] - welf[g, 2]) for g in 1:2), sum(cs[g].share * welf[g, 3] for g in 1:2)),
     welfare_cell = Tuple(ce(welf[g, 1] - welf[g, 2], welf[g, 3]) for g in 1:2))
end

# ------------------------------------------------ the social dimension on --
# With S on, households differ by their steady-state belonging scale u (the
# nodes of the family grid): a household of taste m in cell g has scale
# kappa B_g arg m, with arg = omega + (1 - omega) x participation, the community
# fabric. Along a transition its scale moves with the fabric, u_t = u arg_t /
# arg_ss, so each node's path is solved with that scale path and the steady-
# state node weights (node_weights) integrate the tastes at every date, exactly
# as the steady state does. The fabric's path is a fixed point: guess it, solve
# every node backward and forward, aggregate participation (the unemployed rule
# imposed per node and date), update, damp, repeat. A zero shock returns the
# steady state exactly.

"One node's path: backward with its scale path, forward from its steady state; per-date sums."
function node_path(p0::SAGEParams, ss, rel, lump, Πpath, theta)
    T = length(rel); a = ss.a
    pols = Vector{Any}(undef, T); V, Va = ss.V, ss.Va
    for t in T:-1:1
        pt = update(p0; social_strength = p0.social_strength * rel[t], lumptax = lump[t], Π_override = Πpath[t])
        pol = egm_step(pt, a, V, Va; theta = theta); pols[t] = pol; V, Va = pol.V, pol.Va
    end
    λ = ss.lambda
    out = zeros(T, 12)   # partE massE partU massU cons effE mE assets htm consU mU  V1(first row only)
    for t in 1:T
        pol = pols[t]; z = pol.z; nz = length(z)
        pt = update(p0; lumptax = lump[t])
        st = period_stats(pt, a, λ, pol)
        pE = 0.0; mEs = 0.0; pU = 0.0; mUs = 0.0
        @inbounds for s in 1:nz, i in 1:length(a)
            m = λ[i, s]; m <= 0 && continue
            if z[s] > 0; pE += m * pol.P1[i, s]; mEs += m; else; pU += m * pol.P1[i, s]; mUs += m; end
        end
        out[t, :] .= (pE, mEs, pU, mUs, st.cons, st.effE, st.mE, st.assets, st.htm, st.consU, st.mU, 0.0)
        λ = dist_step(a, λ, pol)
    end
    out[1, 12] = sum(ss.lambda .* pols[1].V)
    out
end

"""
    transition_s(c; delta_scale, T = 60, maxit = 40, damp = 0.5, tol = 1e-7)

`transition` with the social dimension on (G+S, G+S+A; E off, one asset). Returns
the paths of `transition` plus participation and the community fabric, the
number of fixed-point iterations and the final gap.
"""
function transition_s(c::SAGEConfig; delta_scale::Vector{Float64}, T::Int = 60, maxit::Int = 40, damp::Float64 = 0.5, tol::Float64 = 1e-7)
    c.S || error("transition_s is for S on; use transition")
    c.E && error("the transition solver covers E off so far")
    ds = vcat(delta_scale, ones(max(0, T - length(delta_scale))))[1:T]
    r0 = solve_economy(c)
    cs = cells_of(c); bs, bw = betas_of(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    base_ps = [params_of(cT, cs[g]) for g in 1:2]
    Πpath = [[begin
                  cg = SAGEConfig(c; delta = (g == 1 ? (c.delta[1] * ds[t], c.delta[2]) : (c.delta[1], c.delta[2] * ds[t])))
                  params_of(SAGEConfig(cg; lumptax = cT.lumptax), cells_of(cg)[g])[1].Π_override
              end for t in 1:T] for g in 1:2]
    μ = Vector{Vector{Vector{Float64}}}(undef, 2)
    for g in 1:2
        Π0 = base_ps[g][1].Π_override
        v = fill(1.0 / size(Π0, 1), size(Π0, 1)); for _ in 1:20_000; v = vec(v' * Π0); end
        μ[g] = [v]; for t in 1:T; push!(μ[g], vec(μ[g][end]' * Πpath[g][t])); end
    end
    unemp = [SAGEBewley.income_process(base_ps[g][1])[1] .== 0 for g in 1:2]      # benefits only, as in `transition`
    lump = [c.lumptax + sum(cs[g].share * sum(μ[g][t][s] * transfer_at(base_ps[g][1], s) for s in eachindex(μ[g][t]) if unemp[g][s]) for g in 1:2) for t in 1:T]
    argss = c.omega + (1 - c.omega) * r0.rate
    nw = [node_weights(c, cs[g].B, argss) for g in 1:2]
    nw = [w ./ sum(w) for w in nw]
    jobs = [(g, k, j) for g in 1:2 for k in eachindex(bw) for j in eachindex(c.ugrid) if nw[g][j] > 0]
    sss = pmap(jb -> (p = update(base_ps[jb[1]][jb[2]]; social_strength = c.ugrid[jb[3]], solver = :egm);
                      solve_participation_logit(p, 1.0; theta = c.theta, full = true)), jobs)
    ratio = c.unemployed_ratio
    rel = ones(T); outs = nothing; gap = Inf; it = 0; rel_used = rel; rate_used = zeros(T)
    for iter in 1:maxit
        it = iter; rel_used = rel
        outs = pmap(x -> (jb = x[1]; p = update(base_ps[jb[1]][jb[2]]; social_strength = c.ugrid[jb[3]], solver = :egm);
                          node_path(p, x[2], rel, lump, Πpath[jb[1]], c.theta)), zip(jobs, sss))
        # participation by cell and date, the rule imposed per node and date
        rate = zeros(T)
        for (n, (g, k, j)) in enumerate(jobs)
            o = outs[n]
            for t in 1:T
                pE, mE_, pU, mU_ = o[t, 1], o[t, 2], o[t, 3], o[t, 4]
                r_ = ratio === nothing ? pE + pU : pE + min(ratio * (mE_ > 0 ? pE / mE_ : 0.0), 1.0) * mU_
                rate[t] += cs[g].share * bw[k] * nw[g][j] * r_ / (mE_ + mU_)
            end
        end
        rate_used = rate
        newrel = (c.omega .+ (1 - c.omega) .* rate) ./ argss
        gap = maximum(abs.(newrel .- rel))
        gap < tol && break
        rel = (1 - damp) .* rel .+ damp .* newrel
    end
    # aggregates with the same weights
    agg = zeros(T, 12)
    for (n, (g, k, j)) in enumerate(jobs)
        agg .+= (cs[g].share * bw[k] * nw[g][j]) .* outs[n]
    end
    mass = agg[:, 2] .+ agg[:, 4]
    # every path below is from the SAME iterate: the households' response to the
    # fabric `rel_used`, and the participation that response implies. At convergence
    # the two agree to `tol`; if the iterations ran out they do not, and it is said.
    gap < tol || @warn "transition_s stopped at maxit without converging" iterations = it gap tol
    participation = rate_used
    # welfare at t = 1 against the steady state (same distribution), from the nodes
    Wss = 0.0; Vcss = 0.0
    for (n, (g, k, j)) in enumerate(jobs)
        wp = welfare_parts(update(base_ps[g][k]; social_strength = c.ugrid[j]), sss[n])
        wt = cs[g].share * bw[k] * nw[g][j]
        Wss += wt * sum(wp.vmass); Vcss += wt * sum(wp.vcmass)
    end
    γ = base_ps[1][1].γ
    x = 1 + (agg[1, 12] - Wss) / Vcss
    (participation = participation, fabric = rel_used .* argss, converged = gap < tol, unemployment = agg[:, 11] ./ mass, cons = agg[:, 5] ./ mass,
     effort_employed = agg[:, 6] ./ agg[:, 7], assets = agg[:, 8] ./ mass, htm = agg[:, 9] ./ mass,
     cons_unemployed_rel = (agg[:, 10] ./ agg[:, 11]) ./ ((agg[:, 5] .- agg[:, 10]) ./ agg[:, 7]),
     lumptax = lump, delta_scale = ds, iterations = it, gap = gap, steady_state_rate = r0.rate,
     welfare = x > 0 ? x^(1 / (1 - γ)) - 1 : NaN)
end
