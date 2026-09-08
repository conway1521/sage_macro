# Figures for the S+A paper on the Level 4 footing. Reads the scalars from
# sa_level4_results.txt and rebuilds only the response families the pictures
# need, caching them so a second run is instant. Nothing here re-derives a
# number the text quotes; the numbers come from sa_level4.jl.
#
#   julia --project=. scripts/sa_figures_l4.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics
# ---- numerical footing, stage 5 (2026-09-08): same core and grid as sa_level4
const THETA = 0.01
const GRID  = (a_max = 4.0, pexp = 3.0)
ENV["GKSwstype"] = "100"
using Plots
gr()

const FIGDIR = joinpath(@__DIR__, "..", "..", "paper", "figures")
const BLUE = RGB(0.17, 0.35, 0.62); const ORANGE = RGB(0.86, 0.49, 0.13)
const GREEN = RGB(0.18, 0.55, 0.34); const PURPLE = RGB(0.46, 0.28, 0.64)
const GREY  = RGB(0.45, 0.45, 0.45); const RED = RGB(0.70, 0.20, 0.20)

const UGRID = vcat(collect(0.0:0.2:12.0), collect(12.5:0.5:16.0), collect(17.0:1.0:30.0))
const NQ = 2000
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const Bbar = CELL_LOW.share * Blow + CELL_HIGH.share * Bhigh
const ALPHA_MID = 0.838

# ---------------------------------------------------- the Level 4 scalars ----
R = Dict{String,Float64}()
for ln in eachline(joinpath(@__DIR__, "sa_level4_results.txt"))
    (isempty(ln) || startswith(ln, "#")) && continue
    k, v = split(ln, '\t')
    R[k] = parse(Float64, v)
end
const KAPPA = R["kappa"]; const SIGMA = R["sigma"]; const OMEGA = R["omega"]
@printf("Level 4 footing: kappa %.2f, sigma %.3f, omega %.2f, baseline rate %.4f\n",
        KAPPA, SIGMA, OMEGA, R["r0"])

# ------------------------------------------------------- families, cached ----
const TASTE = Dict{Float64,Vector{Float64}}()
tastes(σ) = get!(TASTE, σ) do; taste_nodes_ln(σ; n = NQ) end

function build_family(name, α; subsidy = 0.0, lumptax = 0.0, partcredit = 0.0)
    f = joinpath(@__DIR__, @sprintf("sa_l5_theta%.4f_fam_%s.txt", THETA, name))
    if isfile(f)
        d = readdlm(f, '\t'; skipstart = 1)
        return (d[:, 1], d[:, 2], d[:, 3], d[:, 4])
    end
    print("  building family $name ... "); flush(stdout)
    r = Float64[]; mi = Float64[]; pb = Float64[]
    for u in UGRID
        p = update(cell_params(α; na = 200, ne = 40, a_max = GRID.a_max, pexp = GRID.pexp,
                               subsidy = subsidy, lumptax = lumptax);
                   social_strength = u, partcredit = partcredit)
        _, rate, m, b = solve_participation_logit(p, 1.0; theta = THETA)
        push!(r, rate); push!(mi, m); push!(pb, b)
    end
    open(f, "w") do io
        println(io, join(["u", "r", "minc", "pbase"], '\t'))
        for i in eachindex(UGRID)
            println(io, join([UGRID[i], r[i], mi[i], pb[i]], '\t'))
        end
    end
    println("done"); flush(stdout)
    (copy(UGRID), r, mi, pb)
end

T_sub  = R["T_sub"]
T_ga   = R["cred_25_100_cost"] / 100 * R["mi0"]
T_fr   = R["cred_66_100_cost"] / 100 * R["mi0"]

fl0  = build_family("low",       CELL_LOW.α)
fh0  = build_family("high",      CELL_HIGH.α)
fmid = build_family("mid",       ALPHA_MID)
flS  = build_family("low_sub",   CELL_LOW.α;  subsidy = 0.20, lumptax = T_sub)
fhS  = build_family("high_sub",  CELL_HIGH.α; subsidy = 0.20, lumptax = T_sub)
flG  = build_family("low_ga",    CELL_LOW.α;  lumptax = T_ga, partcredit = 0.25)
fhG  = build_family("high_ga",   CELL_HIGH.α; lumptax = T_ga, partcredit = 0.25)

# ---------------------------------------------------- population machinery ---
function popcol(fl, fh, Bl, Bh, κ, σ, rin, col)
    ms = tastes(σ)
    arg = OMEGA + (1 - OMEGA) * clamp(rin, 0.0, 1.0)
    lo = mean(interp(fl[1], fl[col], κ * m * Bl * arg) for m in ms)
    hi = mean(interp(fh[1], fh[col], κ * m * Bh * arg) for m in ms)
    (CELL_LOW.share * lo + CELL_HIGH.share * hi, lo, hi)
