"""
    SAGEBewley

Clean, stable re-implementation of the Bewley/SAGE wellbeing model from
A. Conway's master's thesis ("Wellbeing and Macroeconomics: A SAGE approach").

Design goals (vs. the original `Bewley change11j` notebook):
  * No brute-force continuous inner optimization → discretize effort `e` and
    solve the household problem as a QuantEcon `DiscreteDP`. Fast and stable.
  * No 5-million-period simulation → the wealth distribution is the exact
    stationary distribution of the controlled Markov chain.
  * No fragile outer A-fixed-point / backward NaN loop → in the *canonical*
    model (notebook change `v11c`) the public good `A` enters utility
    additively and is INDEPENDENT of the agent's own action, so household
    policies do not depend on `A`. `A = Q` is therefore just an aggregate
    computed once from the stationary distribution.

Model (partial equilibrium, exogenous gross rate R, no firms):
  state  s = (a, z),  a ≥ 0 assets, z ∈ {low, high} productivity (Rouwenhorst)
  choice (a', e),     a' ≥ 0 next assets, e ∈ [0,1] labour effort, q = 1-e
  budget c + a' = R·a + α[z]·e·z·Z            (agency α scales labour income)
  u(c,e;z) = Γ·( c^(1-γ)/(1-γ) - ϕ·e^(1+ψ)/(1+ψ) ) + Λ·B[z]·A
             \\_____________ Material Gain U^c ____________/   \\__ Social U^s __/
  public good  A = Q = E[ 1 - e ]  over the stationary distribution.

NOTE (flagged modelling choice): because the canonical code removed the `q·A`
term, effort does NOT respond to the social good - `A`/`B` are a wellbeing
overlay, not an active choice margin. The thesis Euler eq. (14) keeps a B term;
the final code (and hence its figures) does not. We follow the code.
"""
module SAGEBewley

using QuantEcon, LinearAlgebra, Statistics, SparseArrays

export SAGEParams, SAGESolution, solve_model, exponential_grid, income_process,
       wealth_gini, income_gini, frac_constrained, public_good_shares, update,
       country_params, COUNTRIES

# ----------------------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------------------
Base.@kwdef struct SAGEParams
    # preferences
    γ::Float64  = 1.5            # CRRA
    ϕ::Float64  = 1.0            # effort disutility scale
    ψ::Float64  = 0.25           # inverse Frisch (code=0.25; thesis Table 1=4.0 - FLAGGED)
    β::Float64  = 0.99           # discount factor
    R::Float64  = 1.01           # gross interest rate (exogenous, partial eq.)
    # income process: log z ~ AR(1), discretized by Rouwenhorst
    ρ::Float64  = 0.9
    η::Float64  = 0.1
    nz::Int     = 2
    # SAGE parameters (index 1 = low income, 2 = high income)
    α::Vector{Float64} = [0.765, 0.911]   # agency: share of labour income retained
    B::Vector{Float64} = [0.80, 0.94]     # enjoyment of the public good
    Γ::Float64  = 1.0                     # weight on Material Gain (U^c)
    Λ::Float64  = 0.8757834               # weight on Social Cohesion (U^s)
    # asset grid (exponential: fine near 0)
    a_min::Float64 = 1e-10
    a_max::Float64 = 100.0
    na::Int     = 200
    pexp::Float64 = 1.5
    # effort grid
    ne::Int     = 60
    # aggregate productivity multiplier (1.0 = stationary; shock raises it)
    Z::Float64  = 1.0
    # --- behavioural social cohesion (Paper 1) -----------------------------
    # :off        canonical thesis: social term additive, effort does NOT respond
    # :warmglow   add κ·Λ·B·(1-e) to the reward: effort responds, no A feedback
    # :multiplier add κ·Λ·B·A·(1-e): effort responds AND the public good A feeds
    #             back (social multiplier), solved by an outer fixed point on A
    social_mode::Symbol    = :off
    social_strength::Float64 = 1.0   # κ, scales the behavioural social return
    # --- policy experiment (Paper 1 normative) ----------------------------
    # A proportional make-work-pay subsidy to labour income, financed by a
    # lump-sum tax (set externally for budget balance). Raises the return to
    # effort, so it can erode the public good and social cohesion.
    subsidy::Float64 = 0.0           # proportional subsidy to labour income
    lumptax::Float64 = 0.0           # lump-sum tax financing it
