# The endogenous-grid solver for the household problem (SOLVER_DESIGN.md).
#
# The same economics as `solve_participation_logit` (proto_participation_core.jl):
# next assets, effort and a participation choice with logit taste shocks of
# scale theta. It is solved by the endogenous grid method (Carroll 2006) with
# the labour margin of Barillas and Fernandez-Villaverde (2007) and the
# discrete choice of DC-EGM (Iskhakov, Jorgensen, Rust and Schjerning 2017):
# for each state and participation branch, the Euler equation gives
# consumption at every next-asset grid point, the intratemporal condition gives
# effort, and the budget gives the current assets that lead there. Effort and
# next assets are continuous, where the reference solver chooses effort on a
# grid of `ne` points.
#
# Selected by `solver = :egm` (SAGEParams and SAGEConfig); `:grid`, the
# reference, stays the default until the validation in SOLVER_DESIGN.md passes.
# Returns the same fields as the reference, plus `Va` for warm starts, so
# everything downstream is unchanged. Dread in behavioural mode is not yet
# supported here (overlay only).
#
# Layers, kept apart so a second, illiquid asset replaces only the middle one:
# the problem (parameters, grids), the savings step (`egm_branch!`), and the
# distribution and aggregates (`egm_distribution`).

using SparseArrays, LinearAlgebra

"""
    egm_constrained(p, a_i, w, other, tfl, d)

Consumption and effort at the borrowing limit (a' = the grid's lowest point):
the budget c = R a_i - a_min + w e + other with the intratemporal condition
phi T^psi = w c^-gamma, T = floor + e + QBAR d, solved for e by bisection on
the monotone gap. Returns (c, e) or (NaN, NaN) when no effort gives positive
consumption.
"""
function egm_constrained(p::SAGEParams, cash0::Float64, w::Float64, tfl::Float64, d::Int)
    tmax = 1.0 - tfl - QBAR * d
    tmax < 0 && return (NaN, NaN)
    if w <= 0.0
        return cash0 > 0 ? (cash0, 0.0) : (NaN, NaN)
    end
    e_lo = cash0 > 0 ? 0.0 : (1e-12 - cash0) / w
    e_lo > tmax && return (NaN, NaN)
    g(e) = p.ϕ * (tfl + e + QBAR * d)^p.ψ - w * (cash0 + w * e)^(-p.γ)
    g(e_lo) >= 0 && return (cash0 + w * e_lo, e_lo)
    g(tmax) <= 0 && return (cash0 + w * tmax, tmax)
    lo, hi = e_lo, tmax
    for _ in 1:60
        mid = 0.5 * (lo + hi)
        g(mid) > 0 ? (hi = mid) : (lo = mid)
    end
    e = 0.5 * (lo + hi)
    (cash0 + w * e, e)
end

@inline egm_flow(p::SAGEParams, c::Float64, T::Float64) =
    p.Γ * (c^(1 - p.γ) / (1 - p.γ) - p.ϕ * T^(1 + p.ψ) / (1 + p.ψ))

