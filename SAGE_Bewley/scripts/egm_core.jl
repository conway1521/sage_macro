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
# everything downstream is unchanged. Dread in behavioural mode enters the
# Euler equation through its derivative in next assets.
#
# Layers, kept apart so a second, illiquid asset replaces only the middle one:
# the problem (parameters, grids), the savings step (`egm_branch!`), and the
# distribution and aggregates (`egm_distribution`).

using SparseArrays, LinearAlgebra

# MORTGAGES (version 3): the gross rate on liquid wealth is R above zero and Rm below (Rm = 0: R throughout). xcash is
# the cash a period's liquid wealth gives, binv the liquid wealth that gives a cash amount; with Rm = 0 they are R b and
# x / R exactly, the forms used before.
@inline Rm_of(p) = p.Rm > 0 ? p.Rm : p.R
@inline xcash(p, b) = b >= 0 ? p.R * b : Rm_of(p) * b
@inline binv(p, x) = x >= 0 ? x / p.R : x / Rm_of(p)
@inline Rb_at(p, b) = b >= 0 ? p.R : Rm_of(p)

"""
    egm_constrained(p, a_i, w, other, tfl, d)

Consumption and effort at the borrowing limit (a' = the grid's lowest point):
the budget c = R a_i - a_min + w e + other with the intratemporal condition
phi T^psi = w c^-gamma, T = floor + e + QBAR d, solved for e by bisection on
the monotone gap. Returns (c, e) or (NaN, NaN) when no effort gives positive
consumption.
"""
function egm_constrained(p::SAGEParams, cash0::Float64, w::Float64, tfl::Float64, d::Int; efix::Float64 = NaN)
    κ = 1.0 + p.commute                       # time per unit of work (commuting)
    pc = p.pc                                 # price of consumption (a consumption tax)
    tmax = (1.0 - tfl - p.qbar * d) / κ
    tmax < 0 && return (NaN, NaN)
    if !isnan(efix) && w > 0                  # effort set by the job: only the budget is left
        efix > tmax && return (NaN, NaN)
        x = cash0 + w * efix
        return x > 0 ? (x / pc, efix) : (NaN, NaN)
    end
    if w <= 0.0
        return cash0 > 0 ? (cash0 / pc, 0.0) : (NaN, NaN)
    end
    e_lo = cash0 > 0 ? 0.0 : (1e-12 - cash0) / w
    e_lo > tmax && return (NaN, NaN)
    g(e) = p.ϕ * κ * (tfl + κ * e + p.qbar * d)^p.ψ - (w / pc) * ((cash0 + w * e) / pc)^(-p.γ)
    g(e_lo) >= 0 && return ((cash0 + w * e_lo) / pc, e_lo)
    g(tmax) <= 0 && return ((cash0 + w * tmax) / pc, tmax)
    lo, hi = e_lo, tmax
    for _ in 1:60
        mid = 0.5 * (lo + hi)
        g(mid) > 0 ? (hi = mid) : (lo = mid)
    end
    e = 0.5 * (lo + hi)
    ((cash0 + w * e) / pc, e)
end

# T is total time: floor + (1 + commute) x effort + participation
@inline egm_flow(p::SAGEParams, c::Float64, T::Float64) =
    p.Γ * (c^(1 - p.γ) / (1 - p.γ) - p.ϕ * T^(1 + p.ψ) / (1 + p.ψ))

