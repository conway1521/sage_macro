# Version 2: the labour chain and the quarterly income process (V2_BUILD_PLAN.md, stage 1a; paper/sage_v2_design.md,
# sections 2 and 3). Not wired into the model yet: this file builds the chain and fits the income process, and is
# tested on its own before stage 1a changes `params_of`.
#
# THE CHAIN. Labour states, each crossed with the persistent productivity states of a Rouwenhorst base:
#   U_1 ... U_nU   unemployed for 1 to nU periods (exit to work at hazard h_d; otherwise on to the next duration),
#   E              employed (job loss delta, into U_1),
#   L              unemployed beyond nU periods (exit to work at hL).
# Every state carries its labels: type (:U, :E, :L), duration (1 to nU in U, 0 otherwise) and latent index. At an
# annual period with nU = 1 this is version 1's chain (U is the first year, L beyond it), in another order; the
# labels make the order irrelevant. Stationary masses are computed numerically.
#
# THE INCOME PROCESS AT A QUARTER. The published process is annual: an AR(1) with persistence rho and innovation
# sd s_eta, plus a transitory part with sd s_eps, which implies the autocovariances of annual log income
# g0 = s_eta^2/(1-rho^2) + s_eps^2 and gk = rho^k s_eta^2/(1-rho^2). Annual log income in the quarterly model is
# the average of four quarters' log income (a stated convention), with job loss in the chain. The quarterly
# persistence and the two quarterly sds are chosen so that the averages reproduce g0, g1 and g2: three moments
# for three parameters (the second methods review of the version 2 design). g3 is a check.

using LinearAlgebra

"""
The labour chain on a Rouwenhorst base: transition matrix, incomes and labels (see the header). Stage 1b adds
the inactive state N (`withN`) and exits to it: from the d-th period out of work at sU[d], from L at sL, from work
at ιE; out of N to work at νE and into the first period out of work at νU. All zero (the default): stage 1a's chain.
"""
function labour_chain(base::SAGEParams; nU::Int, hU::Vector{Float64}, hL::Float64, δ::Float64,
                      sU::Vector{Float64} = zeros(nU), sL::Float64 = 0.0, ιE::Float64 = 0.0,
                      νE::Float64 = 0.0, νU::Float64 = 0.0, withN::Bool = false)
    length(hU) == nU || error("hU needs one hazard per duration")
    z2, Π2 = SAGEBewley.income_process(base); nz = length(z2)
    nl = nU + 2 + (withN ? 1 : 0)                 # labour states: U_1..U_nU, E, L, (N)
    iE = nU + 1; iL = nU + 2; iN = nU + 3
    Ps = zeros(nl, nl)
    for d in 1:nU
        Ps[d, iE] = hU[d]
        withN && (Ps[d, iN] = sU[d])
        Ps[d, d < nU ? d + 1 : iL] = 1 - hU[d] - (withN ? sU[d] : 0.0)
    end
    Ps[iE, iE] = 1 - δ - (withN ? ιE : 0.0); Ps[iE, 1] = δ
    Ps[iL, iE] = hL; Ps[iL, iL] = 1 - hL - (withN ? sL : 0.0)
    if withN
        Ps[iE, iN] = ιE; Ps[iL, iN] = sL
        Ps[iN, iE] = νE; Ps[iN, 1] = νU; Ps[iN, iN] = 1 - νE - νU
    end
    minimum(Ps) >= -1e-12 || error("the labour chain has a negative transition probability: check the hazards")
    Π = kron(Ps, Π2)
    lab = [d <= nU ? :U : d == iE ? :E : d == iL ? :L : :N for d in 1:nl]
    stype = [lab[d] for d in 1:nl for _ in 1:nz]
    dur = [d <= nU ? d : 0 for d in 1:nl for _ in 1:nz]
    lat = [i for _ in 1:nl for i in 1:nz]
    zv = [lab[d] === :E ? z2[i] : 0.0 for d in 1:nl for i in 1:nz]
    # stationary masses of the labour states
    m = fill(1 / nl, nl)
    for _ in 1:200_000
        mn = Ps' * m
        maximum(abs, mn - m) < 1e-15 && (m = mn; break)
        m = mn
    end
    (z_vals = zv, Π = Π, stype = stype, dur = dur, lat = lat, z_latent = [z2[i] for _ in 1:nl for i in 1:nz],
     Ps = Ps, mass = m, nz = nz, iE = iE, iL = iL, iN = withN ? iN : 0)
