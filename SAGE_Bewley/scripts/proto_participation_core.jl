# Shared core for the participation-margin prototypes: household problem with
# work effort AND a discrete participation choice (lump QBAR), given the
# aggregate participation fabric Q_agg. Requires SAGEBewley to be included
# first.
#
# Policy recovery, and why it is what it is. The joint optimum over
# (next-assets, participation, effort) comes from a DiscreteDP on the asset
# grid. The participation indicator and effort are then TAKEN from that
# optimum: they are the consistent choices against the exact value function,
# and re-optimising effort against an interpolated continuation value collapses
# it to a corner once the social term is behavioural. Next-assets are then
# re-optimised CONTINUOUSLY with (d, e) held fixed, and the stationary
# distribution is built with the Young (2010) lottery.
#
# That last step was missing until 2026-09-06; the engine's own solve_model had
# done it this way all along. Adding it, and rescaling the asset grid (a_max
# had been 100 against a wealth distribution that ends near 2, so 97 percent
# of the nodes were empty), cut the na-sensitivity of every slope-based
# quantity to well under one percent. It did NOT settle the participation
# LEVEL, for a structural reason explained at the aggregate below; the logit
# solver that follows is the fix. Pass `continuous = false` to get the old
# grid-restricted behaviour back for comparison.

using QuantEcon, SparseArrays, LinearAlgebra

const QBAR = 0.10

# State-contingent transfer (stage 6): zero unless SAGEParams.transfer is set.
transfer_at(p::SAGEParams, i_z::Int) = isempty(p.transfer) ? 0.0 : p.transfer[i_z]

# Net budget effect of participating (stage 7): the tax credit rebated on the
# foregone earnings of the time lump, LESS the monetary cost of taking part.
# Both are paid only when d = 1, so every budget line below multiplies this by
# the participation indicator. With pcost = 0 it is the stage-6 credit exactly.
net_participation(p::SAGEParams, α, z) = p.partcredit * α * z * p.Z * QBAR - p.pcost

# State-contingent value of belonging (stage 7): one unless belong_scale is set.
belong_at(p::SAGEParams, i_z::Int) = isempty(p.belong_scale) ? 1.0 : p.belong_scale[i_z]

# Committed time before any choice (stage 8): zero unless time_floor is set.
floor_at(p::SAGEParams, i_z::Int) = isempty(p.time_floor) ? 0.0 : p.time_floor[i_z]

