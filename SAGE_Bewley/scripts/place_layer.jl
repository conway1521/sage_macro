# The place layer, E1 (E_PLACE_CONCEPT.md, economics specification version 1).
#
# Households live in one of three place types, the Degree of Urbanisation
# (cities, towns and suburbs, rural areas), fixed like education. Each place is
# its own economy over the existing engine:
#  - its own education mix and channel parameters (a place spec overrides the
#    national configuration only where it says so);
#  - LOCAL social feedback: each place solves its own participation fixed point,
#    and the community fabric omega_p + (1 - omega_p) x participation_p is local;
#  - NATIONAL financing: one unemployment-insurance budget and one lump-sum tax
#    for everyone, so each place's lump-sum tax is set to make its total tax the
#    national one whatever its own unemployment.
# National results are population-weighted sums over places. Three places
# identical to the nation give back the national economy exactly (the suite).
#
# E2 fills the place specs from data (`places_from_data`): composition and
# access to work now; conversion, community and commuting next.

"""
    place_base(c, pl)

The configuration of one place before financing. `pl` is a NamedTuple with any
of `tertiary` (share of the high-education cell), `f_find`, `delta`, `omega`,
`conv` (the conversion premium, multiplying alpha); missing fields keep the
national value.
"""
function place_base(c::SAGEConfig, pl)
    kw = Dict{Symbol,Any}()
    haskey(pl, :tertiary) && (kw[:share] = (1 - pl.tertiary, pl.tertiary))
    haskey(pl, :f_find) && (kw[:f_find] = pl.f_find)
    haskey(pl, :delta) && (kw[:delta] = pl.delta)
    haskey(pl, :omega) && (kw[:omega] = pl.omega)
    haskey(pl, :commute) && (kw[:commute] = pl.commute)
    if haskey(pl, :conv)
        kw[:alpha] = (c.alpha[1] * pl.conv, c.alpha[2] * pl.conv); kw[:alpha_off] = c.alpha_off * pl.conv
    end
    SAGEConfig(c; kw...)
end

"The national total tax per head: the lump sum plus the population-weighted cost of every place's unemployment insurance."
national_tax(c::SAGEConfig, places, w) = c.lumptax + sum(w[i] * ui_tax_of(place_base(c, places[i])) for i in eachindex(places))

"One place, financed nationally: its lump sum plus its own UI tax equals the national total `T_nat`."
function place_config(c::SAGEConfig, pl, T_nat)
    cp = place_base(c, pl)
    lt = T_nat - ui_tax_of(cp)
    # a place identical to the nation gets the nation's tax exactly (rounding in
    # the national sum would otherwise change it in the last bit and force a
    # rebuild of families that are the nation's)
    abs(lt - c.lumptax) < 1e-13 && (lt = c.lumptax)
    SAGEConfig(cp; lumptax = lt)
end

# fields aggregated over places, and how: :pop weights by population, :emp by the employed
const PLACE_FIELDS = ((:rate, :pop), (:unemployment, :pop), (:A, :pop), (:A_cond, :emp), (:hardship, :pop),
                      (:hand_to_mouth_kvw, :pop), (:wealthy_htm, :pop), (:mean_income, :pop), (:mpc, :pop),
                      (:room, :pop), (:consumption_drop, :emp), (:mean_effort_employed, :emp),
                      (:shock_loss, :pop), (:dread_cost_E, :emp))

"""
    solve_places(c, places; weights)

Solve each place and aggregate. Returns `(by_place, national, T_nat)`, with
`by_place` a vector of (name, result) and `national` a NamedTuple of the
PLACE_FIELDS aggregated with population or employment weights.
"""
function solve_places(c::SAGEConfig, places; weights)
    w = collect(weights) ./ sum(weights)
    T_nat = national_tax(c, places, w)
    # hardship against the NATIONAL poverty line and asset threshold, anchored
    # on the national economy, as policy counterfactuals inherit their baseline's
    r0 = solve_economy(c)
    thr = [(r0.ypov, r0.abar)]
    rs = [solve_economy(place_config(c, pl, T_nat); thresholds = thr) for pl in places]
    emp = [w[i] * (1 - rs[i].unemployment) for i in eachindex(rs)]
    nat = Dict{Symbol,Float64}()
    for (f, how) in PLACE_FIELDS
        ww = how === :pop ? w : emp ./ sum(emp)
        nat[f] = sum(ww[i] * getfield(rs[i], f) for i in eachindex(rs))
    end
    (by_place = [(get(pl, :name, "place $i"), rs[i]) for (i, pl) in enumerate(places)],
     national = (; nat...), T_nat = T_nat)