end

"Log income in every state of the chain crossed with the transitory nodes: earnings in work, a replacement rate out of it."
function chain_log_income(ch, sε, n_eps, rrU::Vector{Float64}, rrL::Float64)
    nt = sε > 0 ? n_eps : 1
    x = nt > 1 ? [sε * sqrt(nt - 1) * (2 * (t - 1) / (nt - 1) - 1) for t in 1:nt] : [0.0]
    w = nt > 1 ? [binomial(nt - 1, t - 1) / 2.0^(nt - 1) for t in 1:nt] : [1.0]
    ε = exp.(x); ε ./= dot(w, ε)
    y = [log(ch.stype[s] === :E ? ch.z_latent[s] * ε[t] : ch.stype[s] in (:L, :N) ? rrL * ch.z_latent[s] : rrU[ch.dur[s]] * ch.z_latent[s])
         for s in eachindex(ch.stype) for t in 1:nt]
    P = kron(ch.Π, ones(nt) * w')
    (y = y, P = P)
end

"Autocovariances of k-period averages of log income at lags of 0 to `lags` averages (k = 4: annual averages of quarters)."
function averaged_autocov(y, P; k::Int = 4, lags::Int = 3)
    N = length(y)
    π = vcat(P' - I, ones(1, N)) \ vcat(zeros(N), 1.0)
    d = y .- dot(π, y)
    kmax = k * lags + k
    c = zeros(kmax + 1); v = copy(d)                # c[j+1] = cov(y_t, y_{t+j})
    for j in 0:kmax
        c[j+1] = dot(π .* d, v); v = P * v
    end
    [sum(c[abs(k * m + jj - ii) + 1] for ii in 0:k-1, jj in 0:k-1) / k^2 for m in 0:lags]
end

"""
    quarterly_income(nz, n_eps, ρ, sη, sε; nU, hU, hL, δ, rrU, rrL)

The quarterly persistence and innovation sds whose annual averages, with job loss in the quarterly chain, have the
autocovariances at lags 0, 1 and 2 that the published annual process (ρ, sη, sε) implies. Returns (ρq, sηq, sεq)
and the check at lag 3.
"""
function quarterly_income(nz, n_eps, ρ, sη, sε; nU, hU, hL, δ, rrU, rrL, iters = 200, tol = 1e-9)
    vp = sη^2 / (1 - ρ^2)
    target = [vp + sε^2, ρ * vp, ρ^2 * vp, ρ^3 * vp]
    mom(r, a, b) = (base = SAGEParams(nz = nz, α = fill(1.0, nz), B = fill(1.0, nz), ρ = r, η = a);
                    ch = labour_chain(base; nU = nU, hU = hU, hL = hL, δ = δ);
                    q = chain_log_income(ch, b, n_eps, rrU, rrL); averaged_autocov(q.y, q.P))
    r = ρ^(1 / 4); a = sη / 2; b = sε * 2
    g = mom(r, a, b)
    for it in 1:iters
        # persistence from the ratio of the second to the first annual autocovariance, the persistent sd from the
        # first, the transitory sd from the variance
        r = clamp(r * (target[3] / target[2] / (g[3] / g[2]))^(1 / 4), 0.5, 0.9999)
        g = mom(r, a, b); a *= clamp(sqrt(target[2] / g[2]), 0.7, 1.4)
        g = mom(r, a, b); b = sqrt(max(b^2 + (target[1] - g[1]) * 4, 1e-10))
        g = mom(r, a, b)
        maximum(abs.(g[1:3] .- target[1:3])) < tol && break
    end
    (ρq = r, sηq = a, sεq = b, fit = g, target = target)
end

"""
    cell_params_chain(αg; δ, hU, hL, rrU, rrL, nU, ppy, ...)

The household problem of one cell on the labour chain (version 2, stage 1a): as `cell_params_u`, with the
unemployed tracked by duration. Benefits are earnings-related, rrU[d] in the d-th period out of work and rrL in
L, times α z Z E_REF, per period. Labels (type, duration, latent index) and periods per year are set.
"""
function cell_params_chain(αg; δ, hU, hL, rrU, rrL, nU, ppy, na = 200, ne = 80, a_max = 4.0, pexp = 3.0,
                           subsidy = 0.0, lumptax = 0.0, partcredit = 0.0, β = 0.96, pcost = 0.0, nz = 11, ρ = 0.9, η = 0.1,
                           sU = zeros(nU), sL = 0.0, ιE = 0.0, νE = 0.0, νU = 0.0, withN = false)
    base = SAGEParams(na = na, ne = ne, nz = nz, α = fill(αg, nz), B = fill(1.0, nz), a_max = a_max, pexp = pexp, ρ = ρ, η = η)
    ch = labour_chain(base; nU = nU, hU = hU, hL = hL, δ = δ, sU = sU, sL = sL, ιE = ιE, νE = νE, νU = νU, withN = withN)
    n = length(ch.z_vals)
    # the inactive state has the income of jobless households, as L (version 1's measured ratio)
    b = [ch.stype[i] === :E ? 0.0 : (ch.stype[i] in (:L, :N) ? rrL : rrU[ch.dur[i]]) * αg * ch.z_latent[i] * base.Z * E_REF for i in 1:n]
    SAGEParams(na = na, ne = ne, nz = n, α = fill(αg, n), B = fill(1.0, n),
               z_vals_override = ch.z_vals, Π_override = ch.Π, transfer = b,
               a_max = a_max, pexp = pexp, subsidy = subsidy, lumptax = lumptax,
               partcredit = partcredit, β = β, pcost = pcost,
               stype = ch.stype, lat = ch.lat, dur = ch.dur, ppy = ppy)
end

"""
    chain_ui_tax(cells, nU, hU, rr; rrL, nz)

The closed-form `ui_tax` on the labour chain: per head, the public benefit in the first spell's states and the
public part of L's income, at the chain's stationary masses (computed numerically) and the mean latent
productivity, as `ui_tax` takes them.
"""
function chain_ui_tax(cells, nU, hU, rr; rrL = 0.0, nz = 2, Z = 1.0, flows = (;))
    T = 0.0
    for c in cells
        c.δ === nothing && continue
        base = SAGEParams(nz = nz, α = fill(c.α, nz), B = fill(1.0, nz))
        ch = labour_chain(base; nU = nU, hU = hU, hL = c.fL, δ = c.δ, flows...)
        z2, Π2 = SAGEBewley.income_process(base)
        πz = fill(1 / length(z2), length(z2))
        for _ in 1:10_000; πn = Π2' * πz; maximum(abs, πn - πz) < 1e-15 && (πz = πn; break); πz = πn; end
        Ez = sum(πz .* z2)
        mU = sum(ch.mass[1:nU]); mL = ch.mass[nU + 2] + (ch.iN > 0 ? ch.mass[ch.iN] : 0.0)      # L and N alike
        T += c.share * mU * rr * c.α * Ez * Z * E_REF
        rrL > 0 && (T += c.share * mL * rrL * c.α * Ez * Z * E_REF)
    end
    T
end
"The mass in L of each cell on the labour chain (for the tax on assistance)."
function chain_mass_L(c_δ, nU, hU, hL; nz = 2, flows = (;))
    ch = labour_chain(SAGEParams(nz = nz, α = fill(1.0, nz), B = fill(1.0, nz)); nU = nU, hU = hU, hL = hL, δ = c_δ, flows...)
    ch.mass[nU + 2] + (ch.iN > 0 ? ch.mass[ch.iN] : 0.0)                  # the assisted: L and N
end
