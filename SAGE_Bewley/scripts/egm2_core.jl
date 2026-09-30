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
    p0.pc == 1.0 || error("a consumption tax (pc) is not built for two assets yet")
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
    dist = two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj;
                                  death = p0.death, oth = oth, wv = wv, trs = [transfer_at(p, s) for s in 1:nz])
    λ = dist.lambda; P1s = dist.P1; es = dist.e
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
     lambda = λ, P1 = P1s, e = es, e_d = dist.e_d, cbar = dist.cbar, ybar = dist.ybar, post = dist.post,
     Pi = Π, Padj = Padj, V = V, Vb = Vb, z_vals = z_vals,
     iters = iters, stalled = stall, relax = relax, theta = theta, inner = (c = cin, e = ein, bp = bpin, P1 = P1in), qadj = qadj,
     j0 = j0, om = om, shift = shift)
end

"""
The stationary distribution over (b, k, s). The decision part maps (b, k, s)
to post-decision (b', k', s) by lotteries on both grids (Young 2010); the
income transition then mixes s. Mass starts at k = 0. Also returns the
participation probability and expected effort by state.
"""
function two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj;
                                death = 0.0, oth = nothing, wv = nothing, trs = nothing)
    na, nk, nz = length(a), length(kg), size(Π, 1)
    n = na * nk * nz
    idx(i, m, s) = i + (m - 1) * na + (s - 1) * na * nk
    rows = Int[]; cols = Int[]; vals = Float64[]
    P1s = zeros(na, nk, nz); es = zeros(na, nk, nz)
    # by participation branch, mixed over keeping and adjusting: effort (as
    # weighted sums, divided by the branch weight below), expected consumption
    # and labour-plus-transfer income, for the summaries (agency_shock.jl)
    e0s = zeros(na, nk, nz); e1s = zeros(na, nk, nz)
    cbar = zeros(na, nk, nz); ybar = zeros(na, nk, nz)
    haveC = oth !== nothing
    # consumption from the budget with the policies, as agency_summary does for
    # one asset, so the two agree exactly when the illiquid asset is inert
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
            e0s[i, m, s] += wt * (1 - p1) * ein[1][i, jj, s]; e1s[i, m, s] += wt * p1 * ein[2][i, jj, s]
            if haveC
                c0 = p.R * a[i] + wv[s] * ein[1][i, jj, s] + oth[s][1] - bpin[1][i, jj, s]
                c1 = p.R * a[i] + wv[s] * ein[2][i, jj, s] + oth[s][2] - bpin[2][i, jj, s]
                p1 < 1 && (cbar[i, m, s] += wt * (1 - p1) * c0; ybar[i, m, s] += wt * (1 - p1) * (wv[s] * ein[1][i, jj, s] + trs[s]))
                p1 > 0 && (cbar[i, m, s] += wt * p1 * c1; ybar[i, m, s] += wt * p1 * (wv[s] * ein[2][i, jj, s] + trs[s]))
            end
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
            e0 = max(e0, 0.0); e1 = max(e1, 0.0)
            es[i, m, s] += wt * ((1 - p1) * e0 + p1 * e1)
            e0s[i, m, s] += wt * (1 - p1) * e0; e1s[i, m, s] += wt * p1 * e1
            if haveC
                c0 = p.R * be + wv[s] * e0 + oth[s][1] - b0
                c1 = p.R * be + wv[s] * e1 + oth[s][2] - b1
                p1 < 1 && (cbar[i, m, s] += wt * (1 - p1) * c0; ybar[i, m, s] += wt * (1 - p1) * (wv[s] * e0 + trs[s]))
                p1 > 0 && (cbar[i, m, s] += wt * p1 * c1; ybar[i, m, s] += wt * p1 * (wv[s] * e1 + trs[s]))
            end
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
    @inbounds for x in eachindex(e0s)
        m0 = 1 - P1s[x]; e0s[x] = m0 > 1e-14 ? e0s[x] / m0 : 0.0
        e1s[x] = P1s[x] > 1e-14 ? e1s[x] / P1s[x] : 0.0
    end
    (lambda = reshape(λ, na, nk, nz), P1 = P1s, e = es, e_d = (e0s, e1s), cbar = cbar, ybar = ybar,
     post = (rows = rows, cols = cols, vals = vals))
end

# ------------------------------------------------------------- summaries --
"Grid for net wealth, liquid plus illiquid, on which the two-asset summaries record its distribution."
const NWGRID = SAGEBewley.exponential_grid(0.0, 80.0, 240, 3.0)

