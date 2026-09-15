# The modular SAGE economy: one configuration type, one solver, one result.
#
# THE POINT. Every dimension of the dashboard is a switch, and switching one
# off has to give back exactly the economy without it. That is what makes the
# thing usable by someone else: they can start from a plain Bewley economy,
# turn on the piece they care about, and know that nothing else moved.
# `test_modular.jl` checks every reduction rather than asserting it.
#
# THE DIMENSIONS, in SAGE terms.
#   G  material gain. Always present: consumption, effort, saving. This alone
#      is a Bewley-Aiyagari economy with an effort margin.
#   S  social cohesion, as the participation margin: a discrete choice to
#      commit a lump of time, with the payoff rising in how many others do the
#      same (Brock and Durlauf 2001). Off means the interaction strength is
#      zero, and the household problem collapses to G; `probe_reduction.jl`
#      confirms that against the engine's own solver to 9e-9.
#   A  agency. Two halves, following Snower and Lima de Miranda (2020) section
#      3.3: alpha, the ability to turn effort into income, which differs
#      across education cells when A is on; and freedom from hardship, which
#      is an accounting column computed for every configuration.
#   E  environment. Not implemented.
#
# EXTENSIONS, independent of the dimensions and each a switch of its own:
# unemployment risk with earnings-related insurance (stage 6), and permanent
# discount-factor heterogeneity (stage 7).
#
# Requires SAGEBewley, proto_participation_core.jl, sa_core.jl, agency_core.jl,
# unemployment_core.jl.

using Printf, Statistics, LinearAlgebra, Distributed, Serialization, SHA

const UGRID_DEFAULT = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))

