# Figures and final numbers for the S+A paper. Loads the saved response
# families and maps from sa_main.jl, so everything here is interpolation:
# fast, deterministic, and tied to the same solves the text quotes.
#   julia --project=. scripts/sa_figures.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf
ENV["GKSwstype"] = "100"
using Plots
gr()

const FIGDIR = joinpath(@__DIR__, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const ORANGE = RGB(0.86, 0.49, 0.13)
const GREEN = RGB(0.18, 0.55, 0.34); const PURPLE = RGB(0.46, 0.28, 0.64)
const GREY = RGB(0.45, 0.45, 0.45)

# calibrated point from sa_main.jl
const KAPPA = 10.0; const SIGMA = 0.5; const OMEGA = 0.30; const REQ = 0.371

d = readdlm(joinpath(@__DIR__, "sa_families.txt"), '\t'; skipstart = 1)
flow  = (d[:, 1], d[:, 2], d[:, 3])
fhigh = (d[:, 1], d[:, 4], d[:, 5])
fmid  = (d[:, 1], d[:, 6], d[:, 7])
dp = readdlm(joinpath(@__DIR__, "sa_policy_families.txt"), '\t'; skipstart = 1)
flowP  = (dp[:, 1], dp[:, 2], dp[:, 3])
fhighP = (dp[:, 1], dp[:, 4], dp[:, 5])

# ---------- F1: the map, baseline vs policy ---------------------------------
grid, out, eqs = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA)
gridP, outP, eqsP = trace_map(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA)
f1 = plot(size = (640, 430), xlabel = "participation rate, conjectured",
          ylabel = "participation rate, implied", legend = :topleft,
          xlims = (0, 0.8), ylims = (0, 0.8))
plot!(f1, grid, grid, c = GREY, lw = 1, ls = :dash, label = "45 degrees")
plot!(f1, grid, out, c = BLUE, lw = 2.5, label = "baseline economy")
plot!(f1, gridP, outP, c = ORANGE, lw = 2.5, label = "with financed work subsidy")
for (r, st) in eqs
    scatter!(f1, [r], [r], c = BLUE, ms = 6, label = "")
end
for (r, st) in eqsP
    scatter!(f1, [r], [r], c = ORANGE, ms = 6, label = "")
end
savefig(f1, joinpath(FIGDIR, "sa_map.png"))
println("F1 written")

# ---------- F2: gradient, model vs data --------------------------------------
_, rlo, rhi = population_rate(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA, REQ)
f2 = plot(size = (560, 380), ylabel = "participation rate",
          xticks = ([1, 2], ["lower education", "higher education"]), legend = :topleft,
          ylims = (0, 0.6))
bar!(f2, [1, 2] .- 0.17, [0.25, 0.45], bar_width = 0.3, c = GREY, label = "target (INSEE 2013, scaled)")
bar!(f2, [1, 2] .+ 0.17, [rlo, rhi], bar_width = 0.3, c = BLUE, label = "model equilibrium")
savefig(f2, joinpath(FIGDIR, "sa_gradient.png"))
@printf("F2 written: model rates %.3f / %.3f\n", rlo, rhi)