"""
The savings step for one state and one participation branch: endogenous grid,
then the policies and branch value on the fixed asset grid, with the
upper-envelope rule where the endogenous grid is not monotone.
"""
function egm_branch!(cd, ed, apd, vd, p::SAGEParams, a, EVs, EVas, s::Int, d::Int,
                     w::Float64, other::Float64, tfl::Float64, belong::Float64,
                     con_c, con_e, aend, cend, eend)
    na = length(a)
    tmax = 1.0 - tfl - QBAR * d
    if tmax < 0
        @inbounds for i in 1:na
            cd[i, s] = NaN; ed[i, s] = 0.0; apd[i, s] = a[1]; vd[i, s] = -Inf
        end
        return
    end
    # --- endogenous grid: one point per next-asset node ---------------------
    monotone = true
    @inbounds for k in 1:na
        m = p.β * EVas[k]
        c = (m / p.Γ)^(-1 / p.γ)
        e = 0.0
        if w > 0
            T = (w * c^(-p.γ) / p.ϕ)^(1 / p.ψ)
            e = clamp(T - tfl - QBAR * d, 0.0, tmax)
        end
        aend[k] = (c + a[k] - w * e - other) / p.R
        cend[k] = c; eend[k] = e
        k > 1 && aend[k] <= aend[k-1] && (monotone = false)
    end
    # --- back onto the fixed grid ---------------------------------------------
    j = 1
    @inbounds for i in 1:na
        ai = a[i]
        # the constrained candidate: next assets at the lowest node
        cc = con_c[i, s]; ec = con_e[i, s]
        vcon = isnan(cc) ? -Inf : egm_flow(p, cc, tfl + ec + QBAR * d) + belong * d + p.β * EVs[1]
        best = vcon; bc = cc; be = ec; bap = a[1]
        if monotone
            if ai >= aend[1]
                while j < na - 1 && aend[j+1] <= ai
                    j += 1
                end
                t = (ai - aend[j]) / (aend[j+1] - aend[j])
                c = cend[j] + t * (cend[j+1] - cend[j])
                e = clamp(eend[j] + t * (eend[j+1] - eend[j]), 0.0, tmax)
                ap = a[j] + t * (a[j+1] - a[j])
                # Above the first endogenous point the household is unconstrained:
                # the interpolated solution is taken as it is. Comparing it with the
                # constrained candidate there made the iteration cycle between two
                # approximations of the same point (2026-09-28).
                if c > 0
                    best = egm_flow(p, c, tfl + e + QBAR * d) + belong * d +
                           p.β * SAGEBewley.interp_lin(a, EVs, ap)
                    bc = c; be = e; bap = max(ap, a[1])
                end
            end
        else
            # upper envelope: every endogenous segment that covers ai
            for k in 1:na-1
                lo, hi = minmax(aend[k], aend[k+1])
                (ai < lo || ai > hi || hi == lo) && continue
                t = (ai - aend[k]) / (aend[k+1] - aend[k])
                c = cend[k] + t * (cend[k+1] - cend[k])
                e = eend[k] + t * (eend[k+1] - eend[k])
                ap = a[k] + t * (a[k+1] - a[k])
                (c <= 0 || ap < a[1]) && continue
                v = egm_flow(p, c, tfl + e + QBAR * d) + belong * d +
                    p.β * SAGEBewley.interp_lin(a, EVs, ap)
                if v > best
                    best = v; bc = c; be = e; bap = ap
                end
            end
            if ai > maximum(aend)     # beyond the endogenous grid: extrapolate the top segment
                k = argmax(aend); k = k == 1 ? 1 : k - 1
                t = (ai - aend[k]) / (aend[k+1] - aend[k])
                c = cend[k] + t * (cend[k+1] - cend[k]); e = clamp(eend[k] + t * (eend[k+1] - eend[k]), 0.0, tmax)
                ap = min(a[k] + t * (a[k+1] - a[k]), a[end])
                if c > 0
                    v = egm_flow(p, c, tfl + e + QBAR * d) + belong * d + p.β * SAGEBewley.interp_lin(a, EVs, ap)
                    v > best && (best = v; bc = c; be = e; bap = ap)
                end
            end
        end
        cd[i, s] = bc; ed[i, s] = be; apd[i, s] = bap; vd[i, s] = best
    end
end

