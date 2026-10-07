# E's environmental side as indicators on the base (V3_START.md, section 27, row B1): the household
# greenhouse-gas footprint per head, by education, by employment status and by place. The national
# figure is the official one (Eurostat env_ac_ghgfp: consumption-based, imports included, households'
# direct emissions included; data/sustainability/footprint_intensity.csv); groups and places differ by
# their consumption at the country's intensity per euro. It is an indicator here, not a policy.
# What it does not yet carry: the composition of consumption by group (a poorer household's basket is
# more carbon-intensive per euro). Exposure to the local environment is reported by type of place from
# official data (second part), not modelled.
#
#   julia --project=scripts/run_env scripts/e_environment.jl [CONFIG with E] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GAE"
codes = length(ARGS) >= 2 ? uppercase.(ARGS[2:end]) : ["FR", "DE", "IT"]
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"); flush(stdout))
for code in codes
    try
        c = country_config(code; config = cfg, v3 = :floor_edu_trans, S = occursin('S', cfg), A = occursin('A', cfg))
        r = solve_economy(c; cache = false)
        e = emissions(r; code = code); rows = place_report(r; code = code)
        w = [x.weight for x in rows]; em = [x.emissions for x in rows]
        @printf("%s %s, %d places | footprint per head %.2f t CO2e (official %.2f), %.3f kg per euro of consumption\n", code, cfg, length(rows), e.total,
                e.total, footprint_intensity(code))
        @printf("   by education: below tertiary %.2f, tertiary %.2f (ratio %.2f) | by status: employed %.2f, out of work %.2f (ratio %.2f)\n",
                e.cells[1], e.cells[2], e.cells[2] / e.cells[1], e.status[1], e.status[2], e.status[2] / e.status[1])
        o = sortperm(em)
        @printf("   by place: lowest %.2f (%s), highest %.2f (%s), ratio %.2f | population-weighted standard deviation %.2f\n", em[o[1]], rows[o[1]].place,
                em[o[end]], rows[o[end]].place, em[o[end]] / em[o[1]], sqrt(sum(w .* (em .- sum(w .* em)) .^ 2) / sum(w)))
        check("$code: the places give back the national footprint to 1e-6", abs(sum(w .* em) / sum(w) - e.total) < 1e-6 * e.total + 1e-9)
        check("$code: the education cells weighted by their shares give back the national footprint to 1%",
              abs(sum(c.share[g] * e.cells[g] for g in 1:2) - e.total) < 0.01 * e.total)
    catch err
        println("   ", first(replace(sprint(showerror, err), "\n" => " "), 300)); check("$code: runs", false)
    end
    flush(stdout)
end
# BY TYPE OF PLACE (cities, towns and suburbs, rural areas): the two environmental sides together. The
# footprint is the model's, as above, with the place layer on the degree-of-urbanisation typology at the
# base's parameters (calibrated on regions: nothing is refitted, so the national figures move a little).
# Exposure is official and not modelled: the share of people reporting pollution, grime or other
# environmental problems where they live (Eurostat ilc_mddw05, data/place/place_by_degurba.csv).
function degurba_value(code, ind, pl)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "place", "place_by_degurba.csv"))
        f = split(ln, ","); length(f) >= 5 && f[1] == ind && f[2] == code && f[3] == pl && return parse(Float64, f[5])
    end
    NaN
end
function hfcs_degurba(code, moment, grp)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 6 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "degurba" && f[5] == grp && return parse(Float64, f[6])
    end
    NaN
end
println("\nby type of place")
for code in codes
    try
        c = SAGEConfig(country_config(code; config = cfg, v3 = :floor_edu_trans, S = occursin('S', cfg), A = occursin('A', cfg)); typology = :degurba)
        r = solve_economy(c; cache = false); rows = place_report(r; code = code)
        @printf("%s %s on the three types of place | national hand-to-mouth %.3f | footprint %.2f t CO2e per head\n", code, cfg, r.hand_to_mouth_kvw, emissions(r; code = code).total)
        @printf("   %-20s %7s %10s %12s %14s %10s\n", "", "weight", "footprint", "exposure, %", "hand-to-mouth", "HFCS")
        hk = ("cities", "towns and suburbs", "rural")
        for (i, (nm, pl)) in enumerate((("cities", "DEG1"), ("towns and suburbs", "DEG2"), ("rural areas", "DEG3")))
            @printf("   %-20s %7.3f %10.2f %12.1f %14.3f %10.3f\n", nm, rows[i].weight, rows[i].emissions, degurba_value(code, "pollution_grime", pl),
                    r.by_place[i][2].hand_to_mouth_kvw, hfcs_degurba(code, "htm_model_narrow_total", hk[i]))
        end
        ex = [degurba_value(code, "pollution_grime", pl) for pl in ("DEG1", "DEG2", "DEG3")]
        check("$code: exposure by type of place is in the data for the three types", all(isfinite, ex))
    catch err
        println("   ", first(replace(sprint(showerror, err), "\n" => " "), 300)); check("$code by type of place: runs", false)
    end
    flush(stdout)
end
np = count(last, results)
println(np, " of ", length(results), " checks pass", np == length(results) ? "" : "; FAILED: " * join([n for (n, ok) in results if !ok], "; "))
println("DONE")