end

"Return a copy of `p` with the named fields overridden (kwdef has no reconstruct)."
update(p::SAGEParams; kwargs...) = SAGEParams(;
    (f => get(Dict(kwargs), f, getfield(p, f)) for f in fieldnames(SAGEParams))...)

# ----------------------------------------------------------------------------
# Country calibration (plug-and-play)
# ----------------------------------------------------------------------------
# Per-country dials. The standard preferences (γ, φ, ψ) are treated as universal;
# the country-specific objects are the gross rate R, the income process (ρ, η),
# agency by education type α, the cohesion taste by type B, and the cohesion
# weight Λ. Index 1 = lower-education/income group, 2 = higher.
#
# Data sources, per parameter (same template for every country):
#   R       real long-term rate (central bank / OECD), deflated by CPI
#   ρ, η    earnings/income process; or set to match wealth Gini + hand-to-mouth
#           share from EU-SILC / HFCS / SCF / WID
#   α       agency: OECD Better Life Index empowerment indicators by education
#           (labour-market security, self-reported health, PISA skills)
#   B       cohesion taste: OECD BLI "quality of support network" by education,
#           or ESS / Gallup social-support items
#   Λ       weight on cohesion: OECD BLI dimension rankings, or estimated from
#           subjective-wellbeing (life-satisfaction) regressions
#
# FR is the thesis calibration (real, OECD BLI 2017 + ECB rate). The others are
# PLACEHOLDERS using the FR template; replace the values with country data.
const COUNTRIES = Dict(
    "FR" => (R=1.01, ρ=0.90, η=0.10, α=[0.765, 0.911], B=[0.80, 0.94], Λ=0.876,
             β=0.99, placeholder=false, note="France, thesis calibration (OECD BLI 2017 + ECB real rate)"),
    "US" => (R=1.01, ρ=0.90, η=0.10, α=[0.765, 0.911], B=[0.80, 0.94], Λ=0.876,
             β=0.99, placeholder=true,  note="PLACEHOLDER: fill α,B from OECD BLI US by education; ρ,η to SCF/Fed; R from Fed real rate"),
    "NL" => (R=1.01, ρ=0.90, η=0.10, α=[0.765, 0.911], B=[0.80, 0.94], Λ=0.876,
             β=0.99, placeholder=true,  note="PLACEHOLDER: fill from OECD BLI Netherlands + Eurostat/HFCS"),
    "IT" => (R=1.01, ρ=0.90, η=0.10, α=[0.765, 0.911], B=[0.80, 0.94], Λ=0.876,
             β=0.99, placeholder=true,  note="PLACEHOLDER: fill from OECD BLI Italy + Eurostat/HFCS"),
)

"""
    country_params(code; kwargs...) -> SAGEParams

Build parameters for a country (e.g. "FR", "US", "NL", "IT") from `COUNTRIES`.
Standard preferences and grids take SAGEParams defaults; country dials are set
from the table. Extra keyword arguments (e.g. `social_mode = :warmglow`) override.
Warns if the country's values are still placeholders.
"""
function country_params(code::AbstractString; kwargs...)
    haskey(COUNTRIES, code) || error("unknown country \"$code\"; have $(collect(keys(COUNTRIES)))")
    c = COUNTRIES[code]
    c.placeholder && @warn "country \"$code\" uses placeholder values; replace with data ($(c.note))"
    update(SAGEParams(; R=c.R, ρ=c.ρ, η=c.η, α=c.α, B=c.B, Λ=c.Λ, β=c.β); kwargs...)
end

# ----------------------------------------------------------------------------
# Grids and income process
# ----------------------------------------------------------------------------
"Exponential asset grid (replicates the notebook's `grid_fun_exp`)."
function exponential_grid(a_min, a_max, na, pexp)
    x = range(a_min, step = 0.5, length = na)
    xp = x .^ pexp
    return a_min .+ (a_max - a_min) .* (xp ./ maximum(xp))
