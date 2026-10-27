# Agency as protection against being knocked off course.
#
# Snower and Lima de Miranda (2020, section 3.3) write the agency component of
# wellbeing as alpha times (1 - p): alpha, how well a person's effort turns into
# outcomes, and (1 - p), how far outcomes stay in the person's own hands. An
# earlier stage read (1 - p) as freedom from asset poverty. That turned agency
# into a mirror of the hand-to-mouth share, which is calibrated, so the column
# returned its own target (MODULAR.md, 2026-09-25).
#
# Here p is the expected share of next year's consumption a household loses to
# unemployment: the chance of being out of work next year, times the shortfall
# of consumption then against what it would be in work at the same assets and
# productivity. It depends on the risk of job loss, the chance of finding work,
# the benefit, and the household's own savings, so the model produces it rather
# than reading it off an input. The same quantity from labour and benefit income
# alone, leaving savings out, is the model's counterpart of the OECD labour
# market insecurity indicator (Cazes, Hijzen and Saint-Martin 2015), and the gap
# between the two is what households' own buffers contribute. The consumption
# drop at the moment a job is lost is kept as a diagnostic against the
# consumption-smoothing literature (Gruber 1997; Ganong and Noel 2019).
#
# Also here, because it needs each household's own income: the hand-to-mouth
# share on the baseline definition of Kaplan, Violante and Weidner (2014): liquid
# balances no larger than half a two-week pay period's income, that is wealth at
# most one week of the household's own labour and benefit income. A one-asset
# model has no illiquid wealth, so its hand-to-mouth are their poor
# hand-to-mouth, and the targets are the poor shares.
#
# Everything is a sum over the stationary distribution, so it pools exactly
# across discount types and belonging scales, like every other family field.
# This file is part of the family cache key (SOLVER_FILES in sage_modular.jl):
# a change here rebuilds the families.

using Distributed