end

# ---------------------------------------------------------- E2: from data --
# One schema, any official geography (E_PLACE_CONCEPT.md, "The standard"): the
# file data/place/place_<typology>.csv holds indicator, country, place, year,
# value, source. :degurba (cities, towns, rural) and :tl2 (OECD TL2 regions:
# NUTS 1 in France and Germany, NUTS 2 in Italy).
const PLACE_DIR = joinpath(@__DIR__, "..", "..", "data", "place")
const DEGURBA = (("cities", "DEG1"), ("towns and suburbs", "DEG2"), ("rural areas", "DEG3"))

function place_data(code; typology = :degurba)
    file = joinpath(PLACE_DIR, typology === :degurba ? "place_by_degurba.csv" : "place_$(typology).csv")
    d = Dict{Tuple{String,String},Vector{Tuple{Int,Float64}}}()
    for (k, ln) in enumerate(eachline(file))
        k == 1 && continue
        f = split(ln, ","); f[2] == code || continue
        v = tryparse(Float64, f[5]); v === nothing && continue
        push!(get!(d, (f[1], f[3]), Tuple{Int,Float64}[]), (parse(Int, f[4]), v))
    end
    d
end
latest(d, k, p) = (x = get(d, (k, p), nothing); x === nothing ? nothing : last(sort(x))[2])
meanyrs(d, k, p, yrs) = (x = get(d, (k, p), nothing); x === nothing ? nothing :
                         (v = [y[2] for y in x if y[1] in yrs]; isempty(v) ? nothing : sum(v) / length(v)))
"The places of a typology for a country: (name, code) pairs, in the file's order for TL2."
function places_of(code; typology = :degurba)
    typology === :degurba && return collect(DEGURBA)
    d = place_data(code; typology = typology)
    codes = sort(unique([k[2] for k in keys(d) if k[1] == "pop_share"]))
    [(c, c) for c in codes]
end

