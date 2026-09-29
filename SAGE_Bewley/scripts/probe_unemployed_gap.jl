# Anatomy of the unemployed participation gap. The data: the unemployed take
# part at about 0.56 of the employed rate (France, INSEE; ESS 0.80 to 0.85).
# The model with the rule off: several times the employed rate, because the
# unemployed have more time. Which measurable mechanism closes the gap, holding
# everything else at France's G+S+A calibration?
#
#   - money cost of taking part (pcost, model income units; mean income about 0.64)
#   - committed time when out of work (search_time, share of the time endowment):
#     home production and job search. Anchor: about 30% of forgone market hours
#     go to home production (Aguiar, Hurst and Karabarbounis 2013); forgone
#     market time is about 0.64 of the endowment, so about 0.19.
#   - belonging when out of work (belong_u): stigma or norms (Stutzer and Lalive
#     2004), the least measurable.
#
#   julia --project=scripts/run_env scripts/probe_unemployed_gap.jl
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
c0 = SAGEConfig(country_config("FR"; config = "GSA", S = true, A = true); unemployed_ratio = nothing)
rows = [("rule off, nothing else", c0)]
for pc in (0.01, 0.02, 0.04, 0.08); push!(rows, (@sprintf("money cost %.2f (%.1f%% of mean income)", pc, 100 * pc / 0.64), SAGEConfig(c0; pcost = pc))); end
for st in (0.05, 0.10, 0.19, 0.30); push!(rows, (@sprintf("committed time out of work %.2f", st), SAGEConfig(c0; search_time = st))); end
for bu in (0.8, 0.6, 0.4); push!(rows, (@sprintf("belonging out of work %.1f", bu), SAGEConfig(c0; belong_u = bu))); end
push!(rows, ("measured together: money 0.02, time 0.19", SAGEConfig(c0; pcost = 0.02, search_time = 0.19)))
@printf("%-46s %8s %8s %8s %8s %8s %6s\n", "mechanism", "overall", "employed", "unempl.", "U/E", "agency", "mult")
for (lab, c) in rows
    t = @elapsed r = try solve_economy(c) catch err; println(lab, ": ", sprint(showerror, err)); continue end
    @printf("%-46s %8.4f %8.4f %8.4f %8.3f %8.4f %6.1f  [%.1f min]\n", lab, r.rate, r.rate_E, r.rate_U,
            r.rate_U / r.rate_E, r.A, 1 / (1 - r.slope), t / 60)
    flush(stdout)
end
println("data: U/E 0.561 (INSEE SRCV 2008); ESS 0.80 to 0.85 (data/ess)")
println("DONE")