"""
The savings step for one state and one participation branch: endogenous grid,
then the policies and branch value on the fixed asset grid, with the
upper-envelope rule where the endogenous grid is not monotone.
"""
function egm_branch!(cd, ed, apd, vd, p::SAGEParams, a, EVs, EVas, s::Int, d::Int,
                     w::Float64, other::Float64, tfl::Float64, belong::Float64,
                     con_c, con_e, aend, cend, eend, Ds, Dps; k0::Int = 1)
    # k0 (mortgages): the first feasible next-asset node, the borrowing limit of this problem's next illiquid wealth;
    # con_c and con_e are then the solutions with next assets at a[k0]. k0 = 1: as before.
    na = length(a)
    κ = 1.0 + p.commute
    tmax = (1.0 - tfl - p.qbar * d) / κ
    efix = (isempty(p.effort_set) || w <= 0) ? NaN : p.effort_set[s]      # effort set by the job, if any
    if tmax < 0 || (!isnan(efix) && efix > tmax)
        @inbounds for i in 1:na
            cd[i, s] = NaN; ed[i, s] = 0.0; apd[i, s] = a[k0]; vd[i, s] = -Inf
        end
        return
    end
    # --- endogenous grid: one point per next-asset node ---------------------
    monotone = true
    @inbounds for k in k0:na
        # dread (behavioural mode) falls as savings rise, so it adds to the
        # marginal value of saving: Gamma c^-gamma = beta E V_a - D'(a')
        m = max(p.β * EVas[k] - Dps[k], 1e-12)     # zero where every next state is on the floor
        c = (p.pc * m / p.Γ)^(-1 / p.γ)
        e = 0.0
        if !isnan(efix)
            e = efix
        elseif w > 0
            T = (w * c^(-p.γ) / (p.ϕ * κ * p.pc))^(1 / p.ψ)
            e = clamp((T - tfl - p.qbar * d) / κ, 0.0, tmax)
        end
        aend[k] = binv(p, p.pc * c + a[k] - w * e - other)
        cend[k] = c; eend[k] = e
        k > k0 && aend[k] <= aend[k-1] && (monotone = false)
    end
    # --- back onto the fixed grid ---------------------------------------------
    # every grid point starts from the constrained candidate (next assets at the
    # lowest node)
    @inbounds for i in 1:na
        cc = con_c[i, s]; ec = con_e[i, s]
        cd[i, s] = cc; ed[i, s] = ec; apd[i, s] = a[k0]
        vd[i, s] = isnan(cc) ? -Inf : egm_flow(p, cc, tfl + κ * ec + p.qbar * d) + belong * d - Ds[k0] + p.β * EVs[k0]
    end
    if monotone
        j = k0
        @inbounds for i in 1:na
            ai = a[i]
            ai >= aend[k0] || continue
            while j < na - 1 && aend[j+1] <= ai
                j += 1
            end
            t = (ai - aend[j]) / (aend[j+1] - aend[j])
            c = cend[j] + t * (cend[j+1] - cend[j])
            e = clamp(eend[j] + t * (eend[j+1] - eend[j]), 0.0, tmax)
            ap = a[j] + t * (a[j+1] - a[j])
            if ap > a[end]
                # THE TOP OF THE GRID (2026-10-16; V3_START.md section 100). Past the last endogenous point the
                # interpolation runs beyond the grid's top. Next assets stay at the top, and consumption and
                # hours come from the budget there, so the budget holds; until now only a' was capped.
                cc, ec = egm_constrained(p, xcash(p, ai) - a[end] + other, w, tfl, d; efix = efix)
                isnan(cc) && continue
                c = cc; e = ec; ap = a[end]
            end
            # Above the first endogenous point the household is unconstrained:
            # the interpolated solution is taken as it is. Comparing it with the
            # constrained candidate there made the iteration cycle between two
            # approximations of the same point (2026-09-28).
            if c > 0
                vd[i, s] = egm_flow(p, c, tfl + κ * e + p.qbar * d) + belong * d - dread_at(p, s, max(ap, a[k0])) +
                           p.β * SAGEBewley.interp_lin(a, EVs, ap)
                cd[i, s] = c; ed[i, s] = e; apd[i, s] = max(ap, a[k0])
            end
        end
    else
        # upper envelope: each endogenous segment is compared only at the grid
        # points it covers (2026-09-29; the same comparisons, in segment order,
        # as the point-by-point loop it replaces, which was O(na^2))
        @inbounds for k in k0:na-1
            lo, hi = minmax(aend[k], aend[k+1])
            hi == lo && continue
            ilo = searchsortedfirst(a, lo); ihi = searchsortedlast(a, hi)
            for i in ilo:ihi
                ai = a[i]
                t = (ai - aend[k]) / (aend[k+1] - aend[k])
                c = cend[k] + t * (cend[k+1] - cend[k])
                e = eend[k] + t * (eend[k+1] - eend[k])
                ap = a[k] + t * (a[k+1] - a[k])
                (c <= 0 || ap < a[k0]) && continue
                v = egm_flow(p, c, tfl + κ * e + p.qbar * d) + belong * d - dread_at(p, s, ap) +
                    p.β * SAGEBewley.interp_lin(a, EVs, ap)
                if v > vd[i, s]
                    vd[i, s] = v; cd[i, s] = c; ed[i, s] = e; apd[i, s] = ap
                end
            end
        end
        amax = maximum(view(aend, k0:na))
        km = k0 - 1 + argmax(view(aend, k0:na)); km = km == k0 ? k0 : km - 1
        @inbounds for i in 1:na
            ai = a[i]
            ai > amax || continue     # beyond the endogenous grid: extrapolate the top segment
            t = (ai - aend[km]) / (aend[km+1] - aend[km])
            c = cend[km] + t * (cend[km+1] - cend[km]); e = clamp(eend[km] + t * (eend[km+1] - eend[km]), 0.0, tmax)
            ap = a[km] + t * (a[km+1] - a[km])
            if ap > a[end]                      # the top of the grid, as in the monotone case
                cc, ec = egm_constrained(p, xcash(p, ai) - a[end] + other, w, tfl, d; efix = efix)
                isnan(cc) && continue
                c = cc; e = ec; ap = a[end]
            end
            if c > 0
                v = egm_flow(p, c, tfl + κ * e + p.qbar * d) + belong * d - dread_at(p, s, ap) +
                    p.β * SAGEBewley.interp_lin(a, EVs, ap)
                v > vd[i, s] && (vd[i, s] = v; cd[i, s] = c; ed[i, s] = e; apd[i, s] = ap)
            end
        end
    end
