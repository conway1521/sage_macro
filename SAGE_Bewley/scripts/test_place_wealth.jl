# E, untargeted, on the wealth side: does the place layer reproduce where
# households without buffers are? Italy, version 3, one asset. Nothing in E is
# fitted to wealth: the places differ by composition, access to work, conversion
# of work into income, and commuting, all from regional data. Against the HFCS
# 2021 by Italian macro-region and region (data/hfcs_targets.csv):
#   the hand-to-mouth share (liquid wealth at most a week of income),
#   liquid-asset poverty (liquid wealth below three months of the poverty line;
#   Balestra and Tonkin 2018),
#   income poverty (half the median).
# The level is not the test (the national hand-to-mouth share is a target and
# income poverty is a step function of the income grid, V3_START.md section 17);
# the ORDER and the SPREAD across places are.
#
# The HFCS region codes IT1 to IT20 are read as ISTAT's region codes (1 Piemonte
# ... 20 Sardegna), with Bolzano and Trento together as 4: an assumption, which
# the macro-region rows do not need.
#
# Second argument: a means-tested floor, as a share of a year's reference
# earnings (as in test_floor.jl). Without it the model orders the regions the
# wrong way round (2026-10-04: more hand-to-mouth in the North, where jobs are
# safe and households need no buffer). Italy's Reddito di cittadinanza, in force
# when the HFCS 2021 was collected, was 0.27 of the gross average wage for a
# single adult with housing support (data/benefits/). A floor removes the reason
# to hold a buffer where it binds (Hubbard, Skinner and Zeldes 1995).
#
# Second argument "base": the floor regime (calibration_v3f_*: the floor in the base, its level
# and patience calibrated with it); a fourth argument then names the configuration whose file is
# read, when the switches of CONFIG are to be turned on at another configuration's parameters
# (GAE at the G file: what places do at the G calibration, nothing refitted).
#
#   julia --project=scripts/run_env scripts/test_place_wealth.jl [CONFIG] [floor share | base] [hh] [file configuration]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GAE"
code = "IT"
BASE = length(ARGS) >= 2 && lowercase(ARGS[2]) == "base"
filecfg = length(ARGS) >= 4 ? uppercase(ARGS[4]) : cfg
c = country_config(code; v3 = BASE ? :floor : true, config = filecfg, S = occursin('S', cfg), A = occursin('A', cfg), E = occursin('E', cfg))
BASE && @printf("floor regime, parameters of %s: floor %.4f (%.3f of reference earnings), patience %.4f\n", filecfg, c.cfloor, c.cfloor / c.e_ref, c.beta_bar)
fsh = (length(ARGS) >= 2 && !BASE) ? parse(Float64, ARGS[2]) : 0.0
# third argument hh: income per head by place keeps the part of a low employment rate that is not
# unemployment (:conversion_hh), so that the South is poorer and not only riskier
if length(ARGS) >= 3 && lowercase(ARGS[3]) == "hh"
    c = SAGEConfig(c; e_channels = Tuple(ch === :conversion ? :conversion_hh : ch for ch in c.e_channels))
    println("income per head by place on the household's view (:conversion_hh)")
end
fsh > 0 && (c = SAGEConfig(c; cfloor = fsh * c.e_ref))
# fifth argument: a shift in patience, no spread (a pilot of what recalibrating with the floor would do)
if length(ARGS) >= 5
    v5 = parse(Float64, ARGS[5])          # above 0.5: patience itself; below: a shift from the file's mean patience
    c = SAGEConfig(c; beta_bar = v5 > 0.5 ? v5 : c.beta_bar - c.beta_spread / 2 + v5, beta_spread = 0.0)
    @printf("patience set to %.4f, no spread\n", c.beta_bar)
end
# sixth argument: the number of income states (11 in every calibration). The states are 45% apart,
# so a region 23% poorer moves at most one of them across the poverty line or the floor.
if length(ARGS) >= 6
    c = SAGEConfig(c; nz = parse(Int, ARGS[6])); println("income states: ", c.nz)
end
r = solve_economy(c)
fsh > 0 && @printf("means-tested floor at %.2f of reference earnings (%.4f), financed nationally: tax per head %.5f\n", fsh, c.cfloor, NAT_FLOOR_TAX[])
_, w = places_from_data(code, SAGEConfig(c; E = false); typology = c.typology, channels = c.e_channels, epsilon = c.epsilon)
names = [nm for (nm, _) in r.by_place]; res = [x for (_, x) in r.by_place]
hfcs = Dict{Tuple{String,String,String},Tuple{Float64,Float64}}()
for ln in eachline(joinpath(@__DIR__, "..", "..", "data", "hfcs_targets.csv"))
    startswith(ln, "#") && continue
    f = split(ln, ","); length(f) >= 7 && f[2] == code && f[3] == "2021" || continue
    v = tryparse(Float64, f[6]); v === nothing && continue
    hfcs[(f[1], f[4], f[5])] = (v, something(tryparse(Float64, f[7]), NaN))