"""
    SAGEConfig(; S, A, ...)

A complete description of one economy. Two configs that compare equal give the
same numbers; `describe` prints the configuration in one line for a manifest.

Defaults are a plain Bewley economy: both dimensions off, no unemployment, no
discount heterogeneity. Every other field is inherited from the calibration
the S and S+A papers already use, so turning a switch on does not silently
change anything else.
"""
Base.@kwdef struct SAGEConfig
    S::Bool = false
    A::Bool = false
    # social technology, used only when S is on
    kappa::Float64   = 10.00
    sigma_m::Float64 = 0.400
    omega::Float64   = 0.30
    # the two education cells
    alpha::NTuple{2,Float64} = (0.765, 0.911)   # when A is on
    alpha_off::Float64       = 0.838            # both cells when A is off
    B::NTuple{2,Float64}     = (0.80, 0.94)     # belonging taste, when S is on
    share::NTuple{2,Float64} = (0.5, 0.5)
    # extensions
    unemployment::Bool       = false
    rr::Float64              = 0.68             # net replacement rate
    f_find::Float64          = 0.767            # annual job-finding rate
    delta::NTuple{2,Float64} = (0.0795784, 0.0403684)   # separation, by cell
    beta_spread::Float64     = 0.0              # downward spread of the discount factor
    nbeta::Int               = 5
    beta_bar::Float64        = 0.96
    # Productivity states per employment status. SEVEN, not the engine's two.
    # With two states of near-equal mass the income distribution is two
    # clusters with a gap between them and the median falls in the gap: the
    # baseline 48th percentile is 0.378 and the 50th is 0.530, giving a
    # median-to-mean ratio of 1.17, which no income distribution has. The
    # poverty line is half the median and the asset threshold a quarter of
    # that, so every hardship statistic inherits the jump. Three states fix the
    # median, and the agency column is converged by seven (0.0001 against nine).
    # The participation results never showed this because they are not
    # threshold statistics. See probe_nz.txt.
    #
    # ELEVEN, not seven. Rouwenhorst matches the mean, variance and
    # autocorrelation of the process exactly at every state count, but its
    # stationary distribution is BINOMIAL and approaches a normal only as the
    # count grows. A threshold on wealth depends on the shape of the income
    # distribution, not only on its variance, so it converges at the rate the
    # binomial approaches the normal rather than at the rate the moments are
    # matched. Agency moves 0.008 from seven states to nine and 0.005 from nine
    # to eleven, then oscillates inside 0.004 out to twenty-three; with
    # unemployment on it is inside 0.002 from nine. Eleven is where it settles,
    # and the residual 0.002 is why agency is quoted to two decimals.
    # See probe_nz2.txt, probe_nz3.txt, probe_nz4.txt.
    nz::Int                  = 11
    # policy instruments
    subsidy::Float64    = 0.0
    lumptax::Float64    = 0.0
    partcredit::Float64 = 0.0
    pcost::Float64      = 0.0
    # Committed time in the UNEMPLOYED states before any choice: job search
    # under benefit conditionality plus the home production that replaces lost
    # market work. Zero reproduces every earlier stage. See SAGEParams.time_floor.
    search_time::Float64 = 0.0
    # Value of belonging when unemployed, as a fraction of its employed value.
    # One reproduces every earlier stage.
    belong_u::Float64    = 1.0
    # Unemployed participation as a RULE rather than a choice: at every
    # belonging scale the unemployed participate at this multiple of the
    # employed rate. `nothing` keeps the choice and reproduces every earlier
    # stage. 0.486 is INSEE Premiere 1327, association membership of 17
    # percent among the unemployed against 35 among the employed.
    #
    # Why a rule. Left as a choice the unemployed participate at one, because
    # joining costs time and they have the most of it. A money cost, a
    # devalued payoff and committed time when out of work were each put to the
    # data and none reaches the ratio (STAGE7.md). The old calibrated
    # equilibrium was held up by the artefact: at its technology, imposing the
    # ratio leaves a single equilibrium at 0.042 against 0.357.
    #
    # Why it is exact. With no participation credit and no money cost, an
    # unemployed household's participation has no budget effect, its effort
    # being zero, and its option value does not depend on assets. So the rule
    # moves no savings or effort policy at a given belonging scale, only the
    # aggregate. quarantine2.jl confirmed this against an independent full
    # re-solve. The combinations that would break it are refused.
    unemployed_ratio::Union{Nothing,Float64} = nothing
    # COUNTRY DIALS. The defaults are France and reproduce every earlier
    # result exactly, because `params_of` leaves the parameters untouched at
    # these values. `phi` is the effort-disutility scale, calibrated per
    # country so that employed effort in the G+A economy stands to France's as
    # the country's paid share of committed time stands to France's (HETUS
    # 2010; ATUS for the United States). `e_ref` is the reference paid-time
    # share in the benefit formula (E_REF in unemployment_core.jl); benefits
    # and the insurance tax are proportional to it. The income process and the
    # interest rate stay at France's values for every country: the old
    # engine's per-country values were fitted in a different model, and
    # hand-to-mouth differences are carried by the discount spread instead.
    phi::Float64   = 14.0
    e_ref::Float64 = 0.53
    # numerics
    na::Int          = 200
    ne::Int          = 80
    a_max::Float64   = 4.0
    pexp::Float64    = 3.0
    theta::Float64   = 0.005
    nq::Int          = 2000
    months::Float64  = 3.0        # OECD asset-poverty horizon
    # HOW THE POVERTY LINE IS SET. The OECD line is half the median
    # equivalised disposable income. Taking the median from the model is the
    # obvious reading and it does not work: income in this model is a set of
    # clusters, one per productivity state, and the median hops between them
    # as the state space changes. At two states that is a jump from 0.378 to
    # 0.530; at thirteen it is still drifting by 0.006 a step, which moves
    # agency by 0.003 each time and 0.015 in total from seven to thirteen.
    #
    # :anchored instead takes the line from the model's MEAN income, which has
    # no atoms and is stable to 0.001 across every state space tried, times the
    # empirical median-to-mean ratio. That fixes a second problem at the same
    # time: the model's own income distribution is far too compressed, a ratio
    # near 0.98 against 0.87 in the data, so its own median gives a poverty
    # line about a tenth too high. :model restores the old behaviour.
    #
    # France, Eurostat ilc_di03, latest reference year: mean equivalised net
    # income EUR 30 438, median EUR 26 459, ratio 0.8693.
    poverty_line::Symbol     = :anchored
    median_to_mean::Float64  = 0.8693
    ugrid::Vector{Float64} = UGRID_DEFAULT
end