"""
    agency_summary(p, sol)

Per-state sums over the stationary distribution: `pmass` of lambda times p from
consumption, `pinc` of lambda times the same from labour and benefit income, and
`dmass`, over employed states, of lambda times the consumption drop if the job
were lost now at the same assets. States with zero productivity are the
unemployed ones and state u + nz/2 is the employed state with the same latent
productivity (see `unemployment_process`). Without unemployed states all three
are zero.
"""
function agency_summary(p::SAGEParams, sol)
    p.illiquid && return two_asset_agency_summary(p, sol)
    a = sol.a; λ = sol.lambda; P1 = sol.P1; na = p.na
    z, Π = SAGEBewley.income_process(p)
    ns = length(z)
    pmass = zeros(ns); pinc = zeros(ns); dmass = zeros(ns); hmass = zeros(ns)
    mpcmass = zeros(ns); mpchmass = zeros(ns); rmass = zeros(ns); xmass = zeros(ns); cmass = zeros(ns)
    kmass = zeros(ns); smass = zeros(ns)        # job search (A): its cost as a consumption equivalent, and the chance chosen
    srch = !isempty(p.search_k) && hasproperty(sol, :search_x)
    # by the chain's labels (version 2, stage 0): a job is lost into the U states, and pE[u] is the employed
    # state with u's latent productivity, pU[s] the U state with the employed state s's
    stv = stypes(p); empv = stv .== :E
    U = findall(stv .=== :U); haveU = !isempty(U) && any(empv)
    pE = haveU ? partner_index(p, :E) : Int[]; pU = haveU ? partner_index(p, :U) : Int[]
    # Expected consumption and labour-plus-benefit income at every grid point,
    # mixing the participation choice with its own probability, from the same
    # budget the solver uses.
    cbar = zeros(na, ns); ybar = zeros(na, ns)
    for s in 1:ns
        α = p.α[s]; credit = net_participation(p, α, z[s]); tr = transfer_at(p, s)
        for i in 1:na, d in (0, 1)
            w = d == 1 ? P1[i, s] : 1 - P1[i, s]
            w <= 0 && continue
            lab = (1 + p.subsidy) * α * sol.e_d[d+1][i, s] * z[s] * p.Z
            x = p.R * a[i] + lab - p.lumptax + credit * d + tr
            cbar[i, s] += w * (x + floor_transfer(p, x) - sol.a_d[d+1][i, s]) / p.pc   # real consumption
            ybar[i, s] += w * (lab + tr)
        end
    end
    for s in 1:ns, i in 1:na
        m = λ[i, s]; m <= 0 && continue
        htm = a[i] <= ybar[i, s] * p.ppy / 52
        htm && (hmass[s] += m)
        # Room to manoeuvre: liquid wealth covering three months of own income.
        a[i] >= ybar[i, s] * p.ppy / 4 && (rmass[s] += m)
        cmass[s] += m * cbar[i, s]
        # Marginal propensity to consume, within the year, out of a windfall of
        # one month of the household's own income (the size in Jappelli and
        # Pistaferri 2014 and the HFCS question): cash on hand rises by delta,
        # which is assets higher by delta / R.
        Δ = ybar[i, s] * p.ppy / 12
        if Δ > 0
            mpc = p.pc * (interp_ext(a, view(cbar, :, s), a[i] + Δ / p.R) - cbar[i, s]) / Δ   # spending share
            mpcmass[s] += m * mpc; htm && (mpchmass[s] += m * mpc)
        end
        # Dread as a consumption equivalent: the share x of this year's
        # consumption with Gamma u(c (1 - x)) = Gamma u(c) - dread cost.
        if dread_weight(p) > 0 && cbar[i, s] > 0
            D = 0.0
            for d in (0, 1)
                w = d == 1 ? P1[i, s] : 1 - P1[i, s]
                w > 0 && (D += w * dread_at(p, s, sol.a_d[d+1][i, s]; weight = dread_weight(p)))
            end
            k = 1 - (1 - p.γ) * D / (p.Γ * cbar[i, s]^(1 - p.γ))
            k > 0 && (xmass[s] += m * (1 - k^(1 / (1 - p.γ))))
        end
        # Job search: the chance of finding work chosen, and its cost as a consumption equivalent, the share k of
        # this year's consumption with Gamma u(c (1 - k)) = Gamma u(c) - cost, as for dread
        if srch && p.search_k[s] > 0
            xx = sol.search_x[i, s]; smass[s] += m * xx
            K = p.search_k[s] * xx^(1 + p.search_gamma) / (1 + p.search_gamma)
            if cbar[i, s] > 0
                kq = 1 - (1 - p.γ) * K / (p.Γ * cbar[i, s]^(1 - p.γ))
                kq > 0 && (kmass[s] += m * (1 - kq^(1 / (1 - p.γ))))
            end
        end
        haveU || continue
        pc = 0.0; py = 0.0
        for d in (0, 1)
            w = d == 1 ? P1[i, s] : 1 - P1[i, s]
            w <= 0 && continue
            ap = sol.a_d[d+1][i, s]
            for u in U
                pr = Π[s, u]; pr <= 0 && continue
                cE = SAGEBewley.interp_lin(a, view(cbar, :, pE[u]), ap)
                cU = SAGEBewley.interp_lin(a, view(cbar, :, u), ap)
                yE = SAGEBewley.interp_lin(a, view(ybar, :, pE[u]), ap)
                yU = SAGEBewley.interp_lin(a, view(ybar, :, u), ap)
                cE > 0 && (pc += w * pr * max(0.0, 1 - cU / cE))
                yE > 0 && (py += w * pr * max(0.0, 1 - yU / yE))
            end
        end
        pmass[s] += m * pc; pinc[s] += m * py
        empv[s] && cbar[i, s] > 0 && (dmass[s] += m * max(0.0, 1 - cbar[i, pU[s]] / cbar[i, s]))
    end
    # STAGE 1d's measures (V3_START.md section 129), at a sub-annual period only (zeros at an annual one, so version 1
    # is unchanged): the twelve-month MPC and the fall on job loss as Kolsrud, Landais, Nilsson and Spinnewijn (2018)
    # measure it. Both follow the households' own choices forward: next assets a_d, participation P1, and the
    # transition the household chose where it searches (as welfare_parts).
    lumpm = zeros(ns)                                 # the lump sum's cohort (part 3 below)
    nonem = zeros(ns)                                 # the job losers' time out of work (part 4 below)
    mpc12mass = zeros(ns); kz = zeros(ns)            # kz[1:5]: entrant mass, its pre-loss consumption, quarter-1 consumption, survivors to quarter 2, their consumption
    if p.ppy > 1
        srch2 = !isempty(p.search_k) && hasproperty(sol, :search_xs) && !isempty(sol.search_xs)
        Pf = Π; Ps = Π
        if srch2
            isEmp = isemp(p); Pf = copy(Π); Ps = copy(Π)
            for s in 1:ns
                p.search_k[s] > 0 || continue
                rowE = Π[s, :] .* isEmp; fs = sum(rowE)
                Pf[s, :] = rowE ./ fs; Ps[s, :] = (Π[s, :] .- rowE) ./ (1 - fs)
            end
        end
        nzr = [findall(Π[s, :] .> 0) for s in 1:ns]
        # the step from (i, s): (weight, bracket k, weight on k, probability of s2) for each branch d and next state s2
        function step!(f, i, s)
            for d in (0, 1)
                w = d == 1 ? P1[i, s] : 1 - P1[i, s]; w <= 0 && continue
                ap = sol.a_d[d+1][i, s]
                k = clamp(searchsortedlast(a, ap), 1, na - 1); wk = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                pw = (srch2 && p.search_k[s] > 0) ?
                     SAGEBewley.interp_lin(a, view(sol.search_xs, :, s), ap) * (isempty(p.search_lam) ? 1.0 : p.search_lam[s]) : NaN
                for s2 in nzr[s]
                    pr = isnan(pw) ? Π[s, s2] : pw * Pf[s, s2] + (1 - pw) * Ps[s, s2]
                    pr > 0 && f(w * pr, k, wk, s2)
                end
            end
        end
        # 1. The twelve-month MPC (the HFCS question: a windfall of one month's income, how much spent within twelve
        #    months). G_t(a, s) is expected consumption t periods on from (a, s); C is its sum over the year's periods, and
        #    the MPC the change in C from the windfall over the windfall, as the within-period MPC above.
        G = copy(cbar); C = copy(cbar)
        for t in 1:p.ppy-1
            Gn = zeros(na, ns)
            let Gc = G
                for s in 1:ns, i in 1:na
                    step!(i, s) do q, k, wk, s2
                        Gn[i, s] += q * (wk * Gc[k, s2] + (1 - wk) * Gc[k+1, s2])
                    end
                end
            end
            G = Gn; C .+= G
        end
        for s in 1:ns, i in 1:na
            m = λ[i, s]; m <= 0 && continue
            Δ = ybar[i, s] * p.ppy / 12
            Δ > 0 && (mpc12mass[s] += m * p.pc * (interp_ext(a, view(C, :, s), a[i] + Δ / p.R) - C[i, s]) / Δ)
        end
        # 2. The fall as Kolsrud and co-authors measure it: the cohort that loses its job (from work into the first
        #    period out of work), its consumption in its last period in work, and in the first and second periods out
        #    of work among those still out of work (into the second duration). Combined in sage_modular.jl.
        dur = isempty(p.dur) ? zeros(Int, ns) : p.dur
        U1 = falses(ns); U2 = falses(ns)
        for s in 1:ns
            stv[s] === :U && dur[s] == 1 && (U1[s] = true); stv[s] === :U && dur[s] == 2 && (U2[s] = true)
        end
        if any(U1) && any(U2)
            c1 = zeros(na, ns)
            for s in 1:ns
                empv[s] || continue
                for i in 1:na
                    m = λ[i, s]; m <= 0 && continue
                    step!(i, s) do q, k, wk, s2
                        U1[s2] || return
                        kz[1] += m * q; kz[2] += m * q * cbar[i, s]
                        c1[k, s2] += m * q * wk; c1[k+1, s2] += m * q * (1 - wk)
                    end
                end
            end
            for s in 1:ns, i in 1:na
                c1[i, s] > 0 || continue
                kz[3] += c1[i, s] * cbar[i, s]
                step!(i, s) do q, k, wk, s2
                    U2[s2] || return
                    kz[4] += c1[i, s] * q; kz[5] += c1[i, s] * q * (wk * cbar[k, s2] + (1 - wk) * cbar[k+1, s2])
                end
            end
            # 4. Time out of work after job loss (V3_START.md section 138; the estimand of Schmieder, von Wachter and
            #    Bender 2012: nonemployment, the time from job loss to the next job, whatever the state in between). The
            #    job losers' cohort is followed through every state out of work (U, L, N) with the households' own
            #    choices; nonem[t] is the cohort's mass still out of work in its t-th quarter (t = 1 the entry quarter),
            #    for t up to min(ns, 40).
            let cur = copy(c1), T = min(ns, 40)
                for t in 1:T
                    nxt = zeros(na, ns)
                    for s in 1:ns, i in 1:na
                        mm = cur[i, s]; mm > 0 || continue
                        nonem[t] += mm
                        step!(i, s) do q, k, wk, s2
                            empv[s2] && return
                            nxt[k, s2] += mm * q * wk; nxt[k+1, s2] += mm * q * (1 - wk)
                        end
                    end
                    cur = nxt
                end
            end
            # 3. A lump sum at the start of the spell, for the current spell only (design section 7; V3_START.md section
            #    137): the job losers' assets on entry raised by SAGE_COHORT_LUMP times their last period's income in work
            #    (cash on hand up by that, assets by it over R), the policies the baseline's, since the future is
            #    unchanged. The cohort is followed through the spell's quarters, with and without the lump sum: in
            #    lumpmass, the mass in each quarter of the spell and its exits to work, base then with the lump sum.
            LUMP = parse(Float64, get(ENV, "SAGE_COHORT_LUMP", "0.1"))
            # GROUP (SAGE_COHORT_GROUP="lo,hi", the methods review of 27 October): the cohort restricted to job losers whose
            # liquid wealth in their last period in work is in [lo, hi) times that period's income, both with and without
            # the lump sum, so that the liquidity share can be read by buffer. Unset: every job loser (the fall and the
            # time out of work above are never restricted).
            grp = parse.(Float64, split(get(ENV, "SAGE_COHORT_GROUP", "-1e300,1e300"), ","))
            ingrp(i, s) = grp[1] <= a[i] / max(ybar[i, s], 1e-12) < grp[2]
            ds_ = [stv[s] === :U && dur[s] < NONENT ? dur[s] : 0 for s in 1:ns]; nUq = maximum(ds_)
            if 4 * nUq <= ns && LUMP > 0
                cl = zeros(na, ns); c1g = zeros(na, ns)
                for s in 1:ns
                    empv[s] || continue
                    for i in 1:na
                        m = λ[i, s]; (m <= 0 || !ingrp(i, s)) && continue
                        step!(i, s) do q, k, wk, s2
                            U1[s2] || return
                            c1g[k, s2] += m * q * wk; c1g[k+1, s2] += m * q * (1 - wk)
                        end
                        Δ = LUMP * ybar[i, s]
                        for d in (0, 1)
                            w = d == 1 ? P1[i, s] : 1 - P1[i, s]; w <= 0 && continue
                            ap = sol.a_d[d+1][i, s] + Δ / p.R
                            k = clamp(searchsortedlast(a, ap), 1, na - 1); wk = clamp((a[k+1] - ap) / (a[k+1] - a[k]), 0.0, 1.0)
                            for s2 in nzr[s]
                                (U1[s2] && Π[s, s2] > 0) || continue
                                cl[k, s2] += m * w * Π[s, s2] * wk; cl[k+1, s2] += m * w * Π[s, s2] * (1 - wk)
                            end
                        end
                    end
                end
                for (j, c0) in enumerate((c1g, cl))
                    cur = c0
                    for dq in 1:nUq
                        nxt = zeros(na, ns)
                        for s in 1:ns, i in 1:na
                            mm = cur[i, s]; mm > 0 || continue
                            lumpm[(j-1)*2*nUq+dq] += mm
                            step!(i, s) do q, k, wk, s2
                                if empv[s2]
                                    lumpm[(j-1)*2*nUq+nUq+dq] += mm * q
                                elseif stv[s2] === :U && ds_[s2] == dq + 1
                                    nxt[k, s2] += mm * q * wk; nxt[k+1, s2] += mm * q * (1 - wk)
                                end
                            end
                        end
                        cur = nxt
                    end
                end
            end
        end
    end
    merge((pmass = pmass, pinc = pinc, dmass = dmass, hmass = hmass, whmass = zeros(ns),
           mpcmass = mpcmass, mpchmass = mpchmass, mpcwmass = zeros(ns), rmass = rmass, xmass = xmass, cmass = cmass,
           kmass = kmass, smass = smass, mpc12mass = mpc12mass, kolmass = kz, lumpmass = lumpm, nonempmass = nonem),
          welfare_parts(p, sol))
