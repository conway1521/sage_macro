# Does the multiplier band depend on the carried-over alpha and B gradients?
#
#   julia --project=. scripts/probe_gradients.jl FR IT DE
#
# alpha and B come from the old engine's table and were never re-derived. Data
# counterparts, non-tertiary over tertiary, ages 25-64:
#   alpha: mean hourly earnings, Eurostat Structure of Earnings Survey 2022
#          (earn_ses22_16, B-S, enterprises with 10+ employees), the two
#          non-tertiary levels weighted by employees (earn_ses22_04). In the
#          model alpha is the pay per unit of effort, so its ratio is the hourly
#          earnings ratio.
#   B:     share with someone to ask for help, EU-SILC 2015 (ilc_scp15), the two
#          non-tertiary levels weighted by population (lfsa_pgaed).
# Each ratio is imposed keeping the population-weighted mean of the parameter,
# and the social technology is refitted to the same participation targets. The
# savings side (phi, beta) is NOT recalibrated: this is a diagnostic of the
# social block only.
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))

const HOURLY = Dict("FR" => 0.631, "DE" => 0.592, "IT" => 0.644)
const HELP   = Dict("FR" => 0.941, "DE" => 0.979, "IT" => 0.927)

for code in ARGS
    base = country_config(code; config = "GSA", S = true, A = true)
    b0 = solve_economy(base); thr = [(b0.ypov, b0.abar)]
    cs = cells_of(base); sh = (cs[1].share, cs[2].share)
    row = country_rows()[code]
    targets = (parse(Float64, row["part_low"]), parse(Float64, row["part_high"]))
    keepmean(v, ratio) = (m = sh[1] * v[1] + sh[2] * v[2]; hi = m / (sh[1] * ratio + sh[2]); (ratio * hi, hi))
    function band(c, fi)
        rows = scan_technology(c, fi, collect(0.30:0.02:1.50), collect(2.0:0.05:25.0);
                               targets = targets, selected_only = true)
        best = rows[argmin([x.loss for x in rows])]
        ok = [x for x in rows if x.loss <= 0.035]
        (best = best, n = length(ok),
         lo = isempty(ok) ? NaN : minimum(x.mult for x in ok),
         hi = isempty(ok) ? NaN : maximum(x.mult for x in ok))
    end
    αn = keepmean(base.alpha, HOURLY[code]); Bn = keepmean(base.B, HELP[code])
    say("\n", code, " targets ", targets, " | carried over alpha ", base.alpha, " B ", base.B,
        " | data alpha ", round.(αn, digits = 3), " B ", round.(Bn, digits = 3))
    fi0 = families(base; thresholds = thr)
    t0 = time()
    cα = SAGEConfig(base; alpha = αn)
    fiα = families(cα; thresholds = thr)
    say(@sprintf("  families at the data alpha built in %.1f min", (time() - t0) / 60))
    for (name, c, fi) in (("carried over", base, fi0),
                          ("B from data", SAGEConfig(base; B = Bn), fi0),
                          ("alpha from data", cα, fiα),
                          ("both from data", SAGEConfig(cα; B = Bn), fiα))
        r = band(c, fi)
        say(@sprintf("  %-16s best kappa %5.2f sigma %4.2f rootloss %.4f (low %.3f high %.3f) mult %5.1f | %2d acceptable sigmas, mult %.1f to %.1f",
                     name, r.best.κ, r.best.σ, r.best.loss, r.best.lo, r.best.hi, r.best.mult, r.n, r.lo, r.hi))
    end
end
say("DONE")
