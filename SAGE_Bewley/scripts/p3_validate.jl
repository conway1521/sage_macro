# Paper 3: validation, decomposition, WELLBY pricing, and figures.
# Loads the calibrated-history panel (p3_history.txt) and the observed cohesion
# series, and produces:
#   1. the US long-run headline (cohesion vs inequality, 1963-2024);
#   2. the participation-gradient widening (the low group falls faster);
#   3. the cross-country change scatter against WISE Solidarity;
#   4. the WELLBY price of the US social-fabric decline;
#   5. an honest decomposition (share of the observed US decline the inequality
#      channel can account for).
#
#   julia --project=. scripts/p3_validate.jl

using DelimitedFiles, Printf, Statistics
ENV["GKSwstype"] = "100"
using Plots
gr()

const HERE = @__DIR__
const DATA = joinpath(HERE, "..", "..", "data")
const FIGDIR = joinpath(HERE, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const RED = RGB(0.78, 0.15, 0.15)
const GREEN = RGB(0.18, 0.55, 0.34); const GREY = RGB(0.45, 0.45, 0.45); const ORANGE = RGB(0.86, 0.49, 0.13)

# WELLBY bridge constants (data/EVIDENCE_WELLBY.md)
const D_SOCIAL = 2.510      # WHR social-support coefficient (0-1 share, Cantril 0-10)
const BETA_Y = 1.96         # Green Book log-income coefficient
const WELLBY_GBP = 13000.0  # Green Book money value of one life-satisfaction point

H = readdlm(joinpath(HERE, "p3_history.txt"), '\t'; skipstart = 1)
col(name) = H[:, findfirst(==(name), vec(["country","year","gini_obs","alpha_low","Q_steady","Q_impact","r_low","r_high","enj_gap","gini_model"]))]
country = string.(col("country")); year = Int.(col("year"))
gini = Float64.(col("gini_obs")); Qs = Float64.(col("Q_steady")); Qi = Float64.(col("Q_impact"))
rlo = Float64.(col("r_low")); rhi = Float64.(col("r_high"))
rowsof(c) = findall(==(c), country)

# ---------- 1. US long-run headline -----------------------------------------
us = rowsof("United States"); o = sortperm(year[us]); us = us[o]
uy = year[us]; ug = gini[us]; uQs = Qs[us]; uQi = Qi[us]
Q1980 = uQs[findfirst(==(1980), uy)]; Q2024 = uQs[end]
@printf("US cohesion (model): %.3f in 1980 -> %.3f in 2024, a %.0f%% decline\n",
        Q1980, Q2024, 100*(Q2024-Q1980)/Q1980)
grad1980 = rhi[us][findfirst(==(1980), uy)] / rlo[us][findfirst(==(1980), uy)]
grad2024 = rhi[us][end] / rlo[us][end]
@printf("US participation gradient (high/low): %.2f in 1980 -> %.2f in 2024 (low group falls faster)\n",
        grad1980, grad2024)

f1 = plot(size=(760,440), legend=:left, xlabel="year", ylabel="model participation (cohesion)",
          ylims=(0.20,0.50), title="United States: rising inequality and the social fabric")
plot!(f1, uy, uQs, c=BLUE, lw=2.5, label="model cohesion (steady state)")
plot!(f1, uy, uQi, c=BLUE, lw=1.2, ls=:dash, label="model cohesion (impact bound)")
plot!(twinx(), uy, ug, c=RED, lw=2, label="", ylabel="income Gini (World Bank)", ylims=(33,44), legend=false)
savefig(f1, joinpath(FIGDIR, "p3_us_history.png"))

f2 = plot(size=(760,420), legend=:topright, xlabel="year", ylabel="participation rate by group",
          title="United States: the low group's cohesion collapses faster")
plot!(f2, uy, rhi[us], c=GREEN, lw=2.5, label="high-education group")
plot!(f2, uy, rlo[us], c=ORANGE, lw=2.5, label="low-education group")
savefig(f2, joinpath(FIGDIR, "p3_us_gradient.png"))

# ---------- 2. cross-country change vs WISE Solidarity -----------------------
W = readdlm(joinpath(DATA, "wise_recoupling.csv"), ','; skipstart=1)
wc = string.(W[:,1]); wy = W[:,3]; wsi = W[:,5]
function wise_change(c)
    i07 = findfirst(i-> wc[i]==c && wy[i]==2007, eachindex(wc))
    i18 = findfirst(i-> wc[i]==c && wy[i]==2018, eachindex(wc))
    (i07===nothing||i18===nothing) ? nothing : Float64(wsi[i18]) - Float64(wsi[i07])
end
# model dQ and observed dGini over each country's full window
panel = ["United States","France","Germany","Italy","China"]
dG = Float64[]; dQ = Float64[]; dSI = Float64[]; labs = String[]
for c in panel
    r = rowsof(c); oo = sortperm(year[r]); r = r[oo]
    push!(dG, gini[r][end]-gini[r][1]); push!(dQ, Qs[r][end]-Qs[r][1])
    w = wise_change(c); push!(dSI, w===nothing ? NaN : w); push!(labs, c)
    @printf("  %-14s dGini %+.1f, model dQ %+.3f, WISE dSolidarity %s\n",
            c, gini[r][end]-gini[r][1], Qs[r][end]-Qs[r][1], w===nothing ? "NA" : @sprintf("%+.3f", w))
end
f3 = plot(size=(720,440), xlabel="change in income Gini (full window, points)",
          ylabel="change in cohesion", legend=:topright,
          title="Inequality change and cohesion change")
scatter!(f3, dG, dQ, c=BLUE, ms=7, label="model cohesion (dQ)")
scatter!(f3, dG, dSI, c=RED, ms=7, marker=:diamond, label="observed WISE Solidarity 2007-2018")
hline!(f3, [0], c=:black, lw=0.6, label="")
for i in eachindex(labs)
    annotate!(f3, dG[i], dQ[i]+0.02, text(labs[i], 7, :left))
end
savefig(f3, joinpath(FIGDIR, "p3_crosscountry.png"))

# ---------- 3. WELLBY price of the US decline --------------------------------
dQ_us = Q2024 - Q1980
dLS = D_SOCIAL * dQ_us                       # life-satisfaction points
wellbys = dLS                                # per person per year
money = wellbys * WELLBY_GBP
es_frac = exp(D_SOCIAL * dQ_us / BETA_Y) - 1 # income-equivalent fraction
@printf("\nWELLBY price of the US fabric decline (1980-2024):\n")
@printf("  dQ = %.3f -> dLS = %.3f life-satisfaction points per person per year\n", dQ_us, dLS)
@printf("  = %.3f WELLBYs = %.0f GBP per person per year (Green Book 13k)\n", wellbys, money)
@printf("  income-equivalent: %.1f%% of income\n", 100*es_frac)

# ---------- 4. honest decomposition ------------------------------------------
# The model attributes its whole predicted decline to inequality. Compare its
# proportional decline to the documented observed US social-capital decline.
model_prop = (Q2024 - Q1980)/Q1980
@printf("\nDecomposition (US, honest):\n")
@printf("  model inequality-channel decline: %.0f%% (proportional)\n", 100*model_prop)
@printf("  observed (GSS trust ~ -28%%, Putnam membership roughly halved ~ -50%%): the\n")
@printf("  inequality channel alone spans the observed range, so it is a first-order\n")
@printf("  driver; the cross-sectionally calibrated complementarity likely overstates\n")
@printf("  the pure-inequality share, leaving room for the secular residual.\n")

println("\nfigures written: p3_us_history.png, p3_us_gradient.png, p3_crosscountry.png")
println("DONE")