function solve_participation(p::SAGEParams, Q_agg::Float64; continuous::Bool = true,
                             full::Bool = false)
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz
    e_grid = range(0.0, 1.0, length = p.ne)
    n_s = na * nz
    sidx(i_a, i_z) = (i_z - 1) * na + i_a

    s_ind = Int[]; a_ind = Int[]; Rvec = Float64[]
    rows = Int[]; cols = Int[]; vals = Float64[]
    Dpol = zeros(Int, n_s, na)
    Epol = zeros(n_s, na)                  # effort at the joint optimum
    pair = 0
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR * belong_at(p, i_z)
        tr = transfer_at(p, i_z)
        for i_a in 1:na
            res = p.R * a[i_a]; s = sidx(i_a, i_z)
            for k in 1:na
                anext = a[k]
                best = -Inf; bestd = 0; beste = 0.0
                # net payoff of participating: the tax credit on the foregone
                # earnings of the time lump, less the monetary cost (stage 7)
                credit = net_participation(p, α, z); tfl = floor_at(p, i_z)
                for d in (0, 1)
                    tmax = 1.0 - tfl - QBAR * d
                    for e in e_grid
                        e > tmax && break
                        c = res + (1 + p.subsidy) * α * e * z * p.Z - p.lumptax - anext + credit * d + tr
                        c <= 0 && continue
                        T = tfl + e + QBAR * d
                        ut = p.Γ * (c^(1 - p.γ) / (1 - p.γ) -
                                    p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)) + belong * d
                        ut > best && (best = ut; bestd = d; beste = e)
                    end
                end
                best == -Inf && continue
                Dpol[s, k] = bestd
                Epol[s, k] = beste
                pair += 1
                push!(s_ind, s); push!(a_ind, k); push!(Rvec, best)
                for i_zn in 1:nz
                    push!(rows, pair); push!(cols, sidx(k, i_zn)); push!(vals, Π[i_z, i_zn])
                end
            end
        end
    end
    ddp = DiscreteDP(Rvec, sparse(rows, cols, vals, pair, n_s), p.β, s_ind, a_ind)
    res = solve(ddp, PFI)
    σ = res.sigma

    # the participation and effort decisions attached to each state
    dpol = [Dpol[sidx(i_a, i_z), σ[sidx(i_a, i_z)]] for i_a in 1:na, i_z in 1:nz]
    epol = [Epol[sidx(i_a, i_z), σ[sidx(i_a, i_z)]] for i_a in 1:na, i_z in 1:nz]

    # --- next-assets ------------------------------------------------------
    anext = zeros(na, nz)
    if continuous
        Vmat = reshape(res.v, na, nz)
        EV = Vmat * Π'                                  # EV[k, z] = E[V(a_k, z')|z]
        for i_z in 1:nz
            z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
            belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR * belong_at(p, i_z)
            tr = transfer_at(p, i_z)
            evz = view(EV, :, i_z)
            for i_a in 1:na
                d = dpol[i_a, i_z]; e = epol[i_a, i_z]
                credit = net_participation(p, α, z); tfl = floor_at(p, i_z)
                resources = p.R * a[i_a] + (1 + p.subsidy) * α * e * z * p.Z -
                            p.lumptax + credit * d + tr
                Tt = tfl + e + QBAR * d
                disut = p.Γ * p.ϕ * Tt^(1 + p.ψ) / (1 + p.ψ)
                hi = min(resources - 1e-10, a[end])
                if hi <= a[1]
                    anext[i_a, i_z] = a[1]
                    continue
                end
                f = ap -> begin
                    c = resources - ap
                    c <= 0 ? -Inf :
                    p.Γ * c^(1 - p.γ) / (1 - p.γ) - disut + belong * d +
                        p.β * SAGEBewley.interp_lin(a, evz, ap)
                end
                kbest = 1; vbest = -Inf
                @inbounds for k in 1:na
                    a[k] >= hi && break
                    v = f(a[k]); (v > vbest) && (vbest = v; kbest = k)
                end
                lo_b = a[max(kbest - 1, 1)]; hi_b = min(a[min(kbest + 1, na)], hi)
                anext[i_a, i_z] = lo_b < hi_b ?
                    SAGEBewley.golden_max(f, lo_b, hi_b)[1] : a[kbest]
            end
        end
    else
        for i_z in 1:nz, i_a in 1:na
            anext[i_a, i_z] = a[σ[sidx(i_a, i_z)]]
        end
    end

    # --- stationary distribution, Young (2010) lottery --------------------
    drows = Int[]; dcols = Int[]; dvals = Float64[]
    @inbounds for i_z in 1:nz, i_a in 1:na
        s = sidx(i_a, i_z)
        ap = anext[i_a, i_z]
        k = clamp(searchsortedlast(a, ap), 1, na - 1)
        w = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
        for i_zn in 1:nz
            pz = Π[i_z, i_zn]
            push!(drows, s); push!(dcols, sidx(k,   i_zn)); push!(dvals, pz * w)
            push!(drows, s); push!(dcols, sidx(k+1, i_zn)); push!(dvals, pz * (1 - w))
        end
    end
    Tt = transpose(sparse(drows, dcols, dvals, n_s, n_s))     # λ' = Tᵀ λ
    λv = fill(1.0 / n_s, n_s); λn = similar(λv)
    dist_d = Inf
    for _ in 1:20_000
        mul!(λn, Tt, λv)
        d = 0.0
        @inbounds for i in eachindex(λv)
            d = max(d, abs(λn[i] - λv[i]))
        end
        λv, λn = λn, λv
        dist_d = d
        d < 1e-12 && break
    end
    if dist_d >= 1e-12                       # slow-mixing fallback, as in the engine
        Td = Matrix(transpose(Tt))
        for _ in 1:45
            Td = Td * Td; Td ./= sum(Td, dims = 2)
        end
        λv = vec(sum(Td .* (1.0 / n_s), dims = 1))
    end
    λv ./= sum(λv)
    λ = reshape(λv, na, nz)

    # --- aggregates ---------------------------------------------------------
    # Node-based: each state participates or not according to its DP decision.
    # This aggregate is mass above a wealth threshold that sits on the atom at
    # the borrowing constraint, and it does NOT converge in na (spread of about
    # two points across na = 200 to 800 even on a well-scaled grid). An earlier
    # attempt to fix that here by bisecting the threshold and interpolating the
    # CDF was unsound (non-monotone in the belonging payoff) and was removed.
    # The resolution is solve_participation_logit below, whose theta -> 0 limit
    # is this model; use that for anything quantitative and keep this one as
    # the reference definition of the hard-threshold problem.
    astar = fill(NaN, nz)
    part = sum(λ[i_a, i_z] * dpol[i_a, i_z] for i_a in 1:na, i_z in 1:nz)
    partbase = 0.0
    for i_z in 1:nz, i_a in 1:na
        partbase += λ[i_a, i_z] * p.α[i_z] * z_vals[i_z] * dpol[i_a, i_z]
    end
    part_nodes = sum(λ[i_a, i_z] * dpol[i_a, i_z] for i_a in 1:na, i_z in 1:nz)
    # mean pre-subsidy labour income E[alpha e z], for budget-balance loops;
    # and the participation wage base E[alpha z | d=1] * P, which is the credit's
    # fiscal-cost base (the credit pays partcredit * alpha * z * Z * QBAR per
    # participating household, so cost per capita = partcredit * QBAR * Z * partbase)
    meaninc = 0.0
    for i_z in 1:nz, i_a in 1:na
        meaninc += λ[i_a, i_z] * p.α[i_z] * epol[i_a, i_z] * z_vals[i_z]
    end
    if full
        return (Q = QBAR * part, rate = part, meaninc = meaninc, partbase = partbase,
                a = a, lambda = λ, dpol = dpol, epol = epol, anext = anext,
                astar = astar, z_vals = z_vals, part_nodes = part_nodes)
    end
    return QBAR * part, part, meaninc, partbase