end

"""
The means-tested floor for one state and branch (p.cfloor > 0): every grid point
whose resources R a + w e + other fall short of the floor is topped up to it, so
it has the consumption, saving and value of a household with exactly the floor.
That household's choice is found on the asset grid (it keeps nothing or little:
saving is taxed away one for one next period while it stays on the floor).
`fl` marks the points on the floor: their marginal value of assets is zero.
"""
function apply_floor!(cd, ed, apd, vd, fl, p::SAGEParams, a, EVs, s::Int, d::Int,
                      w::Float64, other::Float64, tfl::Float64, belong::Float64, Ds; k0::Int = 1)
    na = length(a)
    @inbounds for i in 1:na; fl[i, s] = false; end
    # HOURS CHOSEN BY THE HOUSEHOLD (A, 2026-10-11): `effort_set` empty. On the floor every euro earned is taken
    # back, so a household on it does not work; and a household that could be on it (its resources without
    # work fall short) is on it only if that is worth more than working its way above. With hours set by the
    # job there is no such choice and everything below is as before.
    chosen = isempty(p.effort_set)
    e = (w > 0 && !chosen) ? p.effort_set[s] : 0.0
    κ = 1.0 + p.commute
    T = tfl + κ * e + p.qbar * d
    T > 1.0 && return
    X = p.cfloor                                  # resources guaranteed
    af = binv(p, X - w * e - other)               # assets below which the transfer is paid
    af <= a[k0] && return
    # a household on the floor does not borrow (mortgages): assistance expects its own means used first, and with the
    # floor paying the interest it would otherwise borrow to the limit every period. Without mortgages kf = k0.
    kf = k0
    while kf < na && a[kf] < 0
        kf += 1
    end
    best = -Inf; kb = kf
    @inbounds for k in kf:na
        c = (X - a[k]) / p.pc
        c > 1e-10 || break
        v = egm_flow(p, c, T) + belong * d - Ds[k] + p.β * EVs[k]
        v > best && (best = v; kb = k)
    end
    best == -Inf && return
    cf = (X - a[kb]) / p.pc
    @inbounds for i in 1:na
        a[i] < af || break
        if chosen && w > 0
            # the choice found without the floor stands where it lifts the household above the floor and is worth more
            (xcash(p, a[i]) + w * ed[i, s] + other >= X && vd[i, s] >= best) && continue
        end
        cd[i, s] = cf; ed[i, s] = e; apd[i, s] = a[kb]; vd[i, s] = best; fl[i, s] = true
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
    a = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nz = p.na, p.nz

    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s))
           for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    bel = [p.social_strength * p.Λ * p.B[s] * Q_agg * p.qbar * belong_at(p, s) for s in 1:nz]
    fl = (falses(na, nz), falses(na, nz))        # grid points on the floor, by branch

    # dread in behavioural mode, at each next-asset node, and its derivative
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

    # constrained solutions (next assets at the lowest node): fixed across iterations
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    for s in 1:nz, d in (0, 1), i in 1:na
        cash0 = p.R * a[i] - a[1] + oth[s][d+1]
        c, e = egm_constrained(p, cash0, wv[s], tfl[s], d; efix = isempty(p.effort_set) ? NaN : p.effort_set[s])
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
            Va[i, s] = p.R * p.Γ * c^(-p.γ) / p.pc
        end
    end

    # JOB SEARCH (A; `search_k`, SAGEBewley.jl). Each searching state's row of the transition matrix is split
    # into its part towards work (Pf, normalised) and the rest (Ps); the household's search effort x, chosen
    # at each next-asset node, weights them. Nothing changes where search_k is empty.
    search = !isempty(p.search_k)
    if search
        length(p.search_k) == nz || error("search_k has length $(length(p.search_k)), the problem $nz states")
        isEmp = isemp(p)
        Pf = copy(Π); Ps = copy(Π)
        for s in 1:nz
            p.search_k[s] > 0 || continue
            isEmp[s] && error("search_k is positive in a state in work ($s)")
            rowE = Π[s, :] .* isEmp; fs = sum(rowE)
            (0 < fs < 1) || error("search: state $s has no chance of work to reweight (it is $fs)")
            Pf[s, :] = rowE ./ fs; Ps[s, :] = (Π[s, :] .- rowE) ./ (1 - fs)
        end
        EVf = zeros(na, nz); EVs_ = zeros(na, nz); EVfa = zeros(na, nz); EVsa = zeros(na, nz)
        xs = zeros(na, nz)                       # search at each next-asset node
        γs = p.search_gamma
    end
    cd = (zeros(na, nz), zeros(na, nz)); e_d = (zeros(na, nz), zeros(na, nz))
    a_d = (zeros(na, nz), zeros(na, nz)); vd = (zeros(na, nz), zeros(na, nz))
    EV = similar(V); EVa = similar(Va); Vn = similar(V); Van = similar(Va)
    aend = zeros(na); cend = zeros(na); eend = zeros(na)
    P1 = zeros(na, nz)
    iters = 0
    # With the means-tested floor the value has a kink where the transfer starts and the plain
    # iteration can cycle: 9410 household problems ran to maxit in one run of the Italian places
    # with the floor (2026-10-04). The relaxation of the two-asset solver, for the floor only:
    # when the bound stops improving the step is halved, down to 1/16, and a remaining stall
    # below 1e-2 is accepted and reported. Without a floor nothing here is active.
    floor_on = p.cfloor > 0
    hist = floor_on ? zeros(maxit) : Float64[]; relax = 1.0; stalled = false; stall = 0.0
    for it in 1:maxit
        if search
            mul!(EVf, V, Pf'); mul!(EVs_, V, Ps'); mul!(EVfa, Va, Pf'); mul!(EVsa, Va, Ps')
            @inbounds for s in 1:nz
                ks = p.search_k[s]
                if ks <= 0
                    for k in 1:na; EV[k, s] = EVf[k, s]; EVa[k, s] = EVfa[k, s]; end      # Pf is the row itself
                    continue
                end
                for k in 1:na
                    # beta x EVf + beta (1 - x) EVs - k x^(1+g)/(1+g): x = (beta (EVf - EVs) / k)^(1/g) within [0, 1].
                    # The cost sits inside EV divided by beta, since the branch multiplies EV by beta; the
                    # marginal value of assets follows by the envelope condition.
                    # with offers arriving at rate lam (stage 1b) the chance of work is lam x, and k x^g = beta lam (EVf - EVs)
                    Δ = EVf[k, s] - EVs_[k, s]; lam = isempty(p.search_lam) ? 1.0 : p.search_lam[s]
                    x = Δ > 0 ? min((p.β * lam * Δ / ks)^(1 / γs), 1.0) : 0.0
                    xs[k, s] = x; pw = lam * x
                    EV[k, s] = pw * EVf[k, s] + (1 - pw) * EVs_[k, s] - ks * x^(1 + γs) / ((1 + γs) * p.β)
                    EVa[k, s] = pw * EVfa[k, s] + (1 - pw) * EVsa[k, s]
                end
            end
        else
            mul!(EV, V, Π'); mul!(EVa, Va, Π')
        end
        for s in 1:nz, d in (0, 1)
            egm_branch!(cd[d+1], e_d[d+1], a_d[d+1], vd[d+1], p, a, view(EV, :, s), view(EVa, :, s),
                        s, d, wv[s], oth[s][d+1], tfl[s], bel[s], con_c[d+1], con_e[d+1], aend, cend, eend,
                        view(D, :, s), view(Dp, :, s))
            p.cfloor > 0 && apply_floor!(cd[d+1], e_d[d+1], a_d[d+1], vd[d+1], fl[d+1], p, a, view(EV, :, s), s, d,
                                         wv[s], oth[s][d+1], tfl[s], bel[s], view(D, :, s))
        end
        @inbounds for i in eachindex(V)
            # S exactly off (2026-10-08): with no belonging payoff there is no participation choice, where the logit left a residual
            b0 = vd[1][i]; b1 = p.social_strength == 0 ? -Inf : vd[2][i]
            m = max(b0, b1)
            Vn[i] = m + theta * log(exp((b0 - m) / theta) + exp((b1 - m) / theta))
            isempty(p.out_cost) || (Vn[i] -= p.out_cost[(i - 1) ÷ na + 1])     # out of work, beyond income (A)
            P1[i] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
            # on the floor an extra unit of assets is taken back by the transfer: no marginal value
            mu0 = (b0 == -Inf || fl[1][i]) ? 0.0 : cd[1][i]^(-p.γ)
            mu1 = (b1 == -Inf || fl[2][i]) ? 0.0 : cd[2][i]^(-p.γ)
            Van[i] = p.R * p.Γ * ((1 - P1[i]) * mu0 + P1[i] * mu1) / p.pc
        end
        # McQueen-Porteus bounds: with dmin and dmax the smallest and largest
        # change this iteration, the fixed point lies between V + b/(1-b) dmin and
        # V + b/(1-b) dmax. When that span is below tol the iteration stops and
        # the level is set to the midpoint. Choices depend on value differences
        # only, so they are unaffected; the level shift from one belonging scale
        # to the next, which plain iteration removes slowly, costs nothing.
        dmin = Inf; dmax = -Inf
        @inbounds for i in eachindex(V)
            δ = Vn[i] - V[i]; δ < dmin && (dmin = δ); δ > dmax && (dmax = δ)
        end
        dist = p.β / (1 - p.β) * (dmax - dmin)
        if floor_on
            hist[it] = dist
            if it > 100 && it % 50 == 0 && minimum(view(hist, it-49:it)) > 0.9 * minimum(view(hist, it-99:it-50))
                relax > 1 / 16 ? (relax /= 2) : (dist < p.stall_tol && (stalled = true))
            end
        end
        if dist < tol || stalled
            Vn .+= p.β / (1 - p.β) * 0.5 * (dmin + dmax)
            stalled && (Vn .= 0.5 .* (Vn .+ V); Van .= 0.5 .* (Van .+ Va); stall = dist)
        elseif relax < 1
            @inbounds for i in eachindex(V)
                Vn[i] = V[i] + relax * (Vn[i] - V[i]); Van[i] = Va[i] + relax * (Van[i] - Va[i])
            end
        end
        if trace && (it % 250 == 0 || it < 5)
            ia = argmax(abs.(Vn .- V))
            println("  it ", it, " dist ", dist, " at ", Tuple(CartesianIndices(V)[ia]), " P1 ", P1[ia])
        end
        V, Vn = Vn, V; Va, Van = Van, Va
        iters = it
        # a state with no feasible choice (both branches -Inf: an unemployed state
        # whose benefit net of tax is not positive) makes the log-sum NaN, which
        # then spreads to every state and never converges; say so at once
        isnan(dist) && error("the household problem has a state with no feasible choice (value NaN at iteration $it): check benefits net of the lump-sum tax")
        (dist < tol || stalled) && break
    end
    iters == maxit && !stalled && @warn "solve_participation_egm stopped at maxit without converging" maxit tol
    stall > 1e-4 && @warn "solve_participation_egm accepted a stalled iteration (floor on)" stall
    # every stalled acceptance, however small, when SAGE_STALL_LOG=1 (the on/off test's diagnostic, section 137)
    stalled && stall <= 1e-4 && get(ENV, "SAGE_STALL_LOG", "0") == "1" && println("STALL accepted at ", stall, " after ", iters, " iterations")

    λ = search ? egm_distribution(a, Π, P1, a_d, na, nz; Pf = Pf, Ps = Ps, xs = xs, searching = p.search_k .> 0,
                                  lam = isempty(p.search_lam) ? nothing : p.search_lam) :
                 egm_distribution(a, Π, P1, a_d, na, nz)
    # the search effort at each grid point, at the next assets chosen (mixed over the participation branch)
    x_d = zeros(na, nz)
    if search
        @inbounds for s in 1:nz
            p.search_k[s] > 0 || continue
            for i in 1:na
                x_d[i, s] = (1 - P1[i, s]) * SAGEBewley.interp_lin(a, view(xs, :, s), a_d[1][i, s]) +
                            P1[i, s] * SAGEBewley.interp_lin(a, view(xs, :, s), a_d[2][i, s])
            end
        end
    end
    part = 0.0; meaninc = 0.0; partbase = 0.0
    @inbounds for i_z in 1:nz, i_a in 1:na
        w_ = λ[i_a, i_z]; p1 = P1[i_a, i_z]
        part     += w_ * p1
        meaninc  += w_ * p.α[i_z] * z_vals[i_z] * (p1 * e_d[2][i_a, i_z] + (1 - p1) * e_d[1][i_a, i_z])
        partbase += w_ * p1 * p.α[i_z] * z_vals[i_z]
    end
    if full
        return (Q = p.qbar * part, rate = part, meaninc = meaninc, partbase = partbase,
                a = a, lambda = λ, P1 = P1, e_d = e_d, a_d = a_d, V = V, Va = Va,
                z_vals = z_vals, iters = iters, theta = theta, c_d = cd, floor_d = fl, search_x = x_d,
                search_xs = search ? xs : zeros(0, 0))
    end
    return p.qbar * part, part, meaninc, partbase