end

"""
    income_process(p) -> (z_vals, Π)

Rouwenhorst discretization of log productivity, exponentiated and normalised so
that the stationary mean of `z` is 1. Returns positive productivity levels and
the transition matrix.
"""
function income_process(p::SAGEParams)
    mc = rouwenhorst(p.nz, p.ρ, p.η)
    Π  = mc.p
    π_stat = stationary_distributions(mc)[1]
    z = exp.(mc.state_values)
    z ./= dot(π_stat, z)                # normalise E[z] = 1
    return collect(z), Matrix(Π)
end

# ----------------------------------------------------------------------------
# Solution container
# ----------------------------------------------------------------------------
struct SAGESolution
    p::SAGEParams
    a_grid::Vector{Float64}
    z_vals::Vector{Float64}
    Π::Matrix{Float64}
    # policies on the (na, nz) grid
    c::Matrix{Float64}          # consumption
    e::Matrix{Float64}          # effort
    q::Matrix{Float64}          # social contribution = 1 - e
    a_next::Matrix{Float64}     # next assets
    V::Matrix{Float64}          # value function
    λ::Matrix{Float64}          # stationary distribution over (a, z)
    # aggregates / wellbeing
    Q::Float64                  # public good size  A = Q = E[1-e]
    Uc::Matrix{Float64}         # material-gain utility at the optimum
    Us::Matrix{Float64}         # social-cohesion utility at the optimum
end

# material-gain (consumption) part of utility
@inline uc(c, e, p::SAGEParams) =
    p.Γ * (c^(1 - p.γ) / (1 - p.γ) - p.ϕ * e^(1 + p.ψ) / (1 + p.ψ))

# --- small numerical helpers (kept dependency-free) -------------------------
"Linear interpolation of `y` defined on sorted grid `x`, evaluated at `xq` (clamped)."
@inline function interp_lin(x::AbstractVector, y::AbstractVector, xq)
    n = length(x)
    xq <= x[1]  && return y[1]
    xq >= x[n]  && return y[n]
    k = searchsortedlast(x, xq)
    t = (xq - x[k]) / (x[k+1] - x[k])
    return (1 - t) * y[k] + t * y[k+1]
end

"Golden-section maximisation of unimodal `f` on [lo, hi]."
function golden_max(f, lo, hi; tol = 1e-9, maxit = 200)
    φ = (sqrt(5) - 1) / 2
    a, b = lo, hi
    c = b - φ * (b - a); d = a + φ * (b - a)
    fc, fd = f(c), f(d)
    for _ in 1:maxit
        if fc < fd
            a = c; c = d; fc = fd
            d = a + φ * (b - a); fd = f(d)
        else
            b = d; d = c; fd = fc
            c = b - φ * (b - a); fc = f(c)
        end
        (b - a) < tol && break
    end
    xstar = (a + b) / 2
    return xstar, f(xstar)
end

# Behavioural social-cohesion return to contributing q = (1-e). Zero in the
# canonical (:off) model, so effort is unaffected and policies are unchanged.
@inline function social_reward(e, Bz, p::SAGEParams, A_social)
    p.social_mode === :warmglow   ? p.social_strength * p.Λ * Bz * (1 - e) :
    p.social_mode === :multiplier ? p.social_strength * p.Λ * Bz * A_social * (1 - e) :
    0.0
end

# ----------------------------------------------------------------------------
# Solver
# ----------------------------------------------------------------------------
"""
    solve_model(p; method=PFI, A0=nothing) -> SAGESolution

Build the DiscreteDP, solve for policies, get the exact stationary distribution,
and compute the public good and the wellbeing dashboard.

Effort is collapsed into the reward: for each (state, next-asset) pair we pick
the effort on a grid that maximises within-period utility. The remaining choice
(next assets) is the single DiscreteDP action, exactly as in QuantEcon Aiyagari.

When `p.social_mode == :multiplier` the public good `A` raises the marginal
return to contributing, so the model is solved by an outer fixed point on `A`
(start it with `A0`). For `:off` and `:warmglow` there is no aggregate feedback
and the model is solved in one pass.
"""
function solve_model(p::SAGEParams; method = PFI, A0 = nothing,
                     damp = 0.5, tol = 1e-4, maxit = 80)
    p.social_mode === :multiplier || return _solve_once(p, 0.0; method = method)
    A = A0 === nothing ? 0.3 : A0           # outer fixed point on the public good
    local sol
    for _ in 1:maxit
        sol = _solve_once(p, A; method = method)
        (isnan(sol.Q) || isinf(sol.Q)) && break
        abs(sol.Q - A) < tol && break
        A = damp * A + (1 - damp) * sol.Q
    end
    return sol
