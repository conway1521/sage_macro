# The unemployed's own participation (V3_START.md section 111; the methods review of 18 October). Until now the
# measured ratio of the unemployed's participation rate to the employed's was imposed when results were added up,
# while inside the household problem the unemployed chose freely, so search answered to a participation rate
# that was not the one reported. Here the unemployed choose like everyone else, with a belonging scale of their
# own (`belong_u`), fitted so that their chosen rate is the measured ratio times the employed rate. With A on, the
# search costs are refitted at the same time, since the belonging of the unemployed changes the reward to work.
#
# As in probe_search.jl for G+S+A, the participation equilibrium is held at the calibration's rate (the imposed
# rule gave the same aggregate, so holding it is consistent), and the rates are those of each cell's households
# over the belonging scales the equilibrium puts them on, on a coarse grid of scales with its weights carried on.
#
#   julia --project=scripts/run_env scripts/probe_unemp_rule.jl CODE GS|GSA rate=X
include(joinpath(@__DIR__, "modular_workers.jl"))
using Printf
code = uppercase(ARGS[1]); CFG = uppercase(ARGS[2])
RATE0 = parse(Float64, ARGS[findfirst(a -> startswith(a, "rate="), ARGS)][6:end])
hasA = occursin('A', CFG)
say(x...) = (println(x...); flush(stdout))
const UCOARSE = [0.0, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0, 11.0, 15.0, 20.0, 30.0]

c0 = country_config(code; config = CFG, v3 = :v5m, S = true, A = hasA)
target = c0.ratio_target
isnan(target) && error("no measured ratio for $code")
ARG = c0.omega + (1 - c0.omega) * RATE0
say(@sprintf("%s %s%s | measured ratio of the unemployed's participation to the employed's %.3f | equilibrium rate %.4f (held)",
             code, CFG, hasA ? " (dread in choices, search)" : "", target, RATE0))

"Participation of the employed and the out of work, and (with search) the chances chosen, by cell."
function rates(c)
    c = floor_effort(c); cs = cells_of(c); _, bw = betas_by_cell(c)
    cT = SAGEConfig(c; lumptax = c.lumptax + ui_tax_of(c))
    nc = length(UCOARSE)
    map(1:2) do g
        wf = node_weights(c, cs[g].B, ARG); wc = zeros(nc)
        for (j, u) in enumerate(c.ugrid)
            wf[j] == 0 && continue
            k = clamp(searchsortedlast(UCOARSE, u), 1, nc - 1)
            t = clamp((u - UCOARSE[k]) / (UCOARSE[k+1] - UCOARSE[k]), 0.0, 1.0)
            wc[k] += wf[j] * (1 - t); wc[k+1] += wf[j] * t
        end
        ps = params_of(cT, cs[g])
        jobs = [(k, j) for k in eachindex(ps) for j in 1:nc if wc[j] > 0]
        res = (nworkers() > 1 ? pmap : map)(jobs) do (k, j)
            p = update(ps[k]; social_strength = UCOARSE[j])
            s = solve_participation_logit(p, 1.0; theta = c.theta, full = true)
            λ, P = s.lambda, s.P1; emp = s.z_vals .> 0; n = size(λ, 2); nB = n ÷ 3
            mE = sum(λ[:, emp]); pE = sum(λ[:, emp] .* P[:, emp]); mU = sum(λ[:, .!emp]); pU = sum(λ[:, .!emp] .* P[:, .!emp])
            x = isempty(p.search_k) ? zeros(size(λ)) : s.search_x
            (mE, pE, mU, pU, sum(λ[:, 1:nB]), sum(λ[:, 1:nB] .* x[:, 1:nB]), sum(λ[:, 2nB+1:n]), sum(λ[:, 2nB+1:n] .* x[:, 2nB+1:n]))
        end
        acc = zeros(8)
        for ((k, j), v) in zip(jobs, res)
            acc .+= (bw[g][k] * wc[j]) .* collect(v)
        end
        (share = cs[g].share, mE = acc[1], pE = acc[2], mU = acc[3], pU = acc[4], xU = acc[6] / acc[5], xL = acc[8] / acc[7])
    end