"""
    places_from_data(code, c; typology = :degurba, channels = (:composition, :access), epsilon = 0.4)

Place specs and population weights from the typology's file. The rule per
channel is the same under every typology:
- **composition:** the tertiary share, scaled so the population-weighted share
  equals the national one in `c`;
- **access:** job finding scaled by the place's flow into work relative to the
  mean over the unemployed: the quarterly unemployment-to-employment probability
  compounded to a year where published (degree of urbanisation, lfsi_long_e03),
  otherwise one minus the long-term share of unemployment (TL2, lfst_r_lfu2ltu, the
  national table's rule); separation scaled so the place's unemployment rate holds in steady
  state, separately for each education cell where the rate by education is
  published (TL2, lfst_r_lfu3rt), otherwise the overall rate. A place without
  flow data keeps national job finding;
- **conversion:** the place premium in income that education mix and the
  employment rate (TL2; one minus unemployment by urbanisation) do not explain (median equivalised income by urbanisation, ilc_di17;
  household disposable income per head by region, nama_10r_2hhinc), rescaled so
  the national mean is unchanged. A residual, labelled as such;
- **commuting** (degree of urbanisation only; no regional source): minutes by
  place and education (lfso_19plwk28) over usual weekly hours (lfsa_ewhun2),
  relative to the national mean;
- **community:** omega_p = omega x (infra_p / infra_national)^epsilon with
  predetermined infrastructure: France by urbanisation, sports facilities before
  1990; Italy by region, non-profit institutions per 10,000 in 2011 (ISTAT BES
  05REL008). Elsewhere national omega. epsilon 0.3 to 0.5, 0.4 by default.
"""
function places_from_data(code, c::SAGEConfig; typology = :degurba, channels = (:composition, :access), epsilon = 0.4,
                          weekly_hours = Dict("FR" => 37.6, "DE" => 35.4, "IT" => 37.2))
    d = place_data(code; typology = typology)
    pl = places_of(code; typology = typology); n = length(pl)
    w = [latest(d, "pop_share", p) for (_, p) in pl]
    any(isnothing, w) && error("no population shares by place for $code ($typology)")
    w = w ./ sum(w)
    specs = [Dict{Symbol,Any}(:name => nm) for (nm, _) in pl]
    if :composition in channels
        t = [latest(d, "tertiary_share_25_64", p) for (_, p) in pl]
        if !any(isnothing, t)
            t = t ./ 100; scale = c.share[2] / sum(w .* t)
            for i in 1:n; specs[i][:tertiary] = min(t[i] * scale, 0.95); end
        end
    end
    u = [latest(d, "unemployment_rate_20_64", p) for (_, p) in pl]
    if :access in channels && !any(isnothing, u)
        # the quarterly probability of moving into work, in percent, compounded to
        # the year the model's job finding covers (the ratio of quarterly rates
        # overstated the gap between places: audit 2026-10-02)
        annual(x) = x === nothing ? nothing : 100 * (1 - (1 - x / 100)^4)
        q = typology === :degurba ? [annual(meanyrs(d, "q_unemp_to_emp_25_54", p, 2015:2018)) for (_, p) in pl] :
                                    [(l = latest(d, "ltu_share", p); l === nothing ? nothing : 100 - l) for (_, p) in pl]
        have = [x !== nothing for x in q]
        uu = u ./ 100; un = sum(w .* uu)
        # the national rate is a mean over the UNEMPLOYED, so places weigh by their
        # unemployed, not by their population (audit 2026-10-02: population weights
        # put mean job finding 1 to 5 points below the national figure)
        wu = w .* uu
        qn = any(have) ? sum(wu[i] * q[i] for i in 1:n if have[i]) / sum(wu[have]) : 1.0
        # unemployment by education cell where published (TL2): regional gaps are
        # mostly a lower-education phenomenon, so each cell's separation follows
        # its own rate relative to its national (population-weighted) rate
        ul = [latest(d, "unemployment_rate_low_20_64", p) for (_, p) in pl]
        uh = [latest(d, "unemployment_rate_high_20_64", p) for (_, p) in pl]
        cellrate(v, i) = v[i] === nothing ? nothing : v[i] / 100
        nat(v) = (h = [x !== nothing for x in v]; any(h) ? sum(w[i] * v[i] / 100 for i in 1:n if h[i]) / sum(w[h]) : nothing)
        ul_n, uh_n = nat(ul), nat(uh)
        odds(x) = x / (1 - x)
        for i in 1:n
            f = have[i] ? min(0.99, c.f_find * q[i] / qn) : c.f_find
            s = odds(uu[i]) * f / (odds(un) * c.f_find)
            sl = (ul_n === nothing || cellrate(ul, i) === nothing) ? s : odds(cellrate(ul, i)) * f / (odds(ul_n) * c.f_find)
            sh = (uh_n === nothing || cellrate(uh, i) === nothing) ? s : odds(cellrate(uh, i)) * f / (odds(uh_n) * c.f_find)
            specs[i][:f_find] = f; specs[i][:delta] = (c.delta[1] * sl, c.delta[2] * sh)
        end
    end
    if :conversion in channels && !any(isnothing, u)
        key = typology === :degurba ? "median_income_eur" : "hh_income_per_head"
        inc = [latest(d, key, p) for (_, p) in pl]
        if !any(isnothing, inc)
            t = [get(specs[i], :tertiary, c.share[2]) for i in 1:n]
            # income per inhabitant reflects how many work, not only what work pays:
            # net out the employment rate where it is published (TL2), so that low
            # employment is not loaded into the pay of those who do work (audit
            # 2026-10-02: with 1 - u alone, Campania against Bolzano came out at
            # 0.61 where about 0.86 remains). Otherwise one minus unemployment.
            er = [latest(d, "employment_rate_20_64", p) for (_, p) in pl]
            emp = any(isnothing, er) ? [1 - u[i] / 100 for i in 1:n] : er ./ 100
            pred = [((1 - t[i]) * c.alpha[1] + t[i] * c.alpha[2]) * emp[i] for i in 1:n]
            raw = inc ./ pred; k = sum(w .* pred) / sum(w .* inc)
            for i in 1:n; specs[i][:conv] = raw[i] * k; end
        end
    end
    if :commute in channels && typology === :degurba
        h = weekly_hours[code] * 60
        tl = [(meanyrs(d, "commute_mean_minutes_ED0-2", p, 2019:2019) + meanyrs(d, "commute_mean_minutes_ED3_4", p, 2019:2019)) / 2 for (_, p) in pl]
        th = [meanyrs(d, "commute_mean_minutes_ED5-8", p, 2019:2019) for (_, p) in pl]
        τl = 10 .* tl ./ h; τh = 10 .* th ./ h
        t = [get(specs[i], :tertiary, c.share[2]) for i in 1:n]
        τbar = sum(w[i] * ((1 - t[i]) * τl[i] + t[i] * τh[i]) for i in 1:n)
        for i in 1:n; specs[i][:commute] = ((1 + τl[i]) / (1 + τbar) - 1, (1 + τh[i]) / (1 + τbar) - 1); end
    end
    if :community in channels
        infra = community_infrastructure(code, typology, [p for (_, p) in pl])
        if infra !== nothing
            nat = sum(w .* infra)
            rel = [(infra[i] / nat)^epsilon for i in 1:n]
            rel ./= sum(w .* rel)        # the population-weighted mean of omega stays the national omega
            for i in 1:n; specs[i][:omega] = min(0.95, c.omega * rel[i]); end
        end
    end
    ([(; sp...) for sp in specs], w)