end

"Mix the agency sums across discount types or belonging scales, as `collapse` does the rest."
collapse_agency(ds, w) = (pmass = sum(w[i] .* ds[i].pmass for i in eachindex(ds)),
                          pinc  = sum(w[i] .* ds[i].pinc  for i in eachindex(ds)),
                          dmass = sum(w[i] .* ds[i].dmass for i in eachindex(ds)),
                          hmass = sum(w[i] .* ds[i].hmass for i in eachindex(ds)),
                          whmass = sum(w[i] .* ds[i].whmass for i in eachindex(ds)),
                          mpcwmass = sum(w[i] .* ds[i].mpcwmass for i in eachindex(ds)),
                          cmass = sum(w[i] .* ds[i].cmass for i in eachindex(ds)),
                          mpcmass  = sum(w[i] .* ds[i].mpcmass  for i in eachindex(ds)),
                          mpchmass = sum(w[i] .* ds[i].mpchmass for i in eachindex(ds)),
                          rmass    = sum(w[i] .* ds[i].rmass    for i in eachindex(ds)),
                          xmass    = sum(w[i] .* ds[i].xmass    for i in eachindex(ds)),
                          vmass    = sum(w[i] .* ds[i].vmass    for i in eachindex(ds)),
                          vcmass   = sum(w[i] .* ds[i].vcmass   for i in eachindex(ds)),
                          vemass   = sum(w[i] .* ds[i].vemass   for i in eachindex(ds)),
                          vbmass   = sum(w[i] .* ds[i].vbmass   for i in eachindex(ds)),
                          mpsmass  = sum(w[i] .* ds[i].mpsmass  for i in eachindex(ds)),
                          mpemass  = sum(w[i] .* ds[i].mpemass  for i in eachindex(ds)),
                          mppmass  = sum(w[i] .* ds[i].mppmass  for i in eachindex(ds)),
                          vbumass  = sum(w[i] .* ds[i].vbumass  for i in eachindex(ds)),
                          veumass  = sum(w[i] .* ds[i].veumass  for i in eachindex(ds)),
                          mppumass = sum(w[i] .* ds[i].mppumass for i in eachindex(ds)),
                          kmass    = sum(w[i] .* ds[i].kmass    for i in eachindex(ds)),
                          smass    = sum(w[i] .* ds[i].smass    for i in eachindex(ds)),
                          mpc12mass = sum(w[i] .* ds[i].mpc12mass for i in eachindex(ds)),
                          kolmass  = sum(w[i] .* ds[i].kolmass  for i in eachindex(ds)),
                          lumpmass = sum(w[i] .* ds[i].lumpmass for i in eachindex(ds)),
                          nonempmass = sum(w[i] .* ds[i].nonempmass for i in eachindex(ds)),
                          vdmass   = sum(w[i] .* ds[i].vdmass   for i in eachindex(ds)),
                          vkmass   = sum(w[i] .* ds[i].vkmass   for i in eachindex(ds)))