function describe(c::SAGEConfig)
    dims = "G" * (c.S ? "+S" : "") * (c.A ? "+A" : "")
    ext = String[]
    c.unemployment && push!(ext, "unemployment")
    c.nz == 11 || push!(ext, @sprintf("nz %d", c.nz))
    c.poverty_line === :anchored || push!(ext, "line from the model's own median")
    c.search_time > 0 && push!(ext, @sprintf("search time %.2f", c.search_time))
    c.belong_u < 1 && push!(ext, @sprintf("belonging when out of work %.2f", c.belong_u))
    c.phi == 14.0 || push!(ext, @sprintf("phi %.2f", c.phi))
    c.e_ref == 0.53 || push!(ext, @sprintf("benefit reference %.3f", c.e_ref))
    c.unemployed_ratio === nothing ||
        push!(ext, @sprintf("unemployed participate at %.3f of the employed rate", c.unemployed_ratio))
    c.pcost > 0 && push!(ext, @sprintf("money cost %.4f", c.pcost))
    c.beta_spread > 0 && push!(ext, @sprintf("beta spread %.3f", c.beta_spread))
    c.subsidy > 0 && push!(ext, @sprintf("subsidy %.2f", c.subsidy))
    c.partcredit > 0 && push!(ext, @sprintf("credit %.2f", c.partcredit))
    c.lumptax > 0 && push!(ext, @sprintf("lump tax %.5f", c.lumptax))
    s = @sprintf("%-6s alpha %s  B %s", dims,
                 c.A ? @sprintf("%.3f/%.3f", c.alpha...) : @sprintf("%.3f", c.alpha_off),
                 c.S ? @sprintf("%.2f/%.2f, kappa %.2f sigma %.3f omega %.2f",
                                c.B..., c.kappa, c.sigma_m, c.omega) : "(no social payoff)")
    isempty(ext) ? s : s * " | " * join(ext, ", ")
end

# --------------------------------------------------------------- internals --
"The effective cell parameters implied by a config: alpha and B per cell."
function cells_of(c::SAGEConfig)
    αs = c.A ? c.alpha : (c.alpha_off, c.alpha_off)
    ((α = αs[1], B = c.B[1], share = c.share[1], δ = c.unemployment ? c.delta[1] : 0.0),
     (α = αs[2], B = c.B[2], share = c.share[2], δ = c.unemployment ? c.delta[2] : 0.0))
end

"Discount-factor nodes and weights implied by a config."
function betas_of(c::SAGEConfig)
    c.beta_spread <= 0 && return ([c.beta_bar], [1.0])
    b = [c.beta_bar - c.beta_spread + c.beta_spread * (2i - 1) / (2 * c.nbeta) for i in 1:c.nbeta]
    (b, fill(1 / length(b), length(b)))
end

"Parameter sets for one cell, one per discount type."
function params_of(c::SAGEConfig, cell)
    bs, _ = betas_of(c)
    ps = [cell_params_u(cell.α; δ = cell.δ, f = c.f_find, rr = c.rr, na = c.na, ne = c.ne,
                        a_max = c.a_max, pexp = c.pexp, subsidy = c.subsidy, lumptax = c.lumptax,
                        partcredit = c.partcredit, β = b, pcost = c.pcost, nz = c.nz) for b in bs]
    if c.phi != 14.0 || c.e_ref != E_REF
        ps = [update(p; ϕ = c.phi, transfer = p.transfer .* (c.e_ref / E_REF)) for p in ps]
    end
    (c.search_time == 0 && c.belong_u == 1) && return ps
    emp = ps[1].transfer .== 0
    tf = c.search_time == 0 ? Float64[] : [e ? 0.0 : c.search_time for e in emp]
    bsc = c.belong_u == 1 ? Float64[] : [e ? 1.0 : c.belong_u for e in emp]
    [update(p; time_floor = tf, belong_scale = bsc) for p in ps]
end

"Unemployment-insurance tax implied by a config, closed form (zero when off)."
function ui_tax_of(c::SAGEConfig)
    c.unemployment || return 0.0
    ui_tax([(share = x.share, α = x.α, δ = x.δ) for x in cells_of(c)], c.f_find, c.rr; nz = c.nz) *
        (c.e_ref / E_REF)
end

taste_nodes_of(c::SAGEConfig) = taste_nodes_ln(c.sigma_m; n = c.nq)

# ------------------------------------------------ unemployed participation --
"The employed states of a config's state space, true where employed."
function employment_mask(c::SAGEConfig)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    params_of(cT, cells_of(c)[1])[1].transfer .== 0
end

"""
    impose_unemployed_ratio(nodes, emp, ratio)

Rewrite the participating mass of the unemployed states in each summary so
that their rate is `ratio` times the employed rate in the same summary, capped
at one. Nothing else in a summary changes, which is exact under the conditions
`check_ratio` enforces. Idempotent: applying it twice gives the same result.
"""
function impose_unemployed_ratio(nodes, emp, ratio)
    map(nodes) do n
        mE = sum(n.mass[emp]); rE = mE > 0 ? sum(n.part[emp]) / mE : 0.0
        p = copy(n.part); p[.!emp] .= min(ratio * rE, 1.0) .* n.mass[.!emp]
        merge(n, (part = p, rate = sum(p)))
    end
end

