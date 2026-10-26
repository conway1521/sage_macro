# The first solve of version 2's quarterly two-asset household problem through the configuration (V3_START.md
# section 141): the calibrated one-asset configuration (G or GA) with the illiquid asset on and the design's cash
# flows (section 4.1): housing equity with the real capital gain accruing inside it (JST R6, 1980 to 2015, as a
# quarterly gross rate), tenants below k_min paying the Eurostat rent share of their persistent income in work, the
# housing benefit of tenants out of work (TaxBEN), the floor on the cash after rent. k_min is a PLACEHOLDER in YEARS
# of the cell's mean persistent income in work (to be fitted to the ownership rate), and chi0 the measured
# transaction cost (buyer plus seller, Andrews, Caldera Sanchez and Johansson 2011) times the house at k_min, a
# starting value (to be fitted to the wealthy hand-to-mouth); patience is the one-asset calibration's. Each cell, its
# first patience type. Reports the time, the iterations and the moments the calibration will read.
#
#   JULIA_NUM_THREADS=4 julia --project=scripts/run_env scripts/test_egm2_quarterly.jl CODE CFG KMIN_YEARS [H] [NK] [NB]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); kyears = parse(Float64, ARGS[3])
H = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 0
nk = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 24; nb = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 120
tcost = Dict("FR" => 0.1414, "DE" => 0.0782, "IT" => 0.1200)          # data/housing/housing_evidence.md, item 4
say(x...) = (println(x...); flush(stdout))
gain = Dict("FR" => 0.0192, "DE" => -0.0019, "IT" => 0.0103)          # data/housing/housing_evidence.md, JST R6 1980-2015
share = Dict("FR" => 0.225, "DE" => 0.200, "IT" => 0.205)              # Eurostat ilc_mded02, 2025
c = floor_effort(quarterly_calibrated(code, cfg))
hbU, hbL = housing_benefit_profile(code, c.nU)
for ci in 1:2
# the cell's mean persistent income in work a quarter (the rent's basis over the rent share), at the chain's stationary
# distribution over the employed states
c1 = SAGEConfig(c; illiquid = true, solver = :egm, k_payout = false, rent_share = share[code], k_min = 1.0, hbU_vec = hbU, hb_long = hbL)
p1 = params_of(c1, cells_of(c1)[ci])[1]
_, Π1 = SAGEBewley.income_process(p1); π1 = fill(1 / p1.nz, p1.nz); for _ in 1:20_000; π1 = vec(π1' * Π1); end
emp = isemp(p1); ybarq = sum(π1[emp] .* p1.rent[emp]) / sum(π1[emp]) / share[code]
kmin = 4 * kyears * ybarq; chi0 = tcost[code] * kmin
c2 = SAGEConfig(c; illiquid = true, solver = :egm, chi0 = chi0, k_payout = false, rent_share = share[code], k_min = kmin,
                hbU_vec = hbU, hb_long = hbL, nk = nk, k_max = 4 * 150.0 * ybarq, k_sub = 4, k_mid = 0.0, nb = nb, b_max = c.a_max)     # the liquid grid's top as the one-asset model's
p = params_of(c2, cells_of(c2)[ci])[1]
p = update(p; Rk = (1 + gain[code])^(1 / 4))
say(@sprintf("cell %d: mean persistent income in work %.4f a quarter; k_min %.3f (%.1f years), chi0 %.4f; liquid grid top %.2f (%.0f years)", ci, ybarq, kmin, kyears, chi0, c.a_max, c.a_max / (4 * ybarq)))
say(@sprintf("%s %s two assets: %d states, liquid %d x illiquid %d, R %.5f, Rk %.5f, floor %.4f, rent %.4f to %.4f, k_min %.2f, chi0 %.3f, death %.5f, %d threads, Howard %d",
             code, cfg, p.nz, p.na, p.nk, p.R, p.Rk, p.cfloor, minimum(p.rent), maximum(p.rent), p.k_min, p.chi0, p.death, Threads.nthreads(), H))
t = @elapsed s = solve_two_asset_egm(p, 1.0; full = true, howard = H)
a = s.a; kg = s.k; λ = s.lambda
own = sum(λ[:, m, :] for m in 1:length(kg) if !s.tenant[m]; init = zeros(size(λ, 1), size(λ, 3)))
g = agency_summary(p, s); cs = cell_summary(p, s)
kz = g.kolmass
say(@sprintf("solved in %.1f min, %d full steps (Howard %d), stalled %.1e", t / 60, s.iters, s.timing.howard_steps, s.stalled))
say(@sprintf("ownership %.4f | hand-to-mouth poor %.4f wealthy %.4f | MPC quarter %.4f, 12 months %.4f | fall (Kolsrud, q2) %.4f",
             sum(own), sum(g.hmass), sum(g.whmass), sum(g.mpcmass), sum(g.mpc12mass), kz[4] > 0 ? 1 - (kz[5] / kz[4]) / (kz[2] / kz[1]) : NaN))
say(@sprintf("mean liquid %.4f, illiquid %.4f (quarterly income units), adjusting %.5f a quarter, public outlay (floor and housing benefit) %.5f",
             sum(λ .* reshape(a, :, 1, 1)), sum(λ .* reshape(kg, 1, :, 1)), sum(λ .* s.Padj), cs.fout))
say("illiquid grid: ", join([@sprintf("%.3g", x) for x in kg], " "), "; tenant nodes ", count(s.tenant))
say("mass by illiquid node: ", join([@sprintf("%.3f", sum(λ[:, m, :])) for m in 1:length(kg)], " "))
end
println("DONE")