"""
    solve_participation_egm(p, Q_agg; theta, full, tol, maxit, warm)

The household problem by EGM. `warm` is a previous solution (with fields V and
Va) to start from, as the family builder passes along the belonging scales.
"""
function solve_participation_egm(p::SAGEParams, Q_agg::Float64; theta::Float64 = 0.01,
                                 full::Bool = false, tol::Float64 = 1e-9, maxit::Int = 5000,
                                 warm = nothing, trace::Bool = false)
    p.dread > 0 && error("solver = :egm does not yet support dread in behavioural mode")
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz

    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s))
           for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    bel = [p.social_strength * p.Λ * p.B[s] * Q_agg * QBAR * belong_at(p, s) for s in 1:nz]

    # constrained solutions (next assets at the lowest node): fixed across iterations
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    for s in 1:nz, d in (0, 1), i in 1:na
        cash0 = p.R * a[i] - a[1] + oth[s][d+1]
        c, e = egm_constrained(p, cash0, wv[s], tfl[s], d)
        con_c[d+1][i, s] = c; con_e[d+1][i, s] = e
    end

    # starting point: the warm start, else consume at the constraint forever
    if warm !== nothing
        V = copy(warm.V); Va = copy(warm.Va)
    else
        V = zeros(na, nz); Va = zeros(na, nz)
        for s in 1:nz, i in 1:na
            c = con_c[1][i, s]; e = con_e[1][i, s]
            isnan(c) && (c = con_c[2][i, s]; e = con_e[2][i, s])
            c = isnan(c) ? 1e-6 : c
            V[i, s] = egm_flow(p, c, tfl[s] + e) / (1 - p.β)
            Va[i, s] = p.R * p.Γ * c^(-p.γ)
        end
    end

    cd = (zeros(na, nz), zeros(na, nz)); e_d = (zeros(na, nz), zeros(na, nz))
    a_d = (zeros(na, nz), zeros(na, nz)); vd = (zeros(na, nz), zeros(na, nz))
    EV = similar(V); EVa = similar(Va); Vn = similar(V); Van = similar(Va)
    aend = zeros(na); cend = zeros(na); eend = zeros(na)
    P1 = zeros(na, nz)
    iters = 0
    for it in 1:maxit
        mul!(EV, V, Π'); mul!(EVa, Va, Π')
        for s in 1:nz, d in (0, 1)
            egm_branch!(cd[d+1], e_d[d+1], a_d[d+1], vd[d+1], p, a, view(EV, :, s), view(EVa, :, s),
                        s, d, wv[s], oth[s][d+1], tfl[s], bel[s], con_c[d+1], con_e[d+1], aend, cend, eend)
        end
        @inbounds for i in eachindex(V)
            b0 = vd[1][i]; b1 = vd[2][i]
            m = max(b0, b1)
            Vn[i] = m + theta * log(exp((b0 - m) / theta) + exp((b1 - m) / theta))
            P1[i] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
            mu0 = b0 == -Inf ? 0.0 : cd[1][i]^(-p.γ)
            mu1 = b1 == -Inf ? 0.0 : cd[2][i]^(-p.γ)
            Van[i] = p.R * p.Γ * ((1 - P1[i]) * mu0 + P1[i] * mu1)
        end
        dist = maximum(abs, Vn .- V)
        if trace && (it % 250 == 0 || it < 5)
            ia = argmax(abs.(Vn .- V))
            println("  it ", it, " dist ", dist, " at ", Tuple(CartesianIndices(V)[ia]), " P1 ", P1[ia])
        end
        V, Vn = Vn, V; Va, Van = Van, Va
        iters = it
        dist < tol && break
    end

    λ = egm_distribution(a, Π, P1, a_d, na, nz)
    part = 0.0; meaninc = 0.0; partbase = 0.0
    @inbounds for i_z in 1:nz, i_a in 1:na
        w_ = λ[i_a, i_z]; p1 = P1[i_a, i_z]
        part     += w_ * p1
        meaninc  += w_ * p.α[i_z] * z_vals[i_z] * (p1 * e_d[2][i_a, i_z] + (1 - p1) * e_d[1][i_a, i_z])
        partbase += w_ * p1 * p.α[i_z] * z_vals[i_z]
    end
    if full
        return (Q = QBAR * part, rate = part, meaninc = meaninc, partbase = partbase,
                a = a, lambda = λ, P1 = P1, e_d = e_d, a_d = a_d, V = V, Va = Va,
                z_vals = z_vals, iters = iters, theta = theta)
    end
    return QBAR * part, part, meaninc, partbase
end

"The stationary distribution: the Young (2010) lottery over a', mixed over d."
function egm_distribution(a, Π, P1, a_d, na, nz)
    n_s = na * nz
    sidx(i_a, i_z) = (i_z - 1) * na + i_a
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
    reshape(λv, na, nz)
end
