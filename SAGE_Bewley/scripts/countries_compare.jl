# Run the model for every country in COUNTRIES, print targeted and untargeted
# moments side-by-side with the data targets. Honest reporting: where the model
# misses a target by more than a small tolerance, the cell is flagged.
#
#   julia --project=. scripts/countries_compare.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using Printf

const CODES = ("FR", "DE", "IT", "US", "CO", "ZA", "CN")

function row(code)
    p = country_params(code)
    s = solve_model(p)
    e_mean = sum(s.λ .* s.e)
    wg = wealth_gini(s); ig = income_gini(s); htm = frac_constrained(s)
    sh = public_good_shares(s)
    tg = country_targets(code)
    return (code = code, e_mean = e_mean, Q = s.Q, wg = wg, ig = ig, htm = htm,
            sh_low = sh[1], tg = tg, p = p)
end

results = [row(c) for c in CODES]

println("CALIBRATED MOMENTS (model vs targets)")
println("-"^96)
@printf("%-3s | %-13s | %-13s | %-13s | %-13s | %s\n",
        "cty", "wealth Gini", "HtM share", "work share", "income Gini", "social fabric Q (untargeted)")
println("-"^96)
function fmt(model, target)
    miss = abs(model - target) > 0.10
    @sprintf("%5.2f / %5.2f%s", model, target, miss ? " *" : "  ")
end
for r in results
    @printf("%-3s | %s | %s | %s | %s | %.3f\n",
            r.code,
            fmt(r.wg, r.tg.wealth_gini),
            fmt(r.htm, r.tg.htm),
            fmt(1 - r.Q, r.tg.work_share),                 # work share = 1 - Q
            fmt(r.ig, r.tg.income_gini),
            r.Q)
end
println("-"^96)
println("(starred entries miss the target by more than 0.10; columns are model / target)")
println()
println("UNTARGETED diagnostics by country")
@printf("%-3s | %-22s | %-22s\n", "cty", "low-edu supplies of Q", "country note")
for r in results
    @printf("%-3s | %18.1f%%  | %s\n", r.code, 100 * r.sh_low, COUNTRIES[r.code].note)
end
