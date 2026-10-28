# The two-asset household problem (TWO_ASSET_DESIGN.md): liquid b, return R,
# and illiquid k, return Rk, which accrues to k (or, with k_payout, is paid into
# liquid wealth every period, the keeper then holding k' = k) and can be changed only at a
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
#    With k_sub > 1 the targets also lie between the nodes, k_sub steps to each
#    interval: a target k' between k_j and k_j+1 has the value of the two inner
#    solutions at the same effective liquid wealth, weighted linearly, which is
#    the interpolation of the continuation value in k' that the keeper already
#    uses, and its mass goes to the two nodes with those weights (Young 2010).
#    Without it the remainder between two nodes sits in liquid wealth, and the
#    liquid median moves with the illiquid grid (probe_two_asset_grid.jl).
#    The options of the smoothed choice stay one per node: option j is the best
#    target in [k_j, k_j+1), so k_sub = 1 is the choice among the nodes exactly.
#    The value iteration uses the k_sub steps. Once it has converged, one more
#    pass refines each target by a golden section search around its best step,
#    for the policies only: the value is flat at the best target, so the steps
#    are enough for it, while the liquid remainder moves one for one with the
#    target (the liquid median fell with the number of steps: 0.213, 0.147, 0.108
#    of income at 1, 4 and 16 on 24 nodes). Refining inside the iteration was
#    tried and did not converge in 5000 iterations (2026-10-04): the search lands
#    on a different side of a kink from one iteration to the next.
#    One refining pass alone left the value computed for the steps and the
#    policy for the refined targets, and the liquid median then rose with the
#    number of steps (0.058, 0.068, 0.090 at 4, 8, 16). So the value iteration is
#    continued with the refined targets held fixed, and the targets refined
#    again, K_ROUNDS times: the value is then the value of the refined policy.
#    (Smoothing over every target was tried first, 2026-10-04: the weights spread
#    over many near-equal targets, the branches of the distribution multiplied
#    and a solve no longer fitted in memory.)
# The choice among adjusting targets and between keeping and adjusting carries
# logit smoothing of scale theta_adj, as participation does (Iskhakov,
# Jorgensen, Rust and Schjerning 2017). Default 0.01: at the participation
# scale (0.005) the iteration cycles; at 0.05 the smoothing itself moves the
# adjusting share from 9% to 22% (Italy, 2026-09-29); 0.01 and 0.02 agree. With chi0 so large that no adjustment
# is affordable and no illiquid wealth, the slice k = 0 is the one-asset
# problem exactly, which is the reduction test.

using Printf, SparseArrays
const GOLD = 0.6180339887498949
const K_ROUNDS = 2          # rounds of (value iteration at fixed refined targets, refine again), k_sub > 1
# SPEED (V3_START.md section 128; the user, 2026-10-22). With `fast` (the default; SAGE_EGM2_FAST=0 turns it off):
# (1) the expectation over next period's income state uses the transition matrix as a sparse matrix when most of it is
#     zero (the quarterly labour chain), the same product in another order;
# (2) the inner problems (one per illiquid node) and the outer choice (one per income state) run on the process's
#     threads, each with its own work arrays; they write disjoint parts of the arrays, so the result does not depend
#     on the number of threads;
# (3) each value iteration adds the midpoint of the MacQueen-Porteus bounds, beta/(1-beta) (dmin + dmax)/2, as the
#     final step already did: the fixed point is unchanged (both bounds are zero there) and the error that the
#     iteration removes at rate beta, a common shift of the value, is removed at once;
# (4) a solve without a warm start starts from the last solution of a problem of the same size in this process
#     (WARM2; SAGE_WARM2=0 turns it off). Starting values change the iterations, not the fixed point.
# TENURE (V3_START.md section 139; design section 4.1). A household whose illiquid wealth at the start of the period
# is below k_min is a tenant and pays rent[s] out of the period's cash. The inner (liquid) problems are solved twice
# when anyone pays rent: once with the owner's cash and once with the tenant's, the tenant's in slots nk + 1 to 2 nk
# of the inner arrays (slot j + off[m] for node j, off[m] = nk for a tenant node m, 0 otherwise). The continuation
# depends on the node only; tenure is the current node's, so a buyer pays rent in the quarter it buys and not after.
# With no rent the slots are the nodes and nothing changes.
# HOWARD STEPS (V3_START.md section 139; `howard` = H, SAGE_HOWARD; 10 by default since 2026-10-27, tested: at 10 the
# German test problem converges where H = 0 stalls, the aggregates within 1e-11 of H = 0's; SAGE_HOWARD=0 restores
# the plain iteration). The iteration count,
# 3,700 to 4,900 a problem, is the discount rate's: the span of the bounds falls at about beta a step. After each full
# step that has not converged, H steps of the same policy's evaluation follow (modified policy iteration, Puterman
# 1994, section 6.5): consumption, effort and next liquid wealth in each inner problem, the participation
# probabilities, the adjusting targets and their probabilities all held at the full step's, the value updated as
# V <- flow + beta E V, with the logit choices' value at fixed probabilities (the expected value plus theta times
# their entropy, which equals the log-sum at those probabilities). Such a step costs a fraction of a full one (no
# Euler inversion, no search over the 93 targets). The stopping rule is unchanged and judged on full steps only, so
# the fixed point is the same; the marginal value Vb is updated on full steps only. Not used while the relaxation
# below is active (relax < 1) or in a refining pass.
const WARM2 = Dict{NTuple{4,Int},Any}()

"""
Owners' imputed rent in state s (the user-cost form, `k_yield > 0`): every household's housing costs the measured rent,
the gross rent `rent + hb` (`rent` is the tenant's net of the housing benefit), and the asset pays `k_yield k` back. A
tenant (no equity) pays its net rent as before; an owner pays the gross rent and receives the yield on its equity, so a
larger dwelling saves more, as housing services do. Zero without a yield: owners pay nothing, the first design.
"""
owner_rent(p, s) = (p.k_yield > 0 && !isempty(p.rent)) ? p.rent[s] + (isempty(p.hb) ? 0.0 : p.hb[s]) : 0.0

"""
Illiquid grid. With k_mid = 0: zero, then exponentially spaced to k_max. With
k_mid > 0: three fifths of the nodes on [0, k_mid] with exponent 1.5 (a few
close to zero, then near-even spacing where households hold their wealth), the
rest geometric from k_mid to k_max for the tail.
"""
function illiquid_grid(k_max, nk, pexp, k_mid = 0.0)
    k_mid > 0 || return SAGEBewley.exponential_grid(0.0, k_max, nk, pexp)
    n1 = max(2, round(Int, 0.6 * nk)); n2 = nk - n1
    vcat([k_mid * ((i - 1) / (n1 - 1))^1.5 for i in 1:n1], [k_mid * (k_max / k_mid)^(i / n2) for i in 1:n2])
end
function illiquid_grid(p::SAGEParams)
    g = illiquid_grid(p.k_max, p.nk, p.pexp, p.k_mid)
    if p.k_min > 0 && any(>(0), p.rent) && p.k_min < g[end]        # as hasT in the solver
        if get(ENV, "SAGE_TENANT_NODES", "0") == "1"
            # the first tenure grid: the node nearest the ownership threshold moved onto it, the nodes below it
            # tenant nodes with some equity
            j = argmin(abs.(g[2:end-1] .- p.k_min)) + 1
            g[j] = p.k_min
        else
            # With tenure the asset is the main residence's equity (design section 4.1), so a tenant holds none:
            # the grid is zero and then k_min to k_max (the same spacing on that range). The tenant nodes with some
            # equity that the first grid had were empty, and the iteration cycled there and nowhere else (Germany,
            # patience 0.985, run 40495661231: the bound held at 1 to 10 for 5,000 steps at illiquid node 2, with
            # no mass at nodes 2 to 9), as it had in the empty corners at the grid's top. A kept house that falls
            # below k_min (a real loss, Germany) is split between k_min and zero, which keeps its expected equity
            # (Young 2010) and turns a small loss into a small chance of a large one. Without rent nothing changes,
            # so the reductions stay exact. SAGE_TENANT_NODES=1 restores the first grid.
            g = vcat(0.0, p.k_min .+ illiquid_grid(p.k_max - p.k_min, p.nk - 1, p.pexp, 0.0))
        end
    end
    g
end

# linear interpolation on an increasing grid with extrapolation on the end segments
@inline function lin_at(x, y, xi, j)
    t = (xi - x[j]) / (x[j+1] - x[j])
    y[j] + t * (y[j+1] - y[j])
end
# MORTGAGES (version 3; Berger, Guerrieri, Lorenzoni and Vavra 2018). Liquid wealth after a cash flow sh (in liquid units,
# cash over R): with a mortgage rate the cash is xcash(a) + R sh and the liquid wealth that gives it binv of that; with
# Rm = 0 it is a + sh exactly, as before.
@inline liq_after(p, ai, sh) = p.Rm == 0 ? ai + sh : binv(p, xcash(p, ai) + p.R * sh)
# the mix of two values with weight w on the second, safe where the other side is -Inf
@inline mixw(x, y, w) = w == 0 ? x : (w == 1 ? y : (1 - w) * x + w * y)
"""
The liquid grid. Without mortgages, as before. With them (ltv > 0) the borrowing limits of the illiquid nodes, -ltv k_j,
are grid points, with one point between each pair and between the smallest and zero, below the usual grid.
"""
function liquid_grid(p, kg)
    pos = SAGEBewley.exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    p.ltv > 0 || return pos
    lim = sort(unique(-p.ltv .* kg[2:end]))                     # most negative first
    neg = Float64[]
    for (i, x) in enumerate(lim)
        push!(neg, x)
        nxt = i < length(lim) ? lim[i+1] : 0.0
        push!(neg, 0.5 * (x + nxt))
    end
    vcat(neg, pos)
end

"""
Value and marginal value of liquid wealth of adjusting from illiquid wealth with
`num` = Rk k - chi0 to the target a share ω of the way from node o to node o + 1,
at liquid wealth ai: the two inner solutions at the same effective liquid
wealth, weighted linearly. (-Inf, 0) when the target is not affordable.
"""
# liquid wealth after a cash flow cf, at rate R above zero and Rm below (Rm = 0: ai + cf / R, as before)
@inline liq_cf(ai, cf, R, Rm) = Rm == 0 ? ai + cf / R : (x = (ai >= 0 ? R * ai : Rm * ai) + cf; x >= 0 ? x / R : x / Rm)
@inline function adj_eval(a, Vin, muin, s, o, ω, ai, num, kg, R, off = 0, Rm = 0.0)
    be = liq_cf(ai, num - (ω == 0 ? kg[o] : (1 - ω) * kg[o] + ω * kg[o+1]), R, Rm)
    be < a[1] && return (-Inf, 0.0)
    be = min(be, a[end])
    q = clamp(searchsortedlast(a, be), 1, length(a) - 1)
    (ω == 0 || ω == 1) && (n_ = (ω == 0 ? o : o + 1) + off;
                           v_ = lin_at(a, view(Vin, :, n_, s), be, q);
                           return isnan(v_) ? (-Inf, 0.0) : (v_, max(lin_at(a, view(muin, :, n_, s), be, q), 0.0)))
    v = (1 - ω) * lin_at(a, view(Vin, :, o + off, s), be, q) + ω * lin_at(a, view(Vin, :, o + 1 + off, s), be, q)
    isnan(v) && return (-Inf, 0.0)
    (v, max((1 - ω) * lin_at(a, view(muin, :, o + off, s), be, q) + ω * lin_at(a, view(muin, :, o + 1 + off, s), be, q), 0.0))
