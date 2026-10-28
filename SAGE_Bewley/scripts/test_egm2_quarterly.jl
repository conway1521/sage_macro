# The first solve of version 2's quarterly two-asset household problem through the configuration (V3_START.md
# section 141): the calibrated one-asset configuration (G or GA) with the illiquid asset on and the design's cash
# flows (section 4.1): housing equity with the real capital gain accruing inside it (JST R6, 1980 to 2015, as a
# quarterly gross rate), tenants below k_min paying the Eurostat rent share of their persistent income in work, the
# housing benefit of tenants out of work (TaxBEN), the floor on the cash after rent. k_min is a PLACEHOLDER in YEARS
# of the economy's mean persistent income in work, over both cells and every permanent type (one house size for the
# country, to be fitted to the ownership rate), and chi0 the measured transaction cost (buyer plus seller, Andrews,
# Caldera Sanchez and Johansson 2011) times the house at k_min, a starting value (to be fitted to the wealthy
# hand-to-mouth); patience is the one-asset calibration's.
#
# Each cell has five permanent types (perm_f of the calibration). The first version of this test solved only the
# first, the poorest (0.39 of the mean, weight 0.086), for which the floor is about twice its income, and read its
# moments as the cell's (run 40404864895: nobody saves). Now each (cell, type) is solved and reported with its
# weight, and the moments solved in one job are aggregated by weight (the cell's share times the type's weight).
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_quarterly.jl CODE CFG KMIN_YEARS [H] [CELL] [TYPE] [NK] [NB] [KMAX_YEARS] [trace]
#   CELL 1 or 2, 0 for both (default); TYPE a permanent type's index, 0 for all (default); KMAX_YEARS the illiquid grid's
#   top in years of mean income. Default 40: at 150 the iteration cycled in empty corners (houses of 50 to 120 quarterly
#   units at the top of the liquid grid) and ran to the cap, two hours a type; at 40 and 20 Germany's cell 1 type 4
#   converges in 12 minutes with every moment equal to four decimals (runs 40425262978, 40442794029, 40442804781).
#   A warning is printed when the top two illiquid nodes carry more than 0.1 per cent of the mass (raise it then).
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
A = filter(a -> a != "trace" && !occursin("=", a), ARGS)
# OVERRIDES (key=value arguments): beta=, gap= annual patience of the tertiary cell and the gap below it for the other
# (as the quarterly calibration writes them), chi0= the fixed cost in model units (default: the transaction cost times
# the house at k_min), chi0q= the same in units of the economy's mean persistent income in work a quarter (the design's
# unit, which the calibration driver calib2q.yml passes). For probing and for the calibration's solves. Numerical
# settings for diagnosis: theta_adj= (the keep-or-adjust smoothing, default 0.01), ksub= (targets per illiquid interval, 4).
kv = Dict(split(a, "=")[1] => parse(Float64, split(a, "=")[2]) for a in ARGS if occursin("=", a) && a != "kyield=jst" && a != "mort=data")
code = uppercase(A[1]); cfg = uppercase(A[2]); kyears = parse(Float64, A[3])
H = length(A) >= 4 ? parse(Int, A[4]) : 0
csel = length(A) >= 5 ? parse(Int, A[5]) : 0; tsel = length(A) >= 6 ? parse(Int, A[6]) : 0
nk = length(A) >= 7 ? parse(Int, A[7]) : 24; nb = length(A) >= 8 ? parse(Int, A[8]) : 120
kmax_years = length(A) >= 9 ? parse(Float64, A[9]) : 40.0      # the illiquid grid's top in years of mean income
trace = get(ENV, "SAGE_TRACE", "0") == "1" || "trace" in ARGS
tcost = Dict("FR" => 0.1414, "DE" => 0.0782, "IT" => 0.1200)          # data/housing/housing_evidence.md, item 4
say(x...) = (println(x...); flush(stdout))
gain = Dict("FR" => 0.0192, "DE" => -0.0019, "IT" => 0.0103)          # data/housing/housing_evidence.md, JST R6 1980-2015
share = Dict("FR" => 0.225, "DE" => 0.200, "IT" => 0.205)              # Eurostat ilc_mded02, 2025
c = floor_effort(quarterly_calibrated(code, cfg))
if haskey(kv, "beta") || haskey(kv, "gap")
    qf = Dict(strip(split(l, "=")[1]) => parse(Float64, split(l, "=")[2]) for l in eachline(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")) if occursin("=", l) && !startswith(l, "#"))
    βa = get(kv, "beta", qf["beta_annual"]); ga = get(kv, "gap", qf["beta_gap_annual"])
    c = SAGEConfig(c; beta_bar = βa^(1 / 4), beta_cell = ((βa - ga)^(1 / 4) - βa^(1 / 4), 0.0))
    say(@sprintf("patience overridden: annual %.4f, gap %.4f (calibration %.4f, %.4f)", βa, ga, qf["beta_annual"], qf["beta_gap_annual"]))
end
hbU, hbL = housing_benefit_profile(code, c.nU)
# the economy's mean persistent income in work a quarter (the rent's basis over the rent share), each type at the chain's
# stationary distribution over its employed states, weighted by the cell's share and the type's weight
c1 = SAGEConfig(c; illiquid = true, solver = :egm, k_payout = false, rent_share = share[code], k_min = 1.0, hbU_vec = hbU, hb_long = hbL)
_, wt = type_betas(c1)
cl = cells_of(c1)
ybar_type = Dict{Tuple{Int,Int},Float64}()
for ci in 1:2
    ps = params_of(c1, cl[ci]); length(ps) == length(wt) || error("expected one parameter set per type, got $(length(ps)) for $(length(wt)) weights")
    for (t, p1) in enumerate(ps)
        _, Π1 = SAGEBewley.income_process(p1); π1 = fill(1 / p1.nz, p1.nz); for _ in 1:20_000; π1 = vec(π1' * Π1); end
        emp = isemp(p1); ybar_type[(ci, t)] = sum(π1[emp] .* p1.rent[emp]) / sum(π1[emp]) / share[code]
    end
end
ybarq = sum(cl[ci].share * wt[t] * ybar_type[(ci, t)] for ci in 1:2, t in eachindex(wt)) / sum(cl[ci].share for ci in 1:2)
# kyield=jst: the asset's net rental yield (Jorda and co-authors, 1980 to 2015, deflated rent component, per cent a year,
# data/housing/housing_evidence.md), paid each quarter on equity, owners paying the gross rent (the user-cost form, the
# user's decision of 27 October); kyield=X a given annual yield; absent: none, the first design
yld = Dict("FR" => 0.0392, "DE" => 0.0430, "IT" => 0.0353)
kyA = any(a -> a == "kyield=jst", ARGS) ? yld[code] : get(kv, "kyield", 0.0)
kyq = (1 + kyA)^(1 / 4) - 1
kmin = 4 * kyears * ybarq; chi0 = haskey(kv, "chi0q") ? kv["chi0q"] * ybarq : get(kv, "chi0", tcost[code] * kmin)     # chi0q: in mean quarterly income, as the design states it
say(@sprintf("%s %s: mean persistent income in work %.4f a quarter (cells %.4f, %.4f); k_min %.3f (%.1f years), chi0 %.4f; liquid grid top %.2f; type weights %s",
             code, cfg, ybarq, sum(wt[t] * ybar_type[(1, t)] for t in eachindex(wt)), sum(wt[t] * ybar_type[(2, t)] for t in eachindex(wt)),
             kmin, kyears, chi0, c.a_max, string(round.(wt, digits = 4))))
c2 = SAGEConfig(c; illiquid = true, solver = :egm, chi0 = chi0, k_payout = false, rent_share = share[code], k_min = kmin,
                hbU_vec = hbU, hb_long = hbL, nk = nk, k_max = 4 * kmax_years * ybarq, k_sub = round(Int, get(kv, "ksub", 4.0)), k_mid = 0.0, nb = nb, b_max = c.a_max)     # the liquid grid's top as the one-asset model's
cl2 = cells_of(c2)
# moments solved here, by weight: ownership, hand-to-mouth poor and wealthy, MPC quarter and 12 months, liquid, illiquid,
# adjusting, outlay, and the Kolsrud masses (the fall is computed from the summed masses)
acc = zeros(9); kacc = zeros(5); wsum = 0.0
for ci in (csel == 0 ? (1:2) : (csel:csel)), t in (tsel == 0 ? eachindex(wt) : (tsel:tsel))
    p = params_of(c2, cl2[ci])[t]
    # mortgages: ltv= the borrowing limit as a share of next period's illiquid wealth, mspread= the mortgage rate's spread
    # over the liquid rate, per cent a year (data/housing/mortgage_evidence.md); absent: no borrowing
    # mort=data: each country's average LTV at origination and the 2003-2019 MIR spread over 3-month Euribor
    # (data/housing/mortgage_evidence.md; V3_START.md section 141)
    mltv = Dict("FR" => 0.89, "DE" => 0.84, "IT" => 0.70); msp = Dict("FR" => 0.0201, "DE" => 0.0213, "IT" => 0.0213)
    md = any(==("mort=data"), ARGS)
    ltv_ = md ? mltv[code] : get(kv, "ltv", 0.0); Rm_ = ltv_ > 0 ? (p.R^4 + (md ? msp[code] : get(kv, "mspread", 0.0)))^(1 / 4) : 0.0
    p = update(p; Rk = (1 + gain[code])^(1 / 4), k_yield = kyq, ltv = ltv_, Rm = Rm_)
    w = cl2[ci].share * wt[t]
    say(@sprintf("cell %d type %d (income %.3f of the mean, weight %.4f): %d states, liquid %d x illiquid %d, R %.5f, Rm %.5f, ltv %.2f, Rk %.5f, yield %.5f, floor %.4f, rent %.4f to %.4f, death %.5f, %d threads, Howard %d",
                 ci, t, ybar_type[(ci, t)] / ybarq, w, p.nz, p.na, p.nk, p.R, p.Rm, p.ltv, p.Rk, p.k_yield, p.cfloor, minimum(p.rent), maximum(p.rent), p.death, Threads.nthreads(), H))
    tt = @elapsed s = solve_two_asset_egm(p, 1.0; full = true, howard = H, trace = trace, theta_adj = get(kv, "theta_adj", 0.01))
    a = s.a; kg = s.k; λ = s.lambda
    own = sum(sum(λ[:, m, :]) for m in 1:length(kg) if !s.tenant[m]; init = 0.0)
    g = agency_summary(p, s); cs = cell_summary(p, s)
    kz = g.kolmass
    mom = [own, sum(g.hmass), sum(g.whmass), sum(g.mpcmass), sum(g.mpc12mass), sum(λ .* reshape(a, :, 1, 1)), sum(λ .* reshape(kg, 1, :, 1)), sum(λ .* s.Padj), cs.fout]
    say(@sprintf("  solved in %.1f min, %d full steps (Howard %d), stalled %.1e", tt / 60, s.iters, s.timing.howard_steps, s.stalled))
    say(@sprintf("  ownership %.4f | hand-to-mouth poor %.4f wealthy %.4f | MPC quarter %.4f, 12 months %.4f | fall (Kolsrud, q2) %.4f",
                 mom[1:5]..., kz[4] > 0 ? 1 - (kz[5] / kz[4]) / (kz[2] / kz[1]) : NaN))
    say(@sprintf("  mean liquid %.4f, illiquid %.4f (quarterly income units), adjusting %.5f a quarter, public outlay (floor and housing benefit) %.5f", mom[6:9]...))
    say("  mass by illiquid node: ", join([@sprintf("%.3f", sum(λ[:, m, :])) for m in 1:length(kg)], " "), " (tenant nodes ", count(s.tenant), ")")
    mtop = sum(λ[:, end-1:end, :]); mtop > 1e-3 && say(@sprintf("  WARNING: the top two illiquid nodes carry %.4f of the mass: raise KMAX_YEARS", mtop))
    acc .+= w .* mom; kacc .+= w .* kz[1:5]; global wsum += w
end
if wsum > 0
    m = acc ./ wsum
    say(@sprintf("WEIGHTED over the types solved (weight %.4f): ownership %.4f | hand-to-mouth poor %.4f wealthy %.4f | MPC quarter %.4f, 12 months %.4f | fall %.4f | liquid %.4f illiquid %.4f | adjusting %.5f | outlay %.5f",
                 wsum, m[1:5]..., kacc[4] > 0 ? 1 - (kacc[5] / kacc[4]) / (kacc[2] / kacc[1]) : NaN, m[6:9]...))
    say("RAW sums (weight x moment), to add across jobs: ", join([@sprintf("%.6g", x) for x in vcat(wsum, acc, kacc)], " "))
end
println("DONE")
