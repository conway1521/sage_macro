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
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_quarterly.jl CODE CFG KMIN_YEARS [H] [CELL] [TYPE] [NK] [NB] [trace]
#   CELL 1 or 2, 0 for both (default); TYPE a permanent type's index, 0 for all (default)
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
A = filter(!=("trace"), ARGS)
code = uppercase(A[1]); cfg = uppercase(A[2]); kyears = parse(Float64, A[3])
H = length(A) >= 4 ? parse(Int, A[4]) : 0
csel = length(A) >= 5 ? parse(Int, A[5]) : 0; tsel = length(A) >= 6 ? parse(Int, A[6]) : 0
nk = length(A) >= 7 ? parse(Int, A[7]) : 24; nb = length(A) >= 8 ? parse(Int, A[8]) : 120
trace = get(ENV, "SAGE_TRACE", "0") == "1" || "trace" in ARGS
tcost = Dict("FR" => 0.1414, "DE" => 0.0782, "IT" => 0.1200)          # data/housing/housing_evidence.md, item 4
say(x...) = (println(x...); flush(stdout))
gain = Dict("FR" => 0.0192, "DE" => -0.0019, "IT" => 0.0103)          # data/housing/housing_evidence.md, JST R6 1980-2015
share = Dict("FR" => 0.225, "DE" => 0.200, "IT" => 0.205)              # Eurostat ilc_mded02, 2025
c = floor_effort(quarterly_calibrated(code, cfg))
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
kmin = 4 * kyears * ybarq; chi0 = tcost[code] * kmin
say(@sprintf("%s %s: mean persistent income in work %.4f a quarter (cells %.4f, %.4f); k_min %.3f (%.1f years), chi0 %.4f; liquid grid top %.2f; type weights %s",
             code, cfg, ybarq, sum(wt[t] * ybar_type[(1, t)] for t in eachindex(wt)), sum(wt[t] * ybar_type[(2, t)] for t in eachindex(wt)),
             kmin, kyears, chi0, c.a_max, string(round.(wt, digits = 4))))
c2 = SAGEConfig(c; illiquid = true, solver = :egm, chi0 = chi0, k_payout = false, rent_share = share[code], k_min = kmin,
                hbU_vec = hbU, hb_long = hbL, nk = nk, k_max = 4 * 150.0 * ybarq, k_sub = 4, k_mid = 0.0, nb = nb, b_max = c.a_max)     # the liquid grid's top as the one-asset model's
cl2 = cells_of(c2)
# moments solved here, by weight: ownership, hand-to-mouth poor and wealthy, MPC quarter and 12 months, liquid, illiquid,
# adjusting, outlay, and the Kolsrud masses (the fall is computed from the summed masses)
acc = zeros(9); kacc = zeros(5); wsum = 0.0
for ci in (csel == 0 ? (1:2) : (csel:csel)), t in (tsel == 0 ? eachindex(wt) : (tsel:tsel))
    p = params_of(c2, cl2[ci])[t]
    p = update(p; Rk = (1 + gain[code])^(1 / 4))
    w = cl2[ci].share * wt[t]
    say(@sprintf("cell %d type %d (income %.3f of the mean, weight %.4f): %d states, liquid %d x illiquid %d, R %.5f, Rk %.5f, floor %.4f, rent %.4f to %.4f, death %.5f, %d threads, Howard %d",
                 ci, t, ybar_type[(ci, t)] / ybarq, w, p.nz, p.na, p.nk, p.R, p.Rk, p.cfloor, minimum(p.rent), maximum(p.rent), p.death, Threads.nthreads(), H))
    tt = @elapsed s = solve_two_asset_egm(p, 1.0; full = true, howard = H, trace = trace)
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
    acc .+= w .* mom; kacc .+= w .* kz[1:5]; global wsum += w
end
if wsum > 0
    m = acc ./ wsum
    say(@sprintf("WEIGHTED over the types solved (weight %.4f): ownership %.4f | hand-to-mouth poor %.4f wealthy %.4f | MPC quarter %.4f, 12 months %.4f | fall %.4f | liquid %.4f illiquid %.4f | adjusting %.5f | outlay %.5f",
                 wsum, m[1:5]..., kacc[4] > 0 ? 1 - (kacc[5] / kacc[4]) / (kacc[2] / kacc[1]) : NaN, m[6:9]...))
    say("RAW sums (weight x moment), to add across jobs: ", join([@sprintf("%.6g", x) for x in vcat(wsum, acc, kacc)], " "))
end
println("DONE")