"Refuse the combinations in which the participation rule would be wrong or would do nothing."
function check_ratio(c::SAGEConfig)
    r = c.unemployed_ratio
    r === nothing && return nothing
    c.unemployment || error("unemployed_ratio needs unemployment on: there are no unemployed states to act on")
    r >= 0 || error("unemployed_ratio must be non-negative, got $r")
    (c.partcredit > 0 || c.pcost > 0) &&
        error("unemployed_ratio assumes unemployed participation has no budget effect, which a participation credit or a money cost breaks")
    (c.search_time > 0 || c.belong_u < 1) &&
        error("unemployed_ratio replaces the unemployed participation choice, so search_time and belong_u would do nothing; leave them at their defaults")
    nothing
end

# ------------------------------------------------------- family disk cache --
# A response family is a pure function of the household parameters, the
# belonging grid, the choice smoothing, the discount-type weights and the
# threshold pairs, and of the code that solves it. The key hashes exactly
# those, the solver's source included, so a cached family is only reused for
# the same problem solved by the same code. The social technology, taste
# dispersion, omega, belonging taste, cell shares and the participation rule
# do not enter a family, which is what lets one build serve a whole
# calibration scan and every ratio. A killed run keeps every cell it finished.
const FAMILY_CACHE_DIR = joinpath(@__DIR__, "cache_families")
const SOLVER_FILES = [joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"),
                      joinpath(@__DIR__, "proto_participation_core.jl"),
                      joinpath(@__DIR__, "sa_core.jl"),
                      joinpath(@__DIR__, "agency_core.jl"),
                      joinpath(@__DIR__, "unemployment_core.jl")]
const SOLVER_DIGEST = bytes2hex(sha1(join(read(f, String) for f in SOLVER_FILES)))

"The household part and the threshold part of a family's cache key."
function family_cache_key(c::SAGEConfig, cell, thr)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    _, bw = betas_of(c)
    hh = bytes2hex(sha1(string(SOLVER_DIGEST, "|", repr(params_of(cT, cell)), "|",
                               repr(c.ugrid), "|", repr(c.theta), "|", repr(bw))))
    tk = bytes2hex(sha1(repr(thr === nothing ? Tuple{Float64,Float64}[] : collect(thr))))
    (hh[1:24], tk[1:16])
end

"""
    build_families(c, thr; disk = true, any_thresholds = false)

Both cells' response families, raw, from the disk cache when the same problem
has been solved before. `any_thresholds` accepts a family built at other
thresholds; only the first pass of `solve_economy` uses it, because that pass
reads nothing but income and participation, which thresholds do not touch.
"""
function build_families(c::SAGEConfig, thr; disk = true, any_thresholds = false)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    _, bw = betas_of(c)
    map(cells_of(c)) do cell
        hh, tk = family_cache_key(c, cell, thr)
        file = joinpath(FAMILY_CACHE_DIR, "fam_$(hh)_$(tk).jls")
        if disk
            isfile(file) && return deserialize(file)
            if any_thresholds && isdir(FAMILY_CACHE_DIR)
                other = sort(filter(f -> startswith(f, "fam_$(hh)_") && endswith(f, ".jls"),
                                    readdir(FAMILY_CACHE_DIR)))
                isempty(other) || return deserialize(joinpath(FAMILY_CACHE_DIR, first(other)))
            end
        end
        f = build_family_u(params_of(cT, cell), c.ugrid, c.theta; weights = bw, thresholds = thr)
        if disk
            mkpath(FAMILY_CACHE_DIR); tmp = file * ".tmp"
            serialize(tmp, f); mv(tmp, file; force = true)
        end
        f
    end
end

"Write families already built by this solver for exactly `c` and `thr` into the disk cache."
function seed_family_cache!(c::SAGEConfig, thr, fams)
    want = thr === nothing ? Tuple{Float64,Float64}[] : collect(thr)
    mkpath(FAMILY_CACHE_DIR)
    for (cell, f) in zip(cells_of(c), fams)
        f[1].thresholds == want || error("these families were built at other thresholds")
        hh, tk = family_cache_key(c, cell, thr)
        serialize(joinpath(FAMILY_CACHE_DIR, "fam_$(hh)_$(tk).jls"), f)
    end
end

"Weight each family node by the taste mass landing on it."
function node_weights(c::SAGEConfig, B, arg)
    w = zeros(length(c.ugrid))
    for m in taste_nodes_of(c)
        x = c.kappa * m * B * arg
        if x <= c.ugrid[1]
            w[1] += 1
        elseif x >= c.ugrid[end]
            w[end] += 1
        else
            k = searchsortedlast(c.ugrid, x)
            t = (x - c.ugrid[k]) / (c.ugrid[k+1] - c.ugrid[k])
            w[k] += 1 - t; w[k+1] += t
        end
    end
    w ./ c.nq
