# The two-asset household problem (TWO_ASSET_DESIGN.md): liquid b, return R,
# and illiquid k, return Rk, which accrues to k and can be changed only at a
# fixed cost chi0. Effort, the participation logit, unemployment and dread are
# as in egm_core.jl.
#
# The nested endogenous grid method of Druedahl (2021). The post-decision value
# depends on next liquid b' and next illiquid k'. For every illiquid node k_j
# taken as k', the liquid problem is the one-asset EGM step (`egm_branch!`)
# with continuation V(., k_j, .), solved on the liquid grid as if the household
# held liquid b. Then:
#  - a keeper at (b, k) has k' = Rk k: the inner solution at b, interpolated
#    between the two illiquid nodes around Rk k;
#  - an adjuster at (b, k) chooses k' = k_j and holds the rest as liquid, so it
#    faces the inner problem at effective liquid b + (Rk k - chi0 - k_j) / R.
# The choice among adjusting targets and between keeping and adjusting carries
# logit smoothing of scale theta_adj, as participation does (Iskhakov,
# Jorgensen, Rust and Schjerning 2017). Default 0.01: at the participation
# scale (0.005) the iteration cycles; at 0.05 the smoothing itself moves the
# adjusting share from 9% to 22% (Italy, 2026-09-29); 0.01 and 0.02 agree. With chi0 so large that no adjustment
# is affordable and no illiquid wealth, the slice k = 0 is the one-asset
# problem exactly, which is the reduction test.

using Printf

"Illiquid grid: zero, then exponentially spaced to k_max."
illiquid_grid(p::SAGEParams) = SAGEBewley.exponential_grid(0.0, p.k_max, p.nk, p.pexp)

# linear interpolation on an increasing grid with extrapolation on the end segments
@inline function lin_at(x, y, xi, j)
    t = (xi - x[j]) / (x[j+1] - x[j])
    y[j] + t * (y[j+1] - y[j])
end