end

"Single solve of the household problem given a fixed aggregate public good `A_social`."
function _solve_once(p::SAGEParams, A_social::Float64; method = PFI)
    a = exponential_grid(p.a_min, p.a_max, p.na, p.pexp)
    z_vals, Π = income_process(p)
    na, nz = p.na, p.nz
    e_grid = range(0.0, 1.0, length = p.ne)

    n_s = na * nz                      # states s indexed (i_a, i_z) -> sidx
    sidx(i_a, i_z) = (i_z - 1) * na + i_a

    # Enumerate feasible (state, next-asset) pairs, folding the optimal effort
    # into the reward. Sparse state-action-pair DiscreteDP (QuantEcon idiom):
    # fast and memory-light, so the whole solve stays interactive-speed.
    Epol  = zeros(n_s, na)             # best effort for each (state, action)
    s_ind = Int[]; a_ind = Int[]; Rvec = Float64[]
    rows  = Int[]; cols = Int[]; vals = Float64[]   # sparse Q triplets
    pair  = 0
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]
        for i_a in 1:na
            res_assets = p.R * a[i_a]
            s = sidx(i_a, i_z)
            for k in 1:na
                anext = a[k]
                best = -Inf; beste = 0.0
                Bz = p.B[i_z]
                @inbounds for e in e_grid
                    c = res_assets + (1 + p.subsidy) * α * e * z * p.Z - p.lumptax - anext
                    c <= 0 && continue
                    ut = uc(c, e, p) + social_reward(e, Bz, p, A_social)
                    if ut > best
                        best = ut; beste = e
                    end
                end
                best == -Inf && continue            # no feasible consumption
                Epol[s, k] = beste
                pair += 1
                push!(s_ind, s); push!(a_ind, k); push!(Rvec, best)
                for i_zn in 1:nz
                    push!(rows, pair); push!(cols, sidx(k, i_zn))
                    push!(vals, Π[i_z, i_zn])
                end
            end
        end
    end
    Qsp = sparse(rows, cols, vals, pair, n_s)

    ddp = DiscreteDP(Rvec, Qsp, p.β, s_ind, a_ind)
    results = solve(ddp, method)
    Vmat = reshape(results.v, na, nz)            # value function on the grid
    σ    = results.sigma                         # DiscreteDP next-asset action per state

    # --- Policy recovery --------------------------------------------------
    # EFFORT is taken from the DiscreteDP joint optimum over (a', e): it is the
    # consistent choice against the exact value function. Re-optimising effort
    # against the INTERPOLATED continuation value collapses it to a corner once
    # the social term is behavioural, so we do not do that. We then re-optimise
    # NEXT-ASSETS continuously with effort fixed, which keeps the savings policy
    # and the wealth distribution smooth (no grid sawtooth).
    EV = Vmat * Π'                               # EV[k, z] = E[V(a_k, z')|z]
    c = zeros(na, nz); e = zeros(na, nz); anext = zeros(na, nz)
    for i_z in 1:nz
        z = z_vals[i_z]; α = p.α[i_z]; Bz = p.B[i_z]
        evz = view(EV, :, i_z)
        for i_a in 1:na
            s  = sidx(i_a, i_z)
            ee = Epol[s, σ[s]]                   # effort from the DiscreteDP optimum
            cash0 = p.R * a[i_a]
            resources = cash0 + (1 + p.subsidy) * α * ee * z * p.Z - p.lumptax
            soc = social_reward(ee, Bz, p, A_social)
            hi = min(resources - 1e-10, a[end])
            if hi <= a[1]
                ba = a[1]
            else
                f = ap -> uc(resources - ap, ee, p) + soc + p.β * interp_lin(a, evz, ap)
                kbest = 1; vbest = -Inf
                @inbounds for k in 1:na
                    a[k] >= hi && break
                    v = f(a[k]); (v > vbest) && (vbest = v; kbest = k)
                end
                lo_b = a[max(kbest - 1, 1)]; hi_b = min(a[min(kbest + 1, na)], hi)
                ba = lo_b < hi_b ? golden_max(f, lo_b, hi_b)[1] : a[kbest]
            end
            anext[i_a, i_z] = ba
            e[i_a, i_z]     = ee
            c[i_a, i_z]     = resources - ba
        end
    end
    q = 1 .- e
    V = Vmat

    # --- Stationary distribution via Young (2010) lottery -----------------
    # Split each agent's continuous next-assets across the two bracketing grid
    # nodes for a smooth distribution. Next-assets are fixed, so build the
    # lottery transition ONCE as a sparse matrix and iterate with in-place
    # sparse multiplies (no per-iteration re-location or allocation).
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
    # Iterate the distribution to its stationary point with the prebuilt sparse
    # transition (fast per iteration, and robust to reducibility, where a direct
    # linear solve is numerically unstable). Slow-mixing wealth dynamics can need
    # many iterations, but each is a cheap sparse multiply.
    Tt = transpose(sparse(drows, dcols, dvals, n_s, n_s))   # λ' = Tᵀ λ
    λv = fill(1.0 / n_s, n_s); λn = similar(λv)
    for _ in 1:100_000
        mul!(λn, Tt, λv)
        d = 0.0
        @inbounds for i in eachindex(λv)
            d = max(d, abs(λn[i] - λv[i]))
        end
        λv, λn = λn, λv
        d < 1e-11 && break
    end
    λ = reshape(λv, na, nz)

    Uc = zeros(na, nz); Us = zeros(na, nz)
    # public good A = Q = E[1 - e] over the stationary distribution
    Q = sum(λ .* q)

    # wellbeing dashboard at the optimum
    for i_z in 1:nz, i_a in 1:na
        Uc[i_a, i_z] = uc(c[i_a, i_z], e[i_a, i_z], p)
        Us[i_a, i_z] = p.Λ * p.B[i_z] * Q
    end

    return SAGESolution(p, a, z_vals, Π, c, e, q, anext, V, λ, Q, Uc, Us)
