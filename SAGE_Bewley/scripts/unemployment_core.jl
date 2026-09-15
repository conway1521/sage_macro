# Stage 6 core: the four-state (z, s) household with unemployment risk, the
# per-cell summary everything downstream is read off, and the hardship
# categories. Specification: STAGE6.md Parts 2 to 4. Requires SAGEBewley,
# proto_participation_core.jl, sa_core.jl, agency_core.jl.

using Printf, Statistics, LinearAlgebra, Serialization, Distributed

const E_REF = 0.53          # reference paid-time share (engine's phi calibration, INSEE EDT 2010)

# ---------------------------------------------------------------- process --
"""
    unemployment_process(base, delta, f)

Four-state process on (z, s) from a two-state Rouwenhorst `base`. State
order: (U, z1), (U, z2), (E, z1), (E, z2). Productivity evolves by the
Rouwenhorst matrix whether or not employed; employment moves by
[1-f f; delta 1-delta]; the two are independent. Returns the state values
(zero in the unemployed states), the transition matrix, the latent
productivity in every state, the employment flag, and the Rouwenhorst
stationary distribution.
"""
function unemployment_process(base::SAGEParams, δ::Float64, f::Float64)
    base.z_vals_override === nothing ||
        error("unemployment_process expects a plain Rouwenhorst base")
    z2, Π2 = SAGEBewley.income_process(base)
    nz = length(z2)
    # stationary distribution of the productivity chain
    πz = fill(1 / nz, nz)
    for _ in 1:10_000
        πn = Π2' * πz
        maximum(abs, πn - πz) < 1e-15 && (πz = πn; break)
        πz = πn
    end
    Ps = [1-f f; δ 1-δ]                      # from (U, E) to (U, E)
    n = 2nz
    Π = zeros(n, n)
    for si in 1:2, i in 1:nz, sj in 1:2, j in 1:nz
        Π[(si-1)*nz + i, (sj-1)*nz + j] = Ps[si, sj] * Π2[i, j]
    end
    (z_vals = vcat(zeros(nz), z2), Π = Π, z_latent = vcat(z2, z2),
     employed = vcat(falses(nz), trues(nz)), pi_z = πz, u = δ / (δ + f))
end

"""
    cell_params_u(alpha; delta, f, rr, ...)

Cell parameter set with unemployment risk. Benefit in the unemployed states is
rr * alpha * z_latent * Z * E_REF, earnings-related. Zero return to effort
when unemployed, so effort is zero there. `lumptax` should already include
the unemployment-insurance tax (see `ui_tax`).
"""
function cell_params_u(αg; δ, f, rr, na = 200, ne = 80, a_max = 4.0, pexp = 3.0,
                       subsidy = 0.0, lumptax = 0.0, partcredit = 0.0,
                       β = 0.96, pcost = 0.0, nz = 2)
    base = SAGEParams(na = na, ne = ne, nz = nz, α = fill(αg, nz), B = fill(1.0, nz),
                      a_max = a_max, pexp = pexp)
    if δ === nothing
        # No unemployment: a plain nz-state productivity process and no
        # transfer. This is a DIFFERENT state space from the one below, not the
        # one below with the separation rate set to zero, so the reduction test
        # that compares them is a real test.
        z, Π = SAGEBewley.income_process(base)
        return SAGEParams(na = na, ne = ne, nz = nz, α = fill(αg, nz), B = fill(1.0, nz),
                          z_vals_override = z, Π_override = Π,
                          a_max = a_max, pexp = pexp, subsidy = subsidy, lumptax = lumptax,
                          partcredit = partcredit, β = β, pcost = pcost)
    end
    up = unemployment_process(base, δ, f)
    n = length(up.z_vals)
    b = [up.employed[i] ? 0.0 : rr * αg * up.z_latent[i] * base.Z * E_REF for i in 1:n]
    SAGEParams(na = na, ne = ne, nz = n, α = fill(αg, n), B = fill(1.0, n),
               z_vals_override = up.z_vals, Π_override = up.Π, transfer = b,
               a_max = a_max, pexp = pexp, subsidy = subsidy, lumptax = lumptax,
               partcredit = partcredit, β = β, pcost = pcost)
end

