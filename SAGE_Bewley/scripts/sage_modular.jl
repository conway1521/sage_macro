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

const DEFAULT_SOLVER = Symbol(get(ENV, "SAGE_SOLVER", "egm"))
const UGRID_DEFAULT = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
# Half the belonging scales, for the search stages of a calibration only. At
# France's G+S+A it moves participation by 0.0013 and nothing else beyond 1e-4
# (grid_test.txt, 2026-09-28); every reported number comes from UGRID_DEFAULT.
const UGRID_COARSE = vcat(collect(0.0:0.4:12.0), collect(13.0:1.0:16.0), collect(18.0:2.0:30.0))

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
    # THE PAY PREMIUM BY EDUCATION IN THE BASE (version 5, decided by the user on 2026-10-08;
    # DIMENSIONS_SPEC.md, V3_START.md section 48). When true the two cells earn `alpha` whether A is
    # on or off: pay by education is a fact about the economy and belongs to G. A is then the
    # security dimension alone (dread of job loss and the protection indicators).
    premium_base::Bool       = false
    B::NTuple{2,Float64}     = (0.80, 0.94)     # belonging taste, when S is on
    share::NTuple{2,Float64} = (0.5, 0.5)
    # extensions
    unemployment::Bool       = false
    rr::Float64              = 0.68             # net replacement rate
    # The part of `rr` that the state pays and the lump-sum tax has to cover. NaN: all of it
    # (as before). With the household-level rate of version 3, `rr` is what household income
    # falls to on job loss, and part of that is a partner's earnings, which no tax pays for.
    rr_public::Float64       = NaN
    f_find::Float64          = 0.767            # annual job-finding rate
    delta::NTuple{2,Float64} = (0.0795784, 0.0403684)   # separation, by cell
    beta_spread::Float64     = 0.0              # downward spread of the discount factor
    nbeta::Int               = 5
    # Two patience groups instead of the uniform spread, when impatient_share > 0:
    # a patient majority at beta_bar and an impatient minority at beta_low. A
    # uniform spread wide enough for the German and Italian poor hand-to-mouth
    # dragged the median household's patience down so far that the two-asset
    # model could not hold their median net wealth (TWO_ASSET_DESIGN.md).
    impatient_share::Float64 = 0.0
    beta_low::Float64        = 0.0
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
    # A lump-sum levy on employed households only, the unemployed exempt. It
    # enters as a negative transfer in the employed states, so the income
    # measures that include transfers are net of it.
    levy_employed::Float64 = 0.0
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
    # VERSION 2 (stage 1a, V2_BUILD_PLAN.md): periods a year (1 annual, version 1; 4 quarterly) and the periods of the
    # first spell out of work tracked one by one (the labour chain, labour_chain.jl). Annual and 1: version 1.
    period::Int = 1
    nU::Int = 1
    # the labour chain at an annual period with one period of first spell: version 1's model in the chain's
    # representation, for the test that the chain reproduces version 1 exactly
    chain::Bool = false
    # STAGE 1b (V2_BUILD_PLAN.md): exits from work by period out of work (`hU_vec`, one a period of the first spell;
    # empty, f_find in every period), exits to inactivity (`sU_vec`, `sL`), and the inactive state N (`withN`) with
    # its flows from work (`iotaE`) and out of it to work (`nuE`) and into the first period out of work (`nuU`)
    hU_vec::Vector{Float64} = Float64[]
    sU_vec::Vector{Float64} = Float64[]
    sL::Float64 = 0.0
    withN::Bool = false
    iotaE::NTuple{2,Float64} = (0.0, 0.0)      # by cell (set for each cell's inactive share)
    nuE::Float64 = 0.0
    nuU::Float64 = 0.0
    # STAGE 1c (V2_BUILD_PLAN.md; design section 3.3): the benefit by period of the entitled spell (`rrU_vec`, the
    # household's rate, and its public part `rrU_pub_vec`; empty: rr in every period), and the spell without
    # entitlement for those entering from inactivity (`entN`), paid as L
    rrU_vec::Vector{Float64} = Float64[]
    rrU_pub_vec::Vector{Float64} = Float64[]
    entN::Bool = false
    # The transitory part's persistence at a sub-annual period: the chance it is kept from one period to the next
    # (else drawn afresh). 0: drawn afresh every period, as at an annual period; 0.75 at a quarterly period: it lasts a
    # year on average (the convention probed in V3_START.md section 122)
    eps_stay::Float64 = 0.0
    # The measured ratio itself, kept when the rule is replaced by the unemployed's own choice (`belong_u` fitted to
    # it, V3_START.md section 111): the target of that fit, read by probe_unemp_rule.jl. NaN: not set.
    ratio_target::Float64 = NaN
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
    # Income process of the employed, log z' = rho log z + eps, sd(eps) = eta_z.
    # The defaults are the engine's and reproduce every earlier result; the
    # country table sets rho = 0.92, eta = 0.10 (Bayer and Juessen 2012).
    rho::Float64   = 0.9
    eta_z::Float64 = 0.1
    # AGENCY, VERSION 2: dread of the employment lottery, eta (lambda - 1) in
    # expectations-based news utility (Koszegi and Rabin 2009; Pagel 2017). It
    # acts only when A is on and unemployment is on; zero reproduces every
    # earlier result. The country table sets 1.5 (Pagel 2017, eta = 1, lambda =
    # 2.5; Brown et al. 2024 for the loss-aversion range).
    dread::Float64 = 0.0
    # :overlay (version 1, the calibrated baseline since 2026-09-28): dread is
    # measured at this weight but does not enter choices. :behaviour (version
    # 2): it enters choices. At the literature weight the behavioural version
    # makes households save so much that the German and Italian hand-to-mouth
    # targets are out of reach at any plausible patience (MODULAR.md, 2026-09-28).
    dread_mode::Symbol = :overlay
    # The horizon of the lottery dreaded, in periods: 1, the coming period's (version 1, annual). At a quarterly
    # period, 4 keeps Pagel's (2017) weight, estimated at an annual period, on the coming year's lottery, felt each
    # quarter: with CRRA this keeps dread's size relative to consumption utility (V3_START.md section 124)
    dread_horizon::Int = 1
    # HOURS AS A CHOICE (A, 2026-10-11; DIMENSIONS_SPEC.md, "A, reopened and scoped"): the share of households
    # in each education cell who have control over their working time and choose their hours each year;
    # the others work the hours the job sets. From Eurostat (lfso_19fxwt01, who decides working time).
    # Active with A on only; zero is every earlier result.
    control_share::NTuple{2,Float64} = (0.0, 0.0)
    # JOB SEARCH (A, phase 1 of ROADMAP.md, 2026-10-16; DIMENSIONS_SPEC.md, "Phase 1 scope"). With A on and
    # `search`, those out of work choose their chance of finding work at a cost with curvature `search_gamma`
    # (DellaVigna and co-authors 2017, QJE, Table I column (1), p. 2000: 0.35); the cost's level by education cell, for the first year out of
    # work (`search_kU`) and for the state beyond it (`search_kL`), is fitted so that the mean chances are the
    # measured rates (`f_find`, `f_long`). A off, or `search` false: job finding as measured.
    search::Bool = false
    search_gamma::Float64 = 0.35
    search_kU::NTuple{2,Float64} = (NaN, NaN)
    search_kL::NTuple{2,Float64} = (NaN, NaN)
    # Stage 1d (V3_START.md section 132): the cost level by period of the spell, by cell (nU entries for U_1 .. U_nU,
    # then L), the arrival rate normalised to one as in DellaVigna et al. (2017); empty: search_kU and search_kL
    search_kq::NTuple{2,Vector{Float64}} = (Float64[], Float64[])
    # THE COST OF BEING OUT OF WORK beyond the income lost (A; DIMENSIONS_SPEC.md, phase 1). `out_ls` is the
    # life-satisfaction gap (0 to 10) between those out of work and in work at the same income, positive for a
    # cost; it is turned into a utility cost by the Green Book's bridge (HM Treasury 2021, the formula
    # ES = M [exp(beta_Q dQ / beta_Y) - 1] with beta_Y = 1.96105): being out of work is worth the same as
    # consuming exp(-out_ls / beta_Y) times the mean income `out_M` instead of the mean income, valued once
    # at that mean for everyone (a stated normalisation). Zero: none, the model without it exactly.
    out_ls::Float64 = 0.0
    out_M::Float64 = NaN
    out_betaY::Float64 = 1.96105
    # Household solver: :grid, the reference, or :egm (SOLVER_DESIGN.md). The
    # default can be set for a whole run with the environment variable
    # SAGE_SOLVER (grid or egm), which worker processes inherit.
    solver::Symbol = DEFAULT_SOLVER
    # THE ILLIQUID ASSET (TWO_ASSET_DESIGN.md; egm2_core.jl), EGM only. Off gives
    # the one-asset model exactly. The premium Rk - R comes from the country
    # table (Jorda-Schularick-Taylor data), the fixed cost chi0 is calibrated to
    # the wealthy hand-to-mouth, death gives perpetual youth (Kaplan, Moll and
    # Violante 2018). With it on, the liquid grid is b_max and nb, not a_max and na.
    # Commuting relative to the national average, by cell (the place layer):
    # each unit of work takes 1 + commute units of time. The national effort
    # scale already absorbs average commuting, so the nation has zero here.
    commute::NTuple{2,Float64} = (0.0, 0.0)
    # A tax on consumption, ad valorem (E's cost side: a carbon tax is tau per
    # tonne times the footprint intensity per euro). Its revenue is recycled
    # lump-sum by `carbon_tax_economy`. EGM, one asset.
    ctax::Float64 = 0.0
    # Extra time for every household, as a share of the time endowment (the
    # reporting layer's time propensities: where does an extra hour go?). Zero
    # leaves every solve unchanged.
    time_bonus::Float64 = 0.0
    # THE E SWITCH (E_PLACE_CONCEPT.md, the standard). On, the economy is solved
    # over places of an official geography (TL2 by default, or :degurba), each
    # its own economy with local social feedback and national financing, and the
    # results are the national aggregates plus `by_place`. The place parameters
    # come from data through the channels listed; E fits nothing. With no
    # channels, E on gives back E off exactly (the suite).
    E::Bool = false
    typology::Symbol = :tl2
    e_channels::Tuple = (:composition, :access, :conversion, :commute, :community)
    epsilon::Float64 = 0.4
    # inverse Frisch elasticity of effort (2.0: Frisch 0.5, Chetty et al. 2011). With CRRA gamma
    # it sets the wealth effect on effort, gamma / psi, which caps the MPC of a constrained
    # household near psi / (psi + gamma) (probe_mpc_one_asset.jl, 2026-10-01)
    psi::Float64 = 2.0
    # :free, effort chosen household by household (as always), or :job, effort set by
    # the job: one level per state at which the effort condition holds on average
    # (SAGEParams.job_effort; V3_START.md, decision D1). One asset for now.
    effort_mode::Symbol = :free
    # the means-tested floor on resources (SAGEParams.cfloor), in the model's income units;
    # zero is no floor. Needs effort_mode = :job. Its cost is in the lump-sum tax (floor_tax_of).
    cfloor::Float64 = 0.0
    # the share of time participating takes (SAGEParams.qbar). 0.10 was assumed until version 3;
    # the time-use surveys give about 0.04 (data/timeuse/time_and_inactivity.md), 0.02 to 0.07.
    qbar::Float64 = 0.10
    # Effort levels given from outside, by education cell and state (empty: found by the
    # model, as effort_mode says). Used by the two-asset economy of version 3, which takes
    # the hours the job sets in the one-asset economy of the same country (job_effort_levels):
    # hours do not depend on how wealth is held, and the two-asset solve needs no fixed point.
    effort_by_cell::NTuple{2,Vector{Float64}} = (Float64[], Float64[])
    country::String = ""
    illiquid::Bool = false
    illiquid_premium::Float64 = 0.0
    chi0::Float64 = 0.05
    # The reference version for wealth (V3_START.md, sections 28 and 29): the illiquid return paid
    # into liquid wealth every period (egm2_core.jl), and the gross return on liquid wealth when it
    # differs from the engine's (NaN: the engine's; the illiquid return stays the engine's plus the premium).
    k_payout::Bool = false
    r_liquid::Float64 = NaN
    # Tenure (version 2's two assets, design section 4.1; V3_START.md section 140; the user, 2026-10-26): a household
    # whose illiquid wealth is below k_min (model units) is a tenant and pays rent_share times its persistent income
    # in work (the basis of the benefits: alpha z Z E_REF, not current earnings, so job loss does not cut rent; Eurostat
    # ilc_mded02). Tenants out of work get the housing benefit: the TaxBEN profile with housing benefit less the one
    # without, hbU_vec by quarter of the entitled spell and hb_long beyond and in N (`housing_benefit_profile`).
    # rent_share 0: nobody pays rent.
    rent_share::Float64 = 0.0
    k_min::Float64 = 0.0
    hbU_vec::Vector{Float64} = Float64[]
    hb_long::Float64 = 0.0
    death::Float64 = 1 / 45
    nk::Int = 24
    k_max::Float64 = 150.0        # 60 held 1% of the mass at the top at beta_bar 0.99 (2026-09-29)
    # Adjustment targets between two neighbouring illiquid nodes (egm2_core.jl). At 1 an adjuster
    # chooses among the nodes alone and holds the remainder as liquid wealth, and the liquid median
    # then moves with the grid (0.21 of income at 24 nodes, 0.16 at 48; probe_two_asset_grid.jl,
    # 2026-10-03). 1 reproduces every earlier two-asset result.
    k_sub::Int = 1
    # The floor's tax when it is set from outside (the place layer finances the floor nationally
    # and gives every place the national tax): NaN lets floor_tax_of find it for this economy alone.
    floor_tax_given::Float64 = NaN
    # THE LONG-TERM STATE (unemployment_core.jl, 2026-10-05): the yearly probability of leaving
    # long-term non-employment for work, by education cell; NaN is no such state and every earlier
    # result. With it, the first year out of work is insured (rr) and ends in work with f_find or
    # in the long-term state; that state pays rr_long (assistance in place of insurance; zero means
    # the household lives on the means-tested floor, which must then be on).
    f_long::NTuple{2,Float64} = (NaN, NaN)
    rr_long::Float64 = 0.0
    # Assistance in the long-term state, a flat amount a year; NaN is the floor's level. Paid as a
    # transfer and taxed like insurance. Without it those households would have no income of their
    # own and negative resources after the lump-sum tax, which the household problem does not solve
    # (first run, 2026-10-05: not a number throughout).
    assist_long::Float64 = NaN
    # The part of that income paid by the state (2026-10-12; V3_START.md section 89): where the state out of
    # work pays the measured income of jobless households, which holds other members' incomes too, the public
    # outlay is the statutory minimum income and the rest is the household's own, as a partner's earnings are
    # in the replacement rate. NaN: all of it is public.
    assist_public::Float64 = NaN
    # The share of the long-term state's earnings-related income (rr_long) that the state pays and the tax
    # raises. One: all of it (assistance in place of insurance). Zero: it is the household's own income (other
    # members, other entitlements), and the state's part is what the means-tested floor tops up (2026-10-12).
    long_public_share::Float64 = 1.0
    # PATIENCE BY EDUCATION: a shift of the discount factor in each cell, zero by default. The base
    # puts the hand-to-mouth in the wrong cell (France G+A: 7% below tertiary and 53% with tertiary,
    # against 26% and 15% in the HFCS; test_cell_wealth.jl, 2026-10-05): with one patience for all,
    # the cell with the safer jobs holds no buffer. Estimated discount factors rise with education
    # (Cagetti 2003; Lawrance 1991).
    beta_cell::NTuple{2,Float64} = (0.0, 0.0)
    # Sub-points within an income state for the shares below an income line (cell_summary and
    # income_stats); 1 counts each state as a point, as every result before 2026-10-05 did. The
    # version 3 regimes use 9. No calibration target reads these shares.
    ysmooth::Int = 1
    # THE TRANSITORY PART (2026-10-06; V3_START.md, sections 28 and 29). An independent draw each
    # period on the income of the employed: n_eps nodes, standard deviation sd_eps of the log
    # (binomial nodes and weights, the Rouwenhorst discretisation at zero persistence). Benefits
    # follow the persistent part. Zero reproduces every earlier result.
    sd_eps::Float64 = 0.0
    n_eps::Int = 3
    # How the tax in `lumptax` is raised. :lump, per head, as before. :prop, in proportion to
    # labour income, at the rate lumptax / tax_base, with tax_base mean labour income per head at
    # the job's effort levels (NaN: this economy's own). Needs effort_mode = :job.
    tax_mode::Symbol = :lump
    tax_base::Float64 = NaN
    # THE INCOME PROCESS BY EDUCATION CELL (2026-10-07, V3_START.md sections 34 and 35): the persistence
    # of the persistent part, the standard deviation of its innovation and of the transitory part, for
    # the lower and the higher education cell, as published estimates give them. NaN: the common
    # `rho`, `eta_z` and `sd_eps` above, as in every earlier result.
    rho_cell::NTuple{2,Float64} = (NaN, NaN)
    eta_cell::NTuple{2,Float64} = (NaN, NaN)
    sd_eps_cell::NTuple{2,Float64} = (NaN, NaN)
    # The weight on social cohesion in the belonging payoff. NaN: the engine's (0.8758, carried from
    # the 2020 thesis). One is the normalisation: kappa absorbs it in every choice.
    Lambda::Float64 = NaN
    # A PERMANENT COMPONENT OF INCOME (2026-10-07, V3_START.md section 36): households differ for good
    # by a factor on their earnings and benefits, lognormal with mean one and standard deviation
    # perm_sd of the log, at n_perm nodes (binomial nodes and weights). It is what a published income
    # process leaves out when it is estimated on income net of observables: no risk, only dispersion.
    # Each node is a type of household solved on its own, pooled like the patience types. Zero: none.
    perm_sd::Float64 = 0.0
    n_perm::Int = 3
    # Explicit permanent types (version 5, V3_START.md section 44): factors on income with mean one
    # and their weights, fitted to the official decile cut-offs. When given they replace the
    # symmetric nodes of perm_sd.
    perm_f::Vector{Float64} = Float64[]
    perm_w::Vector{Float64} = Float64[]
    # The gross real return on the single asset when it is not the engine's 1.02 (V3_START.md section
    # 57): the one asset is narrow liquid wealth, mostly sight accounts, whose measured real return
    # is the deposit rate less inflation (data/manual_inputs.csv, field r_deposits_real). NaN: 1.02.
    R_one::Float64 = NaN
    # The economy in which the job's effort levels are found (floor_effort) taxed in proportion to
    # labour income, as the economy itself is, when tax_mode is :prop. false: taxed per head, as in
    # the regime of 2026-10-06, whose files it reproduces. Per head, the lowest income states of a
    # wide published process cannot pay the tax (Italy, 2026-10-07), and the levels found are erratic.
    ref_prop::Bool = false
    # The illiquid grid's dense part: with k_mid > 0, three fifths of the nodes lie on [0, k_mid] and
    # the rest run geometrically to k_max. On the exponential grid (k_mid = 0, every earlier result)
    # the nodes around median net wealth are over two years of income apart at 24 nodes, and liquid
    # wealth and the wealthy hand-to-mouth share only settle at 48 (0.074 against 0.041 of income;
    # probe_two_asset_grid.jl, 2026-10-04).
    k_mid::Float64 = 0.0
    b_max::Float64 = 15.0
    nb::Int = 120
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
    (c.rho != 0.9 || c.eta_z != 0.1) && push!(ext, @sprintf("income process %.2f/%.2f", c.rho, c.eta_z))
    c.dread > 0 && c.A && push!(ext, @sprintf("dread %.2f (%s)", c.dread, c.dread_mode))
    c.beta_spread > 0 && push!(ext, @sprintf("beta spread %.3f", c.beta_spread))
    c.subsidy > 0 && push!(ext, @sprintf("subsidy %.2f", c.subsidy))
    c.partcredit > 0 && push!(ext, @sprintf("credit %.2f", c.partcredit))
    c.lumptax > 0 && push!(ext, @sprintf("lump tax %.5f", c.lumptax))
    c.levy_employed > 0 && push!(ext, @sprintf("levy on the employed %.5f", c.levy_employed))
    s = @sprintf("%-6s alpha %s  B %s", dims,
                 (c.A || c.premium_base) ? @sprintf("%.3f/%.3f", c.alpha...) : @sprintf("%.3f", c.alpha_off),
                 c.S ? @sprintf("%.2f/%.2f, kappa %.2f sigma %.3f omega %.2f",
                                c.B..., c.kappa, c.sigma_m, c.omega) : "(no social payoff)")
    isempty(ext) ? s : s * " | " * join(ext, ", ")