end

"Effective liquid wealth of an adjuster at liquid wealth ai and illiquid k_m whose option is node o with share ω towards the next."
@inline adj_liquid(ai, km, kg, o, ω, Rk, chi0, R, Rm = 0.0) = liq_cf(ai, Rk * km - chi0 - (ω == 0 ? kg[o] : (1 - ω) * kg[o] + ω * kg[o+1]), R, Rm)

"""
    solve_two_asset_egm(p, Q_agg; theta, theta_adj, full, tol, maxit, warm)

Returns the one-asset fields where they carry over, over a state (b, k, s)
array of size (na, nk, nz): lambda, P1 and effort by state, the probability of
adjusting, and the grids, plus V and Vb for warm starts.
"""
function solve_two_asset_egm(p0::SAGEParams, Q_agg::Float64; theta::Float64 = 0.01,
                             theta_adj::Float64 = 0.01, full::Bool = false, tol::Float64 = 1e-9,
                             maxit::Int = 5000, warm = nothing, trace::Bool = false,
                             fast::Bool = get(ENV, "SAGE_EGM2_FAST", "1") == "1",
                             howard::Int = parse(Int, get(ENV, "SAGE_HOWARD", "10")))
    # THE MEANS-TESTED FLOOR (V3_START.md section 141): as in the one-asset solver (`apply_floor!`), in each inner
    # problem, on the cash after rent, so a tenant on the floor has its rent covered (as Germany's Buergergeld covers
    # the housing costs on top of the standard rate); points on the floor have no marginal value of liquid wealth.
    isempty(p0.effort_set) && p0.job_effort && error("effort set by the job is not built for two assets yet")
    # survival enters discounting; the distribution adds the newborns
    p = p0.death > 0 ? update(p0; β = p0.β * (1 - p0.death)) : p0
    kg = illiquid_grid(p)
    a = liquid_grid(p, kg)
    z_vals, Π = SAGEBewley.income_process(p)
    na, nk, nz = length(a), p.nk, p.nz
    # each next illiquid node's borrowing limit, as the first feasible liquid node (1 without mortgages)
    k0 = [p.ltv > 0 ? findfirst(x -> x >= -p.ltv * kg[j] - 1e-12, a) : 1 for j in 1:nk]
    nk >= 2 || error("the illiquid grid needs at least two points")

    wv = [(1 + p.subsidy) * p.α[s] * z_vals[s] * p.Z for s in 1:nz]
    oth = [(-p.lumptax + transfer_at(p, s) - owner_rent(p, s), -p.lumptax + net_participation(p, p.α[s], z_vals[s]) + transfer_at(p, s) - owner_rent(p, s))
           for s in 1:nz]
    tfl = [floor_at(p, s) for s in 1:nz]
    bel = [p.social_strength * p.Λ * p.B[s] * Q_agg * p.qbar * belong_at(p, s) for s in 1:nz]
    # tenure: the tenant's cash is the owner's less rent; tenant nodes read the inner slots nk + 1 to 2 nk
    rentv = isempty(p.rent) ? zeros(nz) : p.rent
    length(rentv) == nz || error("rent needs one entry per income state")
    hasT = p.k_min > 0 && any(>(0), rentv) && any(<(p.k_min), kg)
    nsl = hasT ? 2 * nk : nk
    off = [hasT && kg[m] < p.k_min ? nk : 0 for m in 1:nk]
    # with a yield, oth already carries the owners' gross rent; the tenant pays its net rent instead, so the tenant's
    # extra over an owner is rentv - owner_rent (the housing benefit's negative in states out of work)
    rentx = [rentv[s] - owner_rent(p, s) for s in 1:nz]
    othT = [(oth[s][1] - rentx[s], oth[s][2] - rentx[s]) for s in 1:nz]
    D = zeros(na, nz); Dp = zeros(na, nz)
    if p.dread > 0 && !isempty(p.dread_q)
        for s in 1:nz, k in 1:na
            D[k, s] = dread_at(p, s, a[k])
            q = p.dread_q[s]
            xh = xcash(p, a[k]) + p.dread_hi[s]; xl = xcash(p, a[k]) + p.dread_lo[s]
            uh = xh > 1e-4 ? xh^(-p.γ) : 0.0; ul = xl > 1e-4 ? xl^(-p.γ) : 0.0
            Dp[k, s] = p.Γ * p.dread * q * Rb_at(p, a[k]) * (uh - ul)
        end
    end
    con_c = (fill(NaN, na, nz), fill(NaN, na, nz)); con_e = (zeros(na, nz), zeros(na, nz))
    con_cT = (fill(NaN, na, nz), fill(NaN, na, nz)); con_eT = (zeros(na, nz), zeros(na, nz))
    # the constrained solutions (next liquid wealth at the problem's limit a[k0]), one set per distinct limit
    function cons_at(kk)
        cc = (fill(NaN, na, nz), fill(NaN, na, nz)); ce = (zeros(na, nz), zeros(na, nz))
        ccT = (fill(NaN, na, nz), fill(NaN, na, nz)); ceT = (zeros(na, nz), zeros(na, nz))
        for s in 1:nz, d in (0, 1), i in 1:na
            c, e = egm_constrained(p, xcash(p, a[i]) - a[kk] + oth[s][d+1], wv[s], tfl[s], d; efix = isempty(p.effort_set) ? NaN : p.effort_set[s])
            cc[d+1][i, s] = c; ce[d+1][i, s] = e
            if hasT
                c, e = egm_constrained(p, xcash(p, a[i]) - a[kk] + othT[s][d+1], wv[s], tfl[s], d; efix = isempty(p.effort_set) ? NaN : p.effort_set[s])
                ccT[d+1][i, s] = c; ceT[d+1][i, s] = e
            end
        end
        (cc, ce, ccT, ceT)
    end
    consK = Dict(kk => cons_at(kk) for kk in unique(k0))
    con_c, con_e, con_cT, con_eT = consK[k0[1]]

    # keepers: k' = Rk k, between illiquid nodes j0 and j0 + 1 with weight om on the upper
    kn = [p.k_payout ? kg[m] : min(p.Rk * kg[m], kg[end]) for m in 1:nk]
    j0 = [clamp(searchsortedlast(kg, kn[m]), 1, nk - 1) for m in 1:nk]
    om = [clamp((kn[m] - kg[j0[m]]) / (kg[j0[m]+1] - kg[j0[m]]), 0.0, 1.0) for m in 1:nk]
    # With the return paid out (k_payout, 2026-10-06) a keeper holds k' = k and has (Rk - 1) k more
    # cash in hand: the inner solution at liquid wealth higher by ksh. An adjuster is as before.
    ksh = [((p.k_payout ? p.Rk - 1 : 0.0) + p.k_yield) * kg[m] / p.R for m in 1:nk]      # the return paid out, and the yield
    # adjusters: the shift in effective liquid wealth for each (current k_m, target k_j)
    # targets: (lower node, weight on the node above); k_sub = 1 gives the nodes themselves
    nsub = max(p.k_sub, 1); nf = (nk - 1) * nsub + 1
    # With tenure, the interval that crosses k_min offers its lower node only: a target inside it would be a lottery
    # between renting and owning (the split between the nodes), which no household can buy. With four targets to an
    # interval such lotteries made ownership 0.68 where the nodes alone give 0.05 (Germany cell 2 type 4, runs
    # 40504176503, 40504189298). Every other interval keeps its targets (a split between two dwellings' equity).
    jT = hasT ? something(findlast(<(p.k_min), kg), 0) : 0
    tj = [f == nf ? nk - 1 : (f - 1) ÷ nsub + 1 for f in 1:nf]
    tw = [f == nf ? 1.0 : ((f - 1) % nsub) / nsub for f in 1:nf]
    kt = [(1 - tw[f]) * kg[tj[f]] + tw[f] * kg[tj[f]+1] for f in 1:nf]
    RkA = p.Rk + p.k_yield            # an adjuster's cash from its dwelling: the sale at Rk k and the period's yield
    shift = [(RkA * kg[m] - p.chi0 - kt[f]) / p.R for m in 1:nk, f in 1:nf]

    V = zeros(na, nk, nz); Vb = zeros(na, nk, nz)
    wkey = (na, nk, nz, max(p.k_sub, 1))
    warm === nothing && fast && get(ENV, "SAGE_WARM2", "1") == "1" && haskey(WARM2, wkey) && (warm = WARM2[wkey])
    if warm !== nothing
        V .= warm.V; Vb .= warm.Vb
    else
        for s in 1:nz, m in 1:nk, i in 1:na
            c = con_c[1][i, s]; e = con_e[1][i, s]
            isnan(c) && (c = con_c[2][i, s]; e = con_e[2][i, s])
            isnan(c) && (e = 0.0)              # neither branch affordable (deep in debt, mortgages): no hours either
            c = isnan(c) ? 1e-6 : (p.ltv > 0 ? max(c + (p.Rk - 1) * kg[m], 1e-6) : c + (p.Rk - 1) * kg[m])
            V[i, m, s] = egm_flow(p, c, tfl[s] + e) / (1 - p.β)
            Vb[i, m, s] = p.R * p.Γ * c^(-p.γ)
        end
    end

    cin = (zeros(na, nsl, nz), zeros(na, nsl, nz)); ein = (zeros(na, nsl, nz), zeros(na, nsl, nz))
    bpin = (zeros(na, nsl, nz), zeros(na, nsl, nz)); vin = (zeros(na, nsl, nz), zeros(na, nsl, nz))
    Vin = zeros(na, nsl, nz); P1in = zeros(na, nsl, nz); muin = zeros(na, nsl, nz)
    Vn = similar(V); Vbn = similar(Vb); Padj = zeros(na, nk, nz)
    # Howard steps: each branch's flow at the full step's policy, the value less beta E V at its next liquid wealth
    flw = howard > 0 ? (zeros(na, nsl, nz), zeros(na, nsl, nz)) : (zeros(0, 0, 0), zeros(0, 0, 0))
    flr = p.cfloor > 0 ? (falses(na, nsl, nz), falses(na, nsl, nz)) : (falses(0, 0, 0), falses(0, 0, 0))
    qadj = zeros(nk, na, nk, nz)          # adjusting options: weight of option j at (i, m, s)
    wsel = zeros(nk, na, nk, nz)          # the target option j stands for: this share of the way from k_j to k_j+1
    # work arrays, one set per thread
    nth = Threads.nthreads()
    Vo_t = [zeros(nk) for _ in 1:nth]; Mo_t = [zeros(nk) for _ in 1:nth]
    EV_t = [zeros(na, nz) for _ in 1:nth]; EVb_t = [zeros(na, nz) for _ in 1:nth]
    Vc_t = [zeros(na, nz) for _ in 1:nth]; Vbc_t = [zeros(na, nz) for _ in 1:nth]
    aend_t = [zeros(na) for _ in 1:nth]; cend_t = [zeros(na) for _ in 1:nth]; eend_t = [zeros(na) for _ in 1:nth]
    Vj_t = [zeros(nf) for _ in 1:nth]; Mj_t = [zeros(nf) for _ in 1:nth]; ptr_t = [ones(Int, nf) for _ in 1:nth]
    Πts = sparse(Matrix(transpose(Π))); usesp = fast && nnz(Πts) < 0.35 * nz^2
    # JOB SEARCH (A; V3_START.md section 141), as in the one-asset solver: each searching state's row of the
    # transition is split into its part towards work (Pf) and the rest (Ps), and the search x chosen at each next
    # liquid node and next illiquid node weights them; its cost sits inside EV divided by beta. xs[k, j, s].
    search = !isempty(p.search_k)
    if search
        length(p.search_k) == nz || error("search_k has length $(length(p.search_k)), the problem $nz states")
        isEmp = isemp(p); Pf = copy(Π); Ps = copy(Π)
        for s in 1:nz
            p.search_k[s] > 0 || continue
            isEmp[s] && error("search_k is positive in a state in work ($s)")
            rowE = Π[s, :] .* isEmp; fs = sum(rowE)
            (0 < fs < 1) || error("search: state $s has no chance of work to reweight (it is $fs)")
            Pf[s, :] = rowE ./ fs; Ps[s, :] = (Π[s, :] .- rowE) ./ (1 - fs)
        end
        PfT = sparse(Matrix(transpose(Pf))); PsT = sparse(Matrix(transpose(Ps)))
        xs = zeros(na, nk, nz)
        EVf_t = [zeros(na, nz) for _ in 1:nth]; EVs_t = [zeros(na, nz) for _ in 1:nth]
        EVfb_t = [zeros(na, nz) for _ in 1:nth]; EVsb_t = [zeros(na, nz) for _ in 1:nth]
    else
        Pf = Π; Ps = Π; PfT = Πts; PsT = Πts; xs = zeros(0, 0, 0)
        EVf_t = EV_t; EVs_t = EV_t; EVfb_t = EV_t; EVsb_t = EV_t
    end
    sch = (on = search, PfT = PfT, PsT = PsT, xs = xs, k = p.search_k, lam = p.search_lam, γ = p.search_gamma,
           EVf = EVf_t, EVs = EVs_t, EVfb = EVfb_t, EVsb = EVsb_t)
    oc = isempty(p.out_cost) ? zeros(nz) : p.out_cost        # A's cost of being out of work, beyond income
    iters = 0
    t_in = 0.0; t_out = 0.0; t_how = 0.0; nhow = 0
    hist = zeros(maxit + 1); stall = 0.0; relax = 1.0; stalled = false
    polish = false                        # a refining pass, k_sub > 1: targets refined, value kept
    frozen = false; rounds = 0; itp = 0; hitmax = false     # value iteration at the refined targets; iterations in this phase
    nandbg = get(ENV, "SAGE_NANDBG", "0") == "1" && p.ltv > 0      # the mortgage build: where NaN first appears
    nandbg && println("  NaN at start: V ", count(isnan, V), ", Vb ", count(isnan, Vb), ", -Inf V ", count(==(-Inf), V))
    for it in 1:(K_ROUNDS+1)*(maxit+1)
        polish || (itp += 1)
        t0 = time()
        # inner: the liquid problem for every illiquid node taken as k'
        let V = V, Vb = Vb          # bound for the threads (V and Vb are swapped below)
        Threads.@threads for j in 1:nk
            tid = Threads.threadid()
            EV = EV_t[tid]; EVb = EVb_t[tid]
            if search
                copyto!(Vc_t[tid], view(V, :, j, :)); copyto!(Vbc_t[tid], view(Vb, :, j, :))
                search_mix!(EV, EVb, Vc_t[tid], Vbc_t[tid], sch, tid, j, p.β, false)
            elseif usesp
                copyto!(Vc_t[tid], view(V, :, j, :)); copyto!(Vbc_t[tid], view(Vb, :, j, :))
                mul!(EV, Vc_t[tid], Πts); mul!(EVb, Vbc_t[tid], Πts)
            else
                mul!(EV, view(V, :, j, :), Π'); mul!(EVb, view(Vb, :, j, :), Π')
            end
            for ten in (hasT ? (false, true) : (false,)), s in 1:nz, d in (0, 1)
                jj = ten ? j + nk : j; oo = ten ? othT : oth; kk = k0[j]; ck = consK[kk]
                cc_ = ten ? ck[3] : ck[1]; ce_ = ten ? ck[4] : ck[2]
                egm_branch!(view(cin[d+1], :, jj, :), view(ein[d+1], :, jj, :), view(bpin[d+1], :, jj, :),
                            view(vin[d+1], :, jj, :), p, a, view(EV, :, s), view(EVb, :, s),
                            s, d, wv[s], oo[s][d+1], tfl[s], bel[s], cc_[d+1], ce_[d+1],
                            aend_t[tid], cend_t[tid], eend_t[tid], view(D, :, s), view(Dp, :, s); k0 = kk)
                p.cfloor > 0 && apply_floor!(view(cin[d+1], :, jj, :), view(ein[d+1], :, jj, :), view(bpin[d+1], :, jj, :),
                                             view(vin[d+1], :, jj, :), view(flr[d+1], :, jj, :), p, a, view(EV, :, s), s, d,
                                             wv[s], oo[s][d+1], tfl[s], bel[s], view(D, :, s); k0 = kk)
                if howard > 0
                    fl = flw[d+1]; vv = vin[d+1]; bb = bpin[d+1]; EVs = view(EV, :, s)
                    @inbounds for i in 1:na
                        v = vv[i, jj, s]
                        fl[i, jj, s] = v == -Inf ? -Inf : v - p.β * SAGEBewley.interp_lin(a, EVs, bb[i, jj, s])
                    end
                end
            end
        end
        end
        @inbounds for x in eachindex(Vin)
            b0 = vin[1][x]; b1 = p.social_strength == 0 ? -Inf : vin[2][x]; mx = max(b0, b1)          # S exactly off: no participation choice without a payoff
            Vin[x] = mx == -Inf ? -Inf : mx + theta * log(exp((b0 - mx) / theta) + exp((b1 - mx) / theta)) - oc[(x - 1) ÷ (na * nsl) + 1]
            P1in[x] = b1 == -Inf ? 0.0 : (b0 == -Inf ? 1.0 : 1 / (1 + exp((b0 - b1) / theta)))
            mu0 = (b0 == -Inf || (p.cfloor > 0 && flr[1][x])) ? 0.0 : cin[1][x]^(-p.γ)
            mu1 = (b1 == -Inf || (p.cfloor > 0 && flr[2][x])) ? 0.0 : cin[2][x]^(-p.γ)
            muin[x] = p.Γ * ((1 - P1in[x]) * mu0 + P1in[x] * mu1) / p.pc   # marginal value of a euro: u'(c) / pc
        end
        t1 = time(); t_in += t1 - t0
        nandbg && it <= 2 && println("  it ", it, " inner: NaN vin ", count(isnan, vin[1]), "/", count(isnan, vin[2]), ", cin ", count(isnan, cin[1]),
                                     ", Vin ", count(isnan, Vin), " (-Inf ", count(==(-Inf), Vin), "), muin ", count(isnan, muin), ", P1in ", count(isnan, P1in),
                                     ", EV of last thread ", count(isnan, EV_t[1]), ", EVb ", count(isnan, EVb_t[1]))
        # outer: keep or adjust
        let Vn = Vn, Vbn = Vbn, polish = polish, frozen = frozen
        Threads.@threads for s in 1:nz
          tid = Threads.threadid()
          Vo = Vo_t[tid]; Mo = Mo_t[tid]; Vj = Vj_t[tid]; Mj = Mj_t[tid]; ptr = ptr_t[tid]
          @inbounds for m in 1:nk
            jl = j0[m] + off[m]; w = om[m]; of = off[m]
            fill!(ptr, 1)
            for i in 1:na
                if ksh[m] == 0
                    Vk = p.ltv > 0 ? mixw(Vin[i, jl, s], Vin[i, jl+1, s], w) : (1 - w) * Vin[i, jl, s] + w * Vin[i, jl+1, s]
                    Mk = (1 - w) * muin[i, jl, s] + w * muin[i, jl+1, s]
                else
                    bk = min(liq_after(p, a[i], ksh[m]), a[end]); qk = clamp(searchsortedlast(a, bk), 1, na - 1)
                    Vk = p.ltv > 0 ? mixw(lin_at(a, view(Vin, :, jl, s), bk, qk), lin_at(a, view(Vin, :, jl + 1, s), bk, qk), w) :
                         (1 - w) * lin_at(a, view(Vin, :, jl, s), bk, qk) + w * lin_at(a, view(Vin, :, jl + 1, s), bk, qk)
                    Mk = max((1 - w) * lin_at(a, view(muin, :, jl, s), bk, qk) + w * lin_at(a, view(muin, :, jl + 1, s), bk, qk), 0.0)
                    isnan(Vk) && (Vk = -Inf)
                end
                vmax = -Inf
                if frozen && !polish
                    # the targets of the last refining pass, held fixed
                    num_ = RkA * kg[m] - p.chi0
                    for j in 1:nk
                        Vo[j], Mo[j] = adj_eval(a, Vin, muin, s, j, wsel[j, i, m, s], a[i], num_, kg, p.R, of, p.Rm)
                        Vo[j] > vmax && (vmax = Vo[j])
                    end
                else
                for j in 1:nf
                    be = liq_after(p, a[i], shift[m, j])
                    if be < a[1]
                        Vj[j] = -Inf; Mj[j] = 0.0; continue
                    end
                    be = min(be, a[end])
                    q = ptr[j]
                    while q < na - 1 && a[q+1] <= be
                        q += 1
                    end
                    ptr[j] = q
                    jn = tj[j] + of; wn = tw[j]
                    if wn == 0.0
                        Vj[j] = lin_at(a, view(Vin, :, jn, s), be, q)
                        Mj[j] = max(lin_at(a, view(muin, :, jn, s), be, q), 0.0)
                    elseif wn == 1.0
                        Vj[j] = lin_at(a, view(Vin, :, jn + 1, s), be, q)
                        Mj[j] = max(lin_at(a, view(muin, :, jn + 1, s), be, q), 0.0)
                    else
                        Vj[j] = (1 - wn) * lin_at(a, view(Vin, :, jn, s), be, q) + wn * lin_at(a, view(Vin, :, jn + 1, s), be, q)
                        Mj[j] = max((1 - wn) * lin_at(a, view(muin, :, jn, s), be, q) + wn * lin_at(a, view(muin, :, jn + 1, s), be, q), 0.0)
                    end
                    isnan(Vj[j]) && (Vj[j] = -Inf; Mj[j] = 0.0)      # an unaffordable node next to an affordable one
                    Vj[j] > vmax && (vmax = Vj[j])
                end
                # one option per node: the best target in [k_j, k_j+1) (the node itself when k_sub = 1)
                for j in 1:nk
                    f1 = (j - 1) * nsub + 1; f2 = j == nk ? nf : j == jT ? f1 : j * nsub
                    fb = f1
                    for f in f1+1:f2
                        Vj[f] > Vj[fb] && (fb = f)
                    end
                    Vo[j] = Vj[fb]; Mo[j] = Mj[fb]; wsel[j, i, m, s] = j == nk ? 0.0 : tw[fb]
                end
                if polish && vmax > -Inf
                    # refine the options that carry weight: golden section around the best step
                    num = RkA * kg[m] - p.chi0; cut = vmax - 20 * theta_adj
                    for j in 1:nk-1
                        (Vo[j] < cut || j == jT) && continue
                        w0 = wsel[j, i, m, s]
                        lo = max(w0 - 1 / nsub, 0.0); hi = min(w0 + 1 / nsub, 1.0)
                        x1 = hi - GOLD * (hi - lo); x2 = lo + GOLD * (hi - lo)
                        v1, m1 = adj_eval(a, Vin, muin, s, j, x1, a[i], num, kg, p.R, of, p.Rm)
                        v2, m2 = adj_eval(a, Vin, muin, s, j, x2, a[i], num, kg, p.R, of, p.Rm)
                        for _ in 1:10
                            if v1 < v2
                                lo = x1; x1 = x2; v1 = v2; m1 = m2; x2 = lo + GOLD * (hi - lo)
                                v2, m2 = adj_eval(a, Vin, muin, s, j, x2, a[i], num, kg, p.R, of, p.Rm)
                            else
                                hi = x2; x2 = x1; v2 = v1; m2 = m1; x1 = hi - GOLD * (hi - lo)
                                v1, m1 = adj_eval(a, Vin, muin, s, j, x1, a[i], num, kg, p.R, of, p.Rm)
                            end
                        end
                        v1 < v2 && (v1 = v2; m1 = m2; x1 = x2)
                        if v1 > Vo[j]
                            Vo[j] = v1; Mo[j] = m1; wsel[j, i, m, s] = x1
                            v1 > vmax && (vmax = v1)
                        end
                    end
                end
                end
                if vmax == -Inf
                    Va_ = -Inf; Ma = 0.0
                    for j in 1:nk; qadj[j, i, m, s] = 0.0; end
                else
                    ssum = 0.0
                    for j in 1:nk
                        Vo[j] == -Inf && (qadj[j, i, m, s] = 0.0; continue)
                        ev = exp((Vo[j] - vmax) / theta_adj); qadj[j, i, m, s] = ev; ssum += ev
                    end
                    Ma = 0.0
                    for j in 1:nk
                        qadj[j, i, m, s] /= ssum; Ma += qadj[j, i, m, s] * Mo[j]
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
                Vbn[i, m, s] = Rb_at(p, a[i]) * Mbar
            end
          end
        end
        end
        t_out += time() - t1
        if polish                         # policies are in place; V and Vb stay the converged ones
            polish = false
            rounds >= K_ROUNDS && break
            rounds += 1; frozen = true; itp = 0; relax = 1.0; stalled = false
            continue
        end
        nandbg && it <= 2 && println("  it ", it, " outer: NaN Vn ", count(isnan, Vn), " (-Inf ", count(==(-Inf), Vn), "), Vbn ", count(isnan, Vbn), ", Padj ", count(isnan, Padj))
        dmin = Inf; dmax = -Inf
        @inbounds for x in eachindex(V)
            # states with no feasible choice (value -Inf: with mortgages, a tenant deep in debt, which no household
            # reaches) carry no change; if every state is infeasible the bounds stay infinite and the error below fires
            δ = Vn[x] - V[x]; isfinite(δ) || continue
            δ < dmin && (dmin = δ); δ > dmax && (dmax = δ)
        end
        dist = p.β / (1 - p.β) * (dmax - dmin)
        # a state with no feasible choice (value -Inf: resources after rent and tax not positive) leaves NaN changes,
        # which the bounds skip; said at once rather than read as convergence (the flat-rent test, section 141)
        if !isfinite(dist)
            # name the states (the mortgage build, 27 October): where the change is not finite, the first few
            nbad = 0
            for x in eachindex(V)
                δ = Vn[x] - V[x]
                isfinite(δ) && continue
                ci = Tuple(CartesianIndices(V)[x]); nbad += 1
                nbad <= 12 && println("  not finite at b = ", a[ci[1]], " (node ", ci[1], "), k = ", kg[ci[2]], " (node ", ci[2], "), s = ", ci[3],
                                      ": V ", V[x], " -> ", Vn[x], ", adjust ", Padj[x], ", limit there ", -p.ltv * kg[ci[2]])
            end
            println("  ", nbad, " states not finite of ", length(V))
            error("the two-asset household problem has a state with no feasible choice at iteration $it (value -Inf or NaN): check rent, benefits and the tax")
        end
        # RELAXATION. The kinks that the keep-or-adjust choice puts in the liquid
        # problem can make the plain iteration cycle (Italy and France,
        # 2026-09-29). Convergence is judged on the full Bellman step (the bound
        # above), but when the best bound of the last 50 iterations is not 10%
        # below the best of the 50 before, each update moves only part of the way,
        # halving the step each time down to 1/16. The fixed point is unchanged.
        # A remaining stall below 1e-2 at the smallest step averages the last two
        # iterates and stops; `stalled` in the result records it and its size.
        hist[itp] = dist
        if itp > 100 && itp % 50 == 0 && minimum(view(hist, itp-49:itp)) > 0.9 * minimum(view(hist, itp-99:itp-50))
            if relax > 1 / 16
                relax /= 2
            elseif dist < 1e-2
                stalled = true
            end
            trace && println("  full step ", itp, ": bound ", dist, ", relaxation now ", relax, stalled ? ", stall accepted" : "")
        end
        if dist < tol || stalled
            Vn .+= p.β / (1 - p.β) * 0.5 * (dmin + dmax)
            if stalled
                Vn .= 0.5 .* (Vn .+ V); Vbn .= 0.5 .* (Vbn .+ Vb); stall = dist
            end
        else
            # the midpoint of the bounds, every iteration (fast; see the header)
            fast && (Vn .+= p.β / (1 - p.β) * 0.5 * (dmin + dmax))
        end
        if !(dist < tol || stalled) && relax < 1
            @inbounds for x in eachindex(V)
                Vn[x] = V[x] + relax * (Vn[x] - V[x]); Vbn[x] = Vb[x] + relax * (Vbn[x] - Vb[x])
            end
        end
        trace && (it % 100 == 0 || it < 4) && println("  it ", it, " dist ", dist, " relax ", relax, " adjusting ", sum(Padj) / length(Padj))
        if trace && it % 500 == 0
            dm = 0.5 * (dmin + dmax); dv = vec(abs.((Vn .- V) .- dm)); dv[.!isfinite.(dv)] .= 0.0
            worst = sortperm(dv, rev = true)[1:6]
            for x in worst
                ci = Tuple(CartesianIndices(V)[x])
                println("    cycling at (b ", ci[1], " = ", round(a[ci[1]], digits = 3), ", k ", ci[2], " = ", round(kg[ci[2]], digits = 3), ", s ", ci[3], "): change ", Vn[x] - V[x] - dm, ", adjust prob ", Padj[x], ", limit ", round(-p.ltv * kg[ci[2]], digits = 3))
            end
        end
        V, Vn = Vn, V; Vb, Vbn = Vbn, Vb
        iters += 1
        isnan(dist) && error("the two-asset household problem has a state with no feasible choice (value NaN at iteration $it)")
        if howard > 0 && relax == 1 && !(dist < tol || stalled || itp == maxit)
            th = time()
            for _ in 1:howard
                howard_step!(Vn, V, Vin, p, a, kg, Π, Πts, usesp, flw, bpin, P1in, j0, om, ksh, qadj, wsel, Padj,
                             theta, theta_adj, EV_t, Vc_t, off, hasT, sch, oc)
                V, Vn = Vn, V
            end
            t_how += time() - th; nhow += howard
        end
        if dist < tol || stalled || itp == maxit
            (itp == maxit && !(dist < tol || stalled)) && (hitmax = true)
            nsub > 1 || break
            polish = true
        end
    end
    # said, not swallowed: running out of iterations, and a stall accepted at more
    # than a fifth of the smoothing scale (the summaries do not carry `stalled`)
    hitmax && @warn "solve_two_asset_egm stopped at maxit without converging" maxit tol
    stall > 0.2 * theta_adj && @warn "solve_two_asset_egm accepted a stalled iteration" stall theta_adj chi0 = p.chi0

    # policies by state, for the distribution and the aggregates
    t2 = time()
    get(ENV, "SAGE_MEM", "0") == "1" &&
        (println("  two-asset value iteration: ", iters, " iterations, ", nk, " nodes, ", nf, " targets, resident memory ", round(Sys.maxrss() / 1e9; digits = 2), " GB"); flush(stdout))
    trace && @printf("  value iteration: inner %.1f s, outer %.1f s, Howard %.1f s (%d steps)\n", t_in, t_out, t_how, nhow)
    fast && get(ENV, "SAGE_WARM2", "1") == "1" && (WARM2[wkey] = (V = copy(V), Vb = copy(Vb)))
    dist = two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj;
                                  wsel = wsel, ksh = ksh, death = p0.death, oth = oth, wv = wv, trs = [transfer_at(p, s) for s in 1:nz],
                                  off = off, rent = rentx, sch = sch, Pf = Pf, Ps = Ps)
    λ = dist.lambda; P1s = dist.P1; es = dist.e
    trace && @printf("  distribution %.1f s\n", time() - t2)
    part = 0.0; meaninc = 0.0; partbase = 0.0
    @inbounds for s in 1:nz, m in 1:nk, i in 1:na
        w_ = λ[i, m, s]; w_ == 0 && continue
        part += w_ * P1s[i, m, s]
        meaninc += w_ * p.α[s] * z_vals[s] * es[i, m, s]
        partbase += w_ * P1s[i, m, s] * p.α[s] * z_vals[s]
    end
    full || return p.qbar * part, part, meaninc, partbase
    (Q = p.qbar * part, rate = part, meaninc = meaninc, partbase = partbase, a = a, k = kg,
     lambda = λ, P1 = P1s, e = es, e_d = dist.e_d, cbar = dist.cbar, ybar = dist.ybar, post = dist.post,
     Pi = Π, Padj = Padj, V = V, Vb = Vb, z_vals = z_vals,
     iters = iters, stalled = stall, relax = relax, theta = theta, inner = (c = cin, e = ein, bp = bpin, P1 = P1in), qadj = qadj,
     j0 = j0, om = om, shift = shift, ksh = ksh, wsel = wsel, adjp = (Rk = p.Rk + p.k_yield, chi0 = p.chi0, R = p.R, Rm = p.Rm),
     off = off, rent = rentx, tenant = [kg[m] < p.k_min && hasT for m in 1:nk], floor = flr,
     search_xs = xs, Pf = Pf, Ps = Ps,
     timing = (inner = t_in, outer = t_out, howard = t_how, howard_steps = nhow, threads = nth, sparse = usesp))