end

"Predetermined community infrastructure per head, by place, where an official source exists; else nothing."
function community_infrastructure(code, typology, places)
    if code == "FR" && typology === :degurba
        inf = Dict{String,Float64}()
        for ln in eachline(joinpath(PLACE_DIR, "sports_facilities_fr.csv"))
            f = split(ln, ","); length(f) >= 5 || continue
            f[1] == "entered service before 1990 (central)" || continue
            inf[f[2]] = parse(Float64, f[5])
        end
        return [inf[n] for n in ("cities", "towns", "rural")]
    elseif code == "IT" && typology === :tl2
        inf = Dict{String,Float64}()
        for (k, ln) in enumerate(eachline(joinpath(PLACE_DIR, "italy_regions.csv")))
            k == 1 && continue
            f = split(ln, ","); inf[f[3]] = parse(Float64, f[9])      # nuts2021, np_per10k_2011
        end
        return [inf[p] for p in places]
    end
    nothing
end


# ------------------------------------------------------------ the E switch --
const E_POP = (:rate, :unemployment, :A, :hardship, :hand_to_mouth_kvw, :hand_to_mouth, :wealthy_htm, :mean_income,
               :mean_labour_income, :mpc, :mps, :mpe, :mpp, :room, :shock_loss, :shock_loss_income, :A_hardship,
               :income_poor, :asset_poor, :median_income, :consumption)
const E_EMP = (:rate_E, :A_cond, :consumption_drop, :mean_effort_employed, :dread_cost_E)