# ---------------------------------------------------- discount-factor types --
"""
    beta_nodes(nabla; bbar = 0.96, n = 5)

Equal-mass discretisation of a uniform distribution of the discount factor on
[bbar - nabla, bbar + nabla]: the midpoints of n equal-probability intervals.
This is the beta-dist specification of Carroll, Slacalek, Tokuoka and White
(2017), Quantitative Economics 8(3), whose spread is calibrated to wealth
data; the device is Krusell and Smith (1998).

Refuses a spread whose patient end puts beta times the gross return above
0.995. `MODEL_READINESS.md` records why: near one the wealth distribution
becomes truncation-driven rather than stationary, and aggregates move with
the top of the asset grid. That is a modelling limit, not a numerical one, so
it errors rather than clipping silently.
"""
function beta_nodes(∇; bbar = 0.96, n = 5, R = 1.02)
    ∇ <= 0 && return [bbar]
    bs = [bbar - ∇ + 2∇ * (i - 0.5) / n for i in 1:n]
    maximum(bs) * R <= 0.995 ||
        error("beta spread too wide: max(beta) * R = $(round(maximum(bs) * R, digits = 5)) " *
              "exceeds 0.995, where the wealth distribution stops being stationary")
    bs
end

"""
    collapse(ds, w)

Mix a set of `cell_summary` results with weights `w`. Every field is linear in
the stationary distribution, so mixing permanent types is exact; the minimum
employed income is a minimum rather than a mean because it is used as a
feasibility check.
"""
function collapse(ds, w)
    n = length(ds); length(w) == n || error("weights do not match")
    acc(fld) = sum(w[i] .* getfield(ds[i], fld) for i in 1:n)
    (W = acc(:W), mass = acc(:mass), part = acc(:part), Y = acc(:Y), Ys = acc(:Ys),
     ym_s = acc(:ym_s), jinc = acc(:jinc), jboth = acc(:jboth), ymean = acc(:ymean),
     rate = acc(:rate), minc = acc(:minc), pbase = acc(:pbase), eff_E = acc(:eff_E),
     ypoor = acc(:ypoor),
     ymin_E = minimum(d.ymin_E for d in ds), thresholds = ds[1].thresholds)
end

"Closed-form lump-sum tax financing the benefit: the joint stationary law is a
product, so cost per head is sum_g share_g u_g sum_z pi_z b_{g,z}."
function ui_tax(cells, f, rr; Z = 1.0, nz = 2)
    T = 0.0
    for c in cells
        c.δ === nothing && continue
        base = SAGEParams(nz = nz, α = fill(c.α, nz), B = fill(1.0, nz))
        up = unemployment_process(base, c.δ, f)
        nz = length(up.pi_z)
        T += c.share * up.u * sum(up.pi_z[i] * rr * c.α * up.z_latent[i] * Z * E_REF for i in 1:nz)
    end
    T
end