"""
    each_branch(f, sol, i, m, s)

Call f(wt, d, bprime, j) for every branch of state (i, m, s): keeping (the two
illiquid nodes around Rk k) and adjusting (each target k_j), each split by the
participation choice d, with its probability wt, next liquid wealth bprime and
next illiquid node j. The same branches, in the same order, as
`two_asset_distribution`.
"""
function each_branch(f, sol, i, m, s)
    a = sol.a; na = length(a); inn = sol.inner
    pa = sol.Padj[i, m, s]
    for (jj, wk) in ((sol.j0[m], 1 - sol.om[m]), (sol.j0[m] + 1, sol.om[m]))
        wt = (1 - pa) * wk; wt <= 0 && continue
        p1 = inn.P1[i, jj, s]
        p1 < 1 && f(wt * (1 - p1), 0, inn.bp[1][i, jj, s], jj)
        p1 > 0 && f(wt * p1, 1, inn.bp[2][i, jj, s], jj)
    end
    pa <= 0 && return
    nk = length(sol.k)
    for j in 1:nk
        wt = pa * sol.qadj[j, i, m, s]; wt <= 1e-12 && continue
        be = min(a[i] + sol.shift[m, j], a[end])
        r = clamp(searchsortedlast(a, be), 1, na - 1)
        p1 = clamp(lin_at(a, view(inn.P1, :, j, s), be, r), 0.0, 1.0)
        p1 < 1 && f(wt * (1 - p1), 0, max(lin_at(a, view(inn.bp[1], :, j, s), be, r), a[1]), j)
        p1 > 0 && f(wt * p1, 1, max(lin_at(a, view(inn.bp[2], :, j, s), be, r), a[1]), j)
    end
end

"""
    two_asset_cell_summary(p, sol; thresholds)

`cell_summary` for the two-asset solution: the same fields, with W the LIQUID
wealth distribution (OECD asset poverty is defined on liquid financial assets,
Balestra and Tonkin 2018) and capital income the liquid return only (the
illiquid return accrues to illiquid wealth, not to disposable income), plus K,
the illiquid distribution by state (cumulative on the illiquid grid).
"""
function two_asset_cell_summary(p::SAGEParams, sol; thresholds = nothing)
    a = sol.a; kg = sol.k; λ = sol.lambda; P1 = sol.P1; z = sol.z_vals
    na, nk, nz = length(a), length(kg), p.nz
    W = zeros(nz, na); K = zeros(nz, nk); N = zeros(nz, length(NWGRID))
    mass = zeros(nz); part = zeros(nz); ym_s = zeros(nz)
    Y = zeros(length(YGRID)); Ys = zeros(nz, length(YGRID)); ypoor = zeros(length(YGRID))
    ymean = 0.0; ymin_E = Inf
    thr = thresholds === nothing ? Tuple{Float64,Float64}[] : collect(thresholds)
    np = length(thr)
    jinc = zeros(nz, np); jboth = zeros(nz, np); eff_E = 0.0
    @inbounds for i_z in 1:nz, m in 1:nk, i_a in 1:na
        w = λ[i_a, m, i_z]
        w <= 0 && continue
        W[i_z, i_a] += w; K[i_z, m] += w; mass[i_z] += w
        # net wealth: split between the two NWGRID points around b + k
        nw = a[i_a] + kg[m]; q = clamp(searchsortedlast(NWGRID, nw), 1, length(NWGRID) - 1)
        t = clamp((nw - NWGRID[q]) / (NWGRID[q+1] - NWGRID[q]), 0.0, 1.0)
        N[i_z, q] += w * (1 - t); N[i_z, q+1] += w * t
        p1 = P1[i_a, m, i_z]; part[i_z] += w * p1
        α = p.α[i_z]; zz = z[i_z]
        cap = (p.R - 1) * a[i_a]
        credit = p.partcredit * α * zz * p.Z * QBAR
        tr = transfer_at(p, i_z)
        employed = zz > 0
        for d in (0, 1)
            wd = d == 1 ? w * p1 : w * (1 - p1)
            wd <= 0 && continue
            e = sol.e_d[d+1][i_a, m, i_z]
            y = (1 + p.subsidy) * α * zz * p.Z * e + cap - p.lumptax + (d == 1 ? credit : 0.0) + tr
            ymean += wd * y; ym_s[i_z] += wd * y
            employed && y < ymin_E && (ymin_E = y)
            employed && (eff_E += wd * e)
            k = searchsortedfirst(YGRID, y)
            if k <= length(YGRID)
                Y[k] += wd; Ys[i_z, k] += wd
                np > 0 && a[i_a] < thr[1][2] && (ypoor[k] += wd)
            end
            for q in 1:np
                y < thr[q][1] || continue
                jinc[i_z, q] += wd
                a[i_a] < thr[q][2] && (jboth[i_z, q] += wd)
            end
        end
    end
    for i_z in 1:nz
        cumsum!(view(W, i_z, :), view(W, i_z, :)); cumsum!(view(K, i_z, :), view(K, i_z, :))
        cumsum!(view(N, i_z, :), view(N, i_z, :))
        cumsum!(view(Ys, i_z, :), view(Ys, i_z, :))
    end
    cumsum!(Y, Y); cumsum!(ypoor, ypoor)
    (W = W, K = K, N = N, mass = mass, part = part, Y = Y, Ys = Ys, ymean = ymean, ym_s = ym_s,
     ymin_E = ymin_E, rate = sol.rate, minc = sol.meaninc, pbase = sol.partbase,
     jinc = jinc, jboth = jboth, thresholds = thr, eff_E = eff_E, ypoor = ypoor)
