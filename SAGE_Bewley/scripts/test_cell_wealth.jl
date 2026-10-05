# The same question as the regional wealth test, inside each country and on better-measured data:
# who holds no buffer, by education? The model's two cells are the HFCS's two groups (below tertiary,
# tertiary). Untargeted: the calibration targets the national hand-to-mouth share and nothing by cell.
# HFCS 2021: the hand-to-mouth share is about twice as high below tertiary in all three countries, and
# liquid wealth over income lower. A Bewley household holds more buffers where risk is higher, and
# the lower-education cell has the higher unemployment risk, so the model can have it the wrong way
# round, as it has the regions.
#
#   julia --project=scripts/run_env scripts/test_cell_wealth.jl [CONFIG] [v3 | v3f | v3e | v3fe] [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GA"
reg = length(ARGS) >= 2 ? lowercase(ARGS[2]) : "v3"
codes = length(ARGS) >= 3 ? uppercase.(ARGS[3:end]) : ["FR", "DE", "IT"]
function hfcs(code, moment, grp)
    for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
        startswith(ln, "#") && continue
        f = split(ln, ",")
        length(f) >= 7 && f[1] == moment && f[2] == code && f[3] == "2021" && f[4] == "education" && f[5] == grp && return (parse(Float64, f[6]), parse(Float64, f[7]))
    end
    (NaN, NaN)
end
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"))
for code in codes
    c = country_config(code; v3 = Dict("v3f" => :floor, "v3e" => :edu, "v3fe" => :floor_edu, "v3" => true)[reg], config = cfg, S = occursin('S', cfg), A = occursin('A', cfg))
    r = solve_economy(c)
    htm = [sum(r.pooled[g].hmass) / sum(r.pooled[g].mass) for g in 1:2]
    liq = [(cm = vec(sum(r.pooled[g].W, dims = 1)); cdf_quantile(r.agrid, cm ./ cm[end], 0.5) / r.median_income) for g in 1:2]
    un = [1 - sum(r.pooled[g].mass[r.employed]) / sum(r.pooled[g].mass) for g in 1:2]
    @printf("\n%s %s (%s): national hand-to-mouth %.3f | unemployment by cell %.3f, %.3f | pay by cell %.3f, %.3f\n", code, cfg, reg, r.hand_to_mouth_kvw, un..., c.A ? c.alpha[1] : c.alpha_off, c.A ? c.alpha[2] : c.alpha_off)
    for (g, grp) in enumerate(("below tertiary", "tertiary"))
        h = hfcs(code, "htm_model_narrow_total", grp); l = hfcs(code, "liquid_kvw_to_disposable_income_ratio_of_medians", grp)
        @printf("   %-15s hand-to-mouth: model %.3f | HFCS %.3f (s.e. %.3f)   liquid wealth, median over the national median income: model %.3f | HFCS, over the group's own income %.3f (s.e. %.3f)\n",
                grp, htm[g], h..., liq[g], l...)
    end
    hl = hfcs(code, "htm_model_narrow_total", "below tertiary")[1]; hh = hfcs(code, "htm_model_narrow_total", "tertiary")[1]
    @printf("   below tertiary over tertiary: model %.2f, HFCS %.2f\n", htm[1] / htm[2], hl / hh)
    check("$code: the lower-education cell is the more hand-to-mouth, as in the HFCS", (htm[1] > htm[2]) == (hl > hh))
end
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks pass\n", length(results) - nf, length(results))
println("DONE")