# ---------------------------------------------------------------- summary --
"""
    cell_summary(p, sol)

Everything downstream needs from one solved cell, all linear in the
stationary distribution so that pooling across nodes and cells is exact:

  W       nz x na, cumulative wealth mass by state (each row sums to the
          state's mass, not to one)
  mass    state masses
  part    participating mass by state (so rate_s = part_s / mass_s)
  Y       cumulative mass of disposable income on YGRID
  ymean   mean disposable income
  ym_s    disposable-income mass by state (ym_s / mass = state mean)
  ymin_E  minimum disposable income over all employed states with positive
          mass, used to verify that no employed household is income-poor
  rate, minc, pbase   as the solver returns them
"""
function cell_summary(p::SAGEParams, sol; thresholds = nothing)
    a = sol.a; λ = sol.lambda; P1 = sol.P1; z = sol.z_vals
    na, nz = p.na, p.nz
    W = zeros(nz, na); mass = zeros(nz); part = zeros(nz); ym_s = zeros(nz)
    Y = zeros(length(YGRID)); Ys = zeros(nz, length(YGRID)); ypoor = zeros(length(YGRID))
    ymean = 0.0; ymin_E = Inf
    # joint indicators at each (ypov, abar) pair in `thresholds`: exact for
    # every state, employed included, which the per-state wealth trick cannot
    # give. Pair 1 is the anchored headline; the rest serve the sensitivity
    # tables (horizons, plus and minus ten percent).
    thr = thresholds === nothing ? Tuple{Float64,Float64}[] : collect(thresholds)
    np = length(thr)
    jinc = zeros(nz, np); jboth = zeros(nz, np); eff_E = 0.0
    # Asset-poor mass BY INCOME, accumulated here because it needs the joint
    # distribution of income and wealth, which cannot be recovered from the two
    # marginals afterwards. `ypoor` is cumulative on YGRID exactly as `Y` is,
    # so any income-quantile statistic follows by reading the two together and
    # splitting the boundary bin proportionally. That matters: income has atoms
    # and a hard quintile boundary puts a whole atom on one side, which gave
    # quintile masses of 0.11 to 0.26 instead of 0.20. Uses the headline
    # threshold pair. The OECD publishes this profile (Balestra and Tonkin
    # 2018, Figure 6.2: 68 percent asset-poor in the bottom income quintile,
    # 43 in the second highest, 27 in the top), so it tests the SHAPE of the
    # joint distribution rather than any level.
    @inbounds for i_z in 1:nz, i_a in 1:na
        w = λ[i_a, i_z]
        w <= 0 && continue
        W[i_z, i_a] += w; mass[i_z] += w
        p1 = P1[i_a, i_z]; part[i_z] += w * p1
        α = p.α[i_z]; zz = z[i_z]
        cap = (p.R - 1) * a[i_a]
        credit = p.partcredit * α * zz * p.Z * QBAR
        tr = transfer_at(p, i_z)
        employed = zz > 0
        for d in (0, 1)
            wd = d == 1 ? w * p1 : w * (1 - p1)
            wd <= 0 && continue
            y = (1 + p.subsidy) * α * zz * p.Z * sol.e_d[d+1][i_a, i_z] +
                cap - p.lumptax + (d == 1 ? credit : 0.0) + tr
            ymean += wd * y; ym_s[i_z] += wd * y
            employed && y < ymin_E && (ymin_E = y)
            employed && (eff_E += wd * sol.e_d[d+1][i_a, i_z])
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
        cumsum!(view(W, i_z, :), view(W, i_z, :))
        cumsum!(view(Ys, i_z, :), view(Ys, i_z, :))
    end
    cumsum!(Y, Y); cumsum!(ypoor, ypoor)
    (W = W, mass = mass, part = part, Y = Y, Ys = Ys, ymean = ymean, ym_s = ym_s,
     ymin_E = ymin_E, rate = sol.rate, minc = sol.meaninc, pbase = sol.partbase,
     jinc = jinc, jboth = jboth, thresholds = thr, eff_E = eff_E, ypoor = ypoor)
end

# ----------------------------------------------------------- categories --
"""
    hardship(P, q = 1)

The OECD categories for one pooled cell `P` (see `pool` in the driver), at the
q-th threshold pair the families were built with (1 = anchored headline). Income-poor and both come from the
stored joint indicators, exact for every state; asset-poor from the per-state
wealth distributions. All as shares of the cell. Returns income-poor,
asset-poor, both, vulnerable (asset-poor and not income-poor), union, and the
same split by employment status.
"""
function hardship(P, q::Int = 1)
    ypov, abar = P.thresholds[q]
    nz = length(P.mass)
    inc = 0.0; ast = 0.0; both = 0.0
    incU = 0.0; astU = 0.0; bothU = 0.0; mU = 0.0
    for s in 1:nz
        as = share_below_interp(P.agrid, view(P.W, s, :), abar)
        ast += as; inc += P.jinc[s, q]; both += P.jboth[s, q]
        if !P.employed[s]
            astU += as; incU += P.jinc[s, q]; bothU += P.jboth[s, q]; mU += P.mass[s]
        end
    end
    mE = 1 - mU
    (inc = inc, asset = ast, both = both, vulnerable = ast - both, union = inc + ast - both,
     u = mU,
     inc_U = incU / mU, asset_U = astU / mU, union_U = (incU + astU - bothU) / mU,
     inc_E = (inc - incU) / mE, asset_E = (ast - astU) / mE,
     union_E = ((inc - incU) + (ast - astU) - (both - bothU)) / mE)
end