"""
    solve_two_asset_egm(p, Q_agg; theta, theta_adj, full, tol, maxit, warm)

Returns the one-asset fields where they carry over, over a state (b, k, s)
array of size (na, nk, nz): lambda, P1 and effort by state, the probability of
adjusting, and the grids, plus V and Vb for warm starts.
"""
function solve_two_asset_egm(p0::SAGEParams, Q_agg::Float64; theta::Float64 = 0.01,
                             theta_adj::Float64 = 0.01, full::Bool = false, tol::Float64 = 1e-9,
                             maxit::Int = 5000, warm = nothing, trace::Bool = false)
    # survival enters discounting; the distribution adds the newborns
    p = p0.death > 0 ? update(p0; β = p0.β * (1 - p0.death)) : p0
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    kg = illiquid_grid(p)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nk, nz = p.na, p.nk, p.nz
    nk >= 2 || error("the illiquid grid needs at least two points")

    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s))
           for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    bel = [p.social_strength * p.Λ * p.B[s] * Q_agg * QBAR * belong_at(p, s) for s in 1:nz]
    D = zeros(na, nz); Dp = zeros(na, nz)
    if p.dread > 0 && !isempty(p.dread_q)
        for s in 1:nz, k in 1:na
            D[k, s] = dread_at(p, s, a[k])
            q = p.dread_q[s]
            xh = p.R * a[k] + p.dread_hi[s]; xl = p.R * a[k] + p.dread_lo[s]
            uh = xh > 1e-4 ? xh^(-p.γ) : 0.0; ul = xl > 1e-4 ? xl^(-p.γ) : 0.0
            Dp[k, s] = p.Γ * p.dread * q * p.R * (uh - ul)
        end
    end
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    for s in 1:nz, d in (0, 1), i in 1:na
        c, e = egm_constrained(p, p.R * a[i] - a[1] + oth[s][d+1], wv[s], tfl[s], d)
        con_c[d+1][i, s] = c; con_e[d+1][i, s] = e
    end

    # keepers: k' = Rk k, between illiquid nodes j0 and j0 + 1 with weight om on the upper
    kn = [min(p.Rk * kg[m], kg[end]) for m in 1:nk]
    j0 = [clamp(searchsortedlast(kg, kn[m]), 1, nk - 1) for m in 1:nk]
    om = [clamp((kn[m] - kg[j0[m]]) / (kg[j0[m]+1] - kg[j0[m]]), 0.0, 1.0) for m in 1:nk]
    # adjusters: the shift in effective liquid wealth for each (current k_m, target k_j)
    shift = [(p.Rk * kg[m] - p.chi0 - kg[j]) / p.R for m in 1:nk, j in 1:nk]

    V = zeros(na, nk, nz); Vb = zeros(na, nk, nz)
    if warm !== nothing
        V .= warm.V; Vb .= warm.Vb
    else
        for s in 1:nz, m in 1:nk, i in 1:na
            c = con_c[1][i, s]; e = con_e[1][i, s]
            isnan(c) && (c = con_c[2][i, s]; e = con_e[2][i, s])
            c = isnan(c) ? 1e-6 : c + (p.Rk - 1) * kg[m]
            V[i, m, s] = egm_flow(p, c, tfl[s] + e) / (1 - p.β)
            Vb[i, m, s] = p.R * p.Γ * c^(-p.γ)
        end
    end

    cin = (zeros(na, nk, nz), zeros(na, nk, nz)); ein = (zeros(na, nk, nz), zeros(na, nk, nz))
    bpin = (zeros(na, nk, nz), zeros(na, nk, nz)); vin = (zeros(na, nk, nz), zeros(na, nk, nz))
    Vin = zeros(na, nk, nz); P1in = zeros(na, nk, nz); muin = zeros(na, nk, nz)
    Vn = similar(V); Vbn = similar(Vb); Padj = zeros(na, nk, nz)
    qadj = zeros(nk, na, nk, nz)          # adjusting targets: weight of k_j at (i, m, s)
    EV = zeros(na, nz); EVb = zeros(na, nz)
    aend = zeros(na); cend = zeros(na); eend = zeros(na)
    Vj = zeros(nk); Mj = zeros(nk); ptr = ones(Int, nk)
    iters = 0
    t_in = 0.0; t_out = 0.0
    hist = zeros(maxit); stall = 0.0; relax = 1.0; stalled = false
    for it in 1:maxit
        t0 = time()
        # inner: the liquid problem for every illiquid node taken as k'
        for j in 1:nk
            mul!(EV, view(V, :, j, :), Π'); mul!(EVb, view(Vb, :, j, :), Π')
            for s in 1:nz, d in (0, 1)
                egm_branch!(view(cin[d+1], :, j, :), view(ein[d+1], :, j, :), view(bpin[d+1], :, j, :),
                            view(vin[d+1], :, j, :), p, a, view(EV, :, s), view(EVb, :, s),
                            s, d, wv[s], oth[s][d+1], tfl[s], bel[s], con_c[d+1], con_e[d+1],
                            aend, cend, eend, view(D, :, s), view(Dp, :, s))
            end
        end
        @inbounds for x in eachindex(Vin)
            b0 = vin[1][x]; b1 = vin[2][x]; mx = max(b0, b1)
            Vin[x] = mx == -Inf ? -Inf : mx + theta * log(exp((b0 - mx) / theta) + exp((b1 - mx) / theta))
            P1in[x] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
            mu0 = b0 == -Inf ? 0.0 : cin[1][x]^(-p.γ); mu1 = b1 == -Inf ? 0.0 : cin[2][x]^(-p.γ)
            muin[x] = p.Γ * ((1 - P1in[x]) * mu0 + P1in[x] * mu1)
        end
        t1 = time(); t_in += t1 - t0
        # outer: keep or adjust
        @inbounds for s in 1:nz, m in 1:nk
            jl = j0[m]; w = om[m]
            fill!(ptr, 1)
            for i in 1:na
                Vk = (1 - w) * Vin[i, jl, s] + w * Vin[i, jl+1, s]
                Mk = (1 - w) * muin[i, jl, s] + w * muin[i, jl+1, s]
                vmax = -Inf
                for j in 1:nk
                    be = a[i] + shift[m, j]
                    if be < a[1]
                        Vj[j] = -Inf; Mj[j] = 0.0; continue
                    end
                    be = min(be, a[end])
                    q = ptr[j]
                    while q < na - 1 && a[q+1] <= be
                        q += 1
                    end
                    ptr[j] = q
                    Vj[j] = lin_at(a, view(Vin, :, j, s), be, q)
                    Mj[j] = max(lin_at(a, view(muin, :, j, s), be, q), 0.0)
                    Vj[j] > vmax && (vmax = Vj[j])
                end
                if vmax == -Inf
                    Va_ = -Inf; Ma = 0.0
                    for j in 1:nk; qadj[j, i, m, s] = 0.0; end
                else
                    ssum = 0.0
                    for j in 1:nk
                        Vj[j] == -Inf && (qadj[j, i, m, s] = 0.0; continue)
                        ev = exp((Vj[j] - vmax) / theta_adj); qadj[j, i, m, s] = ev; ssum += ev
                    end
                    Ma = 0.0
                    for j in 1:nk
                        qadj[j, i, m, s] /= ssum; Ma += qadj[j, i, m, s] * Mj[j]
                    end
                    Va_ = vmax + theta_adj * log(ssum)
                end
                if Va_ == -Inf
                    Vn[i, m, s] = Vk; Padj[i, m, s] = 0.0; Mbar = Mk
                else
                    mx = max(Vk, Va_)
                    Vn[i, m, s] = mx + theta_adj * log(exp((Vk - mx) / theta_adj) + exp((Va_ - mx) / theta_adj))
                    pa = 1 / (1 + exp((Vk - Va_) / theta_adj)); Padj[i, m, s] = pa
                    Mbar = (1 - pa) * Mk + pa * Ma
                end
                Vbn[i, m, s] = p.R * Mbar
            end
        end
        t_out += time() - t1
        dmin = Inf; dmax = -Inf
        @inbounds for x in eachindex(V)
            δ = Vn[x] - V[x]; δ < dmin && (dmin = δ); δ > dmax && (dmax = δ)
        end
        dist = p.β / (1 - p.β) * (dmax - dmin)
        # RELAXATION. The kinks that the keep-or-adjust choice puts in the liquid
        # problem can make the plain iteration cycle (Italy and France,
        # 2026-09-29). Convergence is judged on the full Bellman step (the bound
        # above), but when the best bound of the last 50 iterations is not 10%
        # below the best of the 50 before, each update moves only part of the way,
        # halving the step each time down to 1/16. The fixed point is unchanged.
        # A remaining stall below 1e-2 at the smallest step averages the last two
        # iterates and stops; `stalled` in the result records it and its size.
        hist[it] = dist
        if it > 100 && it % 50 == 0 && minimum(view(hist, it-49:it)) > 0.9 * minimum(view(hist, it-99:it-50))
            if relax > 1 / 16
                relax /= 2
            elseif dist < 1e-2
                stalled = true
            end
        end
        if dist < tol || stalled
            Vn .+= p.β / (1 - p.β) * 0.5 * (dmin + dmax)
            if stalled
                Vn .= 0.5 .* (Vn .+ V); Vbn .= 0.5 .* (Vbn .+ Vb); stall = dist
            end
        elseif relax < 1
            @inbounds for x in eachindex(V)
                Vn[x] = V[x] + relax * (Vn[x] - V[x]); Vbn[x] = Vb[x] + relax * (Vbn[x] - Vb[x])
            end
        end
        trace && (it % 100 == 0 || it < 4) && println("  it ", it, " dist ", dist, " relax ", relax, " adjusting ", sum(Padj) / length(Padj))
        if trace && it % 500 == 0
            dm = 0.5 * (dmin + dmax); worst = sortperm(vec(abs.((Vn .- V) .- dm)), rev = true)[1:6]
            for x in worst
                ci = Tuple(CartesianIndices(V)[x])
                println("    cycling at (b ", ci[1], ", k ", ci[2], ", s ", ci[3], "): change ", Vn[x] - V[x] - dm, ", adjust prob ", Padj[x])
            end
        end
        V, Vn = Vn, V; Vb, Vbn = Vbn, Vb
        iters = it
        (dist < tol || stalled) && break
    end

    # policies by state, for the distribution and the aggregates
    t2 = time()
    trace && @printf("  value iteration: inner %.1f s, outer %.1f s\n", t_in, t_out)
    λ, P1s, es = two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj; death = p0.death)
    trace && @printf("  distribution %.1f s\n", time() - t2)
    part = 0.0; meaninc = 0.0; partbase = 0.0
    @inbounds for s in 1:nz, m in 1:nk, i in 1:na
        w_ = λ[i, m, s]; w_ == 0 && continue
        part += w_ * P1s[i, m, s]
        meaninc += w_ * p.α[s] * z_vals[s] * es[i, m, s]
        partbase += w_ * P1s[i, m, s] * p.α[s] * z_vals[s]
    end
    full || return QBAR * part, part, meaninc, partbase
    (Q = QBAR * part, rate = part, meaninc = meaninc, partbase = partbase, a = a, k = kg,
     lambda = λ, P1 = P1s, e = es, Padj = Padj, V = V, Vb = Vb, z_vals = z_vals,
     iters = iters, stalled = stall, relax = relax, theta = theta, inner = (c = cin, e = ein, bp = bpin, P1 = P1in), qadj = qadj,
     j0 = j0, om = om, shift = shift)