"""
    solve_economy_places(c; thresholds = nothing, cache = true)

The economy with E on: every place solved with the national financing and the
national poverty line, then aggregated. The poverty line comes, as for any
economy, from its own median: the place economies are solved once without
thresholds, the national mean income is their population-weighted mean, and
the line anchored on it (or the thresholds given, for counterfactuals). Returns
the national aggregates under the usual field names (population weights, or
employed weights for the employed-only measures; the unemployed rate by
unemployed weights), `pooled` with the national participation by education
cell, `slope` from the population-weighted multiplier, `welfare`, `by_place`,
`places` and `weights`.
"""
function solve_economy_places(c::SAGEConfig; thresholds = nothing, cache = true)
    isempty(c.country) && error("E needs the country code: build the config with country_config")
    c0 = SAGEConfig(c; E = false)
    places, w = places_from_data(c.country, c0; typology = c.typology, channels = c.e_channels, epsilon = c.epsilon)
    T_nat = national_tax(c0, places, w)
    cps = [place_config(c0, pl, T_nat) for pl in places]
    thr = thresholds
    if thr === nothing
        r1 = [_solve(cp, nothing; disk = cache, any_thresholds = true) for cp in cps]
        ym = sum(w[i] * r1[i].mean_income for i in eachindex(w))
        med = c0.poverty_line === :anchored ? c0.median_to_mean * ym : sum(w[i] * r1[i].median_income for i in eachindex(w))
        thr = [(0.5 * med, hardship_threshold(med; months = c0.months))]
    end
    rs = [solve_economy(cp; thresholds = thr, cache = cache) for cp in cps]
    nat = Dict{Symbol,Any}()
    wE = [w[i] * (1 - rs[i].unemployment) for i in eachindex(rs)]; wE ./= sum(wE)
    wU = [w[i] * rs[i].unemployment for i in eachindex(rs)]; wU ./= max(sum(wU), eps())
    for f in E_POP; nat[f] = sum(w[i] * getfield(rs[i], f) for i in eachindex(rs)); end
    for f in E_EMP; nat[f] = sum(wE[i] * getfield(rs[i], f) for i in eachindex(rs)); end
    nat[:rate_U] = sum(wU[i] * rs[i].rate_U for i in eachindex(rs))
    # participation by education cell: each place's cell weighted by its population and cell share
    cellw(g) = [w[i] * cells_of(cps[i])[g].share for i in eachindex(rs)]
    nat[:pooled] = Tuple((rate = sum(cellw(g)[i] * rs[i].pooled[g].rate for i in eachindex(rs)) / sum(cellw(g)),) for g in 1:2)
    mult = sum(w[i] / (1 - rs[i].slope) for i in eachindex(rs))
    nat[:slope] = 1 - 1 / mult
    agrid = rs[1].agrid; Wtot = sum(w[i] .* rs[i].Wtot for i in eachindex(rs))
    nat[:agrid] = agrid; nat[:Wtot] = Wtot; nat[:wealth_p50] = cdf_quantile(agrid, Wtot, 0.5)
    # two assets: the net-wealth and illiquid distributions, summed over places the same way
    hasproperty(rs[1], :Ntot) && (nat[:Ntot] = sum(w[i] .* rs[i].Ntot for i in eachindex(rs)))
    hasproperty(rs[1], :Ktot) && (nat[:Ktot] = sum(w[i] .* rs[i].Ktot for i in eachindex(rs)); nat[:kgrid] = rs[1].kgrid)
    ws = [r.welfare for r in rs]
    comp(k) = sum(w[i] * getfield(ws[i], k) for i in eachindex(ws))
    nat[:welfare] = (V = comp(:V), Vc = comp(:Vc), Ve = comp(:Ve), Vb = comp(:Vb),
                     cell = Tuple((V = sum(cellw(g)[i] * ws[i].cell[g].V for i in eachindex(ws)) / sum(cellw(g)),
                                   Vc = sum(cellw(g)[i] * ws[i].cell[g].Vc for i in eachindex(ws)) / sum(cellw(g))) for g in 1:2),
                     status = ((V = sum(wE[i] * ws[i].status[1].V for i in eachindex(ws)), Vc = sum(wE[i] * ws[i].status[1].Vc for i in eachindex(ws))),
                               (V = sum(wU[i] * ws[i].status[2].V for i in eachindex(ws)), Vc = sum(wU[i] * ws[i].status[2].Vc for i in eachindex(ws)))))
    nat[:consumption_cell] = Tuple(sum(cellw(g)[i] * rs[i].consumption_cell[g] for i in eachindex(rs)) / sum(cellw(g)) for g in 1:2)
    nat[:consumption_status] = (sum(wE[i] * rs[i].consumption_status[1] for i in eachindex(rs)),
                                sum(wU[i] * rs[i].consumption_status[2] for i in eachindex(rs)))
    nat[:ypov] = thr[1][1]; nat[:abar] = thr[1][2]
    nat[:config] = c; nat[:by_place] = [(get(pl, :name, "place $i"), rs[i]) for (i, pl) in enumerate(places)]
    nat[:places] = places; nat[:weights] = w; nat[:T_nat] = T_nat
    (; nat...)