end

# --------------------------------------------------------------- internals --
"The effective cell parameters implied by a config: alpha and B per cell."
function cells_of(c::SAGEConfig)
    αs = (c.A || c.premium_base) ? c.alpha : (c.alpha_off, c.alpha_off)
    pick(v, common) = isnan(v) ? common : v          # the cell's own income process where it is given
    ((gi = 1, α = αs[1], B = c.B[1], share = c.share[1], δ = c.unemployment ? c.delta[1] : 0.0, τ = c.commute[1], eset = c.effort_by_cell[1], fL = c.f_long[1], dβ = c.beta_cell[1],
      ρ = pick(c.rho_cell[1], c.rho), η = pick(c.eta_cell[1], c.eta_z), sε = pick(c.sd_eps_cell[1], c.sd_eps)),
     (gi = 2, α = αs[2], B = c.B[2], share = c.share[2], δ = c.unemployment ? c.delta[2] : 0.0, τ = c.commute[2], eset = c.effort_by_cell[2], fL = c.f_long[2], dβ = c.beta_cell[2],
      ρ = pick(c.rho_cell[2], c.rho), η = pick(c.eta_cell[2], c.eta_z), sε = pick(c.sd_eps_cell[2], c.sd_eps)))
end

"Nodes and weights of the permanent component of income (mean one)."
function perm_nodes(c::SAGEConfig)
    isempty(c.perm_f) || return (c.perm_f, c.perm_w)
    (c.perm_sd <= 0 || c.n_perm <= 1) && return ([1.0], [1.0])
    K = c.n_perm
    x = [c.perm_sd * sqrt(K - 1) * (2 * (k - 1) / (K - 1) - 1) for k in 1:K]
    w = [binomial(K - 1, k - 1) / 2.0^(K - 1) for k in 1:K]
    f = exp.(x); f ./= dot(w, f)
    (f, w)
end

"""
The types of household within a cell and their weights: the discount-factor nodes, each at every
node of the permanent component of income when there is one (the first list then repeats each
discount factor once per income node, in the order `params_of` builds them).
"""
function betas_of(c::SAGEConfig)
    has_choosers(c) && error("with households who choose their hours the weights differ by education cell: use betas_by_cell(c)")
    type_betas(c)
end

"""
    betas_by_cell(c)

The types of household and their weights in each education cell: `(b, (w1, w2))`. The same as `betas_of`
in both cells unless some households choose their hours (A), whose share differs by education: each cell's
list then holds its types twice, first those whose job sets their hours (one less the cell's share), then
those who choose (the cell's share), in the order `params_of` builds them.
"""
function betas_by_cell(c::SAGEConfig)
    b, w = type_betas(c)
    has_choosers(c) || return (b, (w, w))
    (repeat(b, outer = 2), ntuple(g -> [x.w * y for x in control_groups(c, g) for y in w], 2))
end

"Whether some households choose their hours: A on and a share with control over working time."
has_choosers(c::SAGEConfig) = c.A && any(>(0), c.control_share)

"""
    control_groups(c, g)

Who chooses their hours in education cell `g` (A): those whose job sets their hours, with weight one less
the cell's share with control over working time, then those who choose, with that share. One group that
does not choose when no household does. (Until 2026-10-12 three groups with weights common to the two
cells; weights by cell need two, and a third fewer household problems.)
"""
function control_groups(c::SAGEConfig, g::Int)
    has_choosers(c) || return [(w = 1.0, chooses = false)]
    s_ = c.control_share[g]
    0 <= s_ <= 1 || error("control_share must lie between zero and one")
    [(w = 1 - s_, chooses = false), (w = s_, chooses = true)]
end

"The types by patience and permanent income alone, before the groups of `control_groups`: what `_params_of` builds."
function type_betas(c::SAGEConfig)
    b, w = _betas_of(c)
    f, wf = perm_nodes(c)
    length(f) == 1 && return (b, w)
    (repeat(b, inner = length(f)), [w[i] * wf[k] for i in eachindex(b) for k in eachindex(f)])
end

"Discount-factor nodes and weights implied by a config."
function _betas_of(c::SAGEConfig)
    # two groups: a patient majority at beta_bar and an impatient minority of
    # share impatient_share at beta_low (the two-asset calibration, 2026-09-29)
    c.impatient_share > 0 && return ([c.beta_low, c.beta_bar], [c.impatient_share, 1 - c.impatient_share])
    c.beta_spread <= 0 && return ([c.beta_bar], [1.0])
    b = [c.beta_bar - c.beta_spread + c.beta_spread * (2i - 1) / (2 * c.nbeta) for i in 1:c.nbeta]
    (b, fill(1 / length(b), length(b)))
end

"""
The employed states of a parameter set: positive productivity. Until 2026-10-02
this was read from the transfer (no benefit means employed), which made everyone
employed at a zero replacement rate and no one at a negative levy.
"""
employed_states(p::SAGEParams) = isemp(p)
"Whether a configuration is built on the labour chain (version 2): a sub-annual period, a first spell of several periods, or forced."
uses_chain(c) = c.chain || c.period > 1 || c.nU > 1
"The exits from work by period of the first spell on the chain."
chain_hU(c) = isempty(c.hU_vec) ? fill(c.f_find, c.nU) : c.hU_vec
"The chain's flows to and from inactivity, as keywords of labour_chain."
chain_flows(c, gi::Int) = (sU = isempty(c.sU_vec) ? zeros(c.nU) : c.sU_vec, sL = c.sL, ιE = c.iotaE[gi], νE = c.nuE, νU = c.nuU, withN = c.withN, entN = c.entN)

"""
    expand_transitory(p, sd, nt)

The household problem `p` with an independent transitory draw on the income of the employed:
every state becomes `nt` states, productivity times the draw, reached with the draw's
probabilities whatever the state left. Everything else a state carries (the benefit, the job's
effort, dread's reference points) is that of the persistent state.
"""
function expand_transitory(p::SAGEParams, sd, nt; stay = 0.0)
    (sd == 0 || nt <= 1) && return p
    p.z_vals_override === nothing && error("the transitory part needs the unemployment state space")
    z = p.z_vals_override; Π = p.Π_override; ns = length(z)
    x = [sd * sqrt(nt - 1) * (2 * (t - 1) / (nt - 1) - 1) for t in 1:nt]
    w = [binomial(nt - 1, t - 1) / 2.0^(nt - 1) for t in 1:nt]
    ε = exp.(x); ε ./= dot(w, ε)
    ex(v) = isempty(v) ? v : repeat(v, inner = nt)
    zp = sort(unique(z[z .> 0]))
    M = stay == 0 ? ones(nt) * w' : stay * Matrix(1.0I, nt, nt) + (1 - stay) * ones(nt) * w'
    update(p; nz = ns * nt, z_vals_override = [z[s] * ε[t] for s in 1:ns for t in 1:nt], Π_override = kron(Π, M),
           α = ex(p.α), B = ex(p.B), transfer = ex(p.transfer), effort_set = ex(p.effort_set), rent = ex(p.rent), hb = ex(p.hb),
           belong_scale = ex(p.belong_scale), time_floor = ex(p.time_floor),
           dread_q = ex(p.dread_q), dread_hi = ex(p.dread_hi), dread_lo = ex(p.dread_lo), search_k = ex(p.search_k), out_cost = ex(p.out_cost),
           stype = ex(p.stype), lat = isempty(p.lat) ? p.lat : [(p.lat[s] - 1) * nt + t for s in 1:ns for t in 1:nt], dur = ex(p.dur), search_lam = ex(p.search_lam),
           zstep = length(zp) > 1 ? log(zp[2] / zp[1]) : 0.0)
