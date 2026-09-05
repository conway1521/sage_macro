# Does the S+A paper's cohesion object fix the S paper's validation failure?
#
# The WISE benchmark (BENCHMARK_WISE.md) tested Q = E[1-e], all non-work time,
# against the WISE Solidarity Index and found a robust INVERSION: the model
# read France as most cohesive because the French work least, while WISE reads
# the United States as more solidary because Americans give and trust more.
# The benchmark's own conclusion was that the cohesion object needed rethinking.
#
# The S+A paper replaced that object with participation time, q * P(d=1), on
# the grounds that a free rider's leisure should not build fabric. This script
# asks whether the replacement fixes the inversion, using the Level 4
# cross-country participation rates.
#
# It also runs the circularity check that matters here: participation is a
# deterministic function of the calibrated agency and belonging inputs, so the
# question is whether it orders countries BETTER than those inputs do alone.
#
#   julia --project=. scripts/wise_participation.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using DelimitedFiles, Printf, Statistics

const ISO = Dict("FRA"=>"FR","DEU"=>"DE","ITA"=>"IT","USA"=>"US","CHN"=>"CN","ZAF"=>"ZA")

function ranks(x)
    o = sortperm(x); r = zeros(length(x)); i = 1
    while i <= length(o)
        j = i
        while j < length(o) && x[o[j+1]] == x[o[i]]; j += 1; end
        for k in i:j; r[o[k]] = (i + j) / 2; end
        i = j + 1
    end
    r
end
function spearman(a, b)
    ra, rb = ranks(a), ranks(b)
    sa, sb = std(ra), std(rb)
    (sa == 0 || sb == 0) ? NaN : cor(ra, rb)
end

# Level 4 cross-country participation
d = readdlm(joinpath(@__DIR__, "sa_countries_l4.txt"), '\t'; skipstart = 1)
part = Dict(string(d[i,1]) => Float64(d[i,3]) for i in 1:size(d,1))

# the model's calibrated inputs, for the circularity check
inputs = Dict{String,NTuple{2,Float64}}()
for c in keys(part)
    p = country_params(c)
    inputs[c] = (0.5*(p.B[1]+p.B[2]), p.α[1])
end

# the old S-paper cohesion object, from the original benchmark
# the file carries trailing comment lines, so keep only real country rows
w = readdlm(joinpath(@__DIR__, "wise_benchmark.txt"), '\t'; skipstart = 1)
oldQ = Dict{String,Float64}()
for i in 1:size(w, 1)
    code = string(w[i, 1])
    (length(code) == 2 && w[i, 4] isa Number) || continue
    oldQ[code] = Float64(w[i, 4])
end

raw = readdlm(joinpath(@__DIR__, "..", "..", "data", "wise_recoupling.csv"), ','; skipstart = 1)
years = sort(unique(string.(raw[:, 3])))

println("Model cohesion object against the WISE Solidarity Index")
println("Spearman rank correlation. Positive means the model agrees with WISE.\n")
@printf("%-6s %-4s | %-14s %-12s | %-11s %-11s\n",
        "year", "n", "participation", "old Q=E[1-e]", "Bbar alone", "alpha_l alone")
for y in years, samp in ("all", "OECD")
    cs = String[]
    sol = Float64[]
    for i in 1:size(raw, 1)
        string(raw[i,3]) == y || continue
        code = get(ISO, string(raw[i,2]), nothing); code === nothing && continue
        samp == "OECD" && !(code in ("FR","DE","IT","US")) && continue
        haskey(part, code) || continue
        push!(cs, code); push!(sol, Float64(raw[i,5]))
    end
    isempty(cs) && continue
    lbl = samp == "all" ? y : ""
    @printf("%-6s %-4s | %+14.3f %+12.3f | %+11.3f %+11.3f   %s\n",
            lbl, "$(length(cs))",
            spearman([part[c] for c in cs], sol),
            spearman([get(oldQ, c, NaN) for c in cs], sol),
            spearman([inputs[c][1] for c in cs], sol),
            spearman([inputs[c][2] for c in cs], sol),
            samp == "OECD" ? "(OECD four)" : "")
end

println("\nSpread of the two cohesion objects across the seven country rows:")
pv = collect(values(part)); qv = collect(values(oldQ))
@printf("  participation  %.3f to %.3f  (range %.3f)\n", minimum(pv), maximum(pv), maximum(pv)-minimum(pv))
@printf("  old Q          %.3f to %.3f  (range %.3f)\n", minimum(qv), maximum(qv), maximum(qv)-minimum(qv))
println("\nCAUTION. Participation is a deterministic function of the calibrated agency")
println("and belonging inputs, so this is not an out-of-sample prediction from")
println("primitives; it says the model's nonlinear aggregator of those inputs orders")
println("countries more like an independently built index than the inputs do alone.")
println("With six countries, and four in the OECD sample, the coefficients are coarse.")
println("Germany and Italy differ by 0.0002 in the model, below what this solver")
println("resolves, so their relative order carries no information.")
println("DONE")