# ---------- F3: gradient decomposition ---------------------------------------
Bbar = 0.5 * (CELL_LOW.B + CELL_HIGH.B)
function eq_rates(fl, fh, Bl, Bh)
    _, _, e = trace_map(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    r = sts[argmin([abs(x[1] - REQ) for x in sts])][1]
    _, a, b = population_rate(fl, fh, Bl, Bh, KAPPA, OMEGA, SIGMA, r)
    a, b
end
g_base = (rlo, rhi)
g_noB  = eq_rates(flow, fhigh, Bbar, Bbar)
g_noA  = eq_rates(fmid, fmid, CELL_LOW.B, CELL_HIGH.B)
f3 = plot(size = (640, 380), ylabel = "participation gap, high minus low",
          xticks = ([1, 2, 3], ["full model", "taste channel off", "agency channel off"]),
          legend = false, ylims = (0, 0.25))
bar!(f3, [1, 2, 3], [g_base[2]-g_base[1], g_noB[2]-g_noB[1], g_noA[2]-g_noA[1]],
     bar_width = 0.5, c = [BLUE, GREEN, PURPLE])
savefig(f3, joinpath(FIGDIR, "sa_decomposition.png"))
@printf("F3 written: gaps %.3f / %.3f / %.3f\n",
        g_base[2]-g_base[1], g_noB[2]-g_noB[1], g_noA[2]-g_noA[1])

# ---------- F4: policy decomposition and empowerment -------------------------
# direct effect: policy families evaluated at the BASELINE belonging level
direct, _, _ = population_rate(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA, REQ)
stsP = [x for x in eqsP if x[2]]
r_pol = isempty(stsP) ? 0.0 : maximum(x[1] for x in stsP)
gridE, outE, eqsE = trace_map(fmid, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, OMEGA, SIGMA)
stsE = [x for x in eqsE if x[2]]
r_emp = stsE[argmin([abs(x[1] - REQ) for x in stsE])][1]
f4 = plot(size = (660, 400), ylabel = "aggregate participation rate", legend = false,
          xticks = ([1, 2, 3, 4],
                    ["baseline", "subsidy,\ndirect effect", "subsidy,\nequilibrium", "empowerment,\nequilibrium"]),
          ylims = (0, 0.6))
bar!(f4, [1, 2, 3, 4], [REQ, direct, r_pol, r_emp], bar_width = 0.55,
     c = [BLUE, GREY, ORANGE, GREEN])
hline!(f4, [REQ], c = GREY, ls = :dash, lw = 1)
savefig(f4, joinpath(FIGDIR, "sa_policy.png"))
@printf("F4 written: baseline %.3f direct %.3f equilibrium %.3f empowerment %.3f\n",
        REQ, direct, r_pol, r_emp)
@printf("    amplification: direct drop %.3f, equilibrium drop %.3f, ratio %.1f\n",
        REQ - direct, REQ - r_pol, (REQ - r_pol) / max(REQ - direct, 1e-9))

# ---------- F5: where multiplicity lives vs where the data sits --------------
function region_points(ω)
    fitp = Tuple{Float64,Float64}[]; multp = Tuple{Float64,Float64}[]
    for κ in 0.5:0.25:40.0, σ in 0.2:0.05:1.2
        _, _, e = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, ω, σ; ngrid = 201)
        nst = count(x -> x[2], e)
        sts = [x for x in e if x[2]]
        fit = false
        for (r, _) in sts
            _, a, b = population_rate(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, κ, ω, σ, r)
            ((a - 0.25)^2 + (b - 0.45)^2 < 0.005) && (fit = true)
        end
        fit && push!(fitp, (κ, σ))
        nst > 1 && push!(multp, (κ, σ))
    end
    fitp, multp
end
fitp, multp = region_points(OMEGA)
f5 = plot(size = (640, 420), xlabel = "interaction strength", ylabel = "taste dispersion",
          legend = :topright, xlims = (0, 41), ylims = (0.15, 1.25))
scatter!(f5, first.(multp), last.(multp), c = PURPLE, ms = 3, msw = 0, label = "multiple equilibria")
scatter!(f5, first.(fitp), last.(fitp), c = GREEN, ms = 4, msw = 0, label = "fits the French moments")
scatter!(f5, [KAPPA], [SIGMA], c = BLUE, ms = 8, marker = :star5, label = "calibrated point")
savefig(f5, joinpath(FIGDIR, "sa_region.png"))
@printf("F5 written: fit points %d, multiplicity points %d, overlap none\n",
        length(fitp), length(multp))

# ---------- robustness: omega and node count ---------------------------------
println("robustness of the policy collapse and the empowerment lift:")
for ω in (0.15, 0.30, 0.50), nn in (15, 25)
    _, _, e0 = trace_map(flow, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, ω, SIGMA; n_nodes = nn)
    s0 = [x for x in e0 if x[2]]; r0 = isempty(s0) ? NaN : maximum(x[1] for x in s0)
    _, _, eP = trace_map(flowP, fhighP, CELL_LOW.B, CELL_HIGH.B, KAPPA, ω, SIGMA; n_nodes = nn)
    sP = [x for x in eP if x[2]]; rP = isempty(sP) ? NaN : maximum(x[1] for x in sP)
    _, _, eE = trace_map(fmid, fhigh, CELL_LOW.B, CELL_HIGH.B, KAPPA, ω, SIGMA; n_nodes = nn)
    sE = [x for x in eE if x[2]]; rE = isempty(sE) ? NaN : maximum(x[1] for x in sE)
    @printf("    omega=%.2f nodes=%d: baseline %.3f -> policy %.3f, empowerment %.3f\n",
            ω, nn, r0, rP, rE)
end
println("ALL DONE")