end

# ------------------------------------------------------------------ solve --
"""
    solve_economy(config; thresholds = nothing, verbose = false)

Solve one configuration and return every column of the dashboard.

With S off there is no fixed point: each cell is one household problem at zero
social payoff, solved once per discount type and mixed. With S on the
participation rate is a fixed point of the aggregate map, so each cell is
solved across a grid of belonging scales and the crossing is found by
interpolation, which is the response-family reduction the S+A paper uses.

`thresholds` is a LIST of (poverty line, asset threshold) pairs, the first of
which is the headline. Supplying it pins the thresholds from another economy,
which is how policy counterfactuals are anchored to their baseline. Left
empty, they are taken from this economy's own median disposable income.
"""
function solve_economy(c::SAGEConfig; thresholds = nothing, cache = true, verbose = false)
    key = (c, thresholds)
    cache && haskey(ECON_CACHE, key) && return ECON_CACHE[key]
    r = if thresholds === nothing
        # Two passes. The poverty line is half this economy's own median
        # disposable income, which is not known until it is solved, and the
        # joint income-and-asset indicator has to be accumulated DURING the
        # solve because the joint distribution of wealth and income inside a
        # state cannot be recovered from the two marginals. Policy
        # counterfactuals avoid the second pass by inheriting their baseline's
        # thresholds, which is also the right economics: an anchored line.
        r0 = _solve(c, nothing; disk = cache, any_thresholds = true)
        m = r0.median_income
        _solve(c, [(0.5 * m, hardship_threshold(m; months = c.months))]; disk = cache)
    else
        _solve(c, thresholds; disk = cache)
    end
    cache && (ECON_CACHE[key] = r)
    r
end

const ECON_CACHE = Dict{Any,Any}()
"Empty the in-memory economy cache."
clear_cache!() = (empty!(ECON_CACHE); nothing)