end

"""
    solve_job_effort(p, Q_agg; theta, full, tol, maxit, warm, etol, emax)

The household problem with effort set by the job (`p.job_effort`): one level of
effort per state, at which the effort condition holds on average over the
households in that state,

    (w / pc) E[u'(c)] = phi kappa E[T^psi],     T = floor + kappa e + QBAR d,

the expectations over the stationary distribution in the state and over the
participation choice. Found as a fixed point around `solve_participation_egm`:
solve with effort given, read the average marginal utility and participation in
each state, solve the condition for the effort it calls for, and move there
(secant steps after a first damped one; consumption rises with effort, so the
map slopes down and the step is stable). Starts from `warm.effort_set` when the
previous solution has it (the family builder passes the neighbouring belonging
scale), else from the state means of freely chosen effort. Returns the usual
solution plus `effort_set`, the gap left and the iterations.
"""
function solve_job_effort(p::SAGEParams, Q_agg::Float64; theta::Float64 = 0.01, full::Bool = false,
                          tol::Float64 = 1e-9, maxit::Int = 5000, warm = nothing,
                          etol::Float64 = 1e-8, emax::Int = 40)
    z_vals, _ = SAGEBewley.income_process(p)
    nz = p.nz; κ = 1.0 + p.commute
    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s)) for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    emp = [wv[s] > 0 for s in 1:nz]
    pfree = update(p; job_effort = false, effort_set = Float64[])
    # With the means-tested floor on, the job's effort levels are those of the economy without it:
    # the floor changes who works for how much, not what a job asks. Letting the condition respond to
    # the floor gave no solution in version 3 (gap NaN in every Italian place, 2026-10-04): in the
    # lowest income states every household is on the floor, where an extra euro earned is taken back.
    if p.cfloor > 0
        s0 = solve_job_effort(update(p; cfloor = 0.0), Q_agg; theta = theta, full = true, tol = tol, maxit = maxit, etol = etol, emax = emax)
        sol = solve_participation_egm(update(pfree; effort_set = s0.effort_set), Q_agg; theta = theta, full = true, tol = tol, maxit = maxit)
        full || return sol.Q, sol.rate, sol.meaninc, sol.partbase
        return merge(sol, (effort_set = s0.effort_set, effort_gap = s0.effort_gap, effort_iters = s0.effort_iters))
    end
    pstart = update(pfree; cfloor = 0.0)          # the free-effort starting point has no floor
    if warm !== nothing && hasproperty(warm, :effort_set) && length(warm.effort_set) == nz
        e = copy(warm.effort_set); w0 = warm
    else
        s0 = solve_participation_egm(pstart, Q_agg; theta = theta, full = true, tol = tol, maxit = maxit, warm = warm)
        e = zeros(nz)
        for s in 1:nz
            emp[s] || continue
            m = sum(view(s0.lambda, :, s))
            m > 0 && (e[s] = sum(s0.lambda[i, s] * (s0.P1[i, s] * s0.e_d[2][i, s] + (1 - s0.P1[i, s]) * s0.e_d[1][i, s]) for i in 1:p.na) / m)
        end
        w0 = s0
    end
    # the effort the condition calls for in each state, given a solution
    function called_for(sol, e)
        a = sol.a; out = copy(e)
        for s in 1:nz
            emp[s] || continue
            m = 0.0; mu = 0.0; pb = 0.0
            @inbounds for i in eachindex(a)
                l = sol.lambda[i, s]; l <= 0 && continue
                for d in (0, 1)
                    pd = d == 1 ? sol.P1[i, s] : 1 - sol.P1[i, s]; pd <= 0 && continue
                    c = sol.c_d[d+1][i, s]           # the solver's consumption (it includes the floor transfer)
                    c > 0 && (mu += l * pd * c^(-p.γ))
                end
                m += l; pb += l * sol.P1[i, s]
            end
            m > 0 || continue
            mu /= m; pb /= m
            target = (wv[s] / p.pc) * mu
            h(x) = p.ϕ * κ * ((1 - pb) * (tfl[s] + κ * x)^p.ψ + pb * (tfl[s] + κ * x + p.qbar)^p.ψ) - target
            hi = (1.0 - tfl[s] - p.qbar) / κ; lo = 0.0
            if h(lo) >= 0
                out[s] = lo
            elseif h(hi) <= 0
                out[s] = hi
            else
                for _ in 1:60
                    mid = 0.5 * (lo + hi); h(mid) > 0 ? (hi = mid) : (lo = mid)
                end
                out[s] = 0.5 * (lo + hi)
            end
        end
        out
    end
    sol = nothing; gap = Inf; iters = 0
    eprev = copy(e); Fprev = zeros(nz); damp = 1 / (1 + p.γ / p.ψ)
    for k in 1:emax
        iters = k
        sol = solve_participation_egm(update(pfree; effort_set = e), Q_agg; theta = theta, full = true, tol = tol, maxit = maxit, warm = w0)
        F = called_for(sol, e) .- e
        gap = maximum(abs(F[s]) for s in 1:nz if emp[s])
        gap < etol && break
        enew = copy(e)
        for s in 1:nz
            emp[s] || continue
            step = damp * F[s]
            if k > 1 && abs(e[s] - eprev[s]) > 1e-14
                sl = (F[s] - Fprev[s]) / (e[s] - eprev[s])
                sl < -1e-3 && (step = clamp(-F[s] / sl, -0.2, 0.2))
            end
            enew[s] = clamp(e[s] + step, 0.0, (1.0 - tfl[s] - p.qbar) / κ)
        end
        eprev = e; Fprev = F; e = enew; w0 = sol
    end
    gap < etol || @warn "solve_job_effort stopped without converging" gap etol iterations = iters
    full || return sol.Q, sol.rate, sol.meaninc, sol.partbase
    merge(sol, (effort_set = e, effort_gap = gap, effort_iters = iters))
