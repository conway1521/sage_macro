# Figures for the policy section: (a) four policies on one participation axis at
# their real fiscal cost; (b) the GDP versus GDP-B ledger. Reads the cached
# summaries written by sa_partcredit_real.jl and model_gdpb.jl.
#   julia --project=. scripts/sa_partcredit_figure.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
using DelimitedFiles, Printf
ENV["GKSwstype"] = "100"
using Plots
gr()

const FIGDIR = joinpath(@__DIR__, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const ORANGE = RGB(0.86, 0.49, 0.13)
const GREEN = RGB(0.18, 0.55, 0.34); const PURPLE = RGB(0.46, 0.28, 0.64); const GREY = RGB(0.45, 0.45, 0.45)

# ---------- panel (a): participation under the four policies (real rates) -----
cs = readdlm(joinpath(@__DIR__, "sa_credit_summary.txt"), '\t'; skipstart = 1)
rate_of(tag) = cs[findfirst(==(tag), cs[:, 1]), 3]
r0       = rate_of("baseline")     # 0.371
r_ga     = rate_of("giftaid")      # Gift Aid 25%
r_fr     = rate_of("france")       # France 66%
r_work   = 0.081                   # Paper 1's financed subsidy in Paper 2's frame
r_empow  = 0.507                   # alpha_low to mean

labels = ["baseline", "work subsidy\n(cost 20% mi)", "empowerment\n(no fiscal cost)",
          "Gift Aid credit\n(25%, cost 4% mi)", "France credit\n(66%, cost 13% mi)"]
vals = [r0, r_work, r_empow, r_ga, r_fr]
cols = [BLUE, GREY, GREEN, PURPLE, ORANGE]

f = plot(size = (720, 430), ylabel = "equilibrium participation rate", legend = false,
         xticks = (1:5, labels), ylims = (0, 1.05), bottom_margin = 9Plots.mm)
bar!(f, 1:5, vals, bar_width = 0.55, c = cols)
hline!(f, [r0], c = :black, lw = 1, ls = :dash, label = "")
savefig(f, joinpath(FIGDIR, "sa_three_policies.png"))

# ---------- panel (b): GDP versus GDP-B -------------------------------------
g = readdlm(joinpath(@__DIR__, "model_gdpb_table.txt"), '\t'; skipstart = 1)
names = g[:, 1]; GDP = Float64.(g[:, 3]); GDPB = Float64.(g[:, 4])
short = ["baseline", "work\nsubsidy", "empower-\nment", "particip.\ncredit"]
x = 1:length(names)
h = plot(size = (720, 430), ylabel = "output (model income units)",
         xticks = (x, short), legend = :topleft, bottom_margin = 7Plots.mm,
         ylims = (0, maximum(GDPB) * 1.15))
bar!(h, x .- 0.18, GDP,  bar_width = 0.34, c = GREY,   label = "GDP (consumption only)")
bar!(h, x .+ 0.18, GDPB, bar_width = 0.34, c = BLUE,   label = "GDP-B (plus social fabric)")
savefig(h, joinpath(FIGDIR, "sa_gdpb.png"))

println("figures written: sa_three_policies.png, sa_gdpb.png"); flush(stdout)
