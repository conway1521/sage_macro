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
