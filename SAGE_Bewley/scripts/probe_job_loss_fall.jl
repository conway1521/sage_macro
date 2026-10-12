# Where the fall in consumption on job loss comes from (V3_START.md section 87): a reading of the calibrated
# G of each country under three changes, one at a time, with nothing refitted. The measure is the model's own:
# over those in work, one less consumption in a first full year out of work over consumption in work, at the
# same assets and productivity.
#   base        as calibrated
#   no state    without the state out of work: the first year's benefit goes on (what a job loser looks ahead to)
#   new losers  the first year's job-finding rate that of people out of work under a year (the quarterly rate
#               of Eurostat lfsi_long_e01 held for four quarters) in place of the rate over all the unemployed,
#               who are mostly long spells; job loss and the exit from the state follow as they are defined
#   insured     the first year replaced in full: what is left is the response to the prospect alone
#
#   julia --project=scripts/run_env scripts/probe_job_loss_fall.jl [CODE ...]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
codes = isempty(ARGS) ? ["FR", "DE", "IT"] : uppercase.(ARGS)
QSHORT = Dict("FR" => 0.32, "DE" => 0.37, "IT" => 0.28)          # lfsi_long_e01, 2023, ages 15 to 74, out of work under a year
for code in codes
    c = country_config(code; config = "G", v3 = :v5m, S = false, A = false)
    row_ = country_rows()[code]; u = (parse(Float64, row_["u_low"]), parse(Float64, row_["u_high"]))
    s = (manual_input(code, "jobless_low"), manual_input(code, "jobless_high"))
    f2 = 1 - (1 - QSHORT[code])^4
    d2 = ntuple(g -> u[g] * f2 / (1 - u[g]), 2); fl2 = ntuple(g -> d2[g] * (1 - f2) / (s[g] / (1 - s[g]) - d2[g]), 2)
    variants = [("base", c),
                ("no state", SAGEConfig(c; f_long = (NaN, NaN))),
                ("new losers", SAGEConfig(c; f_find = f2, delta = d2, f_long = fl2)),
                ("insured", SAGEConfig(c; rr = 1.0, rr_public = c.rr_public + 1 - c.rr))]
    @printf("\n%s G | first year replaced at %.3f | finds work within the year %.3f (new losers %.3f) | exit from the state %.3f %.3f (new losers %.3f %.3f) | job loss %.4f %.4f (new losers %.4f %.4f)\n",
            code, c.rr, c.f_find, f2, c.f_long..., fl2..., c.delta..., d2...)
    @printf("  %-12s %10s %10s %10s %10s %10s\n", "", "fall", "htm", "median", "MPC", "out of work")
    for (nm, cv) in variants
        try
            r = solve_economy(cv; cache = false)
            @printf("  %-12s %10.4f %10.4f %10.4f %10.4f %10.4f\n", nm, r.consumption_drop, r.hand_to_mouth_kvw, r.wealth_p50 / r.median_income, r.mpc, r.unemployment)
        catch err
            @printf("  %-12s no solution: %s\n", nm, first(replace(sprint(showerror, err), "\n" => " "), 140))
        end
        flush(stdout)
    end
end
println("DONE")