end

"""
    scan_technology_places(cps, fams, w, sigmas, kappas; targets, aggregate, nq, max_mult)

`scan_technology` with E on. For each (sigma, kappa), every place solves its own
participation fixed point on its own families (`fams[i]`, the unemployed rule
imposed), the selected equilibrium being the highest stable one as
`solve_economy` selects, and the national participation by education cell is
the population- and cell-share-weighted sum. The loss is against the two cell
targets, or with `aggregate` against overall participation. The multiplier is
the population-weighted mean of the places' multipliers, and the gate applies to
it. The kappa search is global at every sigma.
"""
function scan_technology_places(cps, fams, w, sigmas, kappas; targets = (0.25, 0.45), aggregate = nothing,
                                nq = cps[1].nq, xgrid = 0.0:0.02:60.0, max_mult = Inf)   # the solver's quadrature (500 here put the scan 0.002 off the solve)
    XG = collect(xgrid); gr = range(0.0, 1.0, length = 401); np = length(cps)
    css = [cells_of(cp) for cp in cps]
    cw = [[w[i] * css[i][g].share for i in 1:np] for g in 1:2]
    rows = NamedTuple[]
    for σ in sigmas
        ms = taste_nodes_ln(σ; n = nq)
        tab(u, col) = [mean(interp(u, col, x * m) for m in ms) for x in XG]
        T = [(tab(cps[i].ugrid, [n.rate for n in fams[i][1]]), tab(cps[i].ugrid, [n.rate for n in fams[i][2]])) for i in 1:np]
        best = nothing
        for κ in kappas
            lo = zeros(np); hi = zeros(np); msum = 0.0; ok = true
            for i in 1:np
                cs = css[i]; ω = cps[i].omega
                f(r) = (arg = ω + (1 - ω) * r;
                        l = interp(XG, T[i][1], κ * cs[1].B * arg); h = interp(XG, T[i][2], κ * cs[2].B * arg);
                        (cs[1].share * l + cs[2].share * h, l, h))
                o = [f(r)[1] for r in gr]; sel = nothing
                for k in 1:400
                    d1 = o[k] - gr[k]; d2 = o[k+1] - gr[k+1]
                    (d1 == 0 || sign(d1) != sign(d2)) || continue
                    sl = (o[k+1] - o[k]) / (gr[k+1] - gr[k]); sl < 1 || continue
                    sel = (r = gr[k] + d1 / (d1 - d2) * (gr[k+1] - gr[k]), sl = sl)     # the highest is kept
                end
                sel === nothing && (ok = false; break)
                _, lo[i], hi[i] = f(sel.r); msum += w[i] / (1 - sel.sl)
            end
            ok || continue
            msum > max_mult && continue
            nlo = sum(cw[1] .* lo) / sum(cw[1]); nhi = sum(cw[2] .* hi) / sum(cw[2])
            rate = sum(w[i] * (css[i][1].share * lo[i] + css[i][2].share * hi[i]) for i in 1:np)
            L = aggregate === nothing ? (nlo - targets[1])^2 + (nhi - targets[2])^2 : (rate - aggregate)^2
            (best === nothing || L < best.L) && (best = (L = L, κ = κ, r = rate, lo = nlo, hi = nhi, mult = msum))
        end
        best === nothing && continue
        push!(rows, (σ = σ, κ = best.κ, loss = sqrt(best.L), r = best.r, lo = best.lo, hi = best.hi,
                     slope = 1 - 1 / best.mult, mult = best.mult))
    end
    rows
end