end

"Value only of adjusting to option o at share ω (`adj_eval` without the marginal value)."
@inline function adj_value(a, Vin, s, o, ω, ai, num, kg, R, off = 0, Rm = 0.0)
    be = liq_cf(ai, num - (ω == 0 ? kg[o] : (1 - ω) * kg[o] + ω * kg[o+1]), R, Rm)
    be < a[1] && return -Inf
    be = min(be, a[end])
    q = clamp(searchsortedlast(a, be), 1, length(a) - 1)
    v = ω == 0 ? lin_at(a, view(Vin, :, o + off, s), be, q) : ω == 1 ? lin_at(a, view(Vin, :, o + 1 + off, s), be, q) :
        (1 - ω) * lin_at(a, view(Vin, :, o + off, s), be, q) + ω * lin_at(a, view(Vin, :, o + 1 + off, s), be, q)
    isnan(v) ? -Inf : v        # an unaffordable side (-Inf) next to an affordable one
end

"""
The expectation over next period's state at illiquid node j with job search (`sch`): EV and EVb from the parts of
the transition towards work and the rest, mixed by the search x chosen at each next liquid node (stored in
sch.xs[:, j, s]) or, with `fixed`, by the x stored there (Howard steps; EVb === nothing). As in egm_core.jl:
x = (beta lam (EVf - EVs) / k)^(1/gamma) within [0, 1], the cost inside EV divided by beta.
"""
function search_mix!(EV, EVb, Vc, Vbc, sch, tid, j, β, fixed)
    EVf = sch.EVf[tid]; EVs = sch.EVs[tid]
    mul!(EVf, Vc, sch.PfT); mul!(EVs, Vc, sch.PsT)
    if EVb !== nothing
        mul!(sch.EVfb[tid], Vbc, sch.PfT); mul!(sch.EVsb[tid], Vbc, sch.PsT)
    end
    na, nz = size(EV); γs = sch.γ
    @inbounds for s in 1:nz
        ks = sch.k[s]
        if ks <= 0
            for k in 1:na; EV[k, s] = EVf[k, s]; end
            EVb !== nothing && for k in 1:na; EVb[k, s] = sch.EVfb[tid][k, s]; end
            continue
        end
        lam = isempty(sch.lam) ? 1.0 : sch.lam[s]
        for k in 1:na
            if fixed
                x = sch.xs[k, j, s]
            else
                Δ = EVf[k, s] - EVs[k, s]
                x = Δ > 0 ? min((β * lam * Δ / ks)^(1 / γs), 1.0) : 0.0
                sch.xs[k, j, s] = x
            end
            pw = lam * x
            EV[k, s] = pw * EVf[k, s] + (1 - pw) * EVs[k, s] - ks * x^(1 + γs) / ((1 + γs) * β)
            EVb !== nothing && (EVb[k, s] = pw * sch.EVfb[tid][k, s] + (1 - pw) * sch.EVsb[tid][k, s])
        end
    end