end
ratio_of(r) = (sum(x.share * x.pU for x in r) / sum(x.share * x.mU for x in r)) / (sum(x.share * x.pE for x in r) / sum(x.share * x.mE for x in r))

# the scale and (with A) the search costs, by secants in logs; starting points: the file's, else one and the search file's
bu = c0.unemployed_ratio === nothing ? c0.belong_u : 1.0
kU = hasA ? collect(c0.search_kU) : Float64[]; kL = hasA ? collect(c0.search_kL) : Float64[]
tU = c0.f_find; tL = collect(c0.f_long)
prev = Dict{Any,Tuple{Float64,Float64}}()
function step!(key, v, m, target, slope0)
    lv, lm = log(v), log(max(m, 1e-6)); slope = slope0
    if haskey(prev, key)
        (lv0, lm0) = prev[key]
        abs(lv - lv0) > 1e-8 && (sl = (lm - lm0) / (lv - lv0); sign(sl) == sign(slope0) && abs(sl) > 0.05 && (slope = sl))
    end
    prev[key] = (lv, lm)
    exp(lv + clamp((log(target) - lm) / slope, -1.0, 1.0))
end
c = c0; r = nothing; ok = false
for it in 1:30
    global c = SAGEConfig(c0; unemployed_ratio = nothing, belong_u = bu,
                          (hasA ? (search = true, search_kU = Tuple(kU), search_kL = Tuple(kL)) : (;))...)
    global r = rates(c)
    rr = ratio_of(r)
    gapR = abs(rr - target)
    gapS = hasA ? maximum(max(abs(r[g].xU - tU), abs(r[g].xL - tL[g])) for g in 1:2) : 0.0
    say(@sprintf("  step %2d: belong_u %.4f -> ratio %.4f (target %.3f; employed %.4f, out of work %.4f)%s",
                 it, bu, rr, target, sum(x.share * x.pE for x in r) / sum(x.share * x.mE for x in r),
                 sum(x.share * x.pU for x in r) / sum(x.share * x.mU for x in r),
                 hasA ? @sprintf(" | k %.4g %.4g / %.4g %.4g: chances %.4f %.4f / %.4f %.4f (gap %.1e)", kU..., kL..., r[1].xU, r[2].xU, r[1].xL, r[2].xL, gapS) : ""))
    if gapR < 2e-3 && gapS < 3e-3
        global ok = true; break
    end
    global bu = step!(:bu, bu, rr, target, 1.0)
    if hasA
        for g in 1:2
            kU[g] = step!((:U, g), kU[g], r[g].xU, tU, -1 / c0.search_gamma)
            kL[g] = step!((:L, g), kL[g], r[g].xL, tL[g], -1 / c0.search_gamma)
        end
    end
end
ok || say("  NOT CONVERGED: the values below miss their targets")
say(@sprintf("\nfitted: belong_u = %.6f%s", bu, hasA ? @sprintf(" | search_kU = %.6g %.6g, search_kL = %.6g %.6g", kU..., kL...) : ""))
tag = hasA && get(ENV, "SAGE_DREAD_CHOICE", "0") == "1" ? "_D" : ""
open(joinpath(@__DIR__, "unemp_v5m_$(code)_$(CFG)$(tag).txt"), "w") do io
    println(io, "# written by probe_unemp_rule.jl $(code) $(CFG) rate=$(RATE0): the unemployed's own belonging scale, their chosen participation the measured ratio ($(target)) times the employed's, the equilibrium held; read by country_config")
    @printf(io, "belong_u = %.6f\n", bu)
end
hasA && open(joinpath(@__DIR__, "search_v5m_$(code)_$(CFG).txt"), "w") do io
    println(io, "# written by probe_unemp_rule.jl $(code) $(CFG) rate=$(RATE0): search cost levels refitted with the unemployed's own participation; read by country_config")
    @printf(io, "search_gamma = %.4f\nsearch_kU = %.6g %.6g\nsearch_kL = %.6g %.6g\n", c0.search_gamma, kU..., kL...)
end
println("DONE")