end
function themap(fl, fh, Bl, Bh, κ, σ; ngrid = 401)
    g = collect(range(0.0, 1.0, length = ngrid))
    o = [popcol(fl, fh, Bl, Bh, κ, σ, r, 2)[1] for r in g]
    eqs = NamedTuple[]
    for i in 1:ngrid-1
        d1 = o[i] - g[i]; d2 = o[i+1] - g[i+1]
        if d1 == 0 || sign(d1) != sign(d2)
            t = d1 / (d1 - d2)
            push!(eqs, (r = g[i] + t*(g[i+1]-g[i]),
                        stable = (o[i+1]-o[i])/(g[i+1]-g[i]) < 1))
        end
    end
    g, o, eqs
end
hi_stable(eqs) = (st = [e for e in eqs if e.stable];
                  isempty(st) ? NaN : maximum(e.r for e in st))

# ---------- F1: the aggregate map under the two fiscal policies --------------
g,  o,  e0 = themap(fl0, fh0, Blow, Bhigh, KAPPA, SIGMA)
_,  oS, eS = themap(flS, fhS, Blow, Bhigh, KAPPA, SIGMA)
_,  oG, eG = themap(flG, fhG, Blow, Bhigh, KAPPA, SIGMA)
f1 = plot(size = (660, 450), xlabel = "participation rate, conjectured",
          ylabel = "participation rate, implied", legend = :topleft,
          xlims = (0, 1), ylims = (0, 1))
plot!(f1, g, g, c = GREY, lw = 1, ls = :dash, label = "45 degrees")
plot!(f1, g, o,  c = BLUE,   lw = 2.5, label = "baseline")
plot!(f1, g, oS, c = ORANGE, lw = 2.5, label = "financed work subsidy")
plot!(f1, g, oG, c = GREEN,  lw = 2.5, label = "participation credit, Gift Aid rate")
for (ee, cc) in ((e0, BLUE), (eS, ORANGE), (eG, GREEN)), q in ee
    q.stable && scatter!(f1, [q.r], [q.r], c = cc, ms = 6, label = "")
end
savefig(f1, joinpath(FIGDIR, "sa_map.png")); println("F1 sa_map")

# ---------- F2: the gradient against its targets -----------------------------
f2 = plot(size = (560, 380), ylabel = "participation rate",
          xticks = ([1, 2], ["lower education", "higher education"]),
          legend = :topleft, ylims = (0, 0.6))
bar!(f2, [1,2].-0.17, [0.25, 0.45], bar_width = 0.3, c = GREY,
     label = "target (INSEE 2013, scaled)")
bar!(f2, [1,2].+0.17, [R["r0_lo"], R["r0_hi"]], bar_width = 0.3, c = BLUE,
     label = "model equilibrium")
savefig(f2, joinpath(FIGDIR, "sa_gradient.png")); println("F2 sa_gradient")

# ---------- F3: where the gradient comes from --------------------------------
f3 = plot(size = (640, 380), ylabel = "participation gap, high minus low",
          xticks = ([1,2,3], ["full model", "taste channel off", "agency channel off"]),
          legend = false, ylims = (0, 0.15))
bar!(f3, [1,2,3], [R["gap_full"], R["gap_agency"], R["gap_taste"]],
     bar_width = 0.5, c = [BLUE, GREEN, PURPLE])
savefig(f3, joinpath(FIGDIR, "sa_decomposition.png")); println("F3 sa_decomposition")

# ---------- F4: direct against equilibrium, and empowerment ------------------
f4 = plot(size = (680, 400), ylabel = "aggregate participation rate", legend = false,
          xticks = ([1,2,3,4], ["baseline", "subsidy,\ndirect effect",
                                "subsidy,\nequilibrium", "empowerment,\nequilibrium"]),
          ylims = (0, 0.45))
bar!(f4, [1,2,3,4], [R["r0"], R["r_sub_direct"], R["r_sub"], R["r_emp"]],
     bar_width = 0.55, c = [BLUE, GREY, ORANGE, GREEN])
hline!(f4, [R["r0"]], c = GREY, ls = :dash, lw = 1)
savefig(f4, joinpath(FIGDIR, "sa_policy.png")); println("F4 sa_policy")