end

"The chance of work chosen by a searching household of state s that goes to next liquid wealth bp at node j (0 if not searching)."
@inline search_pw(sch, a, bp, j, s) = (sch.on && sch.k[s] > 0) ?
    SAGEBewley.interp_lin(a, view(sch.xs, :, j, s), bp) * (isempty(sch.lam) ? 1.0 : sch.lam[s]) : NaN

# x log x with 0 log 0 = 0
@inline xlogx(x) = x > 0 ? x * log(x) : 0.0

"""
One Howard step (see the header): Vout = the value of the full step's policy evaluated on V. Inner: each branch's
flow plus beta E V at its next liquid wealth, the branches combined at the participation probabilities with their
entropy. Outer: the keeper's value, the adjusting options at their targets and probabilities, the keep-or-adjust
probability, each logit with its entropy. Vin is a work array.
"""
function howard_step!(Vout, V, Vin, p, a, kg, Π, Πts, usesp, flw, bpin, P1in, j0, om, ksh, qadj, wsel, Padj,
                      theta, theta_adj, EV_t, Vc_t, off, hasT, sch, oc)
    na, nk, nz = size(V)
    Threads.@threads for j in 1:nk
        tid = Threads.threadid(); EV = EV_t[tid]
        if sch.on
            copyto!(Vc_t[tid], view(V, :, j, :)); search_mix!(EV, nothing, Vc_t[tid], nothing, sch, tid, j, p.β, true)
        elseif usesp
            copyto!(Vc_t[tid], view(V, :, j, :)); mul!(EV, Vc_t[tid], Πts)
        else
            mul!(EV, view(V, :, j, :), Π')
        end
        @inbounds for jj in (hasT ? (j, j + nk) : (j,)), s in 1:nz
            EVs = view(EV, :, s)
            for i in 1:na
                P = P1in[i, jj, s]; v = 0.0; ent = 0.0
                if P < 1
                    f0 = flw[1][i, jj, s]
                    v0 = f0 == -Inf ? -Inf : f0 + p.β * SAGEBewley.interp_lin(a, EVs, bpin[1][i, jj, s])
                    v += (1 - P) * v0; ent += xlogx(1 - P)
                end
                if P > 0
                    v1 = flw[2][i, jj, s] + p.β * SAGEBewley.interp_lin(a, EVs, bpin[2][i, jj, s])
                    v += P * v1; ent += xlogx(P)
                end
                Vin[i, jj, s] = v == -Inf ? -Inf : v - theta * ent - oc[s]
            end
        end
    end
    Threads.@threads for s in 1:nz
        @inbounds for m in 1:nk
            jl = j0[m] + off[m]; w = om[m]; num = (p.Rk + p.k_yield) * kg[m] - p.chi0; of = off[m]
            for i in 1:na
                if ksh[m] == 0
                    Vk = (1 - w) * Vin[i, jl, s] + w * Vin[i, jl+1, s]
                else
                    bk = min(liq_after(p, a[i], ksh[m]), a[end]); qk = clamp(searchsortedlast(a, bk), 1, na - 1)
                    Vk = (1 - w) * lin_at(a, view(Vin, :, jl, s), bk, qk) + w * lin_at(a, view(Vin, :, jl + 1, s), bk, qk)
                end
                pa = Padj[i, m, s]
                if pa == 0
                    Vout[i, m, s] = Vk; continue
                end
                Va = 0.0; ent = 0.0
                for o in 1:nk
                    q = qadj[o, i, m, s]; q == 0 && continue
                    Va += q * adj_value(a, Vin, s, o, wsel[o, i, m, s], a[i], num, kg, p.R, of, p.Rm); ent += xlogx(q)
                end
                out = pa * (Va - theta_adj * ent) - theta_adj * xlogx(pa)
                pa < 1 && (out += (1 - pa) * Vk - theta_adj * xlogx(1 - pa))
                Vout[i, m, s] = out
            end
        end
    end
    Vout
end

"""
The stationary distribution over (b, k, s). The decision part maps (b, k, s)
to post-decision (b', k', s) by lotteries on both grids (Young 2010); the
income transition then mixes s. Mass starts at k = 0. Also returns the
participation probability and expected effort by state.
"""
function two_asset_distribution(p, a, kg, Π, j0, om, shift, P1in, ein, bpin, Padj, qadj;
                                wsel = nothing, ksh = nothing, death = 0.0, oth = nothing, wv = nothing, trs = nothing,
                                off = nothing, rent = nothing, sch = nothing, Pf = nothing, Ps = nothing)
    na, nk, nz = length(a), length(kg), size(Π, 1)
    off === nothing && (off = zeros(Int, nk)); rent === nothing && (rent = zeros(nz))
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
    X = p.cfloor                      # with the floor, resources below it are topped up to it (0: no floor)
    cc(res, bp) = ((X > 0 ? max(res, X) : res) - bp) / p.pc    # consumption from the budget with the policies, as agency_summary does for
    # one asset, so the two agree exactly when the illiquid asset is inert
    # with job search a searching branch's mass is split, before the income step, into the part that goes on with
    # the transition towards work (weight pw, the chance chosen at its next wealth) and the rest (`rowsS`)
    srch = sch !== nothing && sch.on
    rowsS = Int[]; colsS = Int[]; valsS = Float64[]
    function blot!(from, bp, j, s, wt)
        k = clamp(searchsortedlast(a, bp), 1, na - 1)
        w = clamp((a[k+1] - bp) / (a[k+1] - a[k]), 0.0, 1.0)
        pw = srch ? search_pw(sch, a, bp, j, s) : NaN
        if isnan(pw)
            push!(rows, from); push!(cols, idx(k, j, s)); push!(vals, wt * w)
            push!(rows, from); push!(cols, idx(k + 1, j, s)); push!(vals, wt * (1 - w))
        else
            push!(rows, from); push!(cols, idx(k, j, s)); push!(vals, wt * w * pw)
            push!(rows, from); push!(cols, idx(k + 1, j, s)); push!(vals, wt * (1 - w) * pw)
            push!(rowsS, from); push!(colsS, idx(k, j, s)); push!(valsS, wt * w * (1 - pw))
            push!(rowsS, from); push!(colsS, idx(k + 1, j, s)); push!(valsS, wt * (1 - w) * (1 - pw))
        end
    end
    @inbounds for s in 1:nz, m in 1:nk, i in 1:na
        from = idx(i, m, s); pa = Padj[i, m, s]
        of = off[m]; rt = of > 0 ? rent[s] : 0.0           # a tenant's inner slots and rent
        # keeping: the two illiquid nodes around Rk k, inner solution at liquid b
        for (jn, wk) in ((j0[m], 1 - om[m]), (j0[m] + 1, om[m]))
            wt = (1 - pa) * wk; wt <= 0 && continue
            jj = jn + of
            if ksh !== nothing && ksh[m] != 0
                # the return paid out: the inner solution at liquid wealth higher by ksh
                be = min(liq_after(p, a[i], ksh[m]), a[end])
                r = clamp(searchsortedlast(a, be), 1, na - 1)
                p1 = clamp(lin_at(a, view(P1in, :, jj, s), be, r), 0.0, 1.0)
                e0 = max(lin_at(a, view(ein[1], :, jj, s), be, r), 0.0); e1 = max(lin_at(a, view(ein[2], :, jj, s), be, r), 0.0)
                b0 = max(lin_at(a, view(bpin[1], :, jj, s), be, r), a[1]); b1 = max(lin_at(a, view(bpin[2], :, jj, s), be, r), a[1])
                P1s[i, m, s] += wt * p1
                es[i, m, s] += wt * ((1 - p1) * e0 + p1 * e1)
                e0s[i, m, s] += wt * (1 - p1) * e0; e1s[i, m, s] += wt * p1 * e1
                if haveC
                    c0 = cc(xcash(p, be) + wv[s] * e0 + oth[s][1] - rt, b0)
                    c1 = cc(xcash(p, be) + wv[s] * e1 + oth[s][2] - rt, b1)
                    p1 < 1 && (cbar[i, m, s] += wt * (1 - p1) * c0; ybar[i, m, s] += wt * (1 - p1) * (wv[s] * e0 + trs[s]))
                    p1 > 0 && (cbar[i, m, s] += wt * p1 * c1; ybar[i, m, s] += wt * p1 * (wv[s] * e1 + trs[s]))
                end
                p1 < 1 && blot!(from, b0, jn, s, wt * (1 - p1))
                p1 > 0 && blot!(from, b1, jn, s, wt * p1)
                continue
            end
            p1 = P1in[i, jj, s]
            P1s[i, m, s] += wt * p1
            es[i, m, s] += wt * ((1 - p1) * ein[1][i, jj, s] + p1 * ein[2][i, jj, s])
            e0s[i, m, s] += wt * (1 - p1) * ein[1][i, jj, s]; e1s[i, m, s] += wt * p1 * ein[2][i, jj, s]
            if haveC
                c0 = cc(xcash(p, a[i]) + wv[s] * ein[1][i, jj, s] + oth[s][1] - rt, bpin[1][i, jj, s])   # real consumption
                c1 = cc(xcash(p, a[i]) + wv[s] * ein[2][i, jj, s] + oth[s][2] - rt, bpin[2][i, jj, s])
                p1 < 1 && (cbar[i, m, s] += wt * (1 - p1) * c0; ybar[i, m, s] += wt * (1 - p1) * (wv[s] * ein[1][i, jj, s] + trs[s]))
                p1 > 0 && (cbar[i, m, s] += wt * p1 * c1; ybar[i, m, s] += wt * p1 * (wv[s] * ein[2][i, jj, s] + trs[s]))
            end
            p1 < 1 && blot!(from, bpin[1][i, jj, s], jn, s, wt * (1 - p1))
            p1 > 0 && blot!(from, bpin[2][i, jj, s], jn, s, wt * p1)
        end
        pa <= 0 && continue
        # adjusting: each target, at its effective liquid wealth, to the node below it and
        # the node above with the target's weights (one node when the target is a node)
        for o in 1:nk
            q = qadj[o, i, m, s]; pa * q <= 1e-12 && continue
            ω = wsel === nothing ? 0.0 : wsel[o, i, m, s]
            for (j, wn) in ((o, 1 - ω), (o + 1, ω))
            wn <= 0 && continue
            wt = pa * q * wn; wt <= 1e-12 && continue
            be = min(adj_liquid(a[i], kg[m], kg, o, ω, p.Rk + p.k_yield, p.chi0, p.R, p.Rm), a[end])
            r = clamp(searchsortedlast(a, be), 1, na - 1)
            js = j + of
            p1 = clamp(lin_at(a, view(P1in, :, js, s), be, r), 0.0, 1.0)
            e0 = lin_at(a, view(ein[1], :, js, s), be, r); e1 = lin_at(a, view(ein[2], :, js, s), be, r)
            b0 = max(lin_at(a, view(bpin[1], :, js, s), be, r), a[1]); b1 = max(lin_at(a, view(bpin[2], :, js, s), be, r), a[1])
            P1s[i, m, s] += wt * p1
            e0 = max(e0, 0.0); e1 = max(e1, 0.0)
            es[i, m, s] += wt * ((1 - p1) * e0 + p1 * e1)
            e0s[i, m, s] += wt * (1 - p1) * e0; e1s[i, m, s] += wt * p1 * e1
            if haveC
                c0 = cc(xcash(p, be) + wv[s] * e0 + oth[s][1] - rt, b0)
                c1 = cc(xcash(p, be) + wv[s] * e1 + oth[s][2] - rt, b1)
                p1 < 1 && (cbar[i, m, s] += wt * (1 - p1) * c0; ybar[i, m, s] += wt * (1 - p1) * (wv[s] * e0 + trs[s]))
                p1 > 0 && (cbar[i, m, s] += wt * p1 * c1; ybar[i, m, s] += wt * p1 * (wv[s] * e1 + trs[s]))
            end
            p1 < 1 && blot!(from, b0, j, s, wt * (1 - p1))
            p1 > 0 && blot!(from, b1, j, s, wt * p1)
            end
        end
    end
    Tt = transpose(sparse(rows, cols, vals, n, n))
    TtS = srch ? transpose(sparse(rowsS, colsS, valsS, n, n)) : nothing
    empty!(rowsS); empty!(colsS); empty!(valsS)
    postS = srch ? zeros(n) : Float64[]
    # the triplets are the largest objects of a solve and nothing downstream reads them: released here
    # (they were returned with the solution until 2026-10-04, and sent from every worker to the master)
    nent = length(vals)
    if get(ENV, "EGM2_TRACE", "0") == "1"
        rs = vec(sum(sparse(rows, cols, vals, n, n), dims = 2))
        println("  row sums of the decision operator: min ", minimum(rs), " max ", maximum(rs))
    end
    empty!(rows); empty!(cols); empty!(vals); sizehint!(rows, 0); sizehint!(cols, 0); sizehint!(vals, 0)
    get(ENV, "SAGE_MEM", "0") == "1" &&
        (println("  two-asset distribution: ", nent, " transition entries over ", n, " states, resident memory ", round(Sys.maxrss() / 1e9; digits = 2), " GB"); flush(stdout))
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
        if srch
            # searching states: towards work Pf on the first part, Ps on the rest (Pf is Pi's row elsewhere)
            mul!(postS, TtS, λ)
            mul!(Nx, P, Pf); mul!(Nx, reshape(postS, na * nk, nz), Ps, 1.0, 1.0)
        else
            mul!(Nx, P, Π)
        end
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
    get(ENV, "EGM2_TRACE", "0") == "1" && println("  distribution iterations ", nit)
    λ ./= sum(λ)
    @inbounds for x in eachindex(e0s)
        m0 = 1 - P1s[x]; e0s[x] = m0 > 1e-14 ? e0s[x] / m0 : 0.0
        e1s[x] = P1s[x] > 1e-14 ? e1s[x] / P1s[x] : 0.0
    end
    (lambda = reshape(λ, na, nk, nz), P1 = P1s, e = es, e_d = (e0s, e1s), cbar = cbar, ybar = ybar, post = nothing)
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
each_branch(f, sol, i, m, s) = each_branch_full((wt, d, bp, j, e, be) -> f(wt, d, bp, j), sol, i, m, s)

"""
    each_branch_full(f, sol, i, m, s)

As `each_branch`, calling f(wt, d, bprime, j, e, be) with also the effort e of
the branch and its effective liquid wealth be: b itself for a keeper, b plus
(Rk k - chi0 - k_j) / R for an adjuster.
"""
function each_branch_full(f, sol, i, m, s)
    a = sol.a; na = length(a); inn = sol.inner
    pa = sol.Padj[i, m, s]
    of = hasproperty(sol, :off) ? sol.off[m] : 0          # a tenant's inner slots (the callback gets the node)
    for (jn, wk) in ((sol.j0[m], 1 - sol.om[m]), (sol.j0[m] + 1, sol.om[m]))
        wt = (1 - pa) * wk; wt <= 0 && continue
        jj = jn + of
        if hasproperty(sol, :ksh) && sol.ksh[m] != 0      # the return paid out (k_payout)
            be = min(liq_cf(a[i], sol.adjp.R * sol.ksh[m], sol.adjp.R, sol.adjp.Rm), a[end]); r = clamp(searchsortedlast(a, be), 1, na - 1)
            p1 = clamp(lin_at(a, view(inn.P1, :, jj, s), be, r), 0.0, 1.0)
            p1 < 1 && f(wt * (1 - p1), 0, max(lin_at(a, view(inn.bp[1], :, jj, s), be, r), a[1]), jn,
                        max(lin_at(a, view(inn.e[1], :, jj, s), be, r), 0.0), be)
            p1 > 0 && f(wt * p1, 1, max(lin_at(a, view(inn.bp[2], :, jj, s), be, r), a[1]), jn,
                        max(lin_at(a, view(inn.e[2], :, jj, s), be, r), 0.0), be)
            continue
        end
        p1 = inn.P1[i, jj, s]
        p1 < 1 && f(wt * (1 - p1), 0, inn.bp[1][i, jj, s], jn, inn.e[1][i, jj, s], a[i])
        p1 > 0 && f(wt * p1, 1, inn.bp[2][i, jj, s], jn, inn.e[2][i, jj, s], a[i])
    end
    pa <= 0 && return
    for o in 1:length(sol.k)
        q = sol.qadj[o, i, m, s]; pa * q <= 1e-12 && continue
        ω = sol.wsel[o, i, m, s]
        be = min(adj_liquid(a[i], sol.k[m], sol.k, o, ω, sol.adjp.Rk, sol.adjp.chi0, sol.adjp.R, sol.adjp.Rm), a[end])
        r = clamp(searchsortedlast(a, be), 1, na - 1)
        for (j, wn) in ((o, 1 - ω), (o + 1, ω))
            wn <= 0 && continue
            wt = pa * q * wn; wt <= 1e-12 && continue
            js = j + of
            p1 = clamp(lin_at(a, view(inn.P1, :, js, s), be, r), 0.0, 1.0)
            p1 < 1 && f(wt * (1 - p1), 0, max(lin_at(a, view(inn.bp[1], :, js, s), be, r), a[1]), j,
                        max(lin_at(a, view(inn.e[1], :, js, s), be, r), 0.0), be)
            p1 > 0 && f(wt * p1, 1, max(lin_at(a, view(inn.bp[2], :, js, s), be, r), a[1]), j,
                        max(lin_at(a, view(inn.e[2], :, js, s), be, r), 0.0), be)
        end
    end
end

"""
    two_asset_welfare_parts(p0, sol)

`welfare_parts` for the two-asset solution: the policy evaluation of consumption,
effort and belonging over (b, k, s), under the branches the distribution follows,
discounted at beta (1 - death) as the solver does (perpetual youth). The
propensities are out of a liquid windfall at unchanged illiquid wealth. Saving is
next liquid wealth plus the net illiquid outlay, k_j + chi0 - Rk k for an
adjuster and zero for a keeper, so that consumption plus saving is again the
windfall plus the change in earnings.
"""
function two_asset_welfare_parts(p0::SAGEParams, sol)
    p = p0.death > 0 ? update(p0; β = p0.β * (1 - p0.death)) : p0
    a = sol.a; kg = sol.k; λ = sol.lambda; z = sol.z_vals; Π = sol.Pi
    na, nk, ns = length(a), length(kg), length(z)
    κ = 1.0 + p.commute
    wv = [(1 + p.subsidy) * p.α[s] * z[s] * p.Z for s in 1:ns]
    oth = [(-p.lumptax + transfer_at(p, s) - owner_rent(p, s), -p.lumptax + net_participation(p, p.α[s], z[s]) + transfer_at(p, s) - owner_rent(p, s)) for s in 1:ns]
    tfl = [floor_at(p, s) for s in 1:ns]
    bel = [p.social_strength * p.Λ * p.B[s] * p.qbar * belong_at(p, s) for s in 1:ns]
    idx(i, m, s) = i + (m - 1) * na + (s - 1) * na * nk
    n = na * nk * ns
    uc = zeros(n); ue = zeros(n); ub = zeros(n); ubu = zeros(n); ueu = zeros(n)      # the last two: reporting_core.jl
    ud = zeros(n); uk = zeros(n)          # dread in choices and the cost of job search, as in reporting_core.jl
    dreadV = p.dread > 0 && !isempty(p.dread_q)
    sch = hasproperty(sol, :search_xs) && !isempty(sol.search_xs) ?
          (on = true, xs = sol.search_xs, k = p.search_k, lam = p.search_lam) : (on = false,)
    sbar = zeros(na, nk, ns); lbar = zeros(na, nk, ns)
    rows = Int[]; cols = Int[]; vals = Float64[]; rowsS = Int[]; colsS = Int[]; valsS = Float64[]
    @inbounds for s in 1:ns, m in 1:nk, i in 1:na
        x = idx(i, m, s)
        rt = hasproperty(sol, :tenant) && sol.tenant[m] ? sol.rent[s] : 0.0
        each_branch_full(sol, i, m, s) do wt, d, bp, j, e, be
            res = xcash(p, be) + wv[s] * e + oth[s][d+1] - rt
            c = max(((p.cfloor > 0 ? max(res, p.cfloor) : res) - bp) / p.pc, 1e-10)   # the floor's top-up
            T = tfl[s] + κ * e + p.qbar * d
            uc[x] += wt * p.Γ * c^(1 - p.γ) / (1 - p.γ)
            ue[x] -= wt * p.Γ * p.ϕ * T^(1 + p.ψ) / (1 + p.ψ)
            ub[x] += wt * bel[s] * d
            if z[s] == 0 && d == 1
                ubu[x] += wt * bel[s]
                ueu[x] -= wt * p.Γ * p.ϕ * (T^(1 + p.ψ) - (T - p.qbar)^(1 + p.ψ)) / (1 + p.ψ)
            end
            sbar[i, m, s] += wt * (bp + p.R * (a[i] - be))     # R (b - be) is the net illiquid outlay
            lbar[i, m, s] += wt * wv[s] * e
            dreadV && (ud[x] -= wt * dread_at(p, s, bp))
            k = clamp(searchsortedlast(a, bp), 1, na - 1)
            wk = clamp((a[k+1] - bp) / (a[k+1] - a[k]), 0.0, 1.0)
            # the decision only (same income state); the income transition is applied in the iteration. With job
            # search the searching branch is split between the transition towards work (pw) and the rest.
            pw = search_pw(sch, a, bp, j, s)
            if isnan(pw)
                push!(rows, x); push!(cols, idx(k, j, s)); push!(vals, wt * wk)
                push!(rows, x); push!(cols, idx(k + 1, j, s)); push!(vals, wt * (1 - wk))
            else
                xx = pw / (isempty(p.search_lam) ? 1.0 : p.search_lam[s])
                uk[x] -= wt * p.search_k[s] * xx^(1 + p.search_gamma) / (1 + p.search_gamma)
                push!(rows, x); push!(cols, idx(k, j, s)); push!(vals, wt * wk * pw)
                push!(rows, x); push!(cols, idx(k + 1, j, s)); push!(vals, wt * (1 - wk) * pw)
                push!(rowsS, x); push!(colsS, idx(k, j, s)); push!(valsS, wt * wk * (1 - pw))
                push!(rowsS, x); push!(colsS, idx(k + 1, j, s)); push!(valsS, wt * (1 - wk) * (1 - pw))
            end
        end
    end
    # Policy evaluation by iteration on V = u + beta D (V Pi'), with D the decision operator and Pi the
    # income transition. Until 2026-10-04 the operator D Pi was assembled (every branch times every income
    # state: some 140 million entries on 24 nodes) and (I - beta D Pi) factorised, which took 8 to 16 GB a
    # household problem. That, and not the solver, is what killed the two-asset runs on the runners and
    # restarted the laptop three times on 3 October.
    D = sparse(rows, cols, vals, n, n)
    DS = sch.on ? sparse(rowsS, colsS, valsS, n, n) : nothing
    empty!(rows); empty!(cols); empty!(vals); sizehint!(rows, 0); sizehint!(cols, 0); sizehint!(vals, 0)
    empty!(rowsS); empty!(colsS); empty!(valsS)
    U = hcat(uc, ue, ub, ubu, ueu, ud, uk); X = U ./ (1 - p.β); Y = similar(X); Xn = similar(X)
    Πt = Matrix(transpose(sch.on ? sol.Pf : Π)); nb_ = na * nk
    PsT = sch.on ? Matrix(transpose(sol.Ps)) : Πt; YS = sch.on ? similar(X) : X
    for it in 1:20_000
        for q in 1:size(X, 2)
            mul!(reshape(view(Y, :, q), nb_, ns), reshape(view(X, :, q), nb_, ns), Πt)
            sch.on && mul!(reshape(view(YS, :, q), nb_, ns), reshape(view(X, :, q), nb_, ns), PsT)
        end
        mul!(Xn, D, Y); sch.on && mul!(Xn, DS, YS, 1.0, 1.0); Xn .= U .+ p.β .* Xn
        dd = maximum(abs, Xn .- X); X, Xn = Xn, X
        dd * p.β / (1 - p.β) < 1e-11 * (1 + maximum(abs, X)) && break
        it == 20_000 && @warn "two_asset_welfare_parts: the policy evaluation stopped at its iteration limit" dd
    end
    Vc = X[:, 1]; Ve = X[:, 2]; Vb = X[:, 3]; Vbu = X[:, 4]; Veu = X[:, 5]; Vd = X[:, 6]; Vk = X[:, 7]
    get(ENV, "SAGE_MEM", "0") == "1" &&
        (println("  two-asset welfare parts: ", nnz(D), " decision entries, resident memory ", round(Sys.maxrss() / 1e9; digits = 2), " GB"); flush(stdout))
    vmass = zeros(ns); vcmass = zeros(ns); vemass = zeros(ns); vbmass = zeros(ns)
    vbumass = zeros(ns); veumass = zeros(ns); mppumass = zeros(ns); vdmass = zeros(ns); vkmass = zeros(ns)
    mpsmass = zeros(ns); mpemass = zeros(ns); mppmass = zeros(ns)
    @inbounds for s in 1:ns, m in 1:nk, i in 1:na
        mm = λ[i, m, s]; mm <= 0 && continue
        x = idx(i, m, s)
        vmass[s] += mm * sol.V[i, m, s]; vcmass[s] += mm * Vc[x]; vemass[s] += mm * Ve[x]; vbmass[s] += mm * Vb[x]
        vbumass[s] += mm * Vbu[x]; veumass[s] += mm * Veu[x]; vdmass[s] += mm * Vd[x]; vkmass[s] += mm * Vk[x]
        Δ = sol.ybar[i, m, s] / 12
        if Δ > 0
            ai = liq_cf(a[i], Δ, p.R, p.Rm)
            mpsmass[s] += mm * (interp_ext(a, view(sbar, :, m, s), ai) - sbar[i, m, s]) / Δ
            mpemass[s] += mm * (interp_ext(a, view(lbar, :, m, s), ai) - lbar[i, m, s]) / Δ
            dp = mm * (interp_ext(a, view(sol.P1, :, m, s), ai) - sol.P1[i, m, s])
            mppmass[s] += dp; z[s] == 0 && (mppumass[s] += dp)
        end
    end
    (vmass = vmass, vcmass = vcmass, vemass = vemass, vbmass = vbmass,
     mpsmass = mpsmass, mpemass = mpemass, mppmass = mppmass,
     vbumass = vbumass, veumass = veumass, mppumass = mppumass, vdmass = vdmass, vkmass = vkmass)
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
    # the public outlay (V3_START.md section 141): the floor's top-ups, branch by branch, and the housing benefit of
    # tenants; the tax that finances the floor (floor_tax_of) finances both
    fout = 0.0
    wvv = [(1 + p.subsidy) * p.α[s] * z[s] * p.Z for s in 1:nz]
    othv = [(-p.lumptax + transfer_at(p, s) - owner_rent(p, s), -p.lumptax + net_participation(p, p.α[s], z[s]) + transfer_at(p, s) - owner_rent(p, s)) for s in 1:nz]
    ten = hasproperty(sol, :tenant) ? sol.tenant : falses(nk)
    @inbounds for i_z in 1:nz, m in 1:nk, i_a in 1:na
        w = λ[i_a, m, i_z]
        w <= 0 && continue
        W[i_z, i_a] += w; K[i_z, m] += w; mass[i_z] += w
        # net wealth: split between the two NWGRID points around b + k
        nw = a[i_a] + kg[m]; q = clamp(searchsortedlast(NWGRID, nw), 1, length(NWGRID) - 1)
        t = clamp((nw - NWGRID[q]) / (NWGRID[q+1] - NWGRID[q]), 0.0, 1.0)
        N[i_z, q] += w * (1 - t); N[i_z, q+1] += w * t
        p1 = P1[i_a, m, i_z]; part[i_z] += w * p1
        ten[m] && !isempty(p.hb) && (fout += w * p.hb[i_z])
        if p.cfloor > 0
            rt = ten[m] ? sol.rent[i_z] : 0.0
            each_branch_full(sol, i_a, m, i_z) do wt, d, bp, j, e, be
                res = xcash(p, be) + wvv[i_z] * e + othv[i_z][d+1] - rt
                res < p.cfloor && (fout += w * wt * (p.cfloor - res))
            end
        end
        α = p.α[i_z]; zz = z[i_z]
        cap = (p.R - 1) * a[i_a]
        credit = p.partcredit * α * zz * p.Z * p.qbar
        tr = transfer_at(p, i_z)
        employed = zz > 0
        for d in (0, 1)
            wd = d == 1 ? w * p1 : w * (1 - p1)
            wd <= 0 && continue
            e = sol.e_d[d+1][i_a, m, i_z]
            y = ((1 + p.subsidy) * α * zz * p.Z * e + cap - p.lumptax + (d == 1 ? credit : 0.0) + tr) / p.pc   # real, as in cell_summary
            ymean += wd * y; ym_s[i_z] += wd * y
            employed && y < ymin_E && (ymin_E = y)
            employed && (eff_E += wd * e)
            k = searchsortedfirst(YGRID, y)
            if k <= length(YGRID)
                Y[k] += wd; Ys[i_z, k] += wd
                np > 0 && a[i_a] / p.pc < thr[1][2] && (ypoor[k] += wd)
            end
            for q in 1:np
                y < thr[q][1] || continue
                jinc[i_z, q] += wd
                a[i_a] / p.pc < thr[q][2] && (jboth[i_z, q] += wd)
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
     jinc = jinc, jboth = jboth, thresholds = thr, eff_E = eff_E, ypoor = ypoor, fout = fout)
