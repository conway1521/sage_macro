# Is hardship by place wrong-signed because of the one-asset model? G+A with E
# over TL2 regions (composition, access, conversion), one asset against two,
# each region's income poverty, asset poverty and hardship against the official
# at-risk-of-poverty rate by region (ilc_li41, 60% of the national median; the
# model's income poverty is at 50%, so patterns are compared, not levels).
# Regions inherit the national poverty line (anchored, as counterfactuals do).
#
#   julia --project=scripts/run_env scripts/probe_hardship_by_place.jl IT
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
code = length(ARGS) >= 1 ? ARGS[1] : "IT"
d = place_data(code; typology = :tl2)
ch = (:composition, :access, :conversion)
function run(lab, c)
    r0 = solve_economy(c)
    thr = [(r0.ypov, r0.abar)]
    t = @elapsed rE = solve_economy(SAGEConfig(c; E = true, typology = :tl2, e_channels = ch); thresholds = thr)
    names = [n for (n, _) in rE.by_place]
    arop = [latest(d, "arop_rate", n) for n in names]
    inc = [r.income_poor for (_, r) in rE.by_place]; ast = [r.asset_poor for (_, r) in rE.by_place]
    hard = [r.hardship for (_, r) in rE.by_place]
    println("\n", lab, @sprintf(" (%.1f min): national hardship %.4f, income poor %.4f, asset poor %.4f", t / 60, rE.hardship, rE.income_poor, rE.asset_poor))
    @printf("  %-6s %8s %8s %8s %8s\n", "region", "AROP", "inc.poor", "ast.poor", "hardship")
    for i in eachindex(names)
        @printf("  %-6s %8.1f %8.4f %8.4f %8.4f\n", names[i], arop[i], inc[i], ast[i], hard[i])
    end
    @printf("  correlation with the official poverty rate across regions: income poverty %.2f, asset poverty %.2f, hardship %.2f\n",
            cor(inc, arop), cor(ast, arop), cor(hard, arop))
    flush(stdout)
end
run("one asset, G+A+E", country_config(code; config = "GA", S = false, A = true))
isfile(joinpath(@__DIR__, "calibration_country_$(code)_GA_I.txt")) &&
    run("two assets, G+A+E", country_config(code; config = "GA", S = false, A = true, illiquid = true))
println("DONE")