end

const LABOUR_BASE_CACHE = Dict{UInt,Float64}()
"""
    labour_base(c)

Mean labour income per head in economy `c` at the job's effort levels, before tax: the base of
the proportional tax. From the stationary distribution of the states, so it needs no solve.
"""
function labour_base(c::SAGEConfig)
    (c.effort_mode === :job && !isempty(c.effort_by_cell[1])) ||
        error("a proportional tax needs the job's effort levels given (effort_mode = :job, and floor_effort(c) first)")
    c1 = SAGEConfig(c; tax_mode = :lump, tax_base = NaN, sd_eps = 0.0, sd_eps_cell = (0.0, 0.0), lumptax = 0.0, subsidy = 0.0, levy_employed = 0.0,
                    S = false, cfloor = 0.0, floor_tax_given = NaN, control_share = (0.0, 0.0))          # the base of the tax is at the job's hours for everyone
    get!(LABOUR_BASE_CACHE, hash(repr(c1))) do
        cs = cells_of(c1); _, bw = betas_of(c1)
        sum(1:2) do g
            sum(enumerate(_params_of(c1, cs[g]))) do (k, p)
                z, Π = SAGEBewley.income_process(p); π = fill(1 / length(z), length(z))
                for _ in 1:100_000
                    πn = Π' * π; d = maximum(abs, πn - π); π = πn
                    d < 1e-14 && break
                end
                cs[g].share * bw[k] * sum(π[st] * p.α[st] * p.effort_set[st] * z[st] * p.Z for st in eachindex(z))
            end
        end
    end
end

"Parameter sets for one cell, one per discount type."
function params_of(c::SAGEConfig, cell)
    ps = _params_of(c, cell)
    ps = cell.sε > 0 ? [expand_transitory(p, cell.sε, c.n_eps; stay = c.eps_stay) for p in ps] : ps
    has_choosers(c) || return ps
    # the same households once per group; for the group that chooses its hours the job's levels are dropped
    vcat([g.chooses ? [update(p; job_effort = false, effort_set = Float64[]) for p in ps] : ps for g in control_groups(c, cell.gi)]...)
end

function _params_of(c::SAGEConfig, cell)
    # With a transitory part or a proportional tax the job's effort levels are those of the economy
    # without either (floor_effort): what a job asks does not move with the year's draw or with how
    # the benefit bill is raised. Found by the model here, effort would follow the draw.
    (cell.sε > 0 || c.tax_mode === :prop) && c.effort_mode === :job && isempty(cell.eset) &&
        error("with a transitory part or a proportional tax the job's effort levels are given: floor_effort(c) first")
    c.tax_mode in (:lump, :prop) || error("tax_mode is :lump or :prop")
    bs, _ = type_betas(c)
    ps = !uses_chain(c) ?
         [cell_params_u(cell.α; δ = cell.δ, f = c.f_find, rr = c.rr, na = c.na, ne = c.ne,
                        a_max = c.a_max, pexp = c.pexp, subsidy = c.subsidy, lumptax = c.lumptax,
                        partcredit = c.partcredit, β = b + cell.dβ, pcost = c.pcost, nz = c.nz,
                        ρ = cell.ρ, η = cell.η, fL = cell.fL, rrL = c.rr_long) for b in bs] :
         [cell_params_chain(cell.α; δ = cell.δ, hU = chain_hU(c), hL = cell.fL, rrU = isempty(c.rrU_vec) ? fill(c.rr, c.nU) : c.rrU_vec, rrL = c.rr_long, chain_flows(c, cell.gi)...,
                            nU = c.nU, ppy = c.period, na = c.na, ne = c.ne, a_max = c.a_max, pexp = c.pexp, subsidy = c.subsidy,
                            lumptax = c.lumptax, partcredit = c.partcredit, β = b + cell.dβ, pcost = c.pcost, nz = c.nz,
                            ρ = cell.ρ, η = cell.η, rent_share = c.illiquid ? c.rent_share : 0.0,
                            hbU = isempty(c.hbU_vec) ? zeros(c.nU) : c.hbU_vec, hbL = c.hb_long) for b in bs]
    isnan(c.Lambda) || (ps = [update(p; Λ = c.Lambda) for p in ps])
    let (f, _) = perm_nodes(c), K = length(perm_nodes(c)[1])
        K > 1 && (ps = [update(p; Z = p.Z * f[(j - 1) % K + 1], transfer = p.transfer .* f[(j - 1) % K + 1], rent = p.rent .* f[(j - 1) % K + 1], hb = p.hb .* f[(j - 1) % K + 1]) for (j, p) in enumerate(ps)])
    end
    # version 1's annual long-term state was not built for two assets; the quarterly chain's L is (section 141)
    (!isnan(cell.fL) && c.illiquid && !uses_chain(c)) && error("the long-term state is not built for two assets on the annual model")
    if c.tax_mode === :prop && c.lumptax != 0
        # the same revenue per head, raised in proportion to labour income
        τ = c.lumptax / (isnan(c.tax_base) ? labour_base(c) : c.tax_base)
        ps = [update(p; lumptax = p.lumptax - c.lumptax, subsidy = p.subsidy - τ) for p in ps]
    end
    if c.phi != 14.0 || c.e_ref != E_REF
        ps = [update(p; ϕ = c.phi, transfer = p.transfer .* (c.e_ref / E_REF), rent = p.rent .* (c.e_ref / E_REF), hb = p.hb .* (c.e_ref / E_REF)) for p in ps]
    end
    c.ysmooth == 1 || (ps = [update(p; ysmooth = c.ysmooth) for p in ps])
    if !isnan(cell.fL)
        al = assist_of(c); stl = stypes(ps[1])
        dul = isempty(ps[1].dur) ? zeros(Int, length(stl)) : ps[1].dur
        ps = [update(p; transfer = [(stl[s] in (:L, :N) || dul[s] > NONENT) ? p.transfer[s] + al : p.transfer[s] for s in eachindex(p.transfer)]) for p in ps]   # the inactive and the spell without entitlement as L
    end
    emp = employed_states(ps[1])
    if c.levy_employed != 0
        ps = isempty(ps[1].transfer) ? [update(p; lumptax = p.lumptax + c.levy_employed) for p in ps] :
             [update(p; transfer = [e ? -c.levy_employed : t for (e, t) in zip(emp, p.transfer)]) for p in ps]
    end
    if c.A && c.dread > 0 && c.unemployment
        ps = [dread_params(p, c, cell) for p in ps]
    end
    if c.A && c.search && c.unemployment
        isnan(cell.fL) && error("search effort is built on the state out of work (f_long)")
        kq = c.search_kq[cell.gi]
        if isempty(kq)
            (isnan(c.search_kU[cell.gi]) || isnan(c.search_kL[cell.gi])) && error("search on with no cost level for cell $(cell.gi): fit search_kU and search_kL")
            sk = [t === :U ? c.search_kU[cell.gi] : t === :L ? c.search_kL[cell.gi] : 0.0 for t in stypes(ps[1])]
        else
            du_ = ps[1].dur
            sk = [t === :U ? kq[du_[i] > NONENT ? du_[i] - NONENT : du_[i]] : t === :L ? kq[end] : 0.0 for (i, t) in enumerate(stypes(ps[1]))]
        end
        ps = [update(p; search_k = sk, search_gamma = c.search_gamma) for p in ps]
    end
    if c.A && c.out_ls > 0 && c.unemployment
        isnan(cell.fL) && error("the cost of being out of work is built on the state out of work (f_long)")
        isnan(c.out_M) && error("out_ls is set with no mean income out_M to convert it at")
        γ = ps[1].γ; θ = exp(-c.out_ls / c.out_betaY)
        χ = c.out_M^(1 - γ) / (1 - γ) * (1 - θ^(1 - γ))
        oc = [t === :U || t === :L ? χ : 0.0 for t in stypes(ps[1])]
        ps = [update(p; out_cost = oc) for p in ps]
    end
    c.solver === :grid || (ps = [update(p; solver = c.solver) for p in ps])
    cell.τ == 0 || (ps = [update(p; commute = cell.τ) for p in ps])
    c.ctax == 0 || (ps = [update(p; pc = 1 + c.ctax) for p in ps])
    c.psi == 2.0 || (ps = [update(p; ψ = c.psi) for p in ps])
    c.effort_mode === :free || (c.effort_mode === :job ? (ps = [update(p; job_effort = true) for p in ps]) : error("effort_mode is :free or :job"))
    isempty(cell.eset) || (ps = [update(p; job_effort = true, effort_set = cell.eset) for p in ps])
    c.cfloor == 0 || (ps = [update(p; cfloor = c.cfloor) for p in ps])
    isnan(c.R_one) || (ps = [update(p; R = c.R_one) for p in ps])
    c.qbar == 0.10 || (ps = [update(p; qbar = c.qbar) for p in ps])
    if c.illiquid
        c.solver === :egm || error("the illiquid asset needs solver = :egm")
        # c.death is a YEARLY rate (1/45: a 45-year average lifetime); at a sub-annual period it is the period's
        # equivalent (it went in unconverted at the quarterly period until 2026-10-27: V3_START.md section 141)
        ps = [update(p; illiquid = true, Rk = p.R + c.illiquid_premium, chi0 = c.chi0, death = 1 - (1 - c.death)^(1 / c.period),
                     nk = c.nk, k_max = c.k_max, k_sub = c.k_sub, k_mid = c.k_mid, a_max = c.b_max, na = c.nb,
                     k_min = c.rent_share > 0 ? c.k_min : 0.0) for p in ps]
        c.k_payout && (ps = [update(p; k_payout = true) for p in ps])
        isnan(c.r_liquid) || (ps = [update(p; R = c.r_liquid) for p in ps])
    end
    (c.search_time == 0 && c.belong_u == 1 && c.time_bonus == 0) && return ps
    tf = (c.search_time == 0 && c.time_bonus == 0) ? Float64[] : [(e ? 0.0 : c.search_time) - c.time_bonus for e in emp]
    bsc = c.belong_u == 1 ? Float64[] : [e ? 1.0 : c.belong_u for e in emp]
    [update(p; time_floor = tf, belong_scale = bsc) for p in ps]
end

"""
    dread_params(p, c, cell)

Attach the dread vectors to a parameter set: for every state, q(1 - q) with q
the chance of changing employment status next year, and next year's resources
in work (hi) and out of work (lo) at the same latent productivity: labour income
at the reference effort plus the state's transfer, and the benefit, both net of
the lump-sum tax. States 1..n/2 are unemployed, n/2+1..n employed with the same
latent productivity (see `unemployment_process`).
"""
function dread_params(p::SAGEParams, c::SAGEConfig, cell)
    n = length(p.transfer)
    z = p.z_vals_override; Π = p.Π_override
    # by the chain's labels (version 2, stage 0): the chance of a change of status, and the incomes of the
    # employed state and of the bad outcome that share this state's latent productivity
    st = stypes(p); emp = st .== :E
    pE = partner_index(p, :E); pU = partner_index(p, :U); pL = partner_index(p, :L)
    Πh = c.dread_horizon == 1 ? Π : Π^c.dread_horizon
    q = [emp[s] ? sum(Πh[s, .!emp]) : sum(Πh[s, emp]) for s in 1:n]
    hi = [(1 + p.subsidy) * cell.α * z[pE[s]] * p.Z * c.e_ref + p.transfer[pE[s]] - p.lumptax
          for s in 1:n]
    # what income falls to if the bad outcome comes: for those in work the first year's benefit; for those in
    # their first year out of work, with the state out of work, the assistance of the year after (2026-10-11:
    # until then their own benefit, as if it went on); for those beyond a year, the assistance they are on
    nx = next_out_index(p)
    lo = [p.transfer[emp[s] ? pU[s] : nx[s]] - p.lumptax for s in 1:n]
    c.dread_mode in (:overlay, :behaviour) || error("dread_mode must be :overlay or :behaviour")
    c.dread_mode == :behaviour ?
        update(p; dread = c.dread, dread_q = q .* (1 .- q), dread_hi = hi, dread_lo = lo) :
        update(p; dread_overlay = c.dread, dread_q = q .* (1 .- q), dread_hi = hi, dread_lo = lo)
end

"Assistance paid in the long-term state: the amount given, or the floor's level."
function assist_of(c::SAGEConfig)
    al = isnan(c.assist_long) ? c.cfloor : c.assist_long
    (al > 0 || c.rr_long > 0) || error("the long-term state needs an income: give assist_long or rr_long, or turn the means-tested floor on")
    al
end
"The state's share of the income of those out of work beyond a year, for the tax along a path."
long_public_factor(c::SAGEConfig) = isnan(c.f_long[1]) ? 1.0 : (c.rr_long > 0 && assist_of(c) == 0) ? c.long_public_share : assist_public_of(c) / assist_of(c)