# `fams`, when given, are prebuilt RAW response families, one per cell, and the
# household problem is not solved again; the participation rule, if set, is
# applied here either way. `disk` and `any_thresholds` go to `build_families`.
function _solve(c::SAGEConfig, thr; fams = nothing, disk = true, any_thresholds = false)
    check_ratio(c)
    cs = cells_of(c); bs, bw = betas_of(c)
    T = c.lumptax + ui_tax_of(c)
    cfgT = SAGEConfig(c; lumptax = T)
    agrid = SAGEBewley.exponential_grid(1e-10, c.a_max, c.na, c.pexp)

    local pooled, rate, slope
    if c.S
        fams === nothing && (fams = build_families(c, thr; disk = disk, any_thresholds = any_thresholds))
        if c.unemployed_ratio !== nothing
            emp0 = employment_mask(c)
            fams = map(f -> impose_unemployed_ratio(f, emp0, c.unemployed_ratio), fams)
        end
        rs = map(f -> [n.rate for n in f], fams)
        grid = collect(range(0.0, 1.0, length = 401))
        out = map(grid) do r
            arg = c.omega + (1 - c.omega) * r
            sum(cs[g].share * dot(node_weights(c, cs[g].B, arg), rs[g]) for g in 1:2)
        end
        best = nothing
        for i in 1:400
            d1 = out[i] - grid[i]; d2 = out[i+1] - grid[i+1]
            (d1 == 0 || sign(d1) != sign(d2)) || continue
            sl = (out[i+1] - out[i]) / (grid[i+1] - grid[i]); sl < 1 || continue
            rr = grid[i] + d1 / (d1 - d2) * (grid[i+1] - grid[i])
            (best === nothing || rr > best.r) && (best = (r = rr, slope = sl))
        end
        best === nothing && error("no stable participation equilibrium for: " * describe(c))
        rate = best.r; slope = best.slope
        arg = c.omega + (1 - c.omega) * rate
        pooled = [collapse(fams[g], node_weights(c, cs[g].B, arg)) for g in 1:2]
    else
        # One household problem per (cell, discount type), over the workers
        # when there are any. Same problems, same order, same mixing as the
        # serial version; only where they run changes.
        jobs = [(g, p0) for g in 1:2 for p0 in params_of(cfgT, cs[g])]
        solve0 = job -> begin
            s = solve_participation_logit(update(job[2]; social_strength = 0.0), 1.0;
                                          theta = c.theta, full = true)
            cell_summary(job[2], s; thresholds = thr)
        end
        out = nworkers() > 1 ? pmap(solve0, jobs) : map(solve0, jobs)
        nb = length(bw)
        pooled = [collapse(out[(g-1)*nb+1:g*nb], bw) for g in 1:2]
        if c.unemployed_ratio !== nothing
            emp0 = employment_mask(c)
            pooled = map(P -> impose_unemployed_ratio([P], emp0, c.unemployed_ratio)[1], pooled)
        end
        rate = sum(cs[g].share * pooled[g].rate for g in 1:2); slope = 0.0
    end

    Ypop = sum(cs[g].share * pooled[g].Y for g in 1:2)
    ymean = sum(cs[g].share * pooled[g].ymean for g in 1:2)
    med  = c.poverty_line === :anchored ? c.median_to_mean * ymean :
                                          cdf_quantile(YGRID, Ypop, 0.5)
    med_model = cdf_quantile(YGRID, Ypop, 0.5)
    minc = sum(cs[g].share * pooled[g].minc for g in 1:2)
    Wtot = sum(cs[g].share .* vec(sum(pooled[g].W, dims = 1)) for g in 1:2)
    emp  = params_of(cfgT, cs[1])[1].transfer .== 0
    base = (config = c, rate = rate, slope = slope, median_income = med,
            median_model = med_model, mean_income = ymean,
            mean_labour_income = minc,
            hand_to_mouth = share_below_interp(agrid, Wtot, (4 / 52) * minc),
            wealth_p50 = cdf_quantile(agrid, Wtot, 0.5),
            wealth_p90 = cdf_quantile(agrid, Wtot, 0.9),
            mean_effort_employed = sum(cs[g].share * pooled[g].eff_E for g in 1:2),
            unemployment = sum(cs[g].share * sum(pooled[g].mass[.!emp]) for g in 1:2),
            partbase = sum(cs[g].share * pooled[g].pbase for g in 1:2),
            rate_E = sum(cs[g].share * sum(pooled[g].part[emp]) for g in 1:2) /
                     sum(cs[g].share * sum(pooled[g].mass[emp]) for g in 1:2),
            rate_U = (m = sum(cs[g].share * sum(pooled[g].mass[.!emp]) for g in 1:2);
                      m <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].part[.!emp]) for g in 1:2) / m),
            agrid = agrid, Wtot = Wtot, pooled = pooled, employed = emp, lumptax = T)
    thr === nothing && return merge(base, (asset_poor_by_quintile = Float64[],
                                           quintile_mass = Float64[],
                                           A_income_only = NaN, hardship_cell = (),
                                           A = NaN, hardship = NaN, income_poor = NaN,
                                           asset_poor = NaN, both = NaN, vulnerable = NaN,
                                           A_cell = (NaN, NaN), alphabar = NaN,
                                           ypov = NaN, abar = NaN))

    # Hardship from the indicators accumulated during the solve: exact in every
    # state, employed included, which the wealth-threshold shortcut is not.
    # `thr` is a LIST of (poverty line, asset threshold) pairs and the first is
    # the headline; passing a bare pair silently makes the poverty line and the
    # asset threshold into two separate income lines, which is what an earlier
    # version of this file did.
    ypov, abar = thr[1]
    hs = map(1:2) do g
        P = pooled[g]; nz = length(P.mass)
        ast = sum(share_below_interp(agrid, view(P.W, sdx, :), abar) for sdx in 1:nz)
        inc = sum(view(P.jinc, :, 1)); both = sum(view(P.jboth, :, 1))
        (inc = inc, asset = ast, both = both, vulnerable = ast - both, union = inc + ast - both)
    end
    mix(f) = sum(cs[g].share * getfield(hs[g], f) for g in 1:2)
    Ag = [cs[g].α * (1 - hs[g].union) for g in 1:2]
    Ypop2 = sum(cs[g].share * pooled[g].Y for g in 1:2)
    Ypoor = sum(cs[g].share * pooled[g].ypoor for g in 1:2)
    q5 = asset_poverty_by_quantile(Ypop2, Ypoor, 5)
    # Agency on the source's own concept, hardship being low income alone,
    # beside the headline on the OECD union. Stage 6 found the two disagree in
    # sign on every policy that moves risk, which is the finding this whole
    # line of work turns on, so both are carried.
    Ainc = sum(cs[g].share * cs[g].α * (1 - hs[g].inc) for g in 1:2)
    merge(base, (asset_poor_by_quintile = q5.rate, quintile_mass = q5.mass,
                 A_income_only = Ainc, hardship_cell = Tuple(hs),
                 A = sum(cs[g].share * Ag[g] for g in 1:2), A_cell = Tuple(Ag),
                 alphabar = sum(cs[g].share * cs[g].α for g in 1:2),
                 income_poor = mix(:inc), asset_poor = mix(:asset), both = mix(:both),
                 vulnerable = mix(:vulnerable), hardship = mix(:union),
                 ypov = ypov, abar = abar))