end

# =============================================================================
# Logit participation: the Brock-Durlauf (2001) form of the same model
# =============================================================================
# On top of the persistent belonging taste m, each period the household draws
# an i.i.d. type-1 extreme-value shock to the participation payoff, with scale
# theta. The choice then becomes a probability
#
#     P(d = 1 | a, z) = exp(v1/theta) / (exp(v0/theta) + exp(v1/theta)),
#
# where v_d is the value of the best (effort, next-assets) plan conditional on
# d, and the ex-ante value is the log-sum-exp. As theta -> 0 this collapses to
# the hard threshold above, so the proposition, stated for the hard-threshold
# model, is the theta -> 0 limit of this one.
#
# Why it exists. The hard-threshold aggregate is mass above a wealth cutoff,
# and the cutoff sits on top of a large atom at the borrowing constraint, so
# the aggregate would not settle under grid refinement (spread of about two
# points in the participation rate across na = 200 to 800, with the country
# ordering moving inside that band). With the choice smoothed, the aggregate
# is an integral of a smooth function over the wealth distribution and
# converges at the usual rate. Whether theta can be kept small enough to be a
# pure regulariser, or is economically real, is an empirical question that
# the theta-sensitivity test answers.
function solve_participation_logit(p::SAGEParams, Q_agg::Float64; theta::Float64 = 0.01,
                                   full::Bool = false, tol::Float64 = 1e-9,
                                   maxit::Int = 5000)
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz
    e_grid = range(0.0, 1.0, length = p.ne)
    n_s = na * nz
    sidx(i_a, i_z) = (i_z - 1) * na + i_a

    # --- conditional flow rewards: best effort for each (state, a', d) ------
    Rd = (fill(-Inf, n_s, na), fill(-Inf, n_s, na))     # index d+1
    Ed = (zeros(n_s, na), zeros(n_s, na))
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR * belong_at(p, i_z)
        credit = net_participation(p, α, z); tfl = floor_at(p, i_z)
        tr = transfer_at(p, i_z)
        for i_a in 1:na
            res = p.R * a[i_a]; s = sidx(i_a, i_z)
            for k in 1:na, d in (0, 1)
                best = -Inf; beste = 0.0
                tmax = 1.0 - tfl - QBAR * d
                for e in e_grid
                    e > tmax && break
                    c = res + (1 + p.subsidy) * α * e * z * p.Z - p.lumptax - a[k] + credit * d + tr
                    c <= 0 && continue
                    T = tfl + e + QBAR * d
                    ut = p.Γ * (c^(1 - p.γ) / (1 - p.γ) - p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)) +
                         belong * d
                    ut > best && (best = ut; beste = e)
                end
                Rd[d+1][s, k] = best; Ed[d+1][s, k] = beste
            end
        end
    end

    # --- warm start from the hard-max problem via DiscreteDP ----------------
    s_ind = Int[]; a_ind = Int[]; Rvec = Float64[]
    rows = Int[]; cols = Int[]; vals = Float64[]; pair = 0
    for i_z in 1:nz, i_a in 1:na
        s = sidx(i_a, i_z)
        for k in 1:na
            r = max(Rd[1][s, k], Rd[2][s, k])
            r == -Inf && continue
            pair += 1
            push!(s_ind, s); push!(a_ind, k); push!(Rvec, r)
            for i_zn in 1:nz
                push!(rows, pair); push!(cols, sidx(k, i_zn)); push!(vals, Π[i_z, i_zn])
            end
        end
    end
    ddp = DiscreteDP(Rvec, sparse(rows, cols, vals, pair, n_s), p.β, s_ind, a_ind)
    V = reshape(solve(ddp, PFI).v, na, nz)

    # --- logit value iteration --------------------------------------------
    v0 = zeros(na, nz); v1 = zeros(na, nz)
    k0 = ones(Int, na, nz); k1 = ones(Int, na, nz)
    Vn = similar(V)
    EV = similar(V)
    iters = 0
    for it in 1:maxit
        mul!(EV, V, Π')                                 # EV[k, z] = E[V(a_k, z') | z]
        @inbounds for i_z in 1:nz, i_a in 1:na
            s = sidx(i_a, i_z)
            b0 = -Inf; b1 = -Inf; kb0 = 1; kb1 = 1
            for k in 1:na
                ev = p.β * EV[k, i_z]
                r0 = Rd[1][s, k]; r1 = Rd[2][s, k]
                if r0 > -Inf
                    x = r0 + ev; (x > b0) && (b0 = x; kb0 = k)
                end
                if r1 > -Inf
                    x = r1 + ev; (x > b1) && (b1 = x; kb1 = k)
                end
            end
            v0[i_a, i_z] = b0; v1[i_a, i_z] = b1; k0[i_a, i_z] = kb0; k1[i_a, i_z] = kb1
            m = max(b0, b1)
            Vn[i_a, i_z] = m + theta * log(exp((b0 - m) / theta) + exp((b1 - m) / theta))
        end
        d = maximum(abs, Vn .- V)
        V, Vn = Vn, V
        iters = it
        d < tol && break
    end

    # --- policies: participation probability, and (e, a') per branch -------
    P1 = similar(V)
    @inbounds for i in eachindex(V)
        b0 = v0[i]; b1 = v1[i]
        P1[i] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
    end
    mul!(EV, V, Π')
    e_d = (zeros(na, nz), zeros(na, nz))
    a_d = (zeros(na, nz), zeros(na, nz))
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        belong = p.social_strength * p.Λ * Bz * Q_agg * QBAR * belong_at(p, i_z)
        credit = net_participation(p, α, z); tfl = floor_at(p, i_z)
        tr = transfer_at(p, i_z)
        evz = view(EV, :, i_z)
        for i_a in 1:na, d in (0, 1)
            s = sidx(i_a, i_z)
            kb = d == 0 ? k0[i_a, i_z] : k1[i_a, i_z]
            ee = Ed[d+1][s, kb]
            e_d[d+1][i_a, i_z] = ee
            resources = p.R * a[i_a] + (1 + p.subsidy) * α * ee * z * p.Z - p.lumptax + credit * d + tr
            Tt = tfl + ee + QBAR * d
            disut = p.Γ * p.ϕ * Tt^(1 + p.ψ) / (1 + p.ψ)
            hi = min(resources - 1e-10, a[end])
            if hi <= a[1] || Rd[d+1][s, kb] == -Inf
                a_d[d+1][i_a, i_z] = a[1]; continue
            end
            f = ap -> begin
                c = resources - ap
                c <= 0 ? -Inf :
                p.Γ * c^(1 - p.γ) / (1 - p.γ) - disut + belong * d +
                    p.β * SAGEBewley.interp_lin(a, evz, ap)
            end
            lo_b = a[max(kb - 1, 1)]; hi_b = min(a[min(kb + 1, na)], hi)
            a_d[d+1][i_a, i_z] = lo_b < hi_b ? SAGEBewley.golden_max(f, lo_b, hi_b)[1] : a[kb]
        end
    end

    # --- stationary distribution: lottery over a', mixture over d -----------
    drows = Int[]; dcols = Int[]; dvals = Float64[]
    @inbounds for i_z in 1:nz, i_a in 1:na
        s = sidx(i_a, i_z)
        for d in (0, 1)
            pd = d == 1 ? P1[i_a, i_z] : 1 - P1[i_a, i_z]
            pd <= 0 && continue
            ap = a_d[d+1][i_a, i_z]
            k = clamp(searchsortedlast(a, ap), 1, na - 1)
            w = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
            for i_zn in 1:nz
                pz = Π[i_z, i_zn] * pd
                push!(drows, s); push!(dcols, sidx(k,   i_zn)); push!(dvals, pz * w)
                push!(drows, s); push!(dcols, sidx(k+1, i_zn)); push!(dvals, pz * (1 - w))
            end
        end
    end
    Tt = transpose(sparse(drows, dcols, dvals, n_s, n_s))
    λv = fill(1.0 / n_s, n_s); λn = similar(λv); dist_d = Inf
    for _ in 1:20_000
        mul!(λn, Tt, λv)
        dd = 0.0
        @inbounds for i in eachindex(λv); dd = max(dd, abs(λn[i] - λv[i])); end
        λv, λn = λn, λv; dist_d = dd
        dd < 1e-12 && break
    end
    if dist_d >= 1e-12
        Td = Matrix(transpose(Tt))
        for _ in 1:45; Td = Td * Td; Td ./= sum(Td, dims = 2); end
        λv = vec(sum(Td .* (1.0 / n_s), dims = 1))
    end
    λv ./= sum(λv)
    λ = reshape(λv, na, nz)

    # --- aggregates: smooth in everything ----------------------------------
    part = 0.0; meaninc = 0.0; partbase = 0.0
    @inbounds for i_z in 1:nz, i_a in 1:na
        w = λ[i_a, i_z]; p1 = P1[i_a, i_z]
        part     += w * p1
        meaninc  += w * p.α[i_z] * z_vals[i_z] * (p1 * e_d[2][i_a, i_z] + (1 - p1) * e_d[1][i_a, i_z])
        partbase += w * p1 * p.α[i_z] * z_vals[i_z]
    end
    if full
        return (Q = QBAR * part, rate = part, meaninc = meaninc, partbase = partbase,
                a = a, lambda = λ, P1 = P1, e_d = e_d, a_d = a_d, V = V,
                z_vals = z_vals, iters = iters, theta = theta)
    end
    return QBAR * part, part, meaninc, partbase
end
