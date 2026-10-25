# Version 2's asset grid (scorecard row N3; V3_START.md section 137): a calibrated quarterly configuration solved on its
# own grid and on denser or taller ones, every other parameter held. The moments that matter (hand-to-mouth by cell,
# median liquid wealth, the twelve-month MPC, the fall on job loss, the budget) should not move with the grid.
# Each variant is "NA" (points) or "NAxAMAX" (points and the top of the grid as a multiple of the calibrated one), or
# "nzN": the income grid with N persistent states instead of seven, the income process refitted to the same moments
# (duration_config; the asset grid the calibration's).
#
#   julia --project=scripts/run_env scripts/probe_v2_grid.jl CODE CONFIG VARIANT[,VARIANT...]
ENV["SAGE_STALL_LOG"] = "1"
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2])
c0 = quarterly_calibrated(code, cfg)
say(x...) = (println(x...); flush(stdout))
say(@sprintf("%s %s: calibrated grid %d points, top %.2f", code, cfg, c0.na, c0.a_max))
for v in split(ARGS[3], ",")
    c = if startswith(v, "nz")
        quarterly_calibrated(code, cfg; nz = parse(Int, v[3:end]))
    else
        p = split(v, "x"); na = parse(Int, p[1]); am = length(p) > 1 ? parse(Float64, p[2]) : 1.0
        SAGEConfig(c0; na = na, a_max = am * c0.a_max)
    end
    t = @elapsed r = solve_economy(c; cache = false)
    say(@sprintf("%-9s htm %.5f (cells %.5f, %.5f) | median/yr %.5f | MPC 12m %.5f | fall Kolsrud %.5f | unemployed %.5f | budget %.1e | %.1f min",
                 v, r.hand_to_mouth_kvw, r.hand_to_mouth_cell[1], r.hand_to_mouth_cell[2], r.wealth_p50 / (4 * r.median_income), r.mpc12,
                 r.fall_kolsrud, r.unemployment, r.budget_gap, t / 60))
end
println("DONE")