# ---------- F5: multiplicity against the data, in the (kappa, sigma) plane ---
# A binary "fits the moments" region is the wrong picture now that the gradient
# is known to be about forty percent too flat everywhere: almost nothing clears
# a tight tolerance, and a loose one hides the shortfall. Show the calibration
# loss as a surface instead, with the multiplicity region and the analytical
# bound drawn on top of it.
if get(ENV, "SKIP_F5", "0") == "1"
    println("F5 skipped (SKIP_F5=1)")
else
print("F5 scanning the (kappa, sigma) plane ... "); flush(stdout)
ks = collect(1.0:1.0:40.0)
ss = collect(0.10:0.025:1.20)
loss = fill(NaN, length(ss), length(ks))
multp = Tuple{Float64,Float64}[]
for (j, κ) in enumerate(ks), (i, σ) in enumerate(ss)
    _, _, e = themap(fl0, fh0, Blow, Bhigh, κ, σ; ngrid = 201)
    st = [q for q in e if q.stable]
    length(st) > 1 && push!(multp, (κ, σ))
    best = Inf
    for q in st
        _, a, b = popcol(fl0, fh0, Blow, Bhigh, κ, σ, q.r, 2)
        best = min(best, (a - 0.25)^2 + (b - 0.45)^2)
    end
    isfinite(best) && (loss[i, j] = sqrt(best))
end
println("done: $(length(multp)) multiplicity points, best fit distance $(round(minimum(filter(!isnan, loss)), digits=4))")
f5 = heatmap(ks, ss, loss, c = :viridis, clims = (0.0, 0.35),
             size = (700, 440), xlabel = "interaction strength",
             ylabel = "taste dispersion",
             colorbar_title = "distance from the French moments",
             xlims = (0, 41), ylims = (0.10, 1.20))
scatter!(f5, first.(multp), last.(multp), c = :white, ms = 2.5, msw = 0,
         label = "multiple equilibria")
hline!(f5, [R["sigbar"]], c = RED, ls = :dash, lw = 2, label = "analytical bound")
scatter!(f5, [KAPPA], [SIGMA], c = :white, ms = 10, marker = :star5,
         msw = 1.5, msc = :black, label = "calibrated point")
plot!(f5, legend = :topright)
savefig(f5, joinpath(FIGDIR, "sa_region.png")); println("F5 sa_region")
end

# ---------- F6: the five scenarios side by side ------------------------------
names6 = ["baseline", "work subsidy\n(20%)", "empowerment",
          "credit, Gift Aid\n(25%)", "credit, France\n(66%)"]
vals6  = [R["r0"], R["r_sub"], R["r_emp"],
          R["cred_25_100_r"], R["cred_66_100_r"]]
cost6  = [NaN, 100*R["T_sub"]/R["mi0"], 0.0,
          R["cred_25_100_cost"], R["cred_66_100_cost"]]
f6 = plot(size = (760, 420), ylabel = "equilibrium participation rate",
          legend = false, xticks = (1:5, names6), ylims = (0, 1.16))
bar!(f6, 1:5, vals6, bar_width = 0.55, c = [BLUE, ORANGE, GREEN, PURPLE, GREY])
hline!(f6, [R["r0"]], c = GREY, ls = :dash, lw = 1)
for i in 1:5
    lbl = isnan(cost6[i]) ? "" : @sprintf("cost %.1f%%", cost6[i])
    annotate!(f6, i, vals6[i] + 0.045, text(lbl, 7, :center, GREY))
end
savefig(f6, joinpath(FIGDIR, "sa_three_policies.png")); println("F6 sa_three_policies")

# ---------- F7: the two ledgers ----------------------------------------------
lnames = ["work subsidy", "empowerment", "credit (25%)", "credit (66%)"]
gdp  = [R["gdp_work_subsidy_(20%)"], R["gdp_empowerment"],
        R["gdp_participation_credit_(25%)"], R["gdp_participation_credit_(66%)"]]
gdpb = [R["gdpb_work_subsidy_(20%)"], R["gdpb_empowerment"],
        R["gdpb_participation_credit_(25%)"], R["gdpb_participation_credit_(66%)"]]
f7 = plot(size = (700, 420), ylabel = "percent change from baseline",
          xticks = (1:4, lnames), legend = :topleft)
bar!(f7, (1:4).-0.18, gdp,  bar_width = 0.36, c = ORANGE, label = "material GDP")
bar!(f7, (1:4).+0.18, gdpb, bar_width = 0.36, c = GREEN,  label = "GDP-B")
hline!(f7, [0], c = :black, lw = 1, label = "")
savefig(f7, joinpath(FIGDIR, "sa_gdpb.png")); println("F7 sa_gdpb")

println("ALL FIGURES WRITTEN")
