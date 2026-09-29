# Why is the consumption drop on job loss too large in DE and IT? The model has
# one unemployment state, so it pays the replacement rate averaged over the whole
# spell (long-term months included), while the data measure the drop in the first
# year. Same calibrated G+S+A economies, parameters fixed, with the first-year
# (time-weighted, 12-month) TaxBEN rate instead. No recalibration: this sizes the
# channel, it is not a result.
#
#   julia --project=scripts/run_env scripts/probe_drop.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
FIRST_YEAR = Dict("FR" => 0.680, "DE" => 0.590, "IT" => 0.602)   # data/build_country_table.py inputs, 12-month time-weighted
for code in ("FR", "DE", "IT")
    c = country_config(code; config = "GSA", S = true, A = true)
    for (lab, cc) in (("spell rr $(round(c.rr; digits = 3))", c),
                      ("first-year rr $(FIRST_YEAR[code])", SAGEConfig(c; rr = FIRST_YEAR[code])))
        r = solve_economy(cc)
        @printf("%s %-22s drop on job loss %.3f | protection if hit %.4f | MPC %.3f | poor htm %.4f | participation %.4f\n",
                code, lab, r.consumption_drop, r.A_cond, r.mpc, r.hand_to_mouth_kvw, r.rate)
        flush(stdout)
    end
end
println("DONE")