end

"""
    two_asset_agency_summary(p, sol)

`agency_summary` for the two-asset solution, the same fields plus the wealthy hand-to-mouth, rewritten for the
labour chain and a sub-annual period (V3_START.md section 141) as the one-asset summary is (agency_shock.jl).
Hand-to-mouth, room to manoeuvre, the MPCs and dread are on LIQUID wealth: poor hand-to-mouth hold no illiquid
wealth, wealthy hand-to-mouth some (Kaplan, Violante and Weidner 2014). Windfalls are liquid, at unchanged illiquid
wealth. The households' own choices are followed forward through both assets (`each_branch`): next liquid wealth by
the lottery on the liquid grid, next illiquid node j. A job is lost into the U states, pE[u] the employed state with
u's latent productivity and pU[s] the U state with s's. Deaths are left out of the cohorts followed (one in 180 a
quarter). With job search a searching branch moves on with the transition towards work at the chance it chose and
with the rest otherwise, as in the distribution.
"""
function two_asset_agency_summary(p::SAGEParams, sol)
    a = sol.a; kg = sol.k; λ = sol.lambda; z = sol.z_vals; Π = sol.Pi
    na, nk, ns = length(a), length(kg), length(z)
    cbar = sol.cbar; ybar = sol.ybar; ppy = p.ppy
    pmass = zeros(ns); pinc = zeros(ns); dmass = zeros(ns); hmass = zeros(ns); whmass = zeros(ns)
    mpcmass = zeros(ns); mpchmass = zeros(ns); mpcwmass = zeros(ns); rmass = zeros(ns); xmass = zeros(ns); cmass = zeros(ns)
    stv = stypes(p); empv = stv .== :E
    U = findall(stv .=== :U); haveU = !isempty(U) && any(empv)
    pE = haveU ? partner_index(p, :E) : Int[]; pU = haveU ? partner_index(p, :U) : Int[]
    dw = dread_weight(p)
    nzr = [findall(Π[s, :] .> 0) for s in 1:ns]
    sch = hasproperty(sol, :search_xs) && !isempty(sol.search_xs) ?
          (on = true, xs = sol.search_xs, k = p.search_k, lam = p.search_lam) : (on = false,)
    Pf = sch.on ? sol.Pf : Π; Ps = sch.on ? sol.Ps : Π
    kmass = zeros(ns); smass = zeros(ns)
    # the step from (i, m, s): f(probability, liquid bracket k, weight on k, next illiquid node j, next state s2),
    # next liquid wealth raised by `shift` (a windfall carried into next period)
    function step!(f, i, m, s, shift = 0.0)
        each_branch(sol, i, m, s) do wt, d, bp, j
            b2 = bp + shift
            k = clamp(searchsortedlast(a, b2), 1, na - 1); wk = clamp((a[k+1] - b2) / (a[k+1] - a[k]), 0.0, 1.0)
            pw = search_pw(sch, a, bp, j, s)
            for s2 in nzr[s]
                pr = isnan(pw) ? Π[s, s2] : pw * Pf[s, s2] + (1 - pw) * Ps[s, s2]
                pr > 0 && f(wt * pr, k, wk, j, s2)
            end
        end
    end
    @inbounds for s in 1:ns, m in 1:nk, i in 1:na
        mm = λ[i, m, s]; mm <= 0 && continue
        cb = view(cbar, :, m, s)
        htm = a[i] <= ybar[i, m, s] * ppy / 52
        htm && (m == 1 ? (hmass[s] += mm) : (whmass[s] += mm))
        a[i] >= ybar[i, m, s] * ppy / 4 && (rmass[s] += mm)
        cmass[s] += mm * cb[i]
        Δ = ybar[i, m, s] * ppy / 12
        if Δ > 0
            mpc = p.pc * (interp_ext(a, cb, liq_cf(a[i], Δ, p.R, p.Rm)) - cb[i]) / Δ   # spending share of the windfall
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
        # job search: the chance chosen, and its cost as a consumption equivalent (as agency_shock.jl)
        if sch.on && p.search_k[s] > 0
            xx = 0.0
            each_branch(sol, i, m, s) do wt, d, bp, j
                xx += wt * SAGEBewley.interp_lin(a, view(sch.xs, :, j, s), bp)
            end
            smass[s] += mm * xx
            K = p.search_k[s] * xx^(1 + p.search_gamma) / (1 + p.search_gamma)
            if cb[i] > 0
                kq = 1 - (1 - p.γ) * K / (p.Γ * cb[i]^(1 - p.γ))
                kq > 0 && (kmass[s] += mm * (1 - kq^(1 / (1 - p.γ))))
            end
        end
        haveU || continue
        pc = 0.0; py = 0.0
        each_branch(sol, i, m, s) do wt, d, bp, j
            for u in U
                pr = Π[s, u]; pr <= 0 && continue
                cE = SAGEBewley.interp_lin(a, view(cbar, :, j, pE[u]), bp)
                cU = SAGEBewley.interp_lin(a, view(cbar, :, j, u), bp)
                yE = SAGEBewley.interp_lin(a, view(ybar, :, j, pE[u]), bp)
                yU = SAGEBewley.interp_lin(a, view(ybar, :, j, u), bp)
                cE > 0 && (pc += wt * pr * max(0.0, 1 - cU / cE))
                yE > 0 && (py += wt * pr * max(0.0, 1 - yU / yE))
            end
        end
        pmass[s] += mm * pc; pinc[s] += mm * py
        empv[s] && cb[i] > 0 && (dmass[s] += mm * max(0.0, 1 - cbar[i, m, pU[s]] / cb[i]))
    end
    lumpm = zeros(ns); nonem = zeros(ns); mpc12mass = zeros(ns); kz = zeros(ns)
    if ppy > 1
        # 1. the twelve-month MPC: expected consumption t periods on, summed over the year
        G = copy(cbar); C = copy(cbar)
        for t in 1:ppy-1
            Gn = zeros(na, nk, ns)
            let Gc = G
                for s in 1:ns, m in 1:nk, i in 1:na
                    step!(i, m, s) do q, k, wk, j, s2
                        Gn[i, m, s] += q * (wk * Gc[k, j, s2] + (1 - wk) * Gc[k+1, j, s2])
                    end
                end
            end
            G = Gn; C .+= G
        end
        for s in 1:ns, m in 1:nk, i in 1:na
            mm = λ[i, m, s]; mm <= 0 && continue
            Δ = ybar[i, m, s] * ppy / 12
            Δ > 0 && (mpc12mass[s] += mm * p.pc * (interp_ext(a, view(C, :, m, s), liq_cf(a[i], Δ, p.R, p.Rm)) - C[i, m, s]) / Δ)
        end
        # 2. the fall as Kolsrud, Landais, Nilsson and Spinnewijn (2018) measure it
        dur = isempty(p.dur) ? zeros(Int, ns) : p.dur
        U1 = [stv[s] === :U && dur[s] == 1 for s in 1:ns]; U2 = [stv[s] === :U && dur[s] == 2 for s in 1:ns]
        if any(U1) && any(U2)
            c1 = zeros(na, nk, ns)
            for s in 1:ns
                empv[s] || continue
                for m in 1:nk, i in 1:na
                    mm = λ[i, m, s]; mm <= 0 && continue
                    step!(i, m, s) do q, k, wk, j, s2
                        U1[s2] || return
                        kz[1] += mm * q; kz[2] += mm * q * cbar[i, m, s]
                        c1[k, j, s2] += mm * q * wk; c1[k+1, j, s2] += mm * q * (1 - wk)
                    end
                end
            end
            for s in 1:ns, m in 1:nk, i in 1:na
                c1[i, m, s] > 0 || continue
                kz[3] += c1[i, m, s] * cbar[i, m, s]
                step!(i, m, s) do q, k, wk, j, s2
                    U2[s2] || return
                    kz[4] += c1[i, m, s] * q; kz[5] += c1[i, m, s] * q * (wk * cbar[k, j, s2] + (1 - wk) * cbar[k+1, j, s2])
                end
            end
            # 4. time out of work after job loss (U, L, N), the cohort's mass still out of work by quarter
            let cur = copy(c1), T = min(ns, 40)
                for t in 1:T
                    nxt = zeros(na, nk, ns)
                    for s in 1:ns, m in 1:nk, i in 1:na
                        mq = cur[i, m, s]; mq > 0 || continue
                        nonem[t] += mq
                        step!(i, m, s) do q, k, wk, j, s2
                            empv[s2] && return
                            nxt[k, j, s2] += mq * q * wk; nxt[k+1, j, s2] += mq * q * (1 - wk)
                        end
                    end
                    cur = nxt
                end
            end
            # 3. a lump sum at the start of the spell, the current spell only (SAGE_COHORT_LUMP times the last
            #    period's income in work, into liquid wealth)
            LUMP = parse(Float64, get(ENV, "SAGE_COHORT_LUMP", "0.1"))
            ds_ = [stv[s] === :U && dur[s] < NONENT ? dur[s] : 0 for s in 1:ns]; nUq = maximum(ds_)
            if 4 * nUq <= ns && LUMP > 0
                cl = zeros(na, nk, ns)
                for s in 1:ns
                    empv[s] || continue
                    for m in 1:nk, i in 1:na
                        mm = λ[i, m, s]; mm <= 0 && continue
                        step!(i, m, s, LUMP * ybar[i, m, s] / p.R) do q, k, wk, j, s2
                            U1[s2] || return
                            cl[k, j, s2] += mm * q * wk; cl[k+1, j, s2] += mm * q * (1 - wk)
                        end
                    end
                end
                for (jj, c0) in enumerate((c1, cl))
                    cur = c0
                    for dq in 1:nUq
                        nxt = zeros(na, nk, ns)
                        for s in 1:ns, m in 1:nk, i in 1:na
                            mq = cur[i, m, s]; mq > 0 || continue
                            lumpm[(jj-1)*2*nUq+dq] += mq
                            step!(i, m, s) do q, k, wk, j, s2
                                if empv[s2]
                                    lumpm[(jj-1)*2*nUq+nUq+dq] += mq * q
                                elseif stv[s2] === :U && ds_[s2] == dq + 1
                                    nxt[k, j, s2] += mq * q * wk; nxt[k+1, j, s2] += mq * q * (1 - wk)
                                end
                            end
                        end
                        cur = nxt
                    end
                end
            end
        end
    end
    merge((pmass = pmass, pinc = pinc, dmass = dmass, hmass = hmass, whmass = whmass,
           mpcmass = mpcmass, mpchmass = mpchmass, mpcwmass = mpcwmass, rmass = rmass, xmass = xmass, cmass = cmass,
           kmass = kmass, smass = smass, mpc12mass = mpc12mass, kolmass = kz, lumpmass = lumpm, nonempmass = nonem),
          two_asset_welfare_parts(p, sol))
end
