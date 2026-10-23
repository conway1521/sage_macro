# Stage 1d: the social parameters of G+S and G+S+A on the quarterly economy (V3_START.md section 131). Version 1's
# recipe (calibrate_country.jl, stages 2 and 3): the households' response to belonging solved once over the grid of
# belonging scales (response families), the measured ratio of the unemployed's participation imposed, then kappa and
# sigma_m scanned against the two education cells' participation (data/country_labour_participation.csv), the
# equilibrium the economy selects, multiplier at most 5, root loss within 0.035. Patience and its gap given (the
# quarterly G or G+A calibration); the economy at the best point is then solved and its hand-to-mouth reported, so
# that a second pass can refit patience if participation moved it beyond tolerance. Job search off at a quarter
# (refitted later), the cost of being out of work in wellbeing only.
#
# The belonging grid (fifth argument): fast (the default, 22 scales: 0 to 12 by 1, then 14 to 30 by 2), coarse (version
# 1's 42) or full (83). On the quarterly economy a family takes many times an annual one, and the full grid did not
# finish in five hours (Italy G+S, run 39979238942); the scan interpolates between the scales. The economy at the best
# point reuses the families (no second household solve; the poverty thresholds are not computed).
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/calibrate_quarterly_s.jl CODE CONFIG BETA GAP [GRID]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); β = parse(Float64, ARGS[3]); gap = parse(Float64, ARGS[4])
grid = length(ARGS) >= 5 ? lowercase(ARGS[5]) : "fast"
UG = grid == "full" ? UGRID_DEFAULT : grid == "coarse" ? UGRID_COARSE : vcat(collect(0.0:1.0:12.0), collect(14.0:2.0:30.0))
say(x...) = (println(x...); flush(stdout))
A = occursin('A', cfg)
row = country_rows()[code]; PART = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"])); RATIO = parse(Float64, row["ratio"])
SIGMAS = 0.30:0.02:3.00; KAPPAS = 2.0:0.05:25.0; MULT_MAX = 5.0; LOSS_STD = 0.035
ca = country_config(code; config = cfg, v3 = :v5m, S = true, A = A)
c = SAGEConfig(duration_config(ca); beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), unemployed_ratio = RATIO, ugrid = UG)
A && (c = SAGEConfig(c; search = false, out_ls = 0.0))
say(@sprintf("%s %s quarterly: patience %.4f, gap %.4f | participation targets %.4f %.4f at the unemployed ratio %.3f | version 1: kappa %.2f, sigma_m %.2f",
             code, cfg, β, gap, PART..., RATIO, ca.kappa, ca.sigma_m))
t = @elapsed raw = collect(build_families(c, nothing; disk = false))
say(@sprintf("families built in %.1f min (%d belonging scales)", t / 60, length(UG)))
emp = employment_mask(c)
fi = [impose_unemployed_ratio(f, emp, RATIO) for f in raw]
rows = scan_technology(c, fi, collect(SIGMAS), collect(KAPPAS); targets = PART, max_mult = MULT_MAX, selected_only = true)
isempty(rows) && (say("NOT CALIBRATED: no stable equilibrium with a multiplier of at most 5 on the grid"); println("DONE"); exit(0))
best = rows[argmin([x.loss for x in rows])]
ok = best.loss <= LOSS_STD
say(@sprintf("best: kappa %.2f, sigma_m %.2f, root loss %.4f, rate %.4f, multiplier %.2f | %s", best.κ, best.σ, best.loss, best.r, best.mult,
             ok ? "within 0.035" : "NOT within 0.035"))
t = @elapsed r = _solve(SAGEConfig(c; kappa = best.κ, sigma_m = best.σ), nothing; fams = raw, disk = false, any_thresholds = true)
say(@sprintf("the economy there: participation %.4f | htm %.4f, by cell %.4f %.4f (gap %.4f) | median/yr %.4f | MPC 12m %.4f | fall Kolsrud %.4f | budget %.1e | %.1f min",
             r.rate, r.hand_to_mouth_kvw, r.hand_to_mouth_cell..., r.hand_to_mouth_cell[1] - r.hand_to_mouth_cell[2], r.wealth_p50 / (4 * r.median_income),
             r.mpc12, r.fall_kolsrud, r.budget_gap, t / 60))
say("# calibration_v5q_$(code)_$(cfg).txt, written by calibrate_quarterly_s.jl ($(ok ? "participation calibrated" : "best point, not calibrated"); patience from the quarterly G/G+A calibration)")
say(@sprintf("beta_annual = %.6f", β)); say(@sprintf("beta_gap_annual = %.6f", gap))
say(@sprintf("kappa = %.4f", best.κ)); say(@sprintf("sigma_m = %.4f", best.σ))
println("DONE")