"Hardship at thresholds other than the stored ones: exact for the unemployed
(income there is monotone in wealth), and for the employed provided none is
income-poor at that line, which is checked."
function hardship_at(P, ypov, abar; R = 1.02)
    nz = length(P.mass); inc = 0.0; ast = 0.0; both = 0.0
    P.ymin_E > ypov || return nothing
    for s in 1:nz
        Ws = view(P.W, s, :)
        as = share_below_interp(P.agrid, Ws, abar); ast += as
        P.employed[s] && continue
        astar = (ypov - (P.transfer[s] - P.lumptax)) / (R - 1)
        astar <= 0 && continue
        inc += share_below_interp(P.agrid, Ws, astar)
        both += share_below_interp(P.agrid, Ws, min(abar, astar))
    end
    (inc = inc, asset = ast, both = both, vulnerable = ast - both, union = inc + ast - both)
end

"""
    asset_poverty_by_quantile(Y, ypoor, nq = 5)

Asset poverty within each income quantile, from the two cumulative vectors on
YGRID. The boundary bin is split proportionally, so an atom of income sitting
across a quintile line contributes to both sides in the right ratio rather
than landing wholly on one. Returns the poverty rate in each quantile and the
mass in each, which should each be 1/nq and is returned so the caller can
check rather than assume.
"""
function asset_poverty_by_quantile(Y, ypoor, nq = 5)
    tot = Y[end]
    tot <= 0 && return (rate = fill(NaN, nq), mass = zeros(nq))
    "cumulative poor mass at the point where cumulative total mass equals t"
    at(t) = begin
        t <= 0 && return 0.0
        t >= tot && return ypoor[end]
        k = searchsortedfirst(Y, t)
        k <= 1 && return ypoor[1] * (Y[1] > 0 ? t / Y[1] : 0.0)
        k > length(Y) && return ypoor[end]
        dY = Y[k] - Y[k-1]
        dY <= 0 ? ypoor[k-1] : ypoor[k-1] + (ypoor[k] - ypoor[k-1]) * (t - Y[k-1]) / dY
    end
    rate = zeros(nq); mass = zeros(nq)
    for i in 1:nq
        lo = (i - 1) / nq * tot; hi = i / nq * tot
        mass[i] = (hi - lo) / tot
        rate[i] = (at(hi) - at(lo)) / (hi - lo)
    end
    (rate = rate, mass = mass)
end

# ----------------------------------------------------------------- family --
"""
    build_family_u(p0, ugrid, theta; threaded = true, thresholds = nothing)

Solve the cell `p0` at every belonging scale in `ugrid` and return one
`cell_summary` per node. Parallel over PROCESSES (Distributed.pmap) when
workers have been added, serial otherwise; the keyword name `threaded` is
kept for the callers. Threads are not used: Julia 1.7 under Rosetta livelocked
twice in the threaded garbage collector on this workload (2026-09-10 and
2026-09-11, both with every thread spinning in jl_gc_pool_alloc), once at the
first family and once at the eighth, so the failure is not a warm-up issue.
Separate processes share no collector and cannot do this.
"""
function build_family_u(p0::SAGEParams, ugrid, theta; threaded = true, thresholds = nothing)
    solve1 = u -> begin
        p = update(p0; social_strength = u)
        s = solve_participation_logit(p, 1.0; theta = theta, full = true)
        cell_summary(p, s; thresholds = thresholds)
    end
    if threaded && nworkers() > 1
        return pmap(solve1, ugrid)
    end
    [solve1(u) for u in ugrid]
end

"""
    build_family_u(p0s::Vector{SAGEParams}, ugrid, theta; weights, ...)

The same, for a population of permanent types (stage 7 discount factors). Every
(type, belonging scale) problem goes into one flat pmap so the workers stay
full, and the types are mixed at each scale by `collapse`. With one type this
is identical to the single-parameter method.
"""
function build_family_u(p0s::Vector{SAGEParams}, ugrid, theta;
                        weights = fill(1 / length(p0s), length(p0s)),
                        threaded = true, thresholds = nothing)
    nt = length(p0s); nu = length(ugrid)
    jobs = [(i, j) for j in 1:nu for i in 1:nt]
    solve1 = ij -> begin
        i, j = ij
        p = update(p0s[i]; social_strength = ugrid[j])
        s = solve_participation_logit(p, 1.0; theta = theta, full = true)
        cell_summary(p, s; thresholds = thresholds)
    end
    out = (threaded && nworkers() > 1) ? pmap(solve1, jobs) : [solve1(ij) for ij in jobs]
    [collapse(out[(j-1)*nt+1 : j*nt], weights) for j in 1:nu]
end