const INCOME_RISK_CACHE = Dict{UInt,Any}()
"""
    income_chain_moments(nz, n_eps, rho, s_eta, s_eps, delta, f, fL, rr, rrL)

The variance and first autocovariance of log household income in one education cell, from the Markov
chain of its states alone (no household is solved: income by state is given). In work, income is the
persistent part times the transitory part; in the first year out of work, `rr` times the persistent part;
beyond a year, `rrL` times it. Taxes are left out (a few percent on those in work).
"""
function income_chain_moments(nz, n_eps, ρ, sη, sε, δ, f, fL, rr, rrL)
    base = SAGEParams(nz = nz, α = fill(1.0, nz), B = fill(1.0, nz), ρ = ρ, η = sη)
    up = unemployment_process(base, δ, f; fL = fL)
    z = up.z_latent; emp = up.employed; long = up.longterm; nt = sε > 0 ? n_eps : 1
    x = nt > 1 ? [sε * sqrt(nt - 1) * (2 * (t - 1) / (nt - 1) - 1) for t in 1:nt] : [0.0]
    w = nt > 1 ? [binomial(nt - 1, t - 1) / 2.0^(nt - 1) for t in 1:nt] : [1.0]
    ε = exp.(x); ε ./= dot(w, ε)
    y = [log(emp[s] ? z[s] * ε[t] : long[s] ? rrL * z[s] : rr * z[s]) for s in eachindex(z) for t in 1:nt]
    P = kron(up.Π, ones(nt) * w'); N = length(y)
    π = vcat(P' - I, ones(1, N)) \ vcat(zeros(N), 1.0)
    d = y .- dot(π, y)
    (var = dot(π, d .^ 2), ac1 = dot(π .* d, P * d))
end

"""
    purged_income_risk(nz, n_eps, rho, s_eta, s_eps, delta, f, fL, rr, rrL)

THE INCOME PROCESS NET OF JOB LOSS (2026-10-12; V3_START.md section 90). The published process (Ampudia,
Cooper, Le Blanc and Zhu 2024) is estimated on household income after tax with social transfers,
unemployment benefits among them, for all households of working age: the falls in income that come with
job loss are already in its variances. The model has job loss as states of its own, so the published
standard deviations used as they are count that risk twice (by 11 to 54% of the variance of log income,
by education cell and country). Returned are the standard deviations of the persistent innovation and of
the transitory part with which the model's household income, job loss included, has the variance and the
first autocovariance of the published process; the persistence is the published one.
"""
function purged_income_risk(nz, n_eps, ρ, sη, sε, δ, f, fL, rr, rrL)
    get!(INCOME_RISK_CACHE, hash((nz, n_eps, ρ, sη, sε, δ, f, fL, rr, rrL))) do
        pubv = sη^2 / (1 - ρ^2) + sε^2; puba = ρ * sη^2 / (1 - ρ^2)
        mom(a, b) = income_chain_moments(nz, n_eps, ρ, a, b, δ, f, fL, rr, rrL)
        a, b = sη, sε
        for _ in 1:80
            base0 = mom(1e-6, b).ac1          # what job loss alone gives
            puba > base0 || error("job loss alone gives more persistent income risk than the published process has")
            a *= clamp(sqrt((puba - base0) / max(mom(a, b).ac1 - base0, 1e-12)), 0.7, 1.4)
            b = sqrt(max(b^2 + pubv - mom(a, b).var, 1e-10))
        end
        r = mom(a, b)
        (abs(r.var - pubv) < 1e-5 && abs(r.ac1 - puba) < 1e-5) || error("the income process net of job loss was not found: variance $(r.var) against $pubv, autocovariance $(r.ac1) against $puba")
        (a, b)
    end
end

"Assistance in the long-term state where there is one, else one (for ratios taken whether or not the state is on)."
assist_of_or_one(c::SAGEConfig) = isnan(c.f_long[1]) ? 1.0 : assist_of(c)
"The part of the long-term state's income that the state pays: all of it, or `assist_public` where that is given and lower."
assist_public_of(c::SAGEConfig) = isnan(c.f_long[1]) ? 1.0 : isnan(c.assist_public) ? assist_of(c) : min(c.assist_public, assist_of(c))
"What assistance in the long-term state costs per head: the state's mass in each cell times the amount (zero without the state)."
function assist_tax_of(c::SAGEConfig)
    (c.unemployment && !isnan(c.f_long[1])) || return 0.0
    uses_chain(c) && return sum(x.share * chain_mass_L(x.δ, c.nU, chain_hU(c), x.fL; nz = c.nz, flows = chain_flows(c, x.gi)) for x in cells_of(c)) * assist_public_of(c)
    sum(x.share * unemployment_process(SAGEParams(nz = c.nz, α = fill(x.α, c.nz), B = fill(1.0, c.nz), ρ = c.rho, η = c.eta_z), x.δ, c.f_find; fL = x.fL).l
        for x in cells_of(c)) * assist_public_of(c)
end

"Unemployment-insurance tax implied by a config, closed form (zero when off)."
function ui_tax_of(c::SAGEConfig)
    c.unemployment || return 0.0
    ui_only_tax_of(c) + floor_tax_of(c)
end

"The unemployment-benefit part of the tax alone (closed form)."
ui_only_tax_of(c::SAGEConfig) = !c.unemployment ? 0.0 : uses_chain(c) ?
    assist_tax_of(c) + chain_ui_tax([(share = x.share, α = x.α, δ = x.δ, fL = x.fL, fl = chain_flows(c, x.gi)) for x in cells_of(c)], c.nU, chain_hU(c),
                                    !isempty(c.rrU_pub_vec) ? c.rrU_pub_vec : isnan(c.rr_public) ? c.rr : c.rr_public; nz = c.nz, rrL = c.rr_long * c.long_public_share) * (c.e_ref / E_REF) :
    assist_tax_of(c) + ui_tax([(share = x.share, α = x.α, δ = x.δ, fL = x.fL) for x in cells_of(c)], c.f_find, isnan(c.rr_public) ? c.rr : c.rr_public; nz = c.nz, rrL = c.rr_long * c.long_public_share) * (c.e_ref / E_REF)

const FLOOR_EFFORT_CACHE = Dict{UInt,Any}()
"""
    floor_effort(c)

With the means-tested floor on and effort set by the job, the job's effort levels
are those of the same economy WITHOUT the floor and without its tax: the floor
changes who is topped up, not what a job asks. Returns the configuration with
those levels given (`effort_by_cell`), or `c` unchanged when there is no floor,
effort is free, or the levels are already given. Found by the model with the
floor on, the levels have no solution in version 3: in the lowest income states
every household is on the floor, where an extra euro earned is taken back.
"""
function floor_effort(c::SAGEConfig)
    (c.effort_mode === :job && isempty(c.effort_by_cell[1]) && (c.cfloor > 0 || any(x -> x.sε > 0, cells_of(c)) || c.tax_mode === :prop)) || return c
    # With the long-term state the economy without the floor has no solution (those households have no
    # income of their own), so the levels are those of the economy without the floor and without that
    # state, and zero in its block.
    long = !isnan(c.f_long[1])
    # The same holds for the transitory part and the proportional tax (2026-10-06): the levels are
    # those of the economy with persistent risk alone and the tax raised per head.
    c1 = SAGEConfig(c; cfloor = 0.0, S = false, f_long = c.period > 1 ? c.f_long : (NaN, NaN), sd_eps = 0.0, sd_eps_cell = (0.0, 0.0), tax_mode = :lump, tax_base = NaN,
                    control_share = (0.0, 0.0), search = false, out_ls = 0.0)   # what a job asks does not depend on who may choose otherwise, on how hard the unemployed search, or on what being out of work costs them
    lv = if c.ref_prop && c.tax_mode === :prop
        # the reference economy pays its benefit bill T at a rate on labour income. The rate needs the
        # levels (it is T over labour income per head) and the levels the rate, so the pair is found
        # together: a few rounds, since effort hardly moves with a tax of a few percent. With the
        # nation's base given (the place layer) the rate is known and one round is enough.
        get!(FLOOR_EFFORT_CACHE, hash(("prop", repr(c1), c.tax_base))) do
            T = c1.lumptax + ui_tax_of(c1); τ = isnan(c.tax_base) ? 0.0 : T / c.tax_base; lv_ = nothing
            for _ in 1:8
                # job_effort_levels adds the benefit tax to lumptax: taken off here, so nothing is raised per head
                lv_ = job_effort_levels(SAGEConfig(c1; lumptax = c1.lumptax - T, subsidy = c1.subsidy - τ))
                isnan(c.tax_base) || break
                τn = T / labour_base(SAGEConfig(c1; effort_by_cell = lv_))
                done = abs(τn - τ) < 1e-6; τ = τn
                done && break
            end
            lv_
        end
    else
        get!(() -> job_effort_levels(c1), FLOOR_EFFORT_CACHE, hash(repr(c1)))
    end
    (long && c.period == 1) && (lv = Tuple(vcat(v, zeros(length(v) ÷ 2)) for v in lv))   # on the labour chain the reference keeps every state
    SAGEConfig(c; effort_by_cell = lv)
end

"""
    floor_outlay_at(c, T)

What the floor pays out per head in economy `c` (S off) when every household pays
a total lump-sum tax `T`, whoever the tax is raised for. For the place layer,
where the floor is financed by the nation and not by each place.
"""
function floor_outlay_at(c::SAGEConfig, T)
    cg = SAGEConfig(c; S = false, E = false, lumptax = T - ui_only_tax_of(c), floor_tax_given = 0.0)
    c0 = floor_effort(cg); cs = cells_of(c0); _, bw = betas_by_cell(c0)
    cT = SAGEConfig(c0; lumptax = T)
    jobs = [(g, k, p) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
    sum((nworkers() > 1 ? pmap : map)(jobs) do (g, k, p)
            p = update(p; social_strength = 0.0)
            cs[g].share * bw[g][k] * cell_summary(p, solve_participation_logit(p, 1.0; theta = c0.theta, full = true)).fout
        end)
end

const FLOOR_TAX_CACHE = Dict{UInt64,Float64}()
const FLOOR_TAX_LAST = Ref(0.0)
"""
    floor_tax_of(c)

The lump-sum tax per head that pays for the means-tested floor: the fixed point
of "outlay on the floor when households pay the tax that covers it". The outlay
depends on who is poor, which depends on the tax, so it is iterated on the
household problems with S off (saving does not depend on belonging when effort
is set by the job, and participation moves effort through time only slightly;
the economy reports what is left as `budget_gap`). Remembered per configuration.
"""
function floor_tax_of(c::SAGEConfig)
    c.cfloor > 0 || return 0.0
    isnan(c.floor_tax_given) || return c.floor_tax_given
    c.effort_mode === :job || error("the means-tested floor needs effort_mode = :job")
    c0 = floor_effort(SAGEConfig(c; S = false, E = false, cfloor = c.cfloor))
    key = hash(repr((c0.rr_public, c0.qbar, c0.effort_by_cell, c0.cfloor, c0.f_long, c0.assist_long, c0.assist_public, c0.rr_long, c0.long_public_share, c0.control_share, c0.alpha, c0.alpha_off, c0.A, c0.premium_base, c0.share, c0.delta, c0.f_find, c0.rr, c0.e_ref, c0.phi, c0.psi, c0.beta_bar,
                     c0.beta_spread, c0.nbeta, c0.impatient_share, c0.beta_low, c0.lumptax, c0.subsidy, c0.levy_employed, c0.rho, c0.eta_z,
                     c0.nz, c0.na, c0.a_max, c0.pexp, c0.theta, c0.commute, c0.ctax, c0.time_bonus, c0.unemployment, c0.unemployed_ratio === nothing,
                     c0.sd_eps, c0.n_eps, c0.tax_mode, c0.tax_base, c0.beta_cell, c0.ysmooth, c0.rho_cell, c0.eta_cell, c0.sd_eps_cell, c0.Lambda, c0.perm_sd, c0.n_perm, c0.perm_f, c0.perm_w, c0.R_one, c0.ref_prop, c0.search, c0.search_gamma, c0.search_kU, c0.search_kL, c0.out_ls, c0.out_M, c0.out_betaY, c0.period, c0.nU, c0.chain, c0.hU_vec, c0.sU_vec, c0.sL, c0.withN, c0.iotaE, c0.nuE, c0.nuU, c0.eps_stay, c0.dread, c0.dread_mode, c0.dread_horizon, c0.rrU_vec, c0.rrU_pub_vec, c0.entN, c0.search_kq)))
    # with two assets the outlay also holds the housing benefit, and both depend on how wealth is held
    c0.illiquid && (key = hash((key, repr((c0.chi0, c0.illiquid_premium, c0.rent_share, c0.k_min, c0.hbU_vec, c0.hb_long, c0.nk,
                                           c0.k_max, c0.k_sub, c0.k_mid, c0.nb, c0.b_max, c0.death, c0.k_payout, c0.r_liquid)))))
    haskey(FLOOR_TAX_CACHE, key) && return FLOOR_TAX_CACHE[key]
    base = c.lumptax + ui_only_tax_of(c)
    cs = cells_of(c0); _, bw = betas_by_cell(c0)
    # start from the last tax found, unless that run failed (a NaN kept here made every later
    # configuration NaN: all Italian places after the first that broke, 2026-10-04)
    F = isfinite(FLOOR_TAX_LAST[]) ? FLOOR_TAX_LAST[] : 0.0
    for it in 1:40
        cT = SAGEConfig(c0; lumptax = base + F)
        jobs = [(g, k, p) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
        outs = (nworkers() > 1 ? pmap : map)(jobs) do (g, k, p)
            p = update(p; social_strength = 0.0)
            s = solve_participation_logit(p, 1.0; theta = c0.theta, full = true)
            cs[g].share * bw[g][k] * cell_summary(p, s).fout
        end
        out = sum(outs)
        isfinite(out) || error("the floor's outlay is not finite at a tax of $F: a floor of $(c0.cfloor) cannot be financed in this economy")
        if abs(out - F) < 1e-9
            F = out; break
        end
        F = it <= 10 ? out : 0.5 * (F + out)          # damped once the plain step has had its chance
        it == 40 && @warn "floor_tax_of did not settle" F
    end
    FLOOR_TAX_LAST[] = F
    FLOOR_TAX_CACHE[key] = F
end

taste_nodes_of(c::SAGEConfig) = taste_nodes_ln(c.sigma_m; n = c.nq)

# ------------------------------------------------ unemployed participation --
"The employed states of a config's state space, true where employed."
function employment_mask(c::SAGEConfig)
    c = floor_effort(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    employed_states(params_of(cT, cells_of(c)[1])[1])
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
        out = merge(n, (part = p, rate = sum(p)))
        # welfare and the propensity to participate follow the rule too: what
        # participating while unemployed contributes (reporting_core.jl) is scaled
        # from the model's rate to the rule's, k times as much
        haskey(n, :vbumass) || return out
        mU = sum(n.mass[.!emp]); rU = mU > 0 ? sum(n.part[.!emp]) / mU : 0.0
        k = rU > 0 ? min(ratio * rE, 1.0) / rU : 1.0
        merge(out, (vbmass = n.vbmass .- (1 - k) .* n.vbumass, vemass = n.vemass .- (1 - k) .* n.veumass,
                    vmass = n.vmass .- (1 - k) .* (n.vbumass .+ n.veumass),
                    mppmass = n.mppmass .- (1 - k) .* n.mppumass,
                    vbumass = k .* n.vbumass, veumass = k .* n.veumass, mppumass = k .* n.mppumass))
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

"The liquid wealth grid the household problem uses: a_max and na, or b_max and nb with the illiquid asset."
liquid_grid_of(c::SAGEConfig) = c.illiquid ? SAGEBewley.exponential_grid(1e-10, c.b_max, c.nb, c.pexp) :
                                            SAGEBewley.exponential_grid(1e-10, c.a_max, c.na, c.pexp)

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
                      joinpath(@__DIR__, "unemployment_core.jl"),
                 joinpath(@__DIR__, "agency_shock.jl"),
                 joinpath(@__DIR__, "egm_core.jl"),
                 joinpath(@__DIR__, "egm2_core.jl"),
                 joinpath(@__DIR__, "reporting_core.jl")]
const SOLVER_DIGEST = bytes2hex(sha1(join(read(f, String) for f in SOLVER_FILES)))

"The household part and the threshold part of a family's cache key."
function family_cache_key(c::SAGEConfig, cell, thr)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    _, bw = betas_by_cell(c)
    hh = bytes2hex(sha1(string(SOLVER_DIGEST, "|", repr(params_of(cT, cell)), "|",
                               repr(c.ugrid), "|", repr(c.theta), "|", repr(bw[cell.gi]))))
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
    # the job's effort levels where they are given (the floor, the transitory part, the proportional
    # tax), as `_solve` does: a caller that builds families itself (the calibration's scans) reached
    # the household problem without them until 2026-10-06
    c = floor_effort(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    _, bw = betas_by_cell(c)
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
        f = build_family_ag(params_of(cT, cell), c.ugrid, c.theta; weights = bw[cell.gi], thresholds = thr)
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
    c.E && return solve_economy_places(c; thresholds = thresholds, cache = cache)
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
    c = floor_effort(c)
    cs = cells_of(c); bs, bw = betas_by_cell(c)
    T = c.lumptax + ui_tax_of(c)
    cfgT = SAGEConfig(c; lumptax = T)
    agrid = liquid_grid_of(c)

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
        pooled = [collapse_all(fams[g], node_weights(c, cs[g].B, arg)) for g in 1:2]
    else
        # One household problem per (cell, discount type), over the workers
        # when there are any. Same problems, same order, same mixing as the
        # serial version; only where they run changes.
        jobs = [(g, p0) for g in 1:2 for p0 in params_of(cfgT, cs[g])]
        solve0 = job -> begin
            # the summaries read the SAME parameters the household was solved with:
            # passing the unmodified ones (social_strength at its default of one)
            # booked a belonging value with S off (audit 2026-10-02)
            p = update(job[2]; social_strength = 0.0)
            s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
            merge(cell_summary(p, s; thresholds = thr), agency_summary(p, s))
        end
        out = nworkers() > 1 ? pmap(solve0, jobs) : map(solve0, jobs)
        nb = length(bw[1])
        pooled = [collapse_all(out[(g-1)*nb+1:g*nb], bw[g]) for g in 1:2]
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
    emp  = employed_states(params_of(cfgT, cs[1])[1])
    # Agency: alpha times one minus the expected share of next year's
    # consumption lost to unemployment (agency_shock.jl). The same with income
    # alone leaves out households' own savings; the drop is at the moment of
    # job loss, for the employed.
    pbar = [sum(pooled[g].pmass) / sum(pooled[g].mass) for g in 1:2]
    pyb  = [sum(pooled[g].pinc) / sum(pooled[g].mass) for g in 1:2]
    Acell = Tuple(cs[g].α * (1 - pbar[g]) for g in 1:2)
    mE = sum(cs[g].share * sum(pooled[g].mass[emp]) for g in 1:2)
    # Protection if the shock hits, reported beside A: alpha times one minus
    # the drop in consumption on job loss, per cell, among the employed. A
    # averages the drop over the chance of losing the job, which is small, so
    # A is mostly alpha. This one is not averaged over that chance.
    dcell = [(m = sum(pooled[g].mass[emp]); m <= 0 ? 0.0 : sum(pooled[g].dmass[emp]) / m) for g in 1:2]
    Acond = Tuple(cs[g].α * (1 - dcell[g]) for g in 1:2)
    base = (config = c, rate = rate, slope = slope, median_income = med,
            median_model = med_model, mean_income = ymean,
            mean_labour_income = minc,
            # the means-tested floor: what it pays out per head, and what the budget is off by
            # (the outlay less the tax raised for it; zero without a floor)
            floor_outlay = sum(cs[g].share * pooled[g].fout for g in 1:2),
            budget_gap = sum(cs[g].share * pooled[g].fout for g in 1:2) - floor_tax_of(c),
            hand_to_mouth = share_below_interp(agrid, Wtot, (4 / 52) * minc),
            wealth_p50 = cdf_quantile(agrid, Wtot, 0.5),
            wealth_p90 = cdf_quantile(agrid, Wtot, 0.9),
            # effort of the EMPLOYED, averaged over employed households: the HETUS
            # target is the paid share of time of employed people. Until 2026-09-30
            # this was divided by everyone (the unemployed counting as zero), so
            # every calibration had fitted per-person effort to an employed-person
            # target; all were redone.
            # over those who work: a household with a job that works no hours (it chooses its hours and lives on the
            # minimum income) is out of work, and is reported as `idle` (2026-10-12)
            mean_effort_employed = sum(cs[g].share * pooled[g].eff_E for g in 1:2) /
                                   sum(cs[g].share * (sum(pooled[g].mass[emp]) - pooled[g].idle_E) for g in 1:2),
            idle = sum(cs[g].share * pooled[g].idle_E for g in 1:2),
            unemployment = sum(cs[g].share * sum(pooled[g].mass[.!emp]) for g in 1:2),
            partbase = sum(cs[g].share * pooled[g].pbase for g in 1:2),
            rate_E = sum(cs[g].share * sum(pooled[g].part[emp]) for g in 1:2) /
                     sum(cs[g].share * sum(pooled[g].mass[emp]) for g in 1:2),
            rate_U = (m = sum(cs[g].share * sum(pooled[g].mass[.!emp]) for g in 1:2);
                      m <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].part[.!emp]) for g in 1:2) / m),
            A = sum(cs[g].share * Acell[g] for g in 1:2), A_cell = Acell,
            # among the employed, so cells weigh by their employed mass (as consumption_drop does)
            A_cond = mE <= 0 ? sum(cs[g].share * Acond[g] for g in 1:2) :
                     sum(cs[g].share * sum(pooled[g].mass[emp]) * Acond[g] for g in 1:2) / mE, A_cond_cell = Acond,
            shock_loss = sum(cs[g].share * pbar[g] for g in 1:2),
            shock_loss_income = sum(cs[g].share * pyb[g] for g in 1:2),
            A_institutions = sum(cs[g].share * cs[g].α * (1 - pyb[g]) for g in 1:2),
            consumption_drop = mE <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].dmass[emp]) for g in 1:2) / mE,
            hand_to_mouth_kvw = sum(cs[g].share * sum(pooled[g].hmass) for g in 1:2) /
                                sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            hand_to_mouth_cell = Tuple(sum(pooled[g].hmass) / sum(pooled[g].mass) for g in 1:2),
            # the wealthy hand-to-mouth: low liquid wealth, some illiquid (zero without the switch)
            wealthy_htm = sum(cs[g].share * sum(pooled[g].whmass) for g in 1:2) /
                          sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            # the reporting layer (reporting_core.jl): value and its parts, per head,
            # overall and by cell; propensities out of a one-month windfall
            welfare = (m_ = sum(cs[g].share * sum(pooled[g].mass) for g in 1:2);
                       (V = sum(cs[g].share * sum(pooled[g].vmass) for g in 1:2) / m_,
                        Vc = sum(cs[g].share * sum(pooled[g].vcmass) for g in 1:2) / m_,
                        Ve = sum(cs[g].share * sum(pooled[g].vemass) for g in 1:2) / m_,
                        Vb = sum(cs[g].share * sum(pooled[g].vbmass) for g in 1:2) / m_,
                        # A's parts (2026-10-16): dread where it enters choices, the cost of job search
                        Vd = sum(cs[g].share * sum(pooled[g].vdmass) for g in 1:2) / m_,
                        Vk = sum(cs[g].share * sum(pooled[g].vkmass) for g in 1:2) / m_,
                        cell = Tuple((V = sum(pooled[g].vmass) / sum(pooled[g].mass), Vc = sum(pooled[g].vcmass) / sum(pooled[g].mass),
                                      Ve = sum(pooled[g].vemass) / sum(pooled[g].mass), Vb = sum(pooled[g].vbmass) / sum(pooled[g].mass))
                                     for g in 1:2),
                        # by employment status now (employed / unemployed states)
                        status = Tuple((mk = (st == 1 ? emp : .!emp);
                                        ms = sum(cs[g].share * sum(pooled[g].mass[mk]) for g in 1:2);
                                        (V = sum(cs[g].share * sum(pooled[g].vmass[mk]) for g in 1:2) / ms,
                                         Vc = sum(cs[g].share * sum(pooled[g].vcmass[mk]) for g in 1:2) / ms))
                                       for st in 1:2))),
            mps = sum(cs[g].share * sum(pooled[g].mpsmass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            # mean consumption per head, overall, by cell and by employment status (the footprint scales with it)
            consumption = sum(cs[g].share * sum(pooled[g].cmass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            consumption_cell = Tuple(sum(pooled[g].cmass) / sum(pooled[g].mass) for g in 1:2),
            consumption_status = Tuple((mk = (st == 1 ? emp : .!emp);
                                        sum(cs[g].share * sum(pooled[g].cmass[mk]) for g in 1:2) /
                                        sum(cs[g].share * sum(pooled[g].mass[mk]) for g in 1:2)) for st in 1:2),
            mpe = sum(cs[g].share * sum(pooled[g].mpemass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            mpp = sum(cs[g].share * sum(pooled[g].mppmass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            mpc_wealthy = (h = sum(cs[g].share * sum(pooled[g].whmass) for g in 1:2);
                           h <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].mpcwmass) for g in 1:2) / h),
            # untargeted checks and the other agency parts (agency_shock.jl)
            mpc = sum(cs[g].share * sum(pooled[g].mpcmass) for g in 1:2) /
                  sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            # stage 1d (V3_START.md section 129): the MPC over twelve months (the HFCS question; the within-period MPC
            # at an annual period), and the fall on job loss as Kolsrud et al. (2018) measure it: the mean drop over the
            # first 20 weeks out of work among those still out of work, survival-weighted (a quarter is 13 weeks), against
            # consumption in the last period in work; and its two quarters (NaN at an annual period)
            mpc12 = c.period == 1 ? sum(cs[g].share * sum(pooled[g].mpcmass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2) :
                    sum(cs[g].share * sum(pooled[g].mpc12mass) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            fall_kolsrud = (K = sum(cs[g].share .* pooled[g].kolmass[1:5] for g in 1:2);
                            K[1] <= 0 || K[4] <= 0 ? NaN : (c0 = K[2] / K[1]; S2 = K[4] / K[1];
                                                           1 - (13 * K[3] / K[1] + 7 * S2 * K[5] / K[4]) / ((13 + 7 * S2) * c0))),
            fall_q1 = (K = sum(cs[g].share .* pooled[g].kolmass[1:5] for g in 1:2); K[1] <= 0 ? NaN : 1 - K[3] / K[2]),
            fall_q2 = (K = sum(cs[g].share .* pooled[g].kolmass[1:5] for g in 1:2); K[4] <= 0 ? NaN : 1 - (K[5] / K[4]) / (K[2] / K[1])),
            # the job losers' time out of work (agency_shock.jl, part 4): the share still out of work by quarter since job
            # loss, and the mean time out of work in months, capped at 36 months (12 quarters, as Schmieder, von Wachter
            # and Bender 2012) and at 48 (Scrutinio 2019)
            nonemp = (hasproperty(pooled[1], :nonempmass) && c.period > 1 && sum(pooled[1].nonempmass) > 0) ?
                     (M = sum(cs[g].share .* pooled[g].nonempmass for g in 1:2); S_ = M[1:min(40, length(M))] ./ M[1];
                      (surv = S_, months36 = 12.0 / c.period * sum(S_[1:min(c.period * 3, length(S_))]),
                       months48 = 12.0 / c.period * sum(S_[1:min(c.period * 4, length(S_))]))) :
                     (surv = Float64[], months36 = NaN, months48 = NaN),
            # the job losers' cohort with a lump sum at the start of the spell (agency_shock.jl, part 3): its chance of
            # finding work over the entitled quarters, exits over the stock, without and with the lump sum, and by quarter
            lump_cohort = (hasproperty(pooled[1], :lumpmass) && c.period > 1 && 4 * c.nU <= length(pooled[1].lumpmass)) ?
                          (L = sum(cs[g].share .* pooled[g].lumpmass for g in 1:2); n = c.nU;
                           (base = sum(L[n+1:2n]) / max(sum(L[1:n]), 1e-300), lump = sum(L[3n+1:4n]) / max(sum(L[2n+1:3n]), 1e-300),
                            base_q = L[n+1:2n] ./ max.(L[1:n], 1e-300), lump_q = L[3n+1:4n] ./ max.(L[2n+1:3n], 1e-300))) :
                          (base = NaN, lump = NaN, base_q = Float64[], lump_q = Float64[]),
            mpc_htm = (h = sum(cs[g].share * sum(pooled[g].hmass) for g in 1:2);
                       h <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].mpchmass) for g in 1:2) / h),
            room = sum(cs[g].share * sum(pooled[g].rmass) for g in 1:2) /
                   sum(cs[g].share * sum(pooled[g].mass) for g in 1:2),
            dread_cost_E = mE <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].xmass[emp]) for g in 1:2) / mE,
            # job search (A): the cost as a share of the year's consumption among those out of work, and the
            # chance of finding work chosen, in the first year out of work and beyond (U, E, L blocks; NaN off)
            search_cost_out = (mU = sum(cs[g].share * sum(pooled[g].mass[.!emp]) for g in 1:2);
                               mU <= 0 ? 0.0 : sum(cs[g].share * sum(pooled[g].kmass[.!emp]) for g in 1:2) / mU),
            search_UL = (stv_ = stypes(params_of(cfgT, cs[1])[1]); (c.A && c.search && any(stv_ .=== :L)) ?
                         Tuple((r_ = findall(stv_ .=== (blk == 1 ? :U : :L));
                                sum(cs[g].share * sum(pooled[g].smass[r_]) for g in 1:2) / sum(cs[g].share * sum(pooled[g].mass[r_]) for g in 1:2)) for blk in 1:2) :
                         (NaN, NaN)),
            # stage 1d: the chance of finding work chosen, by cell and period of the spell (U_1 .. U_nU, then L); empty without search
            search_exit = (c.A && c.search) ? Tuple((pg = params_of(cfgT, cs[g])[1]; stg = stypes(pg); dg = isempty(pg.dur) ? zeros(Int, length(stg)) : pg.dur;
                                                    vcat([(r_ = findall((stg .=== :U) .& ((dg .== d) .| (dg .== NONENT + d))); sum(pooled[g].smass[r_]) / max(sum(pooled[g].mass[r_]), 1e-300)) for d in 1:max(c.nU, 1)],
                                                         [(r_ = findall(stg .=== :L); sum(pooled[g].smass[r_]) / max(sum(pooled[g].mass[r_]), 1e-300))])) for g in 1:2) : (Float64[], Float64[]),
            # the mass in each period of the spell (U_1 .. U_nU, then L), by cell, for exits by duration group
            search_mass = (c.A && c.search) ? Tuple((pg = params_of(cfgT, cs[g])[1]; stg = stypes(pg); dg = isempty(pg.dur) ? zeros(Int, length(stg)) : pg.dur;
                                                    vcat([sum(pooled[g].mass[findall((stg .=== :U) .& ((dg .== d) .| (dg .== NONENT + d)))]) for d in 1:max(c.nU, 1)],
                                                         [sum(pooled[g].mass[findall(stg .=== :L)])])) for g in 1:2) : (Float64[], Float64[]),
            agrid = agrid, Wtot = Wtot, pooled = pooled, employed = emp, lumptax = T,
            kgrid = c.illiquid ? illiquid_grid(c.k_max, c.nk, c.pexp, c.k_mid) : [0.0],
            Ktot = sum(cs[g].share .* vec(sum(pooled[g].K, dims = 1)) for g in 1:2),
            # net wealth, liquid plus illiquid, with the illiquid asset (cumulative on NWGRID)
            Ntot = sum(cs[g].share .* vec(sum(pooled[g].N, dims = 1)) for g in 1:2))
    thr === nothing && return merge(base, (asset_poor_by_quintile = Float64[],
                                           quintile_mass = Float64[],
                                           A_income_only = NaN, hardship_cell = (),
                                           A_hardship = NaN, hardship = NaN, income_poor = NaN,
                                           asset_poor = NaN, both = NaN, vulnerable = NaN,
                                           A_hardship_cell = (NaN, NaN), alphabar = NaN,
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
        ast = sum(share_below_interp(agrid, view(P.W, sdx, :), abar * (1 + c.ctax)) for sdx in 1:nz)   # real wealth below the threshold
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
                 A_hardship = sum(cs[g].share * Ag[g] for g in 1:2), A_hardship_cell = Tuple(Ag),
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
group participation targets (or, with `aggregate`, against overall
participation alone), and the equilibrium there with its map slope. Equilibria
whose multiplier exceeds `max_mult` are not candidates. The
kappa search is global at every sigma, never a window around a coarse winner,
because a window is what produced a headline this project had to retract.
"""
function scan_technology(c::SAGEConfig, fams, sigmas, kappas;
                         targets = (0.25, 0.45), nq = c.nq, xgrid = 0.0:0.02:60.0,
                         selected_only = false, aggregate = nothing, max_mult = Inf)
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
            # every stable crossing, from the lowest rate up; with
            # `selected_only` just the highest, the one `solve_economy` selects
            cross = Tuple{Float64,Float64}[]
            for i in 1:400
                d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
                (d1 == 0 || sign(d1) != sign(d2)) || continue
                sl = (o[i+1] - o[i]) / (g[i+1] - g[i]); sl < 1 || continue
                push!(cross, (g[i] + d1 / (d1 - d2) * (g[i+1] - g[i]), sl))
            end
            selected_only && length(cross) > 1 && (cross = cross[end:end])
            for (rs, sl) in cross
                1 / (1 - sl) > max_mult && continue
                _, lo, hi = f(rs)
                # `aggregate`: fit overall participation only, for a
                # configuration that does not own the gap between the cells
                L = aggregate === nothing ? (lo - targets[1])^2 + (hi - targets[2])^2 :
                    (cs[1].share * lo + cs[2].share * hi - aggregate)^2
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

"The time participation takes, as a share of the employed's committed time: the country's own diary measure for formal volunteering, the activity the participation targets count (data/timeuse/qbar_from_data.csv, definition A)."
function measured_qbar(code)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "timeuse", "qbar_from_data.csv"))
        f = split(ln, r",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)")          # commas inside quoted fields are not separators
        length(f) >= 6 && f[1] == "qbar_A_AC41" && f[2] == code && f[5] == "2010" && return parse(Float64, f[6])
    end
    error("no measured time cost of participation for $code")
end

"A value of data/manual_inputs.csv."
function manual_input(code, field)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "manual_inputs.csv"))
        f = split(ln, ","); length(f) >= 3 && f[1] == code && f[2] == field && return parse(Float64, f[3])
    end
    error("no $field for $code in data/manual_inputs.csv")
end

"""
    country_config(code; kwargs...)

A country's configuration: its labour market, benefit, education gradients,
benefit reference and participation rule from the data table, then its effort
scale, discount spread and social technology from `calibration_country_<code>.txt`
from the configuration's calibration file. Keyword arguments override both. The
dimension switches S and A are left at their defaults and set by the caller.

A missing calibration file is an ERROR: without it the configuration would run
on the engine's defaults (phi 14, sigma 0.4, kappa 10, chi0 0.05) and return a
plausible-looking economy that was never calibrated (audit 2026-10-02). A
calibration script that is about to produce the file passes `missing_ok = true`.
A file marked not calibrated (`.not_calibrated.txt` beside it, newer than it) is
refused the same way.
"""
function country_config(code::AbstractString; config::AbstractString = "GSA", missing_ok::Bool = false, v3::Union{Bool,Symbol} = false, kwargs...)
    r = country_rows()[code]
    num(k) = parse(Float64, r[k])
    al, ah = num("alpha_low"), num("alpha_high")
    sh = haskey(r, "share_high") ? num("share_high") : 0.5
    # With agency off both cells take the country's population-weighted mean
    # alpha (one, by the table's normalisation).
    d = Dict{Symbol,Any}(:unemployment => true, :share => (1 - sh, sh),
                         :alpha => (al, ah), :alpha_off => round((1 - sh) * al + sh * ah; digits = 6),
                         :B => (num("B_low"), num("B_high")),
                         :delta => (num("delta_low"), num("delta_high")),
                         :f_find => num("f_find"), :rr => num("rr"), :e_ref => num("e_ref"),
                         :unemployed_ratio => num("ratio"), :ratio_target => num("ratio"))
    for (col, key) in (("median_to_mean", :median_to_mean), ("rho", :rho), ("eta", :eta_z), ("dread", :dread))
        haskey(r, col) && r[col] != "NA" && (d[key] = num(col))
    end
    # Each configuration has its own calibration: G+S+A in calibration_country_<code>.txt,
    # the others in calibration_country_<code>_<config>.txt (config G, GA or GS).
    # With the illiquid asset: calibration_country_<code>_<config>_I.txt for every configuration.
    illq = haskey(kwargs, :illiquid) && kwargs[:illiquid] == true
    cal = illq ? joinpath(@__DIR__, "calibration_country_$(code)_$(config)_I.txt") :
          joinpath(@__DIR__, config == "GSA" ? "calibration_country_$(code).txt" :
                                               "calibration_country_$(code)_$(config).txt")
    # VERSION 3 (V3_START.md, section 13), beside version 2 until it is complete:
    # effort set by the job; the replacement rate at the level of the household, of
    # which only the state-paid part is taxed; patience spread uniformly; its own
    # calibration files, calibration_v3_<code>_<config>[_I].txt. Nothing of version 2
    # changes while v3 is false.
    # v3 = :floor: the version 3 economy with the means-tested floor in the base (V3_START.md,
    # section 22); its own files, calibration_v3f_<code>_<config>.txt, which carry the floor's level.
    # v3 = :edu or :floor_edu: patience by education as well (files calibration_v3e_*, calibration_v3fe_*).
    if v3 !== false
        d[:ysmooth] = 9
        d[:effort_mode] = :job
        d[:rr] = num("rr_household"); d[:rr_public] = num("rr_public")
        d[:qbar] = 0.04                       # measured (data/timeuse), not the 0.10 assumed before
        # v3 = :trans, :floor_trans, :edu_trans or :floor_edu_trans: the same regimes with the transitory
        # part (its size from data/manual_inputs.csv, field sd_eps) and the proportional tax
        # (V3_START.md, section 29); files with a t added to the tag, calibration_v3fet_* for the base.
        vs = v3 === true ? "" : string(v3)
        vs in ("", "floor", "edu", "floor_edu", "trans", "floor_trans", "edu_trans", "floor_edu_trans", "v4", "v5", "v5o", "v5m") || error("unknown version 3 regime $v3")
        vmin = vs == "v5m"                               # the state out of work with one measured minimum income (below)
        vout = vs == "v5o" || vmin                       # version 5 with the state out of work (below)
        v5 = vs == "v5" || vout; v4 = vs == "v4" || v5   # version 5 is version 4 with the corrections below
        vfl = v4 || occursin("floor", vs); ved = v4 || occursin("edu", vs); vtr = v4 || occursin("trans", vs)
        vtag = vmin ? "v5m" : vout ? "v5o" : v5 ? "v5" : v4 ? "v4" : "v3" * (vfl ? "f" : "") * (ved ? "e" : "") * (vtr ? "t" : "")
        if vtr
            d[:sd_eps] = manual_input(code, "sd_eps"); d[:tax_mode] = :prop
        end
        # v3 = :v4 (2026-10-07; V3_START.md, sections 34 to 36): the floor, patience by education, the
        # transitory part and the proportional tax, with every parameter under the rule of section 34.
        # The income process by education cell as published (Ampudia, Cooper, Le Blanc and Zhu 2024,
        # Table 16; data/manual_inputs.csv), nothing of it fitted; the time cost of participation the
        # country's own measured one; the weight on social cohesion normalised to one. Files calibration_v4_*.
        if v4
            d[:rho_cell] = (manual_input(code, "rho_low"), manual_input(code, "rho_high"))
            # WHICH VARIANCE IS WHICH (2026-10-08, V3_START.md sections 42 and 43). Until then the source's
            # two variance columns were entered the other way round: the larger as the persistent
            # innovation. data/manual_inputs.csv now has them in the order of the source's equation.
            # Version 4's files were fitted on the old reading and version 4 keeps it, so that they
            # reproduce; version 5 uses the corrected one.
            pk, tk = v5 ? ("var_persistent", "var_transitory") : ("var_transitory", "var_persistent")
            d[:eta_cell] = (sqrt(manual_input(code, pk * "_low")), sqrt(manual_input(code, pk * "_high")))
            d[:sd_eps_cell] = (sqrt(manual_input(code, tk * "_low")), sqrt(manual_input(code, tk * "_high")))
            d[:qbar] = measured_qbar(code)
            d[:Lambda] = 1.0
            d[:ref_prop] = true
            v5 && (d[:premium_base] = true)
            # The return on the one asset is the measured real return on households' overnight deposits
            # (decided by the user on 2026-10-09; V3_START.md sections 57 and 62), not the engine's 2%.
            v5 && (d[:R_one] = manual_input(code, "r_deposits_real"))
            if v5
                # MEASURED LABOUR INPUTS (2026-10-08; V3_START.md section 52). The yearly rate of leaving
                # unemployment for work is the Labour Force Survey's own year-on-year transition (Eurostat
                # lfsi_long_a, 2023, among those still in the labour force), not 1 less the long-term
                # share of the unemployed; the separation rates follow from the unemployment rates by
                # education as before, u f / (1 - u). The pay ratio between the education groups is that
                # of the Structure of Earnings Survey 2022 (the country table's alpha_ratio_ses2022),
                # the two groups' pay averaging to one.
                fm = manual_input(code, "f_find_lfs")
                d[:f_find] = fm
                d[:delta] = (num("u_low") * fm / (1 - num("u_low")), num("u_high") * fm / (1 - num("u_high")))
                ratio = num("alpha_ratio_ses2022")
                ah5 = 1 / ((1 - sh) * ratio + sh)
                d[:alpha] = (ratio * ah5, ah5)
            end
            if vout
                # THE STATE OUT OF WORK (v3 = :v5o, 2026-10-10; V3_START.md section 69). The engine's
                # long-term state: the first year out of work is insured and ends in work at the measured
                # rate or in the state, which pays the official minimum income (OECD TaxBEN, with housing
                # benefit, over net income at the average wage: a flat amount, the same for every type)
                # and ends in work with a yearly probability. The rates of job loss are those of version 5.
                # The yearly exit is fitted, by education, to the official share of people aged 18 to 64
                # in households with very low work intensity (Eurostat ilc_lvhl14n, 2023), in closed
                # form: with s the share out of work, s / (1 - s) = delta + delta (1 - f) / f_long.
                # The measured exit rates are kept as the test (data/validation/out_of_work.csv).
                fl_ = ntuple(2) do g
                    s_ = manual_input(code, g == 1 ? "jobless_low" : "jobless_high"); dl = d[:delta][g]
                    s_ / (1 - s_) > dl || error("$code: the official share out of work ($s_) is below what the first year alone gives; no long-term state fits it")
                    v = dl * (1 - d[:f_find]) / (s_ / (1 - s_) - dl)
                    v <= 1 || error("$code: the official share out of work ($s_) asks for a yearly exit above one in cell $g")
                    v
                end
                d[:f_long] = fl_
                # The insured year is the first: its own replacement rate (the mean of months 1 to 12 of
                # the OECD's profile, same households and weights), not the average over a five-year
                # spell, which holds the assistance of the later years a second time.
                d[:rr] = manual_input(code, "rr_household_first_year"); d[:rr_public] = manual_input(code, "rr_public_first_year")
                # ONE MEASURED MINIMUM INCOME (v3 = :v5m, 2026-10-10; V3_START.md section 72). In v5o the
                # state pays the official minimum income and a means-tested floor is fitted beside it: the
                # same institution twice. In v5m there is one: the floor is the official minimum income
                # (the calibration sets it at the OECD's share of the median), those out of work beyond a
                # year receive its level (assist_long left unset: assist_of gives the floor's level), and
                # everyone else is topped up to it. No floor is fitted and the median is a test.
                vmin || (d[:assist_long] = manual_input(code, "min_income_net_aw") * d[:e_ref])
                # THE ELASTICITY OF HOURS (decided by the user on 2026-10-11; V3_START.md section 79): the
                # Frisch elasticity of the European lottery evidence, 0.14 (Cesarini, Lindqvist, Notowidigdo
                # and Östling 2017, Table 5), in place of the 0.5 of the micro consensus. psi is its inverse.
                # A transfer from Sweden to the three countries, flagged as such in data/manual_inputs.csv.
                vmin && (d[:psi] = 1 / manual_input(code, "frisch_elasticity"))
                # A: who chooses their hours, by education (Eurostat lfso_19fxwt01, the person decides fully)
                vmin && (d[:control_share] = (manual_input(code, "control_hours_low"), manual_input(code, "control_hours_high")))
                if vmin
                    # THE INCOME OF HOUSEHOLDS IN THE STATE (2026-10-12; V3_START.md section 90): a share of what
                    # the household would earn, the measured ratio of the median income of people in jobless
                    # households to that of the rest (Eurostat ilc_di07), so that it is spread as earnings are.
                    # It is the household's own income; the state's part is what the floor tops up.
                    d[:rr_long] = manual_input(code, "jobless_income_over_rest"); d[:assist_long] = 0.0; d[:long_public_share] = 0.0
                    # and the published income process net of the job loss the model has as states of its own
                    tmp = SAGEConfig(; d...)
                    pr = ntuple(g -> purged_income_risk(tmp.nz, tmp.n_eps, d[:rho_cell][g], d[:eta_cell][g], d[:sd_eps_cell][g], d[:delta][g], d[:f_find], d[:f_long][g], d[:rr], d[:rr_long]), 2)
                    d[:eta_cell] = (pr[1][1], pr[2][1]); d[:sd_eps_cell] = (pr[1][2], pr[2][2])
                end
            end
        end
        # Version 5: the pay premium is in the base and dread of job loss is measured without entering
        # choices (the working default from 2026-10-09 evening, V3_START.md section 64, pending the
        # user's confirmation), so A adds no parameter and a configuration with A reads the file of
        # the same one without it. SAGE_DREAD_CHOICE=1 gives the variant tested in section 55: dread
        # in choices, and a calibration of its own for a configuration with A.
        v5dread = v5 && get(ENV, "SAGE_DREAD_CHOICE", "0") == "1"
        v5dread && (d[:dread_mode] = :behaviour)
        cal = joinpath(@__DIR__, "calibration_$(vtag)_$(code)_$((v5 && !v5dread) ? replace(config, "A" => "") : config)" * (illq ? "_I" : "") * ".txt")
        # With households who choose their hours (v5m) A adds no parameter to G, so G+A reads G's file; but it
        # moves participation where S is on (those who choose make time for it), so a configuration with S and
        # A has a file of its own once it is calibrated, and reads the one without A until then (2026-10-12).
        if vmin && occursin('A', config)
            own = joinpath(@__DIR__, "calibration_$(vtag)_$(code)_$(config)" * (illq ? "_I" : "") * ".txt")
            # with dread in choices its own file (`_D`, phase 1 of ROADMAP.md) where it exists; until then the
            # configuration's file without dread, or the one without A
            ownd = replace(own, r"\.txt$" => "_D.txt")
            base_ = joinpath(@__DIR__, "calibration_$(vtag)_$(code)_$(replace(config, "A" => ""))" * (illq ? "_I" : "") * ".txt")
            cal = (v5dread && isfile(ownd)) ? ownd : isfile(own) ? own : base_
        end
        # JOB SEARCH with A and dread in choices (phase 1 of ROADMAP.md, V3_START.md sections 105 and 107): the
        # cost levels fitted by probe_search.jl, in a file of their own so that a calibration never overwrites
        # them. With the file, search is on (the keyword `search = false` turns it off); without it, off.
        if vmin && v5dread && occursin('A', config)
            sf = joinpath(@__DIR__, "search_$(vtag)_$(code)_$(config).txt")
            if isfile(sf)
                for ln in eachline(sf)
                    t = strip(ln); (isempty(t) || startswith(t, "#")) && continue
                    k, v = strip.(split(t, "=")); x = parse.(Float64, split(v))
                    k in ("search_kU", "search_kL") ? (d[Symbol(k)] = (x[1], x[2])) :
                        k == "search_gamma" ? (d[:search_gamma] = x[1]) : error("unknown key $k in $(basename(sf))")
                end
                d[:search] = true
            end
        end
        # THE UNEMPLOYED'S OWN PARTICIPATION (2026-10-19, V3_START.md section 111; the methods review of 18 October):
        # in place of the measured ratio imposed when results are added up, the unemployed choose like everyone
        # else, with a belonging scale of their own (`belong_u`) fitted by probe_unemp_rule.jl so that their chosen
        # rate is the measured ratio times the employed rate. In a file of its own, read for every configuration
        # with S; without it, the ratio is imposed as before.
        if vmin && occursin('S', config)
            uf = joinpath(@__DIR__, "unemp_$(vtag)_$(code)_$(config)" * (v5dread && occursin('A', config) ? "_D" : "") * ".txt")
            if isfile(uf)
                for ln in eachline(uf)
                    t = strip(ln); (isempty(t) || startswith(t, "#")) && continue
                    k, v = strip.(split(t, "="))
                    k == "belong_u" ? (d[:belong_u] = parse(Float64, v)) : error("unknown key $k in $(basename(uf))")
                end
                d[:unemployed_ratio] = nothing
            end
        end
        # In the floor regime places differ by the household's income per head (:conversion_hh): what
        # is not unemployment in a low employment rate stays in the place's income, so a poor place is
        # poor against the national floor and not only riskier (V3_START.md, sections 21 and 22).
        vfl && (d[:e_channels] = (:composition, :access, :conversion_hh, :commute, :community))
        # With the state out of work the places have it too, each at its own official share of jobless households.
        # The conversion channel is not in the base (2026-10-13, V3_START.md section 97): restated net of what
        # the model's place already gives (`:conversion_net`), it still breaks the order of regional poverty in
        # France (an average applied to everyone). It stays an option, documented.
        vmin && (d[:e_channels] = (:composition, :access, :out_of_work, :commute, :community))
    end
    marker = replace(cal, r"\.txt$" => ".not_calibrated.txt")
    stale = isfile(marker) && (!isfile(cal) || mtime(marker) > mtime(cal))
    if isfile(cal) && !(stale && !missing_ok)
        ec = Dict{Int,Vector{Float64}}()
        for ln in eachline(cal)
            t = strip(ln); (isempty(t) || startswith(t, "#")) && continue
            k, v = strip.(split(t, "="))
            if startswith(k, "effort_cell")           # effort levels by state, one line per education cell (two assets, version 3)
                ec[parse(Int, k[end:end])] = parse.(Float64, split(v))
            elseif k in ("perm_f", "perm_w")          # the permanent types and their weights (version 5)
                d[Symbol(k)] = parse.(Float64, split(v))
            elseif k == "beta_gap"                  # patience of the lower-education cell below the other's
                d[:beta_cell] = (-parse(Float64, v), 0.0)
            else
                d[Symbol(k)] = parse(Float64, v)
            end
        end
        isempty(ec) || (d[:effort_by_cell] = (ec[1], ec[2]))
    elseif !missing_ok
        error("no calibration for $code $config" * (illq ? " on two assets" : "") * ": " * basename(cal) *
              (stale ? " is marked not calibrated" : " does not exist") *
              ". Calibrate it first, or pass missing_ok = true to run on the engine defaults knowingly.")
    end
    d[:country] = code
    occursin('E', config) && (d[:E] = true)       # GE, GAE, GSE, GSAE
    for (k, v) in kwargs
        d[k] = v
    end
    # the floor's tax at the outlay of the economy with S (`floor_tax_S`, written by a calibration with S, 2026-10-19,
    # V3_START.md section 111): used where S is on and no tax is given; a calibration passes NaN to fit without it
    fts = pop!(d, :floor_tax_S, NaN)
    (get(d, :S, false) === true && !isnan(fts) && isnan(get(d, :floor_tax_given, NaN))) && (d[:floor_tax_given] = fts)
    # one measured minimum income (v3 = :v5m): assistance in the state out of work is the floor's level,
    # given outright so that it stays when a step of the solution switches the floor off
    (v3 !== false && v3 !== true && string(v3) == "v5m" && !haskey(d, :assist_long) && get(d, :cfloor, 0.0) > 0) && (d[:assist_long] = d[:cfloor])
    # ... and the state's part of that income is the statutory minimum, the floor's level (assist_public)
    (v3 !== false && v3 !== true && string(v3) == "v5m" && !haskey(d, :assist_public) && get(d, :cfloor, 0.0) > 0) && (d[:assist_public] = d[:cfloor])
    SAGEConfig(; d...)
end

"""
The base (2026-10-07): version 3 with the means-tested floor, patience by education, the transitory
income shock and the proportional tax, files calibration_v3fet_* (V3_START.md, sections 29 to 33).
France and Germany in the eight configurations; Italy in six, its two with S and places still to
come. The base of 2026-10-05 is the same without the last two, `:floor_edu`, files calibration_v3fe_*.
"""
const BASE_REGIME = :floor_edu_trans
"`country_config` in the base regime."
base_config(code::AbstractString; kwargs...) = country_config(code; v3 = BASE_REGIME, kwargs...)

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
    @printf("  participation %.6f | agency %.6f (from income alone %.6f) | expected loss %.6f | drop on job loss %.6f\n",
            r.rate, r.A, r.A_institutions, r.shock_loss, r.consumption_drop)
    @printf("  hardship %.6f (income %.6f, asset %.6f) | agency on the old hardship reading %.6f\n",
            r.hardship, r.income_poor, r.asset_poor, r.A_hardship)
    @printf("  hand-to-mouth %.6f | mean labour income %.6f | median disposable %.6f | effort %.6f\n",
            r.hand_to_mouth, r.mean_labour_income, r.median_income, r.mean_effort_employed)
end


# -------------------------------------------------------- reporting layer --
"""
    welfare_ce(rB, rP; γ)

Consumption-equivalent welfare of economy `rP` against the baseline `rB`, both
results of `solve_economy`: the share omega of consumption, in every period and
state, that makes the baseline's expected value equal the policy's, V_B with
consumption scaled by (1 + omega) = V_P, using that the consumption part of
the value scales by (1 + omega)^(1 - gamma). Steady state to steady state: the
cost of the transition is not in it (that needs the transition solver, 7b).
Returns the total, the part carried by each component of the value
(consumption, effort, belonging, the remainder) as each component's change
alone would give, and the same by education cell and by employment status
today (employed, unemployed).
"""
function welfare_ce(rB, rP; γ = 2.0)
    ce(dW, Vc) = (x = 1 + dW / Vc; x > 0 ? x^(1 / (1 - γ)) - 1 : NaN)
    wB, wP = rB.welfare, rP.welfare
    tot = ce(wP.V - wB.V, wB.Vc)
    parts = (consumption = ce(wP.Vc - wB.Vc, wB.Vc), effort = ce(wP.Ve - wB.Ve, wB.Vc),
             belonging = ce(wP.Vb - wB.Vb, wB.Vc), dread = ce(wP.Vd - wB.Vd, wB.Vc), search = ce(wP.Vk - wB.Vk, wB.Vc),
             choice_and_rest = ce((wP.V - wP.Vc - wP.Ve - wP.Vb - wP.Vd - wP.Vk) - (wB.V - wB.Vc - wB.Ve - wB.Vb - wB.Vd - wB.Vk), wB.Vc))
    cells = Tuple(ce(wP.cell[g].V - wB.cell[g].V, wB.cell[g].Vc) for g in 1:2)
    status = Tuple(ce(wP.status[k].V - wB.status[k].V, wB.status[k].Vc) for k in 1:2)
    (total = tot, parts = parts, cells = cells, employed = status[1], unemployed = status[2])
end


"""
    emissions(r; code, rB = r, year = "2021")

Household greenhouse-gas footprint per head, tonnes CO2e (the E cost side):
the country's official per-head household footprint (Eurostat env_ac_ghgfp,
data/sustainability/footprint_intensity.csv) scaled by the economy's mean
consumption relative to the baseline `rB`, at the country's fixed intensity per
euro. So the baseline reproduces the official figure, a policy moves emissions
through consumption, and groups differ by their consumption. Returns the total,
by education cell and by employment status.
"""
function emissions(r; code, rB = r, year = "2021")
    tph = NaN
    for (k, ln) in enumerate(eachline(joinpath(@__DIR__, "..", "..", "data", "sustainability", "footprint_intensity.csv")))
        k == 1 && continue
        f = split(ln, ","); (f[1] == code && f[2] == year) && (tph = parse(Float64, f[7]))
    end
    isnan(tph) && error("no footprint for $code in $year")
    k = tph / rB.consumption
    (total = k * r.consumption, cells = Tuple(k * x for x in r.consumption_cell), status = Tuple(k * x for x in r.consumption_status))
end


"The household footprint intensity, kg CO2e per euro of consumption (data/sustainability/footprint_intensity.csv)."
function footprint_intensity(code; year = "2021")
    for (k, ln) in enumerate(eachline(joinpath(@__DIR__, "..", "..", "data", "sustainability", "footprint_intensity.csv")))
        k == 1 && continue
        f = split(ln, ","); (f[1] == code && f[2] == year) && return parse(Float64, f[5])
    end
    error("no intensity for $code in $year")
end

"""
    job_effort_levels(c)

The effort the job sets in each state, by education cell, in the economy `c`
with S off and effort_mode = :job: the levels of each patience type averaged with
the type weights. For `effort_by_cell` of another configuration.
"""
function job_effort_levels(c::SAGEConfig)
    c0 = SAGEConfig(c; S = false, effort_mode = :job, effort_by_cell = (Float64[], Float64[]), control_share = (0.0, 0.0))
    cs = cells_of(c0); _, bw = betas_of(c0); cT = SAGEConfig(c0; lumptax = c0.lumptax + ui_tax_of(c0))
    Tuple(begin
              ps = params_of(cT, cs[g])
              sum(bw[k] .* solve_participation_logit(update(p; social_strength = 0.0), 1.0; theta = c0.theta, full = true).effort_set
                  for (k, p) in enumerate(ps))
          end for g in 1:2)
end

"""
    income_stats(c)

The distribution of disposable income in the economy `c` with S off, household
by household: the quintile share ratio S80/S20, the Gini, the shares below 50%
and 60% of the median, and the share of the employed below 60% (in-work
poverty). For the income process's dispersion, which version 3 fits to the
official S80/S20 of people under 65 (data/validation/income_distribution.csv).
"""
function income_stats(c::SAGEConfig)
    c0 = floor_effort(SAGEConfig(c; S = false))
    cs = cells_of(c0); _, bw = betas_by_cell(c0); cT = SAGEConfig(c0; lumptax = c0.lumptax + ui_tax_of(c0))
    jobs = [(g, k, p) for g in 1:2 for (k, p) in enumerate(params_of(cT, cs[g]))]
    recs = (nworkers() > 1 ? pmap : map)(jobs) do (g, k, p)
        p = update(p; social_strength = 0.0)
        s = solve_participation_logit(p, 1.0; theta = c0.theta, full = true)
        ys = Float64[]; ws = Float64[]; es = Bool[]
        y2 = Float64[]; w2 = Float64[]; e2 = Bool[]          # with the mass of each income state spread over its interval (ysmooth)
        zp = sort(unique(s.z_vals[s.z_vals .> 0])); K = max(p.ysmooth, 1)
        Δ = K > 1 ? (isnan(p.zstep) ? (length(zp) > 1 ? log(zp[2] / zp[1]) : 0.0) : p.zstep) : 0.0
        for st in eachindex(s.z_vals), i in eachindex(s.a), d in (0, 1)
            pd = d == 1 ? s.P1[i, st] : 1 - s.P1[i, st]; m = cs[g].share * bw[g][k] * s.lambda[i, st] * pd; m <= 0 && continue
            sy = (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * s.z_vals[st] * p.Z + net_participation(p, p.α[st], s.z_vals[st]) * d + transfer_at(p, st)
            x = p.R * s.a[i] + (1 + p.subsidy) * p.α[st] * s.e_d[d+1][i, st] * s.z_vals[st] * p.Z - p.lumptax +
                net_participation(p, p.α[st], s.z_vals[st]) * d + transfer_at(p, st)
            push!(ys, (x + floor_transfer(p, x) - s.a[i]) / p.pc); push!(ws, m); push!(es, s.z_vals[st] > 0)
            Δ == 0 && continue
            for j in 1:K
                xj = p.R * s.a[i] - p.lumptax + sy * exp(Δ * ((j - 0.5) / K - 0.5))
                push!(y2, (xj + floor_transfer(p, xj) - s.a[i]) / p.pc); push!(w2, m / K); push!(e2, s.z_vals[st] > 0)
            end
        end
        (ys, ws, es, y2, w2, e2)
    end
    ys = reduce(vcat, [r[1] for r in recs]); ws = reduce(vcat, [r[2] for r in recs]); es = reduce(vcat, [r[3] for r in recs])
    y2 = reduce(vcat, [r[4] for r in recs]); w2 = reduce(vcat, [r[5] for r in recs]); e2 = reduce(vcat, [r[6] for r in recs])
    o = sortperm(ys); y = ys[o]; w = ws[o] ./ sum(ws); e = es[o]; cw = cumsum(w)
    med = y[findfirst(>=(0.5), cw)]
    # the fifths by interpolation in the cumulative weight, so an atom of income is split and not assigned whole
    part(lo, hi) = sum(max(0.0, min(cw[i], hi) - max(i > 1 ? cw[i-1] : 0.0, lo)) * y[i] for i in eachindex(y))
    L = cumsum(w .* y) ./ sum(w .* y)
    gini = 1 - sum(w[i] * (L[i] + (i > 1 ? L[i-1] : 0.0)) for i in eachindex(y))
    below(q, sel) = sum(w[i] for i in eachindex(y) if sel[i] && y[i] < q * med; init = 0.0) / sum(w[sel])
    # the shares below a line from the spread distribution, where there is one; S80/S20 and the Gini, which
    # the calibration targets, stay on the states themselves
    if !isempty(y2)
        o2 = sortperm(y2); ya = y2[o2]; wa = w2[o2] ./ sum(w2); ea = e2[o2]; ca = cumsum(wa)
        med2 = ya[findfirst(>=(0.5), ca)]
        bel2(q, sel) = sum(wa[i] for i in eachindex(ya) if sel[i] && ya[i] < q * med2; init = 0.0) / sum(wa[sel])
        return (s8020 = part(0.8, 1.0) / part(0.0, 0.2), gini = gini, p50 = bel2(0.5, trues(length(ya))), p60 = bel2(0.6, trues(length(ya))),
                inwork60 = bel2(0.6, ea), median = med2)
    end
    (s8020 = part(0.8, 1.0) / part(0.0, 0.2), gini = gini, p50 = below(0.5, trues(length(y))), p60 = below(0.6, trues(length(y))),
     inwork60 = below(0.6, e), median = med)
end

"""
    carbon_value(rB, rP; code, key = "uba_central", year = "2021")

The optional valuation of the change in household emissions from the baseline
`rB` to the policy `rP`, at an official carbon value (data/sustainability/
carbon_values.csv, `key`). Returns the change in tonnes per head, its value in
euros per head (positive when emissions fall) and that value as a share of
baseline consumption per head in euros (the official footprint over the
intensity). The value is a damage avoided for the world, not a gain the
household enjoys: it sits beside the consumption equivalent of welfare_ce and is
never added to it. No damage feeds back into the economy (parked in version 2.0).
"""
function carbon_value(rB, rP; code, key = "uba_central", year = "2021")
    v = nothing
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "sustainability", "carbon_values.csv"))
        (startswith(ln, "#") || startswith(ln, "key,")) && continue
        f = split(ln, ","); f[1] == key && (v = (value = parse(Float64, f[4]), currency = f[5], kind = f[3], price_year = f[6]))
    end
    v === nothing && error("no carbon value $key")
    eB, eP = emissions(rB; code = code, rB = rB, year = year), emissions(rP; code = code, rB = rB, year = year)
    cB = eB.total * 1000 / footprint_intensity(code; year = year)     # euros per head
    d = eP.total - eB.total
    (tonnes = d, eur = -d * v.value, share = -d * v.value / cB, key = key, kind = v.kind,
     currency = v.currency, price_year = v.price_year)
end

"""
    place_report(rB, rP = rB; code)

The group-by-place table for an economy with E on: one row per place with its
population weight, the WISE indicators in the baseline and their change under
the policy, the money propensities, welfare as a consumption equivalent (in
total, by education cell and by employment status) and emissions per head, all
against the same national baseline. With rP = rB it is the baseline by place.
"""
function place_report(rB, rP = rB; code)
    haskey(rB, :by_place) || error("place_report needs an economy solved with E on")
    eB = emissions(rB; code = code)
    rows = NamedTuple[]
    for (i, ((name, b), (_, q))) in enumerate(zip(rB.by_place, rP.by_place))
        w = welfare_ce(b, q)
        push!(rows, (place = name, weight = rB.weights[i],
                     participation = b.rate, d_participation = q.rate - b.rate,
                     agency = b.A, d_agency = q.A - b.A, hardship = b.hardship, d_hardship = q.hardship - b.hardship,
                     mpc = b.mpc, mps = b.mps, mpe = b.mpe, mpp = b.mpp,
                     welfare = w.total, welfare_cells = w.cells, welfare_employed = w.employed, welfare_unemployed = w.unemployed,
                     emissions = eB.total * b.consumption / rB.consumption,
                     d_emissions = eB.total * (q.consumption - b.consumption) / rB.consumption))
    end
    rows
end

"Print `place_report` rows as a table."
function print_place_report(rows; io = stdout)
    @printf(io, "%-24s %6s %8s %8s %7s %8s %7s %8s %6s %8s %8s %8s\n", "place", "weight", "particip", "change", "agency", "change",
            "hardsh.", "change", "MPC", "welfare", "t CO2e", "change")
    for r in rows
        @printf(io, "%-24s %6.3f %8.4f %+8.4f %7.3f %+8.4f %7.3f %+8.4f %6.3f %+7.3f%% %8.3f %+8.3f\n",
                first(r.place, 24), r.weight, r.participation, r.d_participation, r.agency, r.d_agency,
                r.hardship, r.d_hardship, r.mpc, 100 * r.welfare, r.emissions, r.d_emissions)
    end
end

"""
    carbon_tax_economy(c, eur_per_tonne; code, rB, thresholds, iters = 4)

The economy with a carbon tax of `eur_per_tonne` on household consumption, at
the country's footprint intensity: an ad valorem consumption tax of eur_per_tonne
x kg per euro / 1000, its revenue returned as an equal lump sum to every
household (budget-neutral, found by a few fixed-point steps on the revenue).
Returns the economy and the recycled amount per head.
"""
function carbon_tax_economy(c::SAGEConfig, eur_per_tonne; code, thresholds = nothing, iters = 4)
    t = eur_per_tonne * footprint_intensity(code) / 1000
    # the economy returned is the one solved with the rebate reported; `gap` is
    # what the budget is off by (the revenue it raises less the rebate it pays)
    rev = 0.0; r = nothing; gap = Inf
    for _ in 1:iters
        r = solve_economy(SAGEConfig(c; ctax = t, lumptax = c.lumptax - rev); thresholds = thresholds)
        gap = t * r.consumption - rev
        abs(gap) < 1e-7 && break
        rev += gap
    end
    if abs(gap) >= 1e-7
        r = solve_economy(SAGEConfig(c; ctax = t, lumptax = c.lumptax - rev); thresholds = thresholds)
        gap = t * r.consumption - rev
    end
    (economy = r, rate = t, recycled = rev, gap = gap)
end


"""
    time_propensities(c; h = 0.01, thresholds)

Where extra time goes: every household gets `h` more of its time endowment (h =
0.01 is about an hour a week), and the economy is solved again. Per unit of time:
the change in work of the employed, in participation (time QBAR each), and the
remainder, leisure. By construction the three add to one for the employed; for
the unemployed work is zero. Also the welfare of the extra time.
"""
function time_propensities(c::SAGEConfig; h = 0.01, thresholds = nothing)
    rB = solve_economy(c; thresholds = thresholds)
    thr = [(rB.ypov, rB.abar)]
    rP = solve_economy(SAGEConfig(c; time_bonus = h); thresholds = thr)
    # all three for the EMPLOYED: their effort, their participation (rate_E, not
    # the overall rate that mixed in the unemployed until 2026-10-02), the rest
    # leisure. Commuting time scales with effort and is counted with work.
    cs = cells_of(c)
    κ = 1 + sum(cs[g].share * cs[g].τ for g in 1:2)
    work = κ * (rP.mean_effort_employed - rB.mean_effort_employed) / h
    part = c.qbar * (rP.rate_E - rB.rate_E) / h
    (work_employed = work, participation = part, participation_rate_per_h = (rP.rate_E - rB.rate_E) / h,
     leisure_employed = 1 - work - part, welfare = welfare_ce(rB, rP))
end
