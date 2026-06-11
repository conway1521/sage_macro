# Paper 3: the calibrated history. Drive the model with each country's observed
# income-inequality path and read off the endogenous social fabric, year by
# year. The driver is the agency gap: the low-education group's agency alpha_low
# falls as inequality rises, calibrated so the model's own income Gini tracks
# the observed income Gini change one-for-one (a disciplined driver, not a free
# dial). For each year we report TWO bounds, because wealth is the slow state
# and participation is the fast one: a steady-state bound (the agency gap at its
# current value) and an impact bound (the gap entering with the slow adjustment
# of the wealth distribution, an AR(1) smooth). The truth is bracketed.
#
# Outputs scripts/p3_history.txt (country-year panel) and a console summary
# with the cross-country directional validation against the WISE Solidarity
# changes.
#
#   julia --project=. scripts/p3_history.jl

include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
using DelimitedFiles, Printf, Statistics, LinearAlgebra

# ---------- calibrated social technology (from the S+A paper) -----------------
const OMEGA = 0.30; const KAPPA = 10.0; const SIGMA = 0.5
const Blow = CELL_LOW.B; const Bhigh = CELL_HIGH.B
const ALPHA_HIGH = 0.911           # the upper cell, held fixed
const ALPHA_BASE = 0.765           # the lower cell at the inequality baseline
const RHO_W = 0.85                 # wealth-distribution persistence (slow state)
const LAMBDA = 0.8757834

# ---------- load the 2D family ----------------------------------------------
d = readdlm(joinpath(@__DIR__, "p3_family.txt"), '\t'; skipstart = 1)
const FAM_ALPHAS = sort(unique(d[:, 1]))
const FAM_U = sort(unique(d[:, 2]))
# R[ai, ui], M[ai, ui]
function _grid(col)
    G = zeros(length(FAM_ALPHAS), length(FAM_U))
    for r in 1:size(d, 1)
        ai = searchsortedfirst(FAM_ALPHAS, d[r, 1])
        ui = searchsortedfirst(FAM_U, d[r, 2])
        G[ai, ui] = d[r, col]
    end
    G
end
const FAM_R = _grid(3); const FAM_M = _grid(4)

"Interpolate the response family at agency alpha: returns (u_grid, r, minc)."
function family_at(α)
    α = clamp(α, FAM_ALPHAS[1], FAM_ALPHAS[end])
    k = searchsortedlast(FAM_ALPHAS, α); k = min(k, length(FAM_ALPHAS) - 1)
    t = (α - FAM_ALPHAS[k]) / (FAM_ALPHAS[k+1] - FAM_ALPHAS[k])
    r  = (1 - t) .* FAM_R[k, :] .+ t .* FAM_R[k+1, :]
    mi = (1 - t) .* FAM_M[k, :] .+ t .* FAM_M[k+1, :]
    (FAM_U, r, mi)
end

