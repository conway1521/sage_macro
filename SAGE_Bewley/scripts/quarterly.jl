# Version 2, stage 1a: the quarterly economy from an annual configuration (V2_BUILD_PLAN.md; paper/sage_v2_design.md,
# section 3.1). Nothing is refitted here: this is the period, with version 1's flows.
#
#   - job finding and the exit from L: the chance of not leaving in `ppy` periods equals the year's;
#   - the first spell out of work lasts `ppy` periods (U_1 ... U_ppy) at version 1's first-year replacement rate,
#     then L at version 1's long-term income, so the insured year is a year;
#   - job loss by cell: set so that each cell's share out of work (U and L together) is the annual economy's;
#   - patience and the return: their ppy-th roots;
#   - the income process: refitted (`quarterly_income`, labour_chain.jl) so that annual averages of the period's log
#     income have the published autocovariances at lags 0, 1 and 2, job loss included;
#   - income keeps its normalisation per period (hours, the floor as a share of the period's median and the benefits
#     are unchanged), so the asset grid's top is ppy times higher, in periods of income, with more points.
# Search costs and the cost of being out of work are not converted: stage 1a is run on G (and G+S) first.

"The quarterly (or other sub-annual) version of an annual configuration with the state out of work."
function quarterly_config(c::SAGEConfig; ppy::Int = 4)
    c.period == 1 || error("the configuration is already at $(c.period) periods a year")
    isnan(c.f_long[1]) && error("stage 1a is built on the state out of work")
    isempty(c.country) && error("the income process is refitted from the country's published one: build c with country_config")
    q(x) = 1 - (1 - x)^(1 / ppy)
    fq = q(c.f_find); fLq = (q(c.f_long[1]), q(c.f_long[2]))
    δq = ntuple(2) do g
        δ = c.delta[g]; out = 1 - 1 / (1 + δ + δ * (1 - c.f_find) / c.f_long[g])
        lo, hi = 1e-7, 0.5
        for _ in 1:100
            m = (lo + hi) / 2
            ch = labour_chain(SAGEParams(nz = 2, α = fill(1.0, 2), B = fill(1.0, 2)); nU = ppy, hU = fill(fq, ppy), hL = fLq[g], δ = m)
            (1 - ch.mass[ppy + 1]) < out ? (lo = m) : (hi = m)
        end
        (lo + hi) / 2
    end
    pub(k) = manual_input(c.country, k)
    inc = ntuple(2) do g
        lo = g == 1 ? "low" : "high"
        quarterly_income(c.nz, c.n_eps, pub("rho_$lo"), sqrt(pub("var_persistent_$lo")), sqrt(pub("var_transitory_$lo"));
                         nU = ppy, hU = fill(fq, ppy), hL = fLq[g], δ = δq[g], rrU = fill(c.rr, ppy), rrL = c.rr_long)
    end
    bq = c.beta_bar^(1 / ppy)
    dbq = ntuple(g -> (c.beta_bar + c.beta_cell[g])^(1 / ppy) - bq, 2)
    SAGEConfig(c; period = ppy, nU = ppy, f_find = fq, f_long = fLq, delta = δq, beta_bar = bq, beta_cell = dbq,
               rho_cell = (inc[1].ρq, inc[2].ρq), eta_cell = (inc[1].sηq, inc[2].sηq), sd_eps_cell = (inc[1].sεq, inc[2].sεq),
               R_one = isnan(c.R_one) ? NaN : c.R_one^(1 / ppy), a_max = ppy * c.a_max, na = max(c.na, 300))
end

