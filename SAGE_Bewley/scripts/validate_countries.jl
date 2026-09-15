# Cross-country validation of the agency column.
#
# TWO DIFFERENT TESTS, and the distinction matters because they have different
# right answers.
#
# 1. Against the WISE Recoupling Agency Index. That index is built from labour
#    market insecurity, vulnerable employment, life expectancy, years in
#    education and confidence in government. NONE of those is wealth. The
#    model's alpha, calibrated from OECD How's Life empowerment indicators,
#    already reproduces its ordering at Spearman +0.89 (BENCHMARK_WISE.md).
#    There is no reason asset poverty should IMPROVE that match, and a rough
#    calculation on the country hand-to-mouth targets says it will make it
#    worse. This test is run to find out by how much, not in hope.
#
# 2. Against the OECD's own asset-poverty rates. This is the direct test of the
#    hardship half, because it is the same statistic measured in data. Coverage
#    is coarse: Balestra and Tonkin (2018) give an OECD average of 14 percent
#    income-poor plus a further 36 percent asset-poor-not-income-poor, and
#    OECD (2025) places countries in bands.
#
# The discount spread is calibrated PER COUNTRY to that country's own
# hand-to-mouth target from the engine's country table, which comes from wealth
# data. So nothing in the chain touches the WISE index, and the test is not
# circular.
#
# Run with the social dimension OFF. Agency is a hardship statistic and the
# participation margin moves it only at the third decimal (MODULAR.md), while
# leaving it on would need a per-country social calibration that the data
# cannot support at six countries.
#
#   julia --project=. scripts/validate_countries.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics, DelimitedFiles

const CODES = ("FR", "DE", "IT", "US", "CN", "ZA")
const ISO   = Dict("FR" => "FRA", "DE" => "DEU", "IT" => "ITA",
                   "US" => "USA", "CN" => "CHN", "ZA" => "ZAF")
const NAME  = Dict("FR" => "France", "DE" => "Germany", "IT" => "Italy",
                   "US" => "United States", "CN" => "China", "ZA" => "South Africa")

wise = readdlm(joinpath(@__DIR__, "..", "..", "data", "wise_recoupling.csv"), ','; header = true)
const WROW = Dict((r[2], r[3]) => r[4] for r in eachrow(wise[1]))
wise_agency(code, yr) = WROW[(ISO[code], yr)]

"Spearman rank correlation."
function spearman(x, y)
    n = length(x); rx = sortperm(sortperm(x)); ry = sortperm(sortperm(y))
    d2 = sum((rx .- ry) .^ 2)
    1 - 6 * d2 / (n * (n^2 - 1))
end

"Calibrate one country's discount spread to its own hand-to-mouth target."
function country_economy(code; spreads = 0.0:0.005:0.12)
    p = country_params(code)
    tgt = SAGEBewley.COUNTRY_TARGETS[code].htm
    base = SAGEConfig(A = true, unemployment = true,
                      alpha = (p.α[1], p.α[2]), B = (p.B[1], p.B[2]))
    best = nothing
    for sp in spreads
        r = solve_economy(SAGEConfig(base; beta_spread = sp))
        d = abs(r.hand_to_mouth - tgt)
        (best === nothing || d < best.d) && (best = (d = d, sp = sp, r = r))
        best.d < 0.004 && best.sp == sp && continue
    end
    (target = tgt, spread = best.sp, r = best.r)
end

@printf("%-14s | %-7s %-7s | %-7s %-7s %-7s | %-7s %-7s %-7s | %s\n",
        "country", "alpha", "spread", "htm tgt", "htm", "asset", "agency", "A_inc", "WISE", "line")
println("-"^104)
rows = NamedTuple[]
for code in CODES
    e = country_economy(code)
    r = e.r
    ab = r.alphabar
    push!(rows, (code = code, alpha = ab, A = r.A, Ainc = r.A_income_only,
                 asset = r.asset_poor, htm = r.hand_to_mouth, spread = e.spread,
                 target = e.target, wise = wise_agency(code, 2018),
                 q = r.asset_poor_by_quintile))
    @printf("%-14s | %-7.3f %-7.3f | %-7.3f %-7.3f %-7.3f | %-7.3f %-7.3f %-7.2f | %.4f\n",
            NAME[code], ab, e.spread, e.target, r.hand_to_mouth, r.asset_poor,
            r.A, r.A_income_only, wise_agency(code, 2018), r.ypov)
    flush(stdout)
end
println("-"^104)
println()
println("rank agreement with the WISE Recoupling Agency Index, six countries")
for yr in (2007, 2017, 2018)
    w = [wise_agency(r.code, yr) for r in rows]
    @printf("  %d : alpha alone %+.3f | agency, union hardship %+.3f | agency, income hardship %+.3f\n",
            yr, spearman([r.alpha for r in rows], w), spearman([r.A for r in rows], w),
            spearman([r.Ainc for r in rows], w))
end
let oecd = [r for r in rows if r.code in ("FR", "DE", "IT", "US")]
    println("  OECD four only, 2018:")
    w = [wise_agency(r.code, 2018) for r in oecd]
    @printf("    alpha alone %+.3f | agency %+.3f\n",
            spearman([r.alpha for r in oecd], w), spearman([r.A for r in oecd], w))
end
println()
println("the model's asset poverty against what the OECD publishes")
println("  Balestra and Tonkin (2018) Fig 6.1, OECD average: 14 percent income-poor")
println("  plus a further 36 percent asset-poor but not income-poor")
println("  OECD (2025) regional paper, financial fragility: Austria and Denmark below 30,")
println("  France, Italy, Japan and Finland below 40, Canada and Germany 42 to 44, Slovenia 61")
for r in rows
    @printf("    %-14s model %.3f\n", NAME[r.code], r.asset)
end
println()
println("asset poverty by income quintile, model against the OECD average")
@printf("%-14s | %-8s %-8s %-8s %-8s %s\n", "country", "Q1", "Q2", "Q3", "Q4", "Q5")
println("-"^62)
for r in rows
    @printf("%-14s | %s\n", NAME[r.code], join([@sprintf("%-8.3f", x) for x in r.q]))
end
@printf("%-14s | %-8.2f %-8s %-8s %-8.2f %.2f\n", "OECD average", 0.68, "n/a", "n/a", 0.43, 0.27)
println("  (Balestra and Tonkin 2018, Figure 6.2 and paragraph 73)")
println("DONE")