end

"""
The stationary distribution over (b, k, s). The decision part maps (b, k, s)
to post-decision (b', k', s) by lotteries on both grids (Young 2010); the
income transition then mixes s. Mass starts at k = 0. Also returns the
participation probability and expected effort by state.
"""
function two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj; death = 0.0)
    na, nk, nz = length(a), length(kg), size(Π, 1)
    n = na * nk * nz
    idx(i, m, s) = i + (m - 1) * na + (s - 1) * na * nk
    rows = Int[]; cols = Int[]; vals = Float64[]
    P1s = zeros(na, nk, nz); es = zeros(na, nk, nz)
    function blot!(from, bp, j, s, wt)
        k = clamp(searchsortedlast(a, bp), 1, na - 1)
        w = clamp((a[k+1] - bp) / (a[k+1] - a[k]), 0.0, 1.0)
        push!(rows, from); push!(cols, idx(k, j, s)); push!(vals, wt * w)
        push!(rows, from); push!(cols, idx(k + 1, j, s)); push!(vals, wt * (1 - w))
    end
    @inbounds for s in 1:nz, m in 1:nk, i in 1:na
        from = idx(i, m, s); pa = Padj[i, m, s]
        # keeping: the two illiquid nodes around Rk k, inner solution at liquid b
        for (jj, wk) in ((j0[m], 1 - om[m]), (j0[m] + 1, om[m]))
            wt = (1 - pa) * wk; wt <= 0 && continue
            p1 = P1in[i, jj, s]
            P1s[i, m, s] += wt * p1
            es[i, m, s] += wt * ((1 - p1) * ein[1][i, jj, s] + p1 * ein[2][i, jj, s])
            p1 < 1 && blot!(from, bpin[1][i, jj, s], jj, s, wt * (1 - p1))
            p1 > 0 && blot!(from, bpin[2][i, jj, s], jj, s, wt * p1)
        end
        pa <= 0 && continue
        # adjusting: target k_j, inner solution at effective liquid wealth
        for j in 1:nk
            q = qadj[j, i, m, s]; wt = pa * q; wt <= 1e-12 && continue
            be = min(a[i] + shift[m, j], a[end])
            r = clamp(searchsortedlast(a, be), 1, na - 1)
            p1 = clamp(lin_at(a, view(P1in, :, j, s), be, r), 0.0, 1.0)
            e0 = lin_at(a, view(ein[1], :, j, s), be, r); e1 = lin_at(a, view(ein[2], :, j, s), be, r)
            b0 = max(lin_at(a, view(bpin[1], :, j, s), be, r), a[1]); b1 = max(lin_at(a, view(bpin[2], :, j, s), be, r), a[1])
            P1s[i, m, s] += wt * p1
            es[i, m, s] += wt * ((1 - p1) * max(e0, 0.0) + p1 * max(e1, 0.0))
            p1 < 1 && blot!(from, b0, j, s, wt * (1 - p1))
            p1 > 0 && blot!(from, b1, j, s, wt * p1)
        end
    end
    Tt = transpose(sparse(rows, cols, vals, n, n))
    λ = zeros(n)
    for s in 1:nz, i in 1:na; λ[idx(i, 1, s)] = 1.0; end
    λ ./= sum(λ)
    # Damped iteration: half the old distribution, half its image. The fixed
    # point is unchanged, and the damping removes the near-cycles that
    # deterministic growth of kept illiquid wealth creates, which stalled the
    # plain iteration (2026-09-29). Converged when the total absolute change in
    # one step is below 1e-11.
    # newborns: no wealth, income state drawn from the stationary distribution of Π
    born = fill(1.0 / nz, nz)
    for _ in 1:10_000; born = vec(born' * Π); end
    post = similar(λ); nxt = similar(λ)
    nit = 0
    for it in 1:50_000
        nit = it
        mul!(post, Tt, λ)
        P = reshape(post, na * nk, nz); Nx = reshape(nxt, na * nk, nz)
        mul!(Nx, P, Π)
        if death > 0
            nxt .*= 1 - death
            for s in 1:nz; nxt[idx(1, 1, s)] += death * born[s]; end
        end
        dd = 0.0
        @inbounds for x in eachindex(λ)
            v = 0.5 * (λ[x] + nxt[x]); dd += abs(v - λ[x]); nxt[x] = v
        end
        λ, nxt = nxt, λ
        get(ENV, "EGM2_TRACE", "0") == "1" && it in (10, 100, 1000, 5000, 20000, 49999) &&
            println("    it ", it, " change ", dd, " total mass ", sum(λ), " mass at k = 0 ", sum(view(reshape(λ, na, nk, nz), :, 1, :)))
        dd < 1e-11 && break
    end
    if get(ENV, "EGM2_TRACE", "0") == "1"
        rs = vec(sum(sparse(rows, cols, vals, n, n), dims = 2))
        println("  row sums of the decision operator: min ", minimum(rs), " max ", maximum(rs))
    end
    get(ENV, "EGM2_TRACE", "0") == "1" && println("  distribution iterations ", nit)
    λ ./= sum(λ)
    reshape(λ, na, nk, nz), P1s, es
end
