# Figure: four policies on one axis at matched fiscal cost.
#   julia --project=. scripts/sa_partcredit_figure.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf
ENV["GKSwstype"] = "100"
using Plots
gr()

const FIGDIR = joinpath(@__DIR__, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const ORANGE = RGB(0.86, 0.49, 0.13)
const GREEN = RGB(0.18, 0.55, 0.34); const PURPLE = RGB(0.46, 0.28, 0.64); const GREY = RGB(0.45, 0.45, 0.45)

d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])
fmid  = (d[:, 1], d[:, 6], d[:, 7])

# numbers from sa_main and sa_partcredit
r0 = 0.371
r_work = 0.081           # Paper 1's financed subsidy in Paper 2's frame
r_empower = 0.507        # alpha_low to mean
r_credit_small = 0.818   # boost = 0.25 (low cost: 2% of mi)
r_credit_match = 1.000   # boost = 2.14 (matched cost: 21% of mi)

labels = ["baseline", "work subsidy\n(matched cost)", "empowerment\n(no fiscal cost)",
          "participation credit\n(low cost, 2% mi)", "participation credit\n(matched cost)"]
vals = [r0, r_work, r_empower, r_credit_small, r_credit_match]
cols = [BLUE, GREY, GREEN, PURPLE, ORANGE]

f = plot(size = (700, 420), ylabel = "equilibrium participation rate", legend = false,
         xticks = (1:5, labels), ylims = (0, 1.05), bottom_margin = 9Plots.mm)
bar!(f, 1:5, vals, bar_width = 0.55, c = cols)
hline!(f, [r0], c = :black, lw = 1, ls = :dash, label = "")
savefig(f, joinpath(FIGDIR, "sa_three_policies.png"))
println("figure written"); flush(stdout)
