# E on the base with the state out of work (V3_START.md section 92): the country as places of an
# official geography, each its own economy under one national tax rate, at the national parameters
# (nothing refitted). The channels enter one after another, so each one's part can be read:
#   1. composition, access to work and the state out of work (the place's share of jobless households);
#   2. with conversion (official income per head over what the model's place already gives, jobless households included);
#   3. with commuting (degree of urbanisation only) and, with S on, community.
# First: identical places give back the national economy.
# Untargeted, France by degree of urbanisation: the hand-to-mouth share by place against the HFCS 2021
# (the not retired, the population the base is fitted to) and, with S
# on, formal volunteering by place (EU-SILC 2022, ilc_scp20).
#
#   julia --project=scripts/run_env scripts/run_places_base.jl CODE [degurba | tl2] [G | GS | GA | GSA] [last: the full set of channels alone, without the reduction | reduction: the first test alone]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
code = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "FR"
typ = length(ARGS) >= 2 ? Symbol(lowercase(ARGS[2])) : :degurba
cfg = length(ARGS) >= 3 ? uppercase(ARGS[3]) : "G"
S_ON = occursin('S', cfg); A_ON = occursin('A', cfg)
ONLY_LAST = length(ARGS) >= 4 && lowercase(ARGS[4]) == "last"
c = country_config(code; config = cfg, v3 = :v5m, S = S_ON, A = A_ON)
pl = places_of(code; typology = typ)
d = place_data(code; typology = typ)
t0 = @elapsed r0 = solve_economy(c)
@printf("%s %s, the base, %d places (%s) | national economy [%.1f min]: out of work %.4f, hand-to-mouth %.4f, hours %.4f, participation %.4f, median income %.4f\n",
        code, cfg, length(pl), typ, t0 / 60, r0.unemployment, r0.hand_to_mouth_kvw, r0.mean_effort_employed, r0.rate, r0.median_income)
flush(stdout)

w0 = [latest(d, "pop_share", p) for (_, p) in pl]; w0 = w0 ./ sum(w0)
same = [(name = nm,) for (nm, _) in pl][1:min(3, length(pl))]
# with `last` the reduction is left to its own run (it is three more place solves)
sp0 = ONLY_LAST ? nothing : solve_places(c, same; weights = w0[1:length(same)])
worst = ONLY_LAST ? 0.0 : maximum(abs(getfield(sp0.national, f) - getfield(r0, f)) for (f, _) in PLACE_FIELDS if isfinite(getfield(r0, f)))
ONLY_LAST || @printf("REDUCTION: %d identical places against the nation, largest difference %.1e: %s\n", length(same), worst, worst < 1e-10 ? "PASS" : "FAIL")
if worst >= 1e-10
    # where the difference is: the financing first (total tax per head, the base of the proportional tax), then each aggregate
    cpl = place_config(c, same[1], sp0.T_nat); cn = floor_effort(c)
    @printf("   national total per head: places %.8f | nation: lump sum %.8f + insurance %.8f + floor %.8f = %.8f\n", sp0.T_nat, c.lumptax, ui_only_tax_of(c),
            floor_tax_of(c), c.lumptax + ui_only_tax_of(c) + floor_tax_of(c))
    @printf("   base of the tax: places %.8f | nation's own %.8f | given to the nation %.8f\n", NAT_TAX_BASE[][2], labour_base(SAGEConfig(cn; S = false)), c.tax_base)
    @printf("   one place against the nation: lump sum %.8f %.8f | floor tax given %.8f %.8f | job effort %s %s\n", cpl.lumptax, c.lumptax, cpl.floor_tax_given,
            c.floor_tax_given, floor_effort(cpl).effort_by_cell == cn.effort_by_cell ? "the same" : "DIFFERENT", "")
    for (f, _) in PLACE_FIELDS
        a = getfield(sp0.national, f); b = getfield(r0, f)
        isfinite(b) && abs(a - b) >= 1e-10 && @printf("   %-22s places %.8f nation %.8f difference %+.1e\n", f, a, b, a - b)
    end