"""
    duration_config(c; ppy = 4, nU = 8)

Stage 1b (V2_BUILD_PLAN.md; design section 3.2): the quarterly economy with flows fitted to the duration of
unemployment, from an annual configuration. Nothing is refitted to wealth or participation here.
  - Exits from unemployment by quarter of duration: the monotone hazards fitted to Eurostat's duration bands
    (`data/labour/duration_hazards.csv`, `data/labour/duration_flows.py`) for quarters 1 to 8, then L (9 on),
    split between work and inactivity by the quarterly flows' share of exits to work, the same at every duration.
  - The inactive state N, with the quarterly flows from work and out of inactivity to work and to unemployment.
    N's income is the income of jobless households, as L's.
  - Job loss by cell: set so that each cell's unemployment rate (the unemployed, U and L, over the labour force)
    is the rate version 1 uses (OECD Education at a Glance, through delta = u f / (1 - u)).
  - Patience, return, the asset grid and the income process as in `quarterly_config`, the income process
    refitted on this chain. With `fix_rho` (the default from 2026-10-21, V3_START.md section 123) the quarterly
    persistence is the fourth root of the published annual one and only the two sds are fitted (lags 0 and 1):
    the free fit put France's low cell at a near-unit root (unemployment spells add covariance across years),
    which mixed slowly; the miss at lag 2 is reported.
  - Dread, where A is on, is of the coming year's lottery felt each period (`dread_horizon = ppy`; Pagel's weight is
    annual; decided by the user 2026-10-21, V3_START.md section 124). The hazards are national: the cells differ in job loss only.
The durations, not the flows, set the exit hazards: the flows imply faster exits than the reported durations
allow, most plausibly churning between unemployment and inactivity (V3_START.md section 119).
"""
function duration_config(c::SAGEConfig; ppy::Int = 4, nU::Int = 8, nz::Int = 7, eps_stay::Float64 = 0.0, fix_rho::Bool = true,
                         profile::Bool = true, entitle::Bool = false)
    c.period == 1 || error("give the annual configuration")
    c = SAGEConfig(c; nz = nz)               # seven persistent states pay for the larger chain (checked, V3_START.md section 116)
    tab = Dict{Tuple{String,String,String},Float64}()
    for (k, l) in enumerate(eachline(joinpath(@__DIR__, "..", "..", "data", "labour", "duration_hazards.csv")))
        (k <= 2 || startswith(l, "#")) && continue
        f = split(l, ","); length(f) >= 4 || continue
        v = tryparse(Float64, f[4]); v === nothing || (tab[(f[1], f[2], f[3])] = v)
    end
    g(stat, item) = tab[(c.country, stat, item)]
    hz = [g("exit hazard a quarter", k) for k in ("q1", "q2", "q3-4", "q5-8", "q9+")]
    htot = [hz[1], hz[2], hz[3], hz[3], hz[4], hz[4], hz[4], hz[4]][1:nU]
    # exits to work at the flows' rate into work, the rest of the duration-based exit to inactivity (section 121)
    ws = g("split", "share of exits to work (churn-adjusted)")
    hU = ws .* htot; sU = (1 - ws) .* htot; hL = ws * hz[5]; sL = (1 - ws) * hz[5]
    # THE INACTIVE STATE AT THE HOUSEHOLD'S LEVEL (2026-10-20, V3_START.md section 120). The model's unit is the
    # household's main earner: Eurostat's flows between activity and inactivity are of persons (students, carers,
    # early retirees moving in and out), and applied to main earners they made a fifth to a quarter of households
    # inactive and swamped the income process. So N's size is the household's: by cell, the share of adults in
    # jobless households (EU-SILC ilc_lvhl14n, version 1's data) less the unemployed; the person flows give only how
    # fast N is left, and where to (to work at nuE, to unemployment at nuU); the flow into N (iotaE) and job loss
    # (delta) are set together, by cell, for N's share and the cell's unemployment rate.
    νE = g("quarterly flow", "inactive to employed"); νU = g("quarterly flow", "inactive to unemployed")
    # STAGE 1c (`profile`; design section 3.3; V3_START.md section 125): benefits by quarter of the entitled spell from
    # TaxBEN's household-weighted profile (data/benefits/quarterly_profile.csv, part (h) of the benefits script), the
    # one without social assistance, since the model's minimum income is its means-tested floor; beyond the eight
    # quarters, and in the spell without entitlement of those entering from inactivity, the mean of months 25 to 60.
    # The public part (the partner's earnings removed) finances the tax. Without `profile`: version 1's first-year
    # rate in every quarter of the spell and its jobless-household income beyond, as at stage 1b.
    # Defaults (the user, 2026-10-22, V3_START.md section 125): the profile on; the spell without entitlement off
    # (`entitle`), a stated simplification: it moves the fall by 0.002 to 0.006 at three to five times the time.
    rrU, rrUp, rrL, lps = fill(c.rr, nU), Float64[], c.rr_long, c.long_public_share
    if profile
        pt = Dict{Tuple{String,String},Tuple{Float64,Float64}}()
        for (k, l) in enumerate(eachline(joinpath(@__DIR__, "..", "..", "data", "benefits", "quarterly_profile.csv")))
            (k <= 2 || startswith(l, "#")) && continue
            f = split(l, ","); length(f) >= 6 || continue
            a = tryparse(Float64, f[5]); b = tryparse(Float64, f[6])
            (a === nothing || b === nothing) || (pt[(f[1], f[2])] = (a, b))
        end
        rrU = [pt[(c.country, "q$d")][1] for d in 1:nU]; rrUp = [pt[(c.country, "q$d")][2] for d in 1:nU]
        rrL, pL = pt[(c.country, "months 25-60")]; lps = rrL > 0 ? pL / rrL : 0.0
    end
    mk(δ, ι) = labour_chain(SAGEParams(nz = 2, α = fill(1.0, 2), B = fill(1.0, 2)); nU = nU, hU = hU, hL = hL, δ = δ,
                            sU = sU, sL = sL, ιE = ι, νE = νE, νU = νU, withN = true, entN = entitle)
    function bis(f, lo, hi)                 # f increasing: the root of f = 0
        for _ in 1:80
            m = (lo + hi) / 2; f(m) < 0 ? (lo = m) : (hi = m)
        end
        (lo + hi) / 2
    end
    fit = ntuple(2) do gi
        u = c.delta[gi] / (c.delta[gi] + c.f_find)
        jl = manual_input(c.country, gi == 1 ? "jobless_low" : "jobless_high")
        δfor(ι) = bis(δ -> (ch = mk(δ, ι); mu = sum(ch.mass[ch.iU]) + ch.mass[ch.iL]; mu / (mu + ch.mass[ch.iE]) - u), 1e-7, 0.3)
        ι = bis(ι -> (ch = mk(δfor(ι), ι); ch.mass[ch.iN] - max(jl - (sum(ch.mass[ch.iU]) + ch.mass[ch.iL]), 0.005)), 0.0, 0.2)
        (δ = δfor(ι), ι = ι)
    end
    δq = (fit[1].δ, fit[2].δ); ιE = (fit[1].ι, fit[2].ι)
    pub(k) = manual_input(c.country, k)
    inc = ntuple(2) do gi
        lo = gi == 1 ? "low" : "high"
        quarterly_income(c.nz, c.n_eps, pub("rho_$lo"), sqrt(pub("var_persistent_$lo")), sqrt(pub("var_transitory_$lo"));
                         nU = nU, hU = hU, hL = hL, δ = δq[gi], rrU = rrU, rrL = rrL,
                         flows = (sU = sU, sL = sL, ιE = ιE[gi], νE = νE, νU = νU, withN = true, entN = entitle), stay = eps_stay, fix_rho = fix_rho)
    end
    for gi in 1:2
        @info @sprintf("stage 1b income, cell %d: quarterly persistence %.4f%s, sds %.4f / %.4f; annual autocovariances lags 0-2 %s against %s", gi,
                       inc[gi].ρq, fix_rho ? " (fixed)" : "", inc[gi].sηq, inc[gi].sεq, string(round.(inc[gi].fit[1:3], digits = 5)), string(round.(inc[gi].target[1:3], digits = 5)))
    end
    bq = c.beta_bar^(1 / ppy)
    dbq = ntuple(gi -> (c.beta_bar + c.beta_cell[gi])^(1 / ppy) - bq, 2)
    SAGEConfig(c; period = ppy, nU = nU, f_find = hU[1], hU_vec = hU, sU_vec = sU, f_long = (hL, hL), sL = sL,
               withN = true, iotaE = ιE, nuE = νE, nuU = νU, eps_stay = eps_stay, entN = entitle,
               rrU_vec = profile ? rrU : Float64[], rrU_pub_vec = rrUp, rr_long = rrL, long_public_share = lps, dread_horizon = ppy, delta = δq, beta_bar = bq, beta_cell = dbq,
               rho_cell = (inc[1].ρq, inc[2].ρq), eta_cell = (inc[1].sηq, inc[2].sηq), sd_eps_cell = (inc[1].sεq, inc[2].sεq),
               R_one = isnan(c.R_one) ? NaN : c.R_one^(1 / ppy), a_max = ppy * c.a_max, na = max(c.na, 300))