end

# ----------------------------------------------------------------------------
# Convenience diagnostics
# ----------------------------------------------------------------------------
"Fraction of agents at (essentially) the borrowing constraint (mass at lowest node)."
frac_constrained(s::SAGESolution; nodes = 1) =
    sum(s.λ[1:nodes, :])

"Share of the public good Q supplied by each income state (sums to 1)."
function public_good_shares(s::SAGESolution)
    contrib = [sum(s.λ[:, z] .* s.q[:, z]) for z in 1:s.p.nz]
    return contrib ./ sum(contrib)
end

"Gini of values `x` with population weights `w` (Lorenz-curve area)."
function _gini(x::AbstractVector, w::AbstractVector)
    ord = sortperm(x); x = x[ord]; w = w[ord]
    cw = cumsum(w); cx = cumsum(w .* x); cx ./= cx[end]
    1 - sum((cw[2:end] .- cw[1:end-1]) .* (cx[2:end] .+ cx[1:end-1]))
end

"Wealth (assets) Gini from the stationary distribution."
wealth_gini(s::SAGESolution) = _gini(vec(repeat(s.a_grid, 1, s.p.nz)), vec(s.λ))

"Income (labour income α·e·z) Gini from the stationary distribution. Wealth and
income inequality are distinct objects and can be reported and matched separately."
function income_gini(s::SAGESolution)
    inc = [s.p.α[iz] * s.e[ia, iz] * s.z_vals[iz] for ia in 1:s.p.na, iz in 1:s.p.nz]
    _gini(vec(inc), vec(s.λ))
end

end # module
