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
const PLACE_FILE = joinpath(@__DIR__, "..", "..", "data", "place", "place_by_degurba.csv")
const DEGURBA = (("cities", "DEG1"), ("towns and suburbs", "DEG2"), ("rural areas", "DEG3"))

function place_data(code)
    d = Dict{Tuple{String,String},Vector{Tuple{Int,Float64}}}()
    for (k, ln) in enumerate(eachline(PLACE_FILE))
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

"""
    places_from_data(code, c; channels = (:composition, :access))

Place specs from `data/place/place_by_degurba.csv`, and population weights
(ilc_lvho01):
- **composition:** the tertiary share by place (edat_lfs_9913, latest year),
  scaled so the population-weighted share equals the national one in `c`;
- **access:** job finding scaled by the place's quarterly unemployment-to-
  employment probability over its population-weighted mean (lfsi_long_e03,
  2015 to 2018), and separation scaled so that the place's unemployment rate
  (lfst_r_urgau, latest) holds in steady state, with the two education cells
  keeping their relative separation rates. Without flows by place (Germany),
  job finding stays national and separation carries the unemployment rate.
- **conversion:** the place premium in pay that education mix and
  unemployment do not explain: median equivalised income by place (ilc_di17)
  over the income predicted from the place's education mix at the calibrated
  pay ratio and its employment rate, rescaled so the national mean is unchanged.
  A residual, labelled as such: no official source gives earnings by place and
  education together.
- **community:** omega_p = omega x (infra_p / infra_national)^epsilon, with
  predetermined infrastructure (France: sports facilities in service before
  1990, `data/place/sports_facilities_fr.csv`). epsilon between 0.3 and 0.5
  from France and Italy (E_PLACE_CONCEPT.md); 0.4 by default, report both ends.
  Germany and Italy have no infrastructure by degree of urbanisation yet, so
  they keep the national omega.
Channels without data for a place keep the national value.
"""
function places_from_data(code, c::SAGEConfig; channels = (:composition, :access), epsilon = 0.4,
                          weekly_hours = Dict("FR" => 37.6, "DE" => 35.4, "IT" => 37.2))
    d = place_data(code)
    w = [latest(d, "pop_share", p) for (_, p) in DEGURBA]
    any(isnothing, w) && error("no population shares by place for $code")
    w = w ./ sum(w)
    specs = [Dict{Symbol,Any}(:name => n) for (n, _) in DEGURBA]
    if :composition in channels
        t = [latest(d, "tertiary_share_25_64", p) for (_, p) in DEGURBA]
        if !any(isnothing, t)
            t = t ./ 100; scale = c.share[2] / sum(w .* t)
            for i in 1:3; specs[i][:tertiary] = min(t[i] * scale, 0.95); end
        end
    end
    if :access in channels
        u = [latest(d, "unemployment_rate_20_64", p) for (_, p) in DEGURBA]
        q = [meanyrs(d, "q_unemp_to_emp_25_54", p, 2015:2018) for (_, p) in DEGURBA]
        if !any(isnothing, u)
            # without flows by place (Germany), job finding stays national and
            # separation alone carries the place's unemployment rate
            haveq = !any(isnothing, q)
            u = u ./ 100; qn = haveq ? sum(w .* q) : 1.0; un = sum(w .* u)
            for i in 1:3
                f = haveq ? min(0.99, c.f_find * q[i] / qn) : c.f_find
                s = (u[i] / (1 - u[i])) * f / ((un / (1 - un)) * c.f_find)
                specs[i][:f_find] = f; specs[i][:delta] = (c.delta[1] * s, c.delta[2] * s)
            end
        end
    end
    if :conversion in channels
        inc = [latest(d, "median_income_eur", p) for (_, p) in DEGURBA]
        u = [latest(d, "unemployment_rate_20_64", p) for (_, p) in DEGURBA]
        if !any(isnothing, inc) && !any(isnothing, u)
            t = [get(specs[i], :tertiary, c.share[2]) for i in 1:3]
            pred = [((1 - t[i]) * c.alpha[1] + t[i] * c.alpha[2]) * (1 - u[i] / 100) for i in 1:3]
            raw = inc ./ pred
            k = sum(w .* pred) / sum(w .* inc)
            for i in 1:3; specs[i][:conv] = raw[i] * k; end
        end
    end
    if :commute in channels
        # one-way minutes by place and education (lfso_19plwk28, 2019) over usual
        # weekly hours (lfsa_ewhun2, 2019, employed 20 to 64: FR 37.6, DE 35.4,
        # IT 37.2), five commuting days: tau = 2 x minutes x 5 / (hours x 60).
        # The low cell averages ED0-2 and ED3_4. Relative to the population-
        # weighted national tau, since the national effort scale absorbs the mean.
        h = weekly_hours[code] * 60
        tl = [(meanyrs(d, "commute_mean_minutes_ED0-2", p, 2019:2019) + meanyrs(d, "commute_mean_minutes_ED3_4", p, 2019:2019)) / 2 for (_, p) in DEGURBA]
        th = [meanyrs(d, "commute_mean_minutes_ED5-8", p, 2019:2019) for (_, p) in DEGURBA]
        τl = 10 .* tl ./ h; τh = 10 .* th ./ h
        t = [get(specs[i], :tertiary, c.share[2]) for i in 1:3]
        τbar = sum(w[i] * ((1 - t[i]) * τl[i] + t[i] * τh[i]) for i in 1:3)
        for i in 1:3; specs[i][:commute] = ((1 + τl[i]) / (1 + τbar) - 1, (1 + τh[i]) / (1 + τbar) - 1); end
    end
    if :community in channels && code == "FR"
        inf = Dict{String,Tuple{Float64,Float64}}()
        for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "place", "sports_facilities_fr.csv"))
            f = split(ln, ","); length(f) >= 5 || continue
            f[1] == "entered service before 1990 (central)" || continue
            inf[f[2]] = (parse(Float64, f[5]), parse(Float64, f[4]))
        end
        per = [inf[n][1] for n in ("cities", "towns", "rural")]; pop = [inf[n][2] for n in ("cities", "towns", "rural")]
        nat = sum(per .* pop) / sum(pop)
        for i in 1:3; specs[i][:omega] = min(0.95, c.omega * (per[i] / nat)^epsilon); end
    end
    ([(; sp...) for sp in specs], w)
end
