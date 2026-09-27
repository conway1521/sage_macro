# Germany's unemployed participation ratio: the refit of the social technology
# with the published Freiwilligensurvey figures in place of the unsourced 0.574.
#
#   julia --project=. scripts/probe_ratio_de.jl
#
# Freiwilligensurvey engagement rates, unemployed against employed:
#   2014: 26.1 against 47.8 (full-time 46.7 and part-time 51.1, pooled with the
#         report's shares), ratio 0.546 (Simonson, Vogel and Tesch-Roemer 2017,
#         Abb. 16-3)
#   2019: 19.0 against about 45.3 (full-time 43.5, part-time 50.8), ratio 0.42
#         (Simonson, Kelle, Kausmann and Tesch-Roemer 2022, Abb. 4-5)
# 2014 is the wave nearest the EU-SILC 2015 participation targets. The rule
# moves participation only, so the household solves are unchanged and come from
# the disk cache. Only the social technology is refitted.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))

row = country_rows()["DE"]
targets = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"]))
# The thresholds (poverty line, asset line) are the calibrated baseline's: they
# enter the hardship statistics only, not the participation response, and
# keeping them keeps every household solve in the cache.
for cfg in ("GSA", "GS")
    c0 = country_config("DE"; config = cfg, S = true, A = cfg == "GSA")
    b00 = solve_economy(c0); thr = [(b00.ypov, b00.abar)]
    for ratio in (0.574, 0.546, 0.42)
        c = SAGEConfig(c0; unemployed_ratio = ratio)
        b0 = solve_economy(c; thresholds = thr)
        fi = families(c; thresholds = thr)
        rows = scan_technology(c, fi, collect(0.30:0.02:1.50), collect(2.0:0.05:25.0);
                               targets = targets, selected_only = true)
        best = rows[argmin([x.loss for x in rows])]
        ok = [x for x in rows if x.loss <= 0.035]
        say(@sprintf("DE %-3s ratio %.3f | at the calibrated technology: participation %.4f, multiplier %.1f | refit: kappa %5.2f sigma %4.2f rootloss %.4f mult %.1f, acceptable %.1f to %.1f",
                     cfg, ratio, b0.rate, b0.slope < 1 ? 1 / (1 - b0.slope) : Inf, best.κ, best.σ, best.loss, best.mult,
                     minimum(x.mult for x in ok), maximum(x.mult for x in ok)))
    end
end
say("DONE")