end

"""
    families(c)

The two response families a configuration implies, one per cell: the household
problem solved across the grid of belonging scales. This is the expensive part
of any economy with the social dimension on, and it does NOT depend on the
social technology, because the interaction strength and the taste dispersion
enter only through the scale at which the family is read. So one build serves
a whole scan over (kappa, sigma_m), which is what makes calibration and the
multiplier range affordable.
"""
function families(c::SAGEConfig; thresholds = nothing, disk = true)
    # With the participation rule set, the families come back with it
    # imposed, so a technology scan calibrates the economy that will be solved.
    check_ratio(c)
    fams = collect(build_families(c, thresholds; disk = disk))
    c.unemployed_ratio === nothing && return fams
    emp = employment_mask(c)
    [impose_unemployed_ratio(f, emp, c.unemployed_ratio) for f in fams]
end

"""
    scan_technology(c, fams, sigmas, kappas; targets = (0.25, 0.45), nq = c.nq)

Fit and slope across the social technology, by interpolation on prebuilt
families. Returns one row per sigma: the best kappa, the root loss against the
group participation targets, and the equilibrium there with its map slope. The
kappa search is global at every sigma, never a window around a coarse winner,
because a window is what produced a headline this project had to retract.
"""
function scan_technology(c::SAGEConfig, fams, sigmas, kappas;
                         targets = (0.25, 0.45), nq = c.nq, xgrid = 0.0:0.02:60.0)
    cs = cells_of(c); XG = collect(xgrid)
    rl = [n.rate for n in fams[1]]; rh = [n.rate for n in fams[2]]
    tab(col, σ) = (ms = taste_nodes_ln(σ; n = nq);
                   [mean(interp(c.ugrid, col, x * m) for m in ms) for x in XG])
    rows = NamedTuple[]
    for σ in sigmas
        Rl = tab(rl, σ); Rh = tab(rh, σ); best = nothing
        for κ in kappas
            g = range(0.0, 1.0, length = 401)
            f(r) = (arg = c.omega + (1 - c.omega) * r;
                    lo = interp(XG, Rl, κ * cs[1].B * arg); hi = interp(XG, Rh, κ * cs[2].B * arg);
                    (cs[1].share * lo + cs[2].share * hi, lo, hi))
            o = [f(r)[1] for r in g]
            for i in 1:400
                d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
                (d1 == 0 || sign(d1) != sign(d2)) || continue
                sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
                rs = g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]); _, lo, hi = f(rs)
                L = (lo - targets[1])^2 + (hi - targets[2])^2
                (best === nothing || L < best.L) &&
                    (best = (L = L, κ = κ, r = rs, lo = lo, hi = hi, slope = sl))
            end
        end
        best === nothing && continue
        push!(rows, (σ = σ, κ = best.κ, loss = sqrt(best.L), r = best.r,
                     lo = best.lo, hi = best.hi, slope = best.slope,
                     mult = 1 / (1 - best.slope)))
    end
    rows
end

"Print a technology scan and the range of the multiplier over the region that
fits within `factor` of the best."
function report_technology(rows; factor = 1.5)
    lmin = minimum(x.loss for x in rows)
    @printf("%-8s %-8s %-10s %-8s %-8s %-9s %s\n", "sigma", "kappa", "rootloss", "rate", "slope", "mult", "")
    println("-"^62)
    for x in rows
        @printf("%-8.3f %-8.2f %-10.4f %-8.4f %-8.4f %-9.1f %s\n", x.σ, x.κ, x.loss, x.r,
                x.slope, x.mult, x.loss <= factor * lmin ? "<- acceptable fit" : "")
    end
    ok = [x for x in rows if x.loss <= factor * lmin]
    @printf("\nover the acceptable-fit region: sigma %.3f to %.3f, slope %.4f to %.4f, multiplier %.1f to %.1f\n",
            minimum(x.σ for x in ok), maximum(x.σ for x in ok),
            minimum(x.slope for x in ok), maximum(x.slope for x in ok),
            minimum(x.mult for x in ok), maximum(x.mult for x in ok))
    ok
end

