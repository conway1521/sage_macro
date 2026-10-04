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
#   julia --project=scripts/run_env scripts/test_place_wealth.jl [CONFIG]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf, Statistics
cfg = length(ARGS) >= 1 ? uppercase(ARGS[1]) : "GAE"
code = "IT"
c = country_config(code; v3 = true, config = cfg, S = occursin('S', cfg), A = occursin('A', cfg))
r = solve_economy(c)
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
results = Tuple{String,Bool}[]
check(name, ok) = (push!(results, (name, ok)); @printf("   -> %s: %s\n", name, ok ? "PASS" : "FAIL"))
for (lab, get, mom) in IND
    println("\n", lab)
    M = ["IT North", "IT Centre", "IT South and Islands"]
    mod = [sum(w[i] * get(res[i]) for i in eachindex(res) if macro_of(names[i]) == m) / sum(w[i] for i in eachindex(res) if macro_of(names[i]) == m) for m in M]
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
        push!(xs, sum(w[i] * get(res[i]) for i in idx) / sum(w[i] for i in idx)); push!(ys, d[1]); push!(ws, sum(w[i] for i in idx))
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