end
macro_of(p) = startswith(p, "ITC") || startswith(p, "ITH") ? "IT North" : startswith(p, "ITI") ? "IT Centre" : "IT South and Islands"
istat = Dict("ITC1" => 1, "ITC2" => 2, "ITC4" => 3, "ITH1" => 4, "ITH2" => 4, "ITH3" => 5, "ITH4" => 6, "ITC3" => 7, "ITH5" => 8, "ITI1" => 9, "ITI2" => 10,
             "ITI3" => 11, "ITI4" => 12, "ITF1" => 13, "ITF2" => 14, "ITF3" => 15, "ITF4" => 16, "ITF5" => 17, "ITF6" => 18, "ITG1" => 19, "ITG2" => 20)
IND = [("hand-to-mouth", x -> x.hand_to_mouth_kvw, "htm_model_narrow_total"), ("liquid-asset poverty", x -> x.asset_poor, "asset_poor_disp_persons"),
       ("income poverty", x -> x.income_poor, "income_poor50_disp_persons")]
@printf("%s %s, version 3, %d places | national: hand-to-mouth %.4f, asset poverty %.4f, income poverty %.4f\n", code, cfg, length(res), r.hand_to_mouth_kvw, r.asset_poor, r.income_poor)
@printf("national: liquid wealth over income %.4f (HFCS %.4f, s.e. %.3f) | hand-to-mouth HFCS %.4f (s.e. %.3f) | MPC %.3f | effort %.4f\n", r.wealth_p50 / r.median_income,
        get(hfcs, ("liquid_kvw_to_disposable_income_ratio_of_medians", "all", "all"), (NaN, NaN))..., get(hfcs, ("htm_model_narrow_total", "all", "all"), (NaN, NaN))..., r.mpc, r.mean_effort_employed)
let M = ["IT North", "IT Centre", "IT South and Islands"]
    inc = [sum(w[i] * res[i].mean_income for i in eachindex(res) if macro_of(names[i]) == m) / sum(w[i] for i in eachindex(res) if macro_of(names[i]) == m) for m in M]
    @printf("mean income by macro-region, North = 1: Centre %.2f, South and Islands %.2f (household income per head, Eurostat: 0.90, 0.68)\n", inc[2] / inc[1], inc[3] / inc[1])
end
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"))
for (lab, val, mom) in IND
    println("\n", lab)
    M = ["IT North", "IT Centre", "IT South and Islands"]
    mod = [sum(w[i] * val(res[i]) for i in eachindex(res) if macro_of(names[i]) == m) / sum(w[i] for i in eachindex(res) if macro_of(names[i]) == m) for m in M]
    dat = [get(hfcs, (mom, "macro_region", m), (NaN, NaN)) for m in M]
    for k in 1:3
        @printf("   %-22s model %.3f | HFCS %.3f (s.e. %.3f)\n", M[k], mod[k], dat[k][1], dat[k][2])
    end
    @printf("   South over North: model %.2f, HFCS %.2f\n", mod[3] / mod[1], dat[3][1] / dat[1][1])
    check("$lab: the South above the North, as in the HFCS", (mod[3] > mod[1]) == (dat[3][1] > dat[1][1]))
    # by region, with the code mapping assumed
    g = Dict{Int,Vector{Int}}(); for (i, nm) in enumerate(names); haskey(istat, nm) && push!(get!(g, istat[nm], Int[]), i); end
    xs = Float64[]; ys = Float64[]; ws = Float64[]
    for (k, idx) in sort(collect(g))
        d = get(hfcs, (mom, "region", "IT$k"), nothing); d === nothing && continue
        push!(xs, sum(w[i] * val(res[i]) for i in idx) / sum(w[i] for i in idx)); push!(ys, d[1]); push!(ws, sum(w[i] for i in idx))
    end
    if length(xs) >= 5
        mx = sum(ws .* xs) / sum(ws); my = sum(ws .* ys) / sum(ws)
        rho = sum(ws .* (xs .- mx) .* (ys .- my)) / sqrt(sum(ws .* (xs .- mx) .^ 2) * sum(ws .* (ys .- my) .^ 2))
        @printf("   by region (%d regions, population-weighted): correlation %.2f | spread, max less min: model %.3f, HFCS %.3f\n", length(xs), rho, maximum(xs) - minimum(xs), maximum(ys) - minimum(ys))
    end
end
nf = count(x -> !x[2], results)
@printf("\n%d of %d checks pass\n", length(results) - nf, length(results))
println("DONE")