end

"""
    two_asset_agency_summary(p, sol)

`agency_summary` for the two-asset solution, the same fields plus the wealthy
hand-to-mouth. Hand-to-mouth, room to manoeuvre, the MPC and dread are on
LIQUID wealth. Poor hand-to-mouth hold no illiquid wealth and wealthy
hand-to-mouth some (Kaplan, Violante and Weidner 2014). The MPC is out of a
liquid windfall at unchanged illiquid wealth. The drop on job loss is at the
same liquid and illiquid wealth, and the expected loss follows every branch of
next year's wealth.
"""
function two_asset_agency_summary(p::SAGEParams, sol)
    a = sol.a; kg = sol.k; λ = sol.lambda; z = sol.z_vals; Π = sol.Pi
    na, nk, ns = length(a), length(kg), length(z)
    cbar = sol.cbar; ybar = sol.ybar
    pmass = zeros(ns); pinc = zeros(ns); dmass = zeros(ns); hmass = zeros(ns); whmass = zeros(ns)
    mpcmass = zeros(ns); mpchmass = zeros(ns); mpcwmass = zeros(ns); rmass = zeros(ns); xmass = zeros(ns); cmass = zeros(ns)
    U = findall(==(0.0), z); nh = length(U)
    haveU = !isempty(U) && 2 * nh == ns
    dw = dread_weight(p)
    @inbounds for s in 1:ns, m in 1:nk, i in 1:na
        mm = λ[i, m, s]; mm <= 0 && continue
        cb = view(cbar, :, m, s)
        htm = a[i] <= ybar[i, m, s] / 52
        htm && (m == 1 ? (hmass[s] += mm) : (whmass[s] += mm))
        a[i] >= ybar[i, m, s] / 4 && (rmass[s] += mm)
        cmass[s] += mm * cb[i]
        Δ = ybar[i, m, s] / 12
        if Δ > 0
            mpc = (interp_ext(a, cb, a[i] + Δ / p.R) - cb[i]) / Δ
            mpcmass[s] += mm * mpc
            htm && (m == 1 ? (mpchmass[s] += mm * mpc) : (mpcwmass[s] += mm * mpc))
        end
        if dw > 0 && cb[i] > 0
            D = 0.0
            each_branch(sol, i, m, s) do wt, d, bp, j
                D += wt * dread_at(p, s, bp; weight = dw)
            end
            kk = 1 - (1 - p.γ) * D / (p.Γ * cb[i]^(1 - p.γ))
            kk > 0 && (xmass[s] += mm * (1 - kk^(1 / (1 - p.γ))))
        end
        haveU || continue
        pc = 0.0; py = 0.0
        each_branch(sol, i, m, s) do wt, d, bp, j
            for u in U
                pr = Π[s, u]; pr <= 0 && continue
                cE = SAGEBewley.interp_lin(a, view(cbar, :, j, u + nh), bp)
                cU = SAGEBewley.interp_lin(a, view(cbar, :, j, u), bp)
                yE = SAGEBewley.interp_lin(a, view(ybar, :, j, u + nh), bp)
                yU = SAGEBewley.interp_lin(a, view(ybar, :, j, u), bp)
                cE > 0 && (pc += wt * pr * max(0.0, 1 - cU / cE))
                yE > 0 && (py += wt * pr * max(0.0, 1 - yU / yE))
            end
        end
        pmass[s] += mm * pc; pinc[s] += mm * py
        s > nh && cb[i] > 0 && (dmass[s] += mm * max(0.0, 1 - cbar[i, m, s - nh] / cb[i]))
    end
    merge((pmass = pmass, pinc = pinc, dmass = dmass, hmass = hmass, whmass = whmass,
           mpcmass = mpcmass, mpchmass = mpchmass, mpcwmass = mpcwmass, rmass = rmass, xmass = xmass, cmass = cmass),
          welfare_parts_nan(ns))
end