end
flush(stdout)
length(ARGS) >= 4 && lowercase(ARGS[4]) == "reduction" && (println("DONE"); exit())

htm = Dict{String,Float64}(); vol = Dict{String,Float64}()
if typ === :degurba
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == "htm_model_narrow_total" && f[2] == code && f[3] == "2021" && f[4] == "degurba_nr" && (htm[f[5]] = parse(Float64, f[6]))
    end
end
for ((ind, place), xs) in d
    ind == "formal_volunteering" && (vol[place] = last(sort(xs))[2])
end
hname(nm) = nm == "rural areas" ? "rural" : nm

sets = Any[("composition, access to work, the state out of work", (:composition, :access, :out_of_work)),
           ("with conversion", (:composition, :access, :out_of_work, :conversion_net))]
last_ch = (:composition, :access, :out_of_work, :conversion_net, (typ === :degurba ? (:commute,) : ())..., (S_ON ? (:community,) : ())...)
length(last_ch) > 4 && push!(sets, ("with " * join([x === :commute ? "commuting" : "community" for x in last_ch[5:end]], " and "), last_ch))
ONLY_LAST && (sets = sets[end:end])
for (lab, ch) in sets
    places, w = places_from_data(code, c; typology = typ, channels = ch, epsilon = c.epsilon)
    t = @elapsed sp = solve_places(c, places; weights = w)
    @printf("\n%s  [%.1f min; national tax per head %.4f]\n", lab, t / 60, sp.T_nat)
    @printf("  %-18s %6s %8s %6s %15s %15s %6s | %8s %8s %8s %8s %8s %8s\n", "place", "pop %", "tertiary", "find", "job loss", "exit", "conv",
            "out", "htm", "hours", "part.", "poor", "income")
    for (((name, r), p), wi) in zip(zip(sp.by_place, places), w)
        dl = get(p, :delta, c.delta); fl = get(p, :f_long, c.f_long)
        @printf("  %-18s %6.1f %8.3f %6.3f %7.4f %7.4f %7.3f %7.3f %6.3f | %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f\n", name, 100 * wi, get(p, :tertiary, c.share[2]),
                get(p, :f_find, c.f_find), dl..., fl..., get(p, :conv, 1.0), r.unemployment, r.hand_to_mouth_kvw, r.mean_effort_employed, r.rate, r.income_poor, r.mean_income)
    end
    n = sp.national
    @printf("  %-18s %63s | %8.4f %8.4f %8.4f %8.4f\n", "places together", "", n.unemployment, n.hand_to_mouth_kvw, n.mean_effort_employed, n.rate)
    @printf("  %-18s %63s | %8.4f %8.4f %8.4f %8.4f\n", "national economy", "", r0.unemployment, r0.hand_to_mouth_kvw, r0.mean_effort_employed, r0.rate)
    names = [nm for (nm, _) in sp.by_place]; codes = [p for (_, p) in pl]
    if !isempty(htm) && all(haskey(htm, hname(nm)) for nm in names)
        m = [r.hand_to_mouth_kvw for (_, r) in sp.by_place]; h = [htm[hname(nm)] for nm in names]
        @printf("  untargeted, hand-to-mouth by place over the first place: model %s | HFCS 2021, not retired %s\n",
                join([@sprintf("%.2f", x / m[1]) for x in m], " "), join([@sprintf("%.2f", x / h[1]) for x in h], " "))
    end
    if S_ON && all(haskey(vol, p) for p in codes)
        m = [r.rate for (_, r) in sp.by_place]; v = [vol[p] for p in codes]
        @printf("  untargeted, participation by place over the first place: model %s | volunteering %s", join([@sprintf("%.2f", x / m[1]) for x in m], " "),
                join([@sprintf("%.2f", x / v[1]) for x in v], " "))
        length(m) > 3 && @printf(" | correlation %.2f, spread (sd of log) model %.3f, data %.3f", cor(m, v), std(log.(m)), std(log.(v)))
        println()
    end
    flush(stdout)
end
println("DONE")
