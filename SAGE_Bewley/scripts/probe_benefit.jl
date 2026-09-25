# Can each country reach its hand-to-mouth target once the benefit is averaged
# over an unemployment spell instead of a fixed twelve months? A diagnostic:
# nothing is written except this log. For each country, fit effort on the G+A
# economy at a moderate spread, then trace hand-to-mouth across discount spreads
# from 0 to 0.15 and report the spread each aim needs.
#
# Spell-averaged replacement (TaxBEN 2023, single, 100 percent of the average
# wage, social assistance in, housing out; monthly exit hazard from the
# long-term unemployment share): FR 0.653, DE 0.456, IT 0.374, US 0.221,
# against the twelve-month averages 0.680, 0.590, 0.597, 0.132.
#
#   SAGE_WORKERS=4 julia --project=. scripts/probe_benefit.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
say(args...) = (println(args...); flush(stdout))
const NEWRR = Dict("FR" => 0.653, "DE" => 0.456, "IT" => 0.374, "US" => 0.221)
const GAP_GSA = 0.029          # what cohesion adds to hand-to-mouth (France, EU-SILC)
soff(code, phi, sp) = _solve(country_config(code; config = "GA", S = false, A = true, phi = phi,
                                            beta_spread = sp, rr = NEWRR[code]), nothing; disk = false)
for code in ("IT", "US", "DE", "FR")
    t0 = time(); row = country_rows()[code]
    et = parse(Float64, row["effort_target"]); ht = parse(Float64, row["htm_target"])
    lo, hi = 3.0, 40.0
    for _ in 1:12
        mid = 0.5 * (lo + hi)
        soff(code, mid, 0.04).mean_effort_employed > et ? (lo = mid) : (hi = mid)
    end
    phi = round(0.5 * (lo + hi); digits = 2)
    sps = collect(0.0:0.01:0.15)
    hs = [soff(code, phi, sp).hand_to_mouth for sp in sps]
    need(target) = (k = findfirst(>=(target), hs); k === nothing ? "UNREACHABLE" :
                    k == 1 ? "at spread 0" :
                    @sprintf("spread %.3f", sps[k-1] + (target - hs[k-1]) / (hs[k] - hs[k-1]) * 0.01))
    say(@sprintf("\n%s  rr %.3f (was %s)  phi %.2f  [%.1f min]", code, NEWRR[code], row["rr"], phi, (time() - t0) / 60))
    say("  hand-to-mouth by spread: ", join([@sprintf("%.2f:%.3f", s, h) for (s, h) in zip(sps, hs)], "  "))
    say(@sprintf("  G and G+A aim %.2f: %s  |  G+S+A aim %.3f: %s", ht, need(ht), ht - GAP_GSA, need(ht - GAP_GSA)))
end
say("DONE")