end

"""
    quarterly_calibrated(code, cfg)

Version 2's calibrated configuration (V3_START.md section 134): stage 1c's quarterly economy (`duration_config`) at
the patience and gap of `calibration_v5q_<code>_<cfg>.txt`, with kappa and sigma_m (and the measured ratio of the
unemployed) where S is on, and with A: dread in choices over the year unless the file says `dread_mode = overlay`
(France, section 133), and job search at the costs of `search_v5q_<code>_GA.txt` where that file exists (G+S+A takes
G+A's, section 134). The cost of being out of work is in wellbeing only (out_ls = 0).
"""
function quarterly_calibrated(code::AbstractString, cfg::AbstractString)
    kv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
             k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
    S = occursin('S', cfg); A = occursin('A', cfg)
    q = kv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt"))
    β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
    ca = country_config(code; config = cfg, v3 = :v5m, S = S, A = A)
    c = SAGEConfig(duration_config(ca); beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = false)
    # S on the belonging grid it was calibrated on (22 scales, calibrate_quarterly_s.jl; section 131)
    S && (c = SAGEConfig(c; kappa = parse(Float64, q["kappa"]), sigma_m = parse(Float64, q["sigma_m"]),
                         unemployed_ratio = parse(Float64, country_rows()[code]["ratio"]),
                         ugrid = vcat(collect(0.0:1.0:12.0), collect(14.0:2.0:30.0))))
    if A
        get(q, "dread_mode", "") == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
        sf = joinpath(@__DIR__, "search_v5q_$(code)_GA.txt")
        if isfile(sf)
            s = kv(sf)
            c = SAGEConfig(c; search = true, search_gamma = parse(Float64, s["search_gamma"]),
                           search_kq = (parse.(Float64, split(s["search_kq_cell1"])), parse.(Float64, split(s["search_kq_cell2"]))))
        end
    end
    c
end