end

"""The stationary distribution: the Young (2010) lottery over a', mixed over d. With job search the row of
a searching state is x Pf + (1 - x) Ps, x the search chosen at the next assets (interpolated on `xs`)."""
function egm_distribution(a, Π, P1, a_d, na, nz; Pf = nothing, Ps = nothing, xs = nothing, searching = nothing, lam = nothing)
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
            srch = searching !== nothing && searching[i_z]
            x = srch ? SAGEBewley.interp_lin(a, view(xs, :, i_z), ap) * (lam === nothing ? 1.0 : lam[i_z]) : 0.0   # the chance of work
            for i_zn in 1:nz
                pz = (srch ? x * Pf[i_z, i_zn] + (1 - x) * Ps[i_z, i_zn] : Π[i_z, i_zn]) * pd
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
        # where power iteration has not settled (slow mixing: income persistence near one at a quarterly period),
        # the stationary distribution solved directly: (T' - I) lambda = 0 with the last equation replaced by
        # sum(lambda) = 1, a sparse system. It replaces squaring the dense transition matrix, which at quarterly
        # sizes (about 20,000 states) took hours (version 2, stage 1a, 2026-10-20); version 1 checked by the regression.
        A = sparse(Tt) - sparse(1.0I, n_s, n_s)
        A = vcat(A[1:n_s-1, :], sparse(ones(1, n_s)))
        rhs = zeros(n_s); rhs[n_s] = 1.0
        λv = A \ rhs
        λv .= max.(λv, 0.0)
    end
    λv ./= sum(λv)
    reshape(λv, na, nz)
end
