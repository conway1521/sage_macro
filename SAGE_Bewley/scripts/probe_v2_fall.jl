# The fall diagnosis (2 November; V3_START.md): why version 2's fall on job loss, measured as Kolsrud, Landais,
# Nilsson and Spinnewijn (2018) measure it, is four to five times their 0.044. On the calibrated quarterly G+A (as
# probe_v2_benefit.jl), nothing fitted, one change at a time:
#   base               the fall, its two quarters, and the fall among job losers who were hand-to-mouth in their last
#                      quarter in work against the rest (agency_shock.jl part 2, kolmass[6:15]), with the shares of each
#   beta=B             annual patience B in both cells (the gap kept), e.g. version 1's, to read the buffer channel
#   nodread            dread out of choices (wellbeing only)
#   rr=X               the entitled benefit scaled by X in every quarter (the tax held), to read the replacement channel
#
#   julia --project=scripts/run_env scripts/probe_v2_fall.jl CODE [beta=B] [nodread] [rr=X]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = "GA"
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
arg(k) = (i = findfirst(a -> startswith(a, k * "="), ARGS); i === nothing ? nothing : parse(Float64, split(ARGS[i], "=")[2]))
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
arg("beta") === nothing || (β = arg("beta"))
sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg).txt"))
γq = parse(Float64, sq["search_gamma"])
kq = (parse.(Float64, split(sq["search_kq_cell1"])), parse.(Float64, split(sq["search_kq_cell2"])))
ca = country_config(code; config = cfg, v3 = :v5m, S = false, A = true)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = γq, search_kq = kq)
get(q, "dread_mode", "") == "overlay" && (c = SAGEConfig(c; dread_mode = :overlay))
"nodread" in ARGS && (c = SAGEConfig(c; dread_mode = :overlay))
arg("rr") === nothing || (c = SAGEConfig(c; rrU_vec = arg("rr") .* c.rrU_vec))
r = solve_economy(c; cache = false)
cs = cells_of(c)
K = sum(cs[g].share .* r.pooled[g].kolmass[1:15] for g in 1:2)
"Kolsrud's fall from five sums: entrants, their consumption in work, in quarter 1, survivors to quarter 2, theirs."
function fallK(k)
    (k[1] <= 0 || k[4] <= 0) && return NaN
    c0 = k[2] / k[1]; S2 = k[4] / k[1]
    1 - (13 * k[3] / k[1] + 7 * S2 * k[5] / k[4]) / ((13 + 7 * S2) * c0)
end
println(code, " G+A, version 2, fall diagnosis: annual patience ", round(β, digits = 4), " (gap ", round(gap, digits = 4), ")",
        c.dread_mode === :overlay ? ", dread in wellbeing only" : ", dread in choices", arg("rr") === nothing ? "" : ", entitled benefit x $(arg("rr"))")
@printf("  fall (Kolsrud) %.4f, quarter 1 %.4f, quarter 2 %.4f | hand-to-mouth %.4f, MPC 12 months %.4f\n",
        r.fall_kolsrud, r.fall_q1, r.fall_q2, r.hand_to_mouth_kvw, r.mpc12)
@printf("  job losers hand-to-mouth in their last quarter in work: share %.4f, fall %.4f | the rest: fall %.4f | check, all %.4f\n",
        K[6] / K[1], fallK(K[6:10]), fallK(K[11:15]), fallK(K[1:5]))
println("DONE")
