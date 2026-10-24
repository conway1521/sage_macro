# Stage 1d: job search on the quarterly economy (V3_START.md section 132). The chance of finding work in a period out
# of work is the effort x chosen at cost k x^(1+gamma)/(1+gamma), gamma = 0.35 (DellaVigna, Lindner, Reizer and
# Schmieder 2017, whose search intensity is the chance of finding work: the arrival rate is one). An arrival rate and
# a cost level are not identified apart from exits alone (scaling the one up and the other by the matching power leaves
# every exit unchanged), so the normalisation is theirs, and the cost level varies by period of the spell and by cell.
# Fitted so that the chance chosen, averaged over the stationary distribution, equals the duration-based exit to work
# of stage 1b (data/labour/duration_hazards.csv, through duration_config) in every period of the spell and in L, in
# both cells: k <- k (chosen / target)^gamma, the exact step when the gain from work does not move. Patience from the
# quarterly calibration of the configuration (calibration_v5q_<C>_<CFG>.txt), dread in choices over the year; the
# cost of being out of work in wellbeing only. The response of job finding to benefits is a test, not a target.
#
# RESUME (third argument `resume`): start from search_v5q_<C>_<CFG>.txt, the costs of an earlier run. The step is
# damped (DAMP = 0.6 of the exact exponent): the cost of one period moves the gain from work in the periods before it,
# so the undamped step overshot and alternated in the first two periods (Germany, run 40015089568).
#
#   SAGE_DREAD_CHOICE=1 julia --project=scripts/run_env scripts/calibrate_search_q.jl CODE CONFIG [ROUNDS] [resume] [DAMP] [grouped]
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); cfg = uppercase(ARGS[2]); rounds = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 8
resume = length(ARGS) >= 4 && ARGS[4] == "resume"; DAMP = length(ARGS) >= 5 ? parse(Float64, ARGS[5]) : 0.6   # 1: the exact step (Italy converges without alternating)
# GROUPED (sixth argument `grouped`): one cost level per duration group of the data (quarter 1, quarter 2, quarters 3-4,
# quarters 5-8, L), the groups whose hazards the bands identify; each group's step from the mean chosen chance over its
# quarters. Per quarter, neighbouring quarters' costs alternated in France's tertiary cell (run 40081907881).
grouped = length(ARGS) >= 6 && ARGS[6] == "grouped"
say(x...) = (println(x...); flush(stdout))
# dread in choices (SAGE_DREAD_CHOICE=1), or in wellbeing only where the country's calibration with it in choices
# failed (France, section 133: the configuration's file then carries G's patience)
say("dread ", get(ENV, "SAGE_DREAD_CHOICE", "0") == "1" ? "in choices" : "in wellbeing only")
readkv(f) = (d = Dict{String,String}(); for l in eachline(f); t = strip(l); (isempty(t) || startswith(t, "#") || !occursin("=", t)) && continue;
                 k, v = strip.(split(t, "=", limit = 2)); d[k] = v; end; d)
q = readkv(joinpath(@__DIR__, "calibration_v5q_$(code)_$(cfg).txt")); β = parse(Float64, q["beta_annual"]); gap = parse(Float64, q["beta_gap_annual"])
s1 = readkv(joinpath(@__DIR__, "search_v5m_$(code)_GA.txt"))
kU = parse.(Float64, split(s1["search_kU"])); kL = parse.(Float64, split(s1["search_kL"])); γs = 0.35
S = occursin('S', cfg)
ca = country_config(code; config = cfg, v3 = :v5m, S = S, A = true)
cb = duration_config(ca)
c = SAGEConfig(cb; beta_bar = β^(1 / 4), beta_cell = ((β - gap)^(1 / 4) - β^(1 / 4), 0.0), out_ls = 0.0, search = true, search_gamma = γs)
S && (c = SAGEConfig(c; kappa = parse(Float64, q["kappa"]), sigma_m = parse(Float64, q["sigma_m"]), unemployed_ratio = parse(Float64, country_rows()[code]["ratio"])))
target = vcat(cb.hU_vec, cb.f_long[1])
k = [fill(kU[g], cb.nU + 1) for g in 1:2]; for g in 1:2; k[g][end] = kL[g]; end
if resume
    sq = readkv(joinpath(@__DIR__, "search_v5q_$(code)_$(cfg).txt"))
    k = [parse.(Float64, split(sq["search_kq_cell$g"])) for g in 1:2]
    say("resuming from search_v5q_$(code)_$(cfg).txt")
end
GROUPS = [[1], [2], [3, 4], [5, 6, 7, 8], [9]]
if grouped
    for g in 1:2, G in GROUPS
        m = sum(k[g][G]) / length(G); k[g][G] .= m
    end
    say("cost by duration group: ", string(GROUPS))
end
say(@sprintf("%s %s quarterly, patience %.4f gap %.4f: target exits to work by period of the spell %s, L %.4f", code, cfg, β, gap,
             string(round.(cb.hU_vec, digits = 4)), cb.f_long[1]))
best = nothing
for it in 1:rounds
    cc = SAGEConfig(c; search_kq = (copy(k[1]), copy(k[2])))
    t = @elapsed r = solve_economy(cc; cache = false)
    err = maximum(abs(r.search_exit[g][d] / target[d] - 1) for g in 1:2, d in eachindex(target))
    say(@sprintf("round %d: worst relative error %.3f | htm %.4f | MPC 12m %.4f | fall Kolsrud %.4f | %.1f min", it, err, r.hand_to_mouth_kvw, r.mpc12, r.fall_kolsrud, t / 60))
    for g in 1:2
        say(@sprintf("  cell %d chosen %s | cost %s", g, string(round.(r.search_exit[g], digits = 4)), string(round.(k[g], digits = 3))))
    end
    global best = (k = deepcopy(k), err = err, r = r)
    err < 0.03 && break
    if grouped
        for g in 1:2, G in GROUPS
            f = sum(r.search_exit[g][G]) / sum(target[G])
            k[g][G] .*= clamp(f^(DAMP * γs), 0.5, 2.0)
        end
    else
        for g in 1:2, d in eachindex(target)
            k[g][d] *= clamp((r.search_exit[g][d] / target[d])^(DAMP * γs), 0.5, 2.0)
        end
    end
end
say("# search_v5q_$(code)_$(cfg).txt, written by calibrate_search_q.jl ($(best.err < 0.03 ? "fitted" : "best round, worst error $(round(best.err, digits = 3))")); arrival rate one")
say(@sprintf("search_gamma = %.4f", γs))
for g in 1:2; say("search_kq_cell$g = ", join([@sprintf("%.5f", x) for x in best.k[g]], " ")); end
println("DONE")