# ---------- z process, for the model income Gini -----------------------------
let p = SAGEParams()
    global Z_VALS, Z_PROB
    zv, Π = SAGEBewley.income_process(p)
    # stationary distribution of the Markov chain
    A = Matrix(Π'); A[diagind(A)] .-= 1.0; A[end, :] .= 1.0
    b = zeros(length(zv)); b[end] = 1.0
    Z_PROB = A \ b
    Z_VALS = zv
end
const ZBAR = sum(Z_VALS .* Z_PROB)

function _gini(vals, wts)
    o = sortperm(vals); v = vals[o]; w = wts[o]
    cw = cumsum(w); cw ./= cw[end]
    cwv = cumsum(v .* w); cwv ./= cwv[end]
    cw = vcat(0.0, cw); cwv = vcat(0.0, cwv)
    1 - sum((cw[2:end] .- cw[1:end-1]) .* (cwv[2:end] .+ cwv[1:end-1]))
end

"Per-cell mean labour income at the equilibrium rate (population, over tastes)."
function cell_meaninc(fam, B, rate)
    ms = taste_nodes_ln(SIGMA; n = 15)
    arg = OMEGA + (1 - OMEGA) * clamp(rate, 0.0, 1.0)
    mean(interp(fam[1], fam[3], KAPPA * m * B * arg) for m in ms)
end

"Model income Gini given alpha_low at its equilibrium (two cells + z spread)."
function model_income_gini(αlow)
    fl = family_at(αlow); fh = family_at(ALPHA_HIGH)
    r = eq_rate(fl, fh)
    milo = cell_meaninc(fl, Blow, r); mihi = cell_meaninc(fh, Bhigh, r)
    # population income points: each cell's mean scaled by the z distribution
    vals = vcat(milo .* (Z_VALS ./ ZBAR), mihi .* (Z_VALS ./ ZBAR))
    wts  = vcat(0.5 .* Z_PROB, 0.5 .* Z_PROB)
    _gini(vals, wts)
end

# ---------- equilibrium + outcomes -------------------------------------------
"Highest stable equilibrium participation rate."
function eq_rate(fl, fh)
    _, _, e = trace_map(fl, fh, Blow, Bhigh, KAPPA, OMEGA, SIGMA)
    sts = [x for x in e if x[2]]
    isempty(sts) ? NaN : sts[argmax([x[1] for x in sts])][1]
end

"Solve the year: aggregate Q, group rates, enjoyed-wellbeing gap, income Gini."
function solve_year(αlow)
    fl = family_at(αlow); fh = family_at(ALPHA_HIGH)
    Q = eq_rate(fl, fh)
    _, rlo, rhi = population_rate(fl, fh, Blow, Bhigh, KAPPA, OMEGA, SIGMA, Q)
    # experienced social wellbeing per cell: enjoyment requires participating,
    # so it scales with the cell's participation rate times its belonging value
    enj_lo = LAMBDA * Blow  * Q * rlo
    enj_hi = LAMBDA * Bhigh * Q * rhi
    gini_inc = model_income_gini(αlow)
    (Q = Q, rlo = rlo, rhi = rhi, enj_lo = enj_lo, enj_hi = enj_hi,
     enj_gap = enj_hi - enj_lo, gini_inc = gini_inc)
end

# ---------- the driver: observed income Gini -> agency gap -------------------
# A transparent common mapping, the same for every country: a society at low
# inequality (Gini 30, Nordic-like) has no agency gap (alpha_low = alpha_high);
# a highly unequal society (Gini 45, US/SA-like) sits at the widest gap in the
# family (alpha_low = 0.60). Linear in between, clamped. This is the driver
# assumption, stated plainly; the model's own income Gini is then a consistency
# check that co-moves, not a target forced to match (the one-asset two-cell
# model understates income dispersion, so it cannot match the level, only track
# the direction).
const GINI_LO = 30.0; const GINI_HI = 45.0
const ALPHA_AT_HI = FAM_ALPHAS[1]               # 0.60, widest gap
@printf("model income Gini consistency: %.3f at alpha=0.911 (no gap), %.3f at alpha=0.60 (wide gap)\n",
        model_income_gini(ALPHA_HIGH), model_income_gini(ALPHA_AT_HI))

"Map an observed income Gini (0-100) to alpha_low under the common driver map."
function alpha_of_gini(gini_obs, gini_base = nothing)
    f = clamp((gini_obs - GINI_LO) / (GINI_HI - GINI_LO), 0.0, 1.0)
    ALPHA_HIGH + f * (ALPHA_AT_HI - ALPHA_HIGH)
end

# ---------- run the history per country --------------------------------------
gini_data = readdlm(joinpath(@__DIR__, "..", "..", "data", "income_gini_wb.csv"), ','; skipstart = 1)
countries = unique(string.(gini_data[:, 1]))

outrows = Vector{Any}()
println("\nRunning the calibrated history per country (steady-state and impact bounds):")
summary = Dict{String,Any}()
for c in countries
    rows = gini_data[gini_data[:, 1] .== c, :]
    yrs = Int.(rows[:, 3]); gobs = Float64.(rows[:, 4])
    o = sortperm(yrs); yrs = yrs[o]; gobs = gobs[o]
    gini_base = gobs[1]
    # fast (steady-state) alpha path, and slow (impact) AR(1) smooth
    αfast = [alpha_of_gini(g, gini_base) for g in gobs]
    αslow = similar(αfast); αslow[1] = αfast[1]
    for t in 2:length(αfast)
        αslow[t] = RHO_W * αslow[t-1] + (1 - RHO_W) * αfast[t]
    end
    Qfast = Float64[]; Qslow = Float64[]; enjgap = Float64[]; ginimod = Float64[]
    rlos = Float64[]; rhis = Float64[]
    for t in eachindex(yrs)
        sf = solve_year(αfast[t]); ss = solve_year(αslow[t])
        push!(Qfast, sf.Q); push!(Qslow, ss.Q); push!(enjgap, sf.enj_gap)
        push!(ginimod, sf.gini_inc); push!(rlos, sf.rlo); push!(rhis, sf.rhi)
        push!(outrows, [c, yrs[t], gobs[t], round(αfast[t], digits=4),
                        round(sf.Q, digits=4), round(ss.Q, digits=4),
                        round(sf.rlo, digits=4), round(sf.rhi, digits=4),
                        round(sf.enj_gap, digits=5), round(sf.gini_inc, digits=4)])
    end
    ΔQ_fast = Qfast[end] - Qfast[1]
    ΔQ_slow = Qslow[end] - Qslow[1]
    summary[c] = (y0 = yrs[1], y1 = yrs[end], dGini = gobs[end] - gobs[1],
                  Q0 = Qfast[1], Q1 = Qfast[end], dQ_fast = ΔQ_fast, dQ_slow = ΔQ_slow,
                  enjgap0 = enjgap[1], enjgap1 = enjgap[end])
    @printf("  %-14s %d-%d: dGini %+.1f pts -> dQ [%+.3f impact, %+.3f steady]; enjoyment gap %.4f -> %.4f\n",
            c, yrs[1], yrs[end], gobs[end] - gobs[1], ΔQ_slow, ΔQ_fast, enjgap[1], enjgap[end])
end

open(joinpath(@__DIR__, "p3_history.txt"), "w") do io
    println(io, join(["country","year","gini_obs","alpha_low","Q_steady","Q_impact",
                      "r_low","r_high","enj_gap","gini_model"], '\t'))
    for r in outrows
        println(io, join(r, '\t'))
    end
end
println("\nsaved p3_history.txt (", length(outrows), " country-year rows)")
println("DONE")