# ------------------------------------------------------------- countries --
const COUNTRY_FILE = joinpath(@__DIR__, "..", "..", "data", "country_labour_participation.csv")

"The country data table, one Dict per country code. Numbers only; sources in the companion markdown."
function country_rows(file = COUNTRY_FILE)
    lines = [l for l in eachline(file) if !isempty(strip(l)) && !startswith(strip(l), "#")]
    hdr = strip.(split(lines[1], ','))
    Dict(begin
             row = Dict(String(h) => String(strip(v)) for (h, v) in zip(hdr, split(l, ',')))
             row["code"] => row
         end for l in lines[2:end])
end

"""
    country_config(code; kwargs...)

A country's configuration: its labour market, benefit, education gradients,
benefit reference and participation rule from the data table, then its effort
scale, discount spread and social technology from `calibration_country_<code>.txt`
when that file exists. Keyword arguments override both. The dimension switches
S and A are left at their defaults and set by the caller.
"""
function country_config(code::AbstractString; config::AbstractString = "GSA", kwargs...)
    r = country_rows()[code]
    num(k) = parse(Float64, r[k])
    al, ah = num("alpha_low"), num("alpha_high")
    # With agency off both cells take the country's mean alpha, as France's
    # 0.838 is the mean of its two cells.
    d = Dict{Symbol,Any}(:unemployment => true,
                         :alpha => (al, ah), :alpha_off => round((al + ah) / 2; digits = 6),
                         :B => (num("B_low"), num("B_high")),
                         :delta => (num("delta_low"), num("delta_high")),
                         :f_find => num("f_find"), :rr => num("rr"), :e_ref => num("e_ref"),
                         :unemployed_ratio => num("ratio"))
    # Each configuration has its own calibration: G+S+A in calibration_country_<code>.txt,
    # the others in calibration_country_<code>_<config>.txt (config G, GA or GS).
    cal = joinpath(@__DIR__, config == "GSA" ? "calibration_country_$(code).txt" :
                                               "calibration_country_$(code)_$(config).txt")
    if isfile(cal)
        for ln in eachline(cal)
            t = strip(ln); (isempty(t) || startswith(t, "#")) && continue
            k, v = strip.(split(t, "=")); d[Symbol(k)] = parse(Float64, v)
        end
    end
    for (k, v) in kwargs
        d[k] = v
    end
    SAGEConfig(; d...)
end

"""
    france_footing()

France's calibrated footing, for the suite and anything that needs the
reference economy: the EU-SILC country calibration once
calibration_country_FR.txt exists, the INSEE-target footing in
calibration_ratio.txt otherwise. Returns the config, the two participation
targets, the hand-to-mouth target and a line saying which it is.
"""
function france_footing()
    if isfile(joinpath(@__DIR__, "calibration_country_FR.txt"))
        r = country_rows()["FR"]
        return (config = country_config("FR"),
                part = (parse(Float64, r["part_low"]), parse(Float64, r["part_high"])),
                htm = parse(Float64, r["htm_target"]),
                source = "calibration_country_FR.txt, EU-SILC participation targets and OECD 2023 labour market")
    end
    d = Dict{String,Float64}()
    for ln in eachline(joinpath(@__DIR__, "calibration_ratio.txt"))
        t = strip(ln); (isempty(t) || startswith(t, "#")) && continue
        k, v = strip.(split(t, "=")); d[String(k)] = parse(Float64, v)
    end
    (config = SAGEConfig(unemployment = true, beta_spread = d["beta_spread"], kappa = d["kappa"],
                         sigma_m = d["sigma_m"], unemployed_ratio = d["unemployed_ratio"]),
     part = (0.25, 0.45), htm = 0.30,
     source = "calibration_ratio.txt, INSEE participation targets")
end

"Copy a config with fields overridden."
SAGEConfig(c::SAGEConfig; kwargs...) = SAGEConfig(;
    (f => get(Dict(kwargs), f, getfield(c, f)) for f in fieldnames(SAGEConfig))...)

"One line per column, for a manifest or a quick look."
function report(r; label = "")
    isempty(label) || println(label)
    println("  ", describe(r.config))
    @printf("  participation %.6f | agency %.6f | hardship %.6f (income %.6f, asset %.6f)\n",
            r.rate, r.A, r.hardship, r.income_poor, r.asset_poor)
    @printf("  hand-to-mouth %.6f | mean labour income %.6f | median disposable %.6f | effort %.6f\n",
            r.hand_to_mouth, r.mean_labour_income, r.median_income, r.mean_effort_employed)
end