collapse_all(ds, w) = merge(collapse(ds, w), collapse_agency(ds, w))

"""
    build_family_ag(p0s, ugrid, theta; weights, thresholds)

`build_family_u` with the agency sums added to every summary: the same
household problems in the same order, mixed the same way.
"""
function build_family_ag(p0s::Vector{SAGEParams}, ugrid, theta; weights, thresholds = nothing,
                         chunked::Bool = true)
    nt = length(p0s); nu = length(ugrid)
    if !chunked
        # the original path: every (type, belonging scale) problem from scratch
        jobs = [(i, j) for j in 1:nu for i in 1:nt]
        solve1 = ij -> begin
            i, j = ij
            p = update(p0s[i]; social_strength = ugrid[j])
            s = solve_participation_logit(p, 1.0; theta = theta, full = true)
            merge(cell_summary(p, s; thresholds = thresholds), agency_summary(p, s))
        end
        out = nworkers() > 1 ? pmap(solve1, jobs) : [solve1(ij) for ij in jobs]
        return [collapse_all(out[(j-1)*nt+1 : j*nt], weights) for j in 1:nu]
    end
    # The fast path (2026-09-28): the problems of one discount type differ only
    # in the belonging scale, so they share one reward table, and each starts
    # from the solution at the neighbouring scale. The belonging grid is split
    # into as many runs as keep every worker busy.
    nch = min(nu, max(1, cld(max(nworkers(), 1), nt)))
    runs = [collect(r) for r in Iterators.partition(1:nu, cld(nu, nch))]
    jobs = [(i, run) for run in runs for i in 1:nt]
    solve_run = job -> begin
        i, run = job
        rw = p0s[i].solver === :egm ? nothing : participation_rewards(p0s[i])
        V = nothing
        out = Vector{Any}(undef, length(run))
        for (m, j) in enumerate(run)
            p = update(p0s[i]; social_strength = ugrid[j])
            s = solve_participation_logit(p, 1.0; theta = theta, full = true, rewards = rw, V0 = V)
            V = s          # the whole solution: the EGM starts from V and its derivative
            out[m] = (j, merge(cell_summary(p, s; thresholds = thresholds), agency_summary(p, s)))
        end
        out
    end
    res = nworkers() > 1 ? pmap(solve_run, jobs) : [solve_run(jb) for jb in jobs]
    table = Dict{Tuple{Int,Int},Any}()
    for (jb, r) in zip(jobs, res), (j, summ) in r
        table[(jb[1], j)] = summ
    end
    [collapse_all([table[(i, j)] for i in 1:nt], weights) for j in 1:nu]
end
