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
    refitted on this chain. The hazards are national: the cells differ in job loss only.
The durations, not the flows, set the exit hazards: the flows imply faster exits than the reported durations
allow, most plausibly churning between unemployment and inactivity (V3_START.md section 119).
"""
function duration_config(c::SAGEConfig; ppy::Int = 4, nU::Int = 8, nz::Int = 7)
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
    ws = g("split", "share of exits to work")
    hU = ws .* htot; sU = (1 - ws) .* htot; hL = ws * hz[5]; sL = (1 - ws) * hz[5]
    ιE = g("quarterly flow", "employed to inactive"); νE = g("quarterly flow", "inactive to employed"); νU = g("quarterly flow", "inactive to unemployed")
    flows = (sU = sU, sL = sL, ιE = ιE, νE = νE, νU = νU, withN = true)
    # job loss by cell: the cell's unemployment rate among the active (U types over E and U types)
    δq = ntuple(2) do gi
        u = c.delta[gi] / (c.delta[gi] + c.f_find)
        lo, hi = 1e-7, 0.5
        for _ in 1:100
            m = (lo + hi) / 2
            ch = labour_chain(SAGEParams(nz = 2, α = fill(1.0, 2), B = fill(1.0, 2)); nU = nU, hU = hU, hL = hL, δ = m, flows...)
            mu = sum(ch.mass[1:nU]) + ch.mass[ch.iL]; ma = mu + ch.mass[ch.iE]
            mu / ma < u ? (lo = m) : (hi = m)
        end
        (lo + hi) / 2
    end
    pub(k) = manual_input(c.country, k)
    inc = ntuple(2) do gi
        lo = gi == 1 ? "low" : "high"
        quarterly_income(c.nz, c.n_eps, pub("rho_$lo"), sqrt(pub("var_persistent_$lo")), sqrt(pub("var_transitory_$lo"));
                         nU = nU, hU = hU, hL = hL, δ = δq[gi], rrU = fill(c.rr, nU), rrL = c.rr_long, flows = flows)
    end
    bq = c.beta_bar^(1 / ppy)
    dbq = ntuple(gi -> (c.beta_bar + c.beta_cell[gi])^(1 / ppy) - bq, 2)
    SAGEConfig(c; period = ppy, nU = nU, f_find = hU[1], hU_vec = hU, sU_vec = sU, f_long = (hL, hL), sL = sL,
               withN = true, iotaE = ιE, nuE = νE, nuU = νU, delta = δq, beta_bar = bq, beta_cell = dbq,
               rho_cell = (inc[1].ρq, inc[2].ρq), eta_cell = (inc[1].sηq, inc[2].sηq), sd_eps_cell = (inc[1].sεq, inc[2].sεq),
               R_one = isnan(c.R_one) ? NaN : c.R_one^(1 / ppy), a_max = ppy * c.a_max, na = max(c.na, 300))
end
