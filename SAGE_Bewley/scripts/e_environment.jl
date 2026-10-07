# E's environmental side as indicators on the base (V3_START.md, section 27, row B1): the household
# greenhouse-gas footprint per head, by education, by employment status and by place. The national
# figure is the official one (Eurostat env_ac_ghgfp: consumption-based, imports included, households'
# direct emissions included; data/sustainability/footprint_intensity.csv); groups and places differ by
# their consumption at the country's intensity per euro. It is an indicator here, not a policy.
# What it does not yet carry: the composition of consumption by group (a poorer household's basket is
# more carbon-intensive per euro), and exposure to the local environment by place.
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
np = count(last, results)
println(np, " of ", length(results), " checks pass", np == length(results) ? "" : "; FAILED: " * join([n for (n, ok) in results if !ok], "; "))
println("DONE")
