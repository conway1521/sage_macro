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
place_config(c::SAGEConfig, pl, T_nat) = (cp = place_base(c, pl); SAGEConfig(cp; lumptax = T_nat - ui_tax_of(cp)))

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
  population-weighted mean: the quarterly unemployment-to-employment probability
  where published (degree of urbanisation, lfsi_long_e03), otherwise one minus the
  long-term share of unemployment (TL2, lfst_r_lfu2ltu, the national table's
  rule); separation scaled so the place's unemployment rate holds in steady
  state. A place without flow data keeps national job finding;
- **conversion:** the place premium in income that education mix and employment
  do not explain (median equivalised income by urbanisation, ilc_di17;
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
        q = typology === :degurba ? [meanyrs(d, "q_unemp_to_emp_25_54", p, 2015:2018) for (_, p) in pl] :
                                    [(l = latest(d, "ltu_share", p); l === nothing ? nothing : 100 - l) for (_, p) in pl]
        have = [x !== nothing for x in q]
        qn = any(have) ? sum(w[i] * q[i] for i in 1:n if have[i]) / sum(w[have]) : 1.0
        uu = u ./ 100; un = sum(w .* uu)
        for i in 1:n
            f = have[i] ? min(0.99, c.f_find * q[i] / qn) : c.f_find
            s = (uu[i] / (1 - uu[i])) * f / ((un / (1 - un)) * c.f_find)
            specs[i][:f_find] = f; specs[i][:delta] = (c.delta[1] * s, c.delta[2] * s)
        end
    end
    if :conversion in channels && !any(isnothing, u)
        key = typology === :degurba ? "median_income_eur" : "hh_income_per_head"
        inc = [latest(d, key, p) for (_, p) in pl]
        if !any(isnothing, inc)
            t = [get(specs[i], :tertiary, c.share[2]) for i in 1:n]
            pred = [((1 - t[i]) * c.alpha[1] + t[i] * c.alpha[2]) * (1 - u[i] / 100) for i in 1:n]
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
            for i in 1:n; specs[i][:omega] = min(0.95, c.omega * (infra[i] / nat)^epsilon); end
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
