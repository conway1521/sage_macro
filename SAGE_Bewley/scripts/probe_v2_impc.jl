# The macro review's tests of version 2 (31 October; V3_START.md): on the calibrated quarterly G+A, the same as
# probe_v2_benefit.jl, two outputs a macroeconomist reads first.
#
# 1. The profile of spending out of a windfall of one month's income, quarter by quarter for H quarters and summed by
#    year: the intertemporal MPCs (Auclert, Rognlie and Straub), to set against the lottery evidence of Fagereng, Holm
#    and Natvik (2021). The windfall is the HFCS question's (one month of the household's own income); theirs are
#    larger, so the comparison is of shape and of the first year more than of the tail.
# 2. The twelve-month MPC by quintile of liquid wealth, against the HFCS 2021 answers by the same quintiles
#    (data/hfcs_targets.csv is not needed: the five values are printed by the reader from the aggregate table). The HFCS
#    quintiles are of all households, the model's of its working-age population.
#
#   julia --project=scripts/run_env scripts/probe_v2_impc.jl CODE [H]
ENV["SAGE_IMPC_H"] = length(ARGS) >= 2 ? ARGS[2] : "20"          # set before the workers start, which inherit it
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = "GA"; H = parse(Int, ENV["SAGE_IMPC_H"])
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg).txt"))
γq = parse(Float64, sq["search_gamma"])
kq = (parse.(Float64, split(sq["search_kq_cell1"])), parse.(Float64, split(sq["search_kq_cell2"])))
ca = country_config(code; config = cfg, v3 = :v5m, S = false, A = true)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = γq, search_kq = kq)
get(q, "dread_mode", "") == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
r = solve_economy(c; cache = false)
cs = cells_of(c); P = r.pooled
M = sum(cs[g].share * sum(P[g].mass) for g in 1:2)
impc = sum(cs[g].share .* P[g].impcmass for g in 1:2) ./ M
println(code, " G+A, version 2: spending out of a windfall of one month's income, by quarter since receipt (quarter 1 = the quarter of receipt)")
println("  by quarter: ", round.(impc, digits = 4))
ny = H ÷ 4
@printf("  by year: %s | cumulative after %d years %.4f\n", string([round(sum(impc[4k+1:4k+4]), digits = 4) for k in 0:ny-1]), ny, sum(impc[1:4ny]))
@printf("  check: twelve-month MPC pooled %.4f, the sum of the first four quarters %.4f\n", r.mpc12, sum(impc[1:4]))
# the twelve-month MPC by quintile of liquid wealth: each node's mass split across the quintile bands it straddles, so a
# mass point (at the borrowing limit) is shared between quintiles as a survey's tied ranks would be
lam = sum(cs[g].share .* P[g].lama for g in 1:2); num = sum(cs[g].share .* P[g].mpc12a for g in 1:2)
F = cumsum(lam) ./ sum(lam); F0 = [0.0; F[1:end-1]]
lf = sum(cs[g].share .* P[g].lamf for g in 1:2); nf = sum(cs[g].share .* P[g].mpc12f for g in 1:2)
lz = sum(cs[g].share .* P[g].lamz for g in 1:2)
qm = zeros(5); qn = zeros(5); qfm = zeros(5); qfn = zeros(5); qz = zeros(5)
for i in eachindex(lam), k in 1:5
    lo, hi = (k - 1) / 5, k / 5
    ov = max(0.0, min(F[i], hi) - max(F0[i], lo)); w = F[i] > F0[i] ? ov / (F[i] - F0[i]) : 0.0
    qm[k] += w * num[i]; qn[k] += w * lam[i]; qfm[k] += w * nf[i]; qfn[k] += w * lf[i]; qz[k] += w * lz[i]
end
# the floor's part (the poorest-quintile check, 1 November): the share of each quintile the floor tops up now, their
# MPC, and the MPC of the rest
@printf("  share with no income (no windfall, counted at zero), by quintile: %s; MPC by quintile without them: %s\n",
        string(round.(qz ./ qn, digits = 4)), string(round.(qm ./ (qn .- qz), digits = 4)))
@printf("  share topped up by the floor, by quintile: %s\n", string(round.(qfn ./ qn, digits = 4)))
@printf("  MPC of those topped up: %s; of the rest: %s\n", string(round.(qfm ./ max.(qfn, 1e-300), digits = 4)),
        string(round.((qm .- qfm) ./ max.(qn .- qfn, 1e-300), digits = 4)))
@printf("  twelve-month MPC by liquid wealth quintile Q1..Q5: %s (pooled %.4f)\n", string(round.(qm ./ qn, digits = 4)), sum(num) / sum(lam))
@printf("  mass at the lowest asset node %.4f\n", lam[1] / sum(lam))
println("DONE")
