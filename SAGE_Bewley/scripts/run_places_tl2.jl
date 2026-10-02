# E at the OECD TL2 level (E_PLACE_CONCEPT.md, "The standard"): each region its
# own economy with composition, access to work and conversion from Eurostat
# regional data, community where predetermined infrastructure exists (Italy:
# non-profits 2011), local feedback and national financing. Untargeted check
# for Italy: organised volunteering by region (ISTAT, annual survey 2023-25),
# correlation and slope of model participation on it.
#
#   julia --project=scripts/run_env scripts/run_places_tl2.jl IT
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
code = length(ARGS) >= 1 ? ARGS[1] : "IT"
c = country_config(code; config = "GSA", S = true, A = true)
pl = places_of(code; typology = :tl2)
vol = Dict{String,Float64}()
if code == "IT"
    for (k, ln) in enumerate(eachline(joinpath(PLACE_DIR, "italy_regions.csv")))
        k == 1 && continue
        f = split(ln, ","); vol[f[3]] = parse(Float64, f[8])     # avq_vol_2023_25
    end
end
# Germany (and any country with the indicator in the regional table): formal
# volunteering by region, here the Freiwilligensurvey 2019 by Land. No German
# infrastructure enters the model, so this is untargeted in every channel.
if isempty(vol)
    for ((ind, place), xs) in place_data(code; typology = :tl2)
        ind == "formal_volunteering" && (vol[place] = last(sort(xs))[2])
    end
end
base_ch = (:composition, :access, :conversion)
runs = Any[("composition, access, conversion", base_ch, 0.4)]
if code == "IT"
    push!(runs, ("with community, epsilon 0.3", (base_ch..., :community), 0.3))
    push!(runs, ("with community, epsilon 0.5", (base_ch..., :community), 0.5))
end
r0 = solve_economy(c)
@printf("%s national G+S+A: participation %.4f, agency %.4f, protection %.4f, hardship %.4f | %d TL2 regions\n",
        code, r0.rate, r0.A, r0.A_cond, r0.hardship, length(pl))
for (lab, ch, eps) in runs
    places, w = places_from_data(code, c; typology = :tl2, channels = ch, epsilon = eps)
    t = @elapsed sp = solve_places(c, places; weights = w)
    println("\n", lab, @sprintf("  [%.1f min]", t / 60))
    @printf("  %-6s %6s %8s %8s %8s %8s %8s %8s %6s %s\n", "region", "pop %", "tertiary", "part.", "unempl.", "agency", "prot.", "hardship", "mult", isempty(vol) ? "" : "  volunteering")
    for ((name, r), p, wi) in zip(sp.by_place, places, w)
        @printf("  %-6s %6.1f %8.3f %8.4f %8.4f %8.4f %8.4f %8.4f %6.1f %s\n", name, 100 * wi, get(p, :tertiary, NaN), r.rate,
                r.unemployment, r.A, r.A_cond, r.hardship, 1 / (1 - r.slope), haskey(vol, name) ? @sprintf("  %.1f", vol[name]) : "")
    end
    n = sp.national
    @printf("  together: participation %.4f (national economy %.4f), agency %.4f, hardship %.4f\n", n.rate, r0.rate, n.A, n.hardship)
    if !isempty(vol)
        have = [haskey(vol, name) for (name, _) in sp.by_place]
        m = [r.rate for (name, r) in sp.by_place][have]; v = [vol[name] for (name, _) in sp.by_place if haskey(vol, name)]
        w = w[have] ./ sum(w[have])
        lm, lv = log.(m), log.(v)
        b = cov(lm, lv) / var(lv)
        @printf("  untargeted test: correlation of model participation with volunteering across regions %.2f; log-log slope %.2f; population-weighted spread (sd of log) model %.3f, data %.3f\n",
                cor(m, v), b, sqrt(sum(w .* (lm .- sum(w .* lm)).^2)), sqrt(sum(w .* (lv .- sum(w .* lv)).^2)))
    end
    flush(stdout)
end
println("DONE")
